using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using BepTroLy.API.Data;
using BepTroLy.API.Models;
using Microsoft.EntityFrameworkCore;

namespace BepTroLy.API.Services;

/// <summary>
/// Service tích hợp Gemini Batch API (REST) — xử lý hàng loạt với 50% chi phí.
/// Sử dụng inline requests (tổng < 20MB).
/// </summary>
public class GeminiBatchService
{
    private const string GeminiBaseUrl = "https://generativelanguage.googleapis.com/v1beta";
    private const string DefaultModel = "gemini-3-pro";

    private readonly string? _apiKey;
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly AppDbContext _db;
    private readonly ILogger<GeminiBatchService> _logger;

    public GeminiBatchService(
        IConfiguration configuration,
        IHttpClientFactory httpClientFactory,
        AppDbContext db,
        ILogger<GeminiBatchService> logger)
    {
        _apiKey = configuration["Gemini:ApiKey"];
        _httpClientFactory = httpClientFactory;
        _db = db;
        _logger = logger;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // 1. Tạo Batch Job
    // ═══════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Tạo batch job gợi ý món ăn cho user dựa trên pantry.
    /// Gửi nhiều prompt (món nhanh, món chay, món miền, ...) cùng lúc.
    /// </summary>
    public async Task<BatchJob> CreateRecipeBatchForUserAsync(
        int userId,
        Dictionary<string, object>? preferences = null,
        CancellationToken ct = default)
    {
        if (string.IsNullOrEmpty(_apiKey))
            throw new InvalidOperationException("Gemini API key chưa được cấu hình.");

        // Lấy nguyên liệu trong tủ lạnh
        var pantryItems = await _db.PantryItems
            .Where(p => p.UserId == userId && p.Status == "active")
            .Select(p => p.NameVi)
            .ToListAsync(ct);

        var ingredientsList = pantryItems.Count > 0
            ? string.Join(", ", pantryItems.Take(50))
            : string.Empty;

        preferences ??= new Dictionary<string, object>();

        var cuisine = GetPref(preferences, "cuisine", "Việt Nam");
        var regionalSeasoning = GetPref(preferences, "regional_seasoning", "");

        // Tạo nhiều prompt cho các loại món khác nhau
        var prompts = BuildBatchPrompts(ingredientsList, cuisine, regionalSeasoning);

        // Gọi Gemini Batch API
        var batchName = await CallGeminiBatchApiAsync(prompts, "recipe-batch-user-" + userId, ct);

        // Lưu vào DB
        var batchJob = new BatchJob
        {
            BatchName = batchName,
            DisplayName = $"Gợi ý hàng loạt cho user {userId}",
            State = "JOB_STATE_PENDING",
            UserId = userId,
            RequestCount = prompts.Count,
            InputData = JsonSerializer.Serialize(prompts.Select(p => new { prompt = p.Length > 200 ? p[..200] + "..." : p })),
        };

        _db.BatchJobs.Add(batchJob);
        await _db.SaveChangesAsync(ct);

        _logger.LogInformation("Created batch job {BatchName} for user {UserId} with {Count} requests",
            batchName, userId, prompts.Count);

        return batchJob;
    }

    /// <summary>
    /// Tạo batch job tùy chỉnh với danh sách prompt.
    /// </summary>
    public async Task<BatchJob> CreateCustomBatchAsync(
        List<string> prompts,
        string displayName,
        int? userId = null,
        CancellationToken ct = default)
    {
        if (string.IsNullOrEmpty(_apiKey))
            throw new InvalidOperationException("Gemini API key chưa được cấu hình.");

        if (prompts.Count == 0)
            throw new ArgumentException("Cần ít nhất 1 prompt.");

        var batchName = await CallGeminiBatchApiAsync(prompts, displayName, ct);

        var batchJob = new BatchJob
        {
            BatchName = batchName,
            DisplayName = displayName,
            State = "JOB_STATE_PENDING",
            UserId = userId,
            RequestCount = prompts.Count,
            InputData = JsonSerializer.Serialize(prompts.Select(p => new { prompt = p.Length > 200 ? p[..200] + "..." : p })),
        };

        _db.BatchJobs.Add(batchJob);
        await _db.SaveChangesAsync(ct);

        return batchJob;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // 2. Poll trạng thái
    // ═══════════════════════════════════════════════════════════════════════

    /// <summary>Poll trạng thái batch job từ Gemini API và cập nhật DB.</summary>
    public async Task<BatchJob?> PollBatchStatusAsync(int jobId, CancellationToken ct = default)
    {
        var job = await _db.BatchJobs.FindAsync([jobId], ct);
        if (job == null) return null;
        if (job.IsTerminal) return job;

        await PollAndUpdateAsync(job, ct);
        return job;
    }

    /// <summary>Poll và cập nhật trạng thái cho 1 job.</summary>
    public async Task PollAndUpdateAsync(BatchJob job, CancellationToken ct = default)
    {
        if (string.IsNullOrEmpty(_apiKey) || job.IsTerminal) return;

        try
        {
            using var client = _httpClientFactory.CreateClient("Gemini");
            var url = $"{GeminiBaseUrl}/{job.BatchName}?key={_apiKey}";

            using var response = await client.GetAsync(url, ct);
            var responseText = await response.Content.ReadAsStringAsync(ct);

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning("Batch poll failed for {BatchName}: {Status} {Body}",
                    job.BatchName, (int)response.StatusCode, responseText[..Math.Min(200, responseText.Length)]);
                return;
            }

            using var doc = JsonDocument.Parse(responseText);
            var root = doc.RootElement;

            // Trạng thái nằm trong metadata.state
            var state = "JOB_STATE_PENDING";
            if (root.TryGetProperty("metadata", out var metadata) &&
                metadata.TryGetProperty("state", out var stateEl))
            {
                state = stateEl.GetString() ?? "JOB_STATE_PENDING";
            }

            // done field
            var done = root.TryGetProperty("done", out var doneEl) && doneEl.GetBoolean();

            job.State = state;

            if (done || state == "JOB_STATE_SUCCEEDED")
            {
                job.State = "JOB_STATE_SUCCEEDED";
                job.CompletedAt = DateTime.UtcNow;

                // Parse kết quả từ inline responses
                if (root.TryGetProperty("response", out var responseObj))
                {
                    var results = ParseBatchResults(responseObj);
                    job.ResultData = JsonSerializer.Serialize(results);
                    job.SucceededCount = results.Count;
                }

                _logger.LogInformation("Batch job {BatchName} completed with {Count} results",
                    job.BatchName, job.SucceededCount);
            }
            else if (state is "JOB_STATE_FAILED" or "JOB_STATE_CANCELLED" or "JOB_STATE_EXPIRED")
            {
                job.CompletedAt = DateTime.UtcNow;

                if (root.TryGetProperty("error", out var errorEl))
                {
                    job.ErrorMessage = errorEl.TryGetProperty("message", out var msgEl)
                        ? msgEl.GetString()
                        : errorEl.GetRawText();
                }
                else
                {
                    job.ErrorMessage = $"Job ended with state: {state}";
                }

                _logger.LogWarning("Batch job {BatchName} ended: {State} - {Error}",
                    job.BatchName, state, job.ErrorMessage);
            }

            await _db.SaveChangesAsync(ct);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error polling batch job {BatchName}", job.BatchName);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // 3. Lấy kết quả
    // ═══════════════════════════════════════════════════════════════════════

    /// <summary>Lấy kết quả đã parse từ batch job.</summary>
    public async Task<List<Dictionary<string, object>>?> GetBatchResultsAsync(int jobId, CancellationToken ct = default)
    {
        var job = await _db.BatchJobs.AsNoTracking().FirstOrDefaultAsync(j => j.Id == jobId, ct);
        if (job == null) return null;

        if (job.State != "JOB_STATE_SUCCEEDED" || string.IsNullOrEmpty(job.ResultData))
            return null;

        return JsonSerializer.Deserialize<List<Dictionary<string, object>>>(job.ResultData);
    }

    /// <summary>Liệt kê batch jobs cho user.</summary>
    public async Task<List<BatchJob>> ListUserBatchJobsAsync(int userId, int limit = 10, CancellationToken ct = default)
    {
        return await _db.BatchJobs
            .Where(j => j.UserId == userId)
            .OrderByDescending(j => j.CreatedAt)
            .Take(limit)
            .ToListAsync(ct);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Internal: Gọi Gemini Batch API REST
    // ═══════════════════════════════════════════════════════════════════════

    private async Task<string> CallGeminiBatchApiAsync(
        List<string> prompts,
        string displayName,
        CancellationToken ct)
    {
        // Build inline requests theo format REST API
        var inlineRequests = prompts.Select((prompt, index) => new
        {
            request = new
            {
                contents = new[]
                {
                    new
                    {
                        parts = new[] { new { text = prompt } },
                        role = "user"
                    }
                }
            },
            metadata = new { key = $"request-{index + 1}" }
        }).ToList();

        var requestBody = new
        {
            batch = new
            {
                display_name = displayName,
                input_config = new
                {
                    requests = new
                    {
                        requests = inlineRequests
                    }
                }
            }
        };

        var url = $"{GeminiBaseUrl}/models/{DefaultModel}:batchGenerateContent?key={_apiKey}";

        using var client = _httpClientFactory.CreateClient("Gemini");
        var jsonContent = new StringContent(
            JsonSerializer.Serialize(requestBody),
            Encoding.UTF8,
            "application/json");

        using var cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        cts.CancelAfter(TimeSpan.FromSeconds(30));

        using var response = await client.PostAsync(url, jsonContent, cts.Token);
        var responseText = await response.Content.ReadAsStringAsync(cts.Token);

        if (!response.IsSuccessStatusCode)
        {
            throw new HttpRequestException(
                $"Gemini Batch API trả về lỗi {(int)response.StatusCode}: {responseText[..Math.Min(300, responseText.Length)]}");
        }

        // Parse batch name từ response
        // Response format: { "name": "batches/123456", "metadata": { "state": "JOB_STATE_PENDING", ... } }
        using var doc = JsonDocument.Parse(responseText);
        var batchName = doc.RootElement.TryGetProperty("name", out var nameEl)
            ? nameEl.GetString() ?? throw new JsonException("Missing batch name in response")
            : throw new JsonException("Missing 'name' field in batch response");

        _logger.LogInformation("Created Gemini batch: {BatchName} for '{DisplayName}'", batchName, displayName);
        return batchName;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Internal: Parse kết quả
    // ═══════════════════════════════════════════════════════════════════════

    private List<Dictionary<string, object>> ParseBatchResults(JsonElement responseObj)
    {
        var results = new List<Dictionary<string, object>>();

        // Inline responses format
        if (responseObj.TryGetProperty("inlinedResponses", out var inlinedArr))
        {
            foreach (var inlined in inlinedArr.EnumerateArray())
            {
                if (!inlined.TryGetProperty("response", out var resp)) continue;

                try
                {
                    // Extract text from candidates[0].content.parts[0].text
                    var text = resp.GetProperty("candidates")[0]
                        .GetProperty("content")
                        .GetProperty("parts")[0]
                        .GetProperty("text")
                        .GetString() ?? string.Empty;

                    var recipes = ParseRecipesFromText(text);
                    foreach (var recipe in recipes)
                    {
                        results.Add(recipe);
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogDebug("Failed to parse batch response item: {Error}", ex.Message);
                }
            }
        }

        return results;
    }

    private static List<Dictionary<string, object>> ParseRecipesFromText(string text)
    {
        text = text.Trim();

        // Strip markdown code fences
        if (text.StartsWith("```"))
        {
            var lines = text.Split('\n');
            text = string.Join('\n', lines.Skip(1).Take(lines.Length - 2));
        }

        // Try parse directly
        try
        {
            using var doc = JsonDocument.Parse(text);
            if (doc.RootElement.TryGetProperty("recipes", out var recipesEl))
            {
                return recipesEl.EnumerateArray()
                    .Select(r => JsonSerializer.Deserialize<Dictionary<string, object>>(r.GetRawText()))
                    .Where(r => r != null)
                    .Select(r => r!)
                    .ToList();
            }
        }
        catch { /* try regex fallback */ }

        // Regex fallback: find JSON object containing "recipes"
        var match = Regex.Match(text, @"\{[\s\S]*\}");
        if (match.Success)
        {
            try
            {
                using var doc = JsonDocument.Parse(match.Value);
                if (doc.RootElement.TryGetProperty("recipes", out var recipesEl))
                {
                    return recipesEl.EnumerateArray()
                        .Select(r => JsonSerializer.Deserialize<Dictionary<string, object>>(r.GetRawText()))
                        .Where(r => r != null)
                        .Select(r => r!)
                        .ToList();
                }
            }
            catch { /* ignore */ }
        }

        return new List<Dictionary<string, object>>();
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Internal: Build prompts
    // ═══════════════════════════════════════════════════════════════════════

    private static List<string> BuildBatchPrompts(string ingredients, string cuisine, string regionalSeasoning)
    {
        var hasIngredients = !string.IsNullOrWhiteSpace(ingredients);

        var statusText = hasIngredients
            ? $"Nguyên liệu có sẵn: {ingredients}"
            : "Tủ lạnh đang trống. Hãy gợi ý những món phổ biến, dễ làm.";

        var seasoningLine = !string.IsNullOrWhiteSpace(regionalSeasoning)
            ? $"\nNêm vị ưu tiên: {regionalSeasoning}"
            : "";

        string BuildPrompt(string category, string extraInstructions, int count) => $$"""
            Bạn là đầu bếp Việt Nam tài ba. {{statusText}}
            Phong cách: {{cuisine}}{{seasoningLine}}

            NHIỆM VỤ: Đề xuất {{count}} món ăn {{category}}, KHÔNG trùng lặp.
            {{extraInstructions}}

            QUY ĐỊNH: Chỉ trả về JSON thuần, KHÔNG markdown, KHÔNG ```.
            {
                "recipes": [
                    {
                        "name": "Tên món",
                        "description": "Mô tả 1-2 câu",
                        "difficulty": "easy | medium | hard",
                        "prep_time": <phút>, "cook_time": <phút>,
                        "ingredients_used": ["có sẵn"],
                        "ingredients_missing": ["cần mua"],
                        "match_score": <0.0-1.0>,
                        "instructions": ["Bước 1...", "Bước 2..."],
                        "tips": "Bí quyết"
                    }
                ]
            }
            """;

        return new List<string>
        {
            BuildPrompt("ngon nhất, phù hợp nhất", "Ưu tiên sử dụng nhiều nguyên liệu sẵn có.", 6),
            BuildPrompt("nhanh gọn (dưới 30 phút)", "Chỉ chọn món nấu nhanh, đơn giản.", 4),
            BuildPrompt("đặc sản vùng miền Việt Nam", "Đa dạng Bắc-Trung-Nam, đặc trưng.", 4),
        };
    }

    private static string? GetPref(Dictionary<string, object> prefs, string key, string? fallback = "") =>
        prefs.TryGetValue(key, out var v) ? v?.ToString() ?? fallback : fallback;
}
