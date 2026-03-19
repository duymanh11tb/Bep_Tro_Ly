using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Collections.Concurrent;
using System.Globalization;
using BepTroLy.API.Data;
using BepTroLy.API.Models;
using Microsoft.EntityFrameworkCore;

namespace BepTroLy.API.Services;

/// <summary>
/// AI Recipe Suggestion Service using Google Gemini API.
/// </summary>
public class AIRecipeService
{
    // ── Circuit breaker (static = shared across all instances) ──────────────
    private static readonly object _circuitLock = new();
    private static int _consecutiveGeminiFailures;
    private static DateTime _circuitOpenUntilUtc = DateTime.MinValue;
    private static readonly TimeSpan CircuitOpenDuration = TimeSpan.FromSeconds(45);
    private const int GeminiFailureThreshold = 5;

    // ── Per-cache-key locks (thundering-herd prevention) ────────────────────
    // Value = (semaphore, refCount) so we can safely remove when no one holds it.
    private static readonly ConcurrentDictionary<string, (SemaphoreSlim Sem, int Refs)> _keyLocks = new();
    private static readonly object _keyLocksLock = new();

    // ── Wikimedia image cache (search query → direct image URL, process lifetime) ──
    // Avoids re-hitting the API for the same dish name across requests.
    private static readonly ConcurrentDictionary<string, string> _wikimediaImageCache =
        new(StringComparer.OrdinalIgnoreCase);
    private static readonly TimeSpan WikimediaTimeout = TimeSpan.FromSeconds(5);
    private const string WikimediaApiBase = "https://commons.wikimedia.org/w/api.php";

    // ── Blocked / fallback image data (static read-only) ────────────────────
    private static readonly HashSet<string> BlockedImageHosts = new(StringComparer.OrdinalIgnoreCase)
    {
        "imgur.com", "i.imgur.com", "m.imgur.com",
        "source.unsplash.com", "picsum.photos", "loremflickr.com"
    };

    private static readonly Dictionary<string, string> ExactDishFallbackImages =
        new(StringComparer.OrdinalIgnoreCase)
        {
            ["pho bo"] = "https://images.pexels.com/photos/6646035/pexels-photo-6646035.jpeg?auto=compress&cs=tinysrgb&w=1200",
            ["bun bo hue"] = "https://images.pexels.com/photos/723198/pexels-photo-723198.jpeg?auto=compress&cs=tinysrgb&w=1200",
            ["bun rieu cua"] = "https://images.pexels.com/photos/884600/pexels-photo-884600.jpeg?auto=compress&cs=tinysrgb&w=1200",
            ["thit bo luc lac"] = "https://images.pexels.com/photos/1860204/pexels-photo-1860204.jpeg?auto=compress&cs=tinysrgb&w=1200",
            ["ca kho to"] = "https://images.pexels.com/photos/262959/pexels-photo-262959.jpeg?auto=compress&cs=tinysrgb&w=1200",
            ["goi cuon tom thit"] = "https://images.pexels.com/photos/2097090/pexels-photo-2097090.jpeg?auto=compress&cs=tinysrgb&w=1200",
            ["com chien duong chau"] = "https://images.pexels.com/photos/723198/pexels-photo-723198.jpeg?auto=compress&cs=tinysrgb&w=1200",
            ["mi xao bo"] = "https://images.pexels.com/photos/1279330/pexels-photo-1279330.jpeg?auto=compress&cs=tinysrgb&w=1200"
        };

    private static readonly Dictionary<string, string[]> KeywordFallbackImages =
        new(StringComparer.OrdinalIgnoreCase)
        {
            ["bo"] = ["https://images.pexels.com/photos/1860204/pexels-photo-1860204.jpeg?auto=compress&cs=tinysrgb&w=1200",
                    "https://images.pexels.com/photos/361184/asparagus-steak-veal-steak-veal-361184.jpeg?auto=compress&cs=tinysrgb&w=1200",
                    "https://images.pexels.com/photos/769289/pexels-photo-769289.jpeg?auto=compress&cs=tinysrgb&w=1200"],
            ["ga"] = ["https://images.pexels.com/photos/616354/pexels-photo-616354.jpeg?auto=compress&cs=tinysrgb&w=1200",
                    "https://images.pexels.com/photos/2338407/pexels-photo-2338407.jpeg?auto=compress&cs=tinysrgb&w=1200"],
            ["ca"] = ["https://images.pexels.com/photos/262959/pexels-photo-262959.jpeg?auto=compress&cs=tinysrgb&w=1200",
                    "https://images.pexels.com/photos/1516415/pexels-photo-1516415.jpeg?auto=compress&cs=tinysrgb&w=1200"],
            ["tom"] = ["https://images.pexels.com/photos/3296277/pexels-photo-3296277.jpeg?auto=compress&cs=tinysrgb&w=1200",
                    "https://images.pexels.com/photos/725991/pexels-photo-725991.jpeg?auto=compress&cs=tinysrgb&w=1200"],
            ["bun"] = ["https://images.pexels.com/photos/884600/pexels-photo-884600.jpeg?auto=compress&cs=tinysrgb&w=1200",
                    "https://images.pexels.com/photos/723198/pexels-photo-723198.jpeg?auto=compress&cs=tinysrgb&w=1200"],
            ["pho"] = ["https://images.pexels.com/photos/6646035/pexels-photo-6646035.jpeg?auto=compress&cs=tinysrgb&w=1200"],
            ["mi"] = ["https://images.pexels.com/photos/1279330/pexels-photo-1279330.jpeg?auto=compress&cs=tinysrgb&w=1200"],
            ["lau"] = ["https://images.pexels.com/photos/699953/pexels-photo-699953.jpeg?auto=compress&cs=tinysrgb&w=1200"],
            ["com"] = ["https://images.pexels.com/photos/723198/pexels-photo-723198.jpeg?auto=compress&cs=tinysrgb&w=1200"],
            ["chay"] = ["https://images.pexels.com/photos/1640774/pexels-photo-1640774.jpeg?auto=compress&cs=tinysrgb&w=1200"]
        };

    private static readonly string[] GenericFallbackImages =
    [
        "https://images.pexels.com/photos/1640774/pexels-photo-1640774.jpeg?auto=compress&cs=tinysrgb&w=1200",
        "https://images.pexels.com/photos/958545/pexels-photo-958545.jpeg?auto=compress&cs=tinysrgb&w=1200",
        "https://images.pexels.com/photos/958547/pexels-photo-958547.jpeg?auto=compress&cs=tinysrgb&w=1200"
    ];

    private static readonly HashSet<string> RecipeNameStopwords = new(StringComparer.OrdinalIgnoreCase)
    {
        "mon", "viet", "ngon", "truyen", "thong", "dac", "biet",
        "kieu", "phien", "ban", "cho", "va", "voi", "tu"
    };

    // ── Dependencies ─────────────────────────────────────────────────────────
    private readonly string? _apiKey;
    private readonly IHttpClientFactory _httpClientFactory;  // FIX: avoid socket exhaustion
    private readonly AppDbContext _db;
    private readonly ILogger<AIRecipeService> _logger;

    public AIRecipeService(
        IConfiguration configuration,
        IHttpClientFactory httpClientFactory,
        AppDbContext db,
        ILogger<AIRecipeService> logger)
    {
        _apiKey = configuration["Gemini:ApiKey"];
        _httpClientFactory = httpClientFactory;
        _db = db;
        _logger = logger;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Public API
    // ═════════════════════════════════════════════════════════════════════════

    /// <summary>Gợi ý món ăn dựa trên nguyên liệu.</summary>
    public async Task<Dictionary<string, object>> SuggestRecipesAsync(
        List<string>? ingredients,
        Dictionary<string, object>? preferences = null,
        int limit = 8,
        int offset = 0,
        CancellationToken ct = default)
    {
        limit = Math.Clamp(limit, 1, 24);
        offset = Math.Max(0, offset);
        preferences ??= new Dictionary<string, object>();

        // FIX: use a local variable instead of reassigning the parameter
        var effectiveIngredients = ingredients is { Count: > 0 }
            ? ingredients
            : new List<string>();

        const int generationLimit = 24;
        var cacheKey = GenerateCacheKey(effectiveIngredients, preferences, generationLimit);

        // Fast path: cache hit before acquiring any lock
        var cached = await GetFromCacheAsync(cacheKey, ct);
        if (cached != null)
        {
            return BuildPagedSuccessResponse(await EnsureRecipeImagesAsync(cached, ct), "cache", limit, offset);
        }

        // Acquire per-key lock (thundering-herd prevention, fixed race condition)
        var sem = AcquireKeyLock(cacheKey);
        try
        {
            await sem.WaitAsync(ct);

            // Re-check after acquiring (another request may have populated the cache)
            cached = await GetFromCacheAsync(cacheKey, ct);
            if (cached != null)
            {
                return BuildPagedSuccessResponse(await EnsureRecipeImagesAsync(cached, ct), "cache", limit, offset);
            }

            var aiRecipes = await GenerateAISuggestionsAsync(effectiveIngredients, preferences, generationLimit, ct);
            if (aiRecipes.Count < generationLimit)
            {
                var fallback = BuildLocalFallbackRecipes(effectiveIngredients, generationLimit);
                aiRecipes = MergeUniqueRecipes(aiRecipes, fallback, generationLimit);
            }

            var withImages = await EnsureRecipeImagesAsync(aiRecipes, ct);
            await SaveToCacheAsync(cacheKey, withImages, ct: ct);
            return BuildPagedSuccessResponse(withImages, "ai", limit, offset);
        }
        catch (OperationCanceledException)
        {
            throw; // don't swallow cancellation
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "AI suggestion error for key {CacheKey}", cacheKey);

            var fallbackRecipes = BuildLocalFallbackRecipes(effectiveIngredients, generationLimit);
            if (fallbackRecipes.Count > 0)
            {
                var fallbackWithImages = await EnsureRecipeImagesAsync(fallbackRecipes, ct);
                await SaveToCacheAsync(cacheKey, fallbackWithImages, ttlHours: 2, ct: ct);
                return BuildPagedSuccessResponse(fallbackWithImages, "local_fallback", limit, offset);
            }

            return new Dictionary<string, object>
            {
                ["success"] = false,
                ["error"] = $"Lỗi AI: {ex.Message}",
                ["recipes"] = new List<object>()
            };
        }
        finally
        {
            sem.Release();
            ReleaseKeyLock(cacheKey);
        }
    }

    /// <summary>Gợi ý từ pantry của người dùng.</summary>
    public async Task<Dictionary<string, object>> SuggestFromPantryAsync(
        int userId,
        Dictionary<string, object>? preferences = null,
        int limit = 8,
        int offset = 0,
        CancellationToken ct = default)
    {
        var pantryItems = await _db.PantryItems
            .Where(p => p.UserId == userId && p.Status == "active")
            .Select(p => p.NameVi)
            .ToListAsync(ct);

        return await SuggestRecipesAsync(pantryItems, preferences, limit, offset, ct);
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Key-lock helpers (fixed race condition)
    // ═════════════════════════════════════════════════════════════════════════

    private static SemaphoreSlim AcquireKeyLock(string key)
    {
        lock (_keyLocksLock)
        {
            var (sem, refs) = _keyLocks.GetOrAdd(key, _ => (new SemaphoreSlim(1, 1), 0));
            _keyLocks[key] = (sem, refs + 1);
            return sem;
        }
    }

    private static void ReleaseKeyLock(string key)
    {
        lock (_keyLocksLock)
        {
            if (!_keyLocks.TryGetValue(key, out var entry)) return;

            var newRefs = entry.Refs - 1;
            if (newRefs <= 0)
                _keyLocks.TryRemove(key, out _);
            else
                _keyLocks[key] = (entry.Sem, newRefs);
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Gemini API
    // ═════════════════════════════════════════════════════════════════════════

    private async Task<List<object>> GenerateAISuggestionsAsync(
        List<string> ingredients,
        Dictionary<string, object>? preferences,
        int limit,
        CancellationToken ct)
    {
        if (string.IsNullOrEmpty(_apiKey))
            throw new InvalidOperationException("Gemini API key chưa được cấu hình.");

        if (IsCircuitOpen(out var retryAfter))
        {
            var waitSecs = Math.Max(1, (int)Math.Ceiling(retryAfter.TotalSeconds));
            throw new InvalidOperationException($"AI đang quá tải, vui lòng thử lại sau {waitSecs} giây.");
        }

        preferences ??= new Dictionary<string, object>();

        var dietary = GetPref(preferences, "dietary_restrictions");
        var cuisine = GetPref(preferences, "cuisine", "Việt Nam");
        var regionalSeasoning = GetPref(preferences, "regional_seasoning");
        var difficulty = GetPref(preferences, "difficulty", "any");

        var overGenerate = Math.Clamp(Math.Max(limit + 4, limit * 2), limit, 24);

        // FIX: sanitize user inputs before embedding in prompt
        var sanitizedIngredients = ingredients
            .Select(i => i.Trim().Replace("\"", "").Replace("\n", " "))
            .Where(i => !string.IsNullOrWhiteSpace(i))
            .Take(50) // hard cap to keep prompt size bounded
            .ToList();

        var statusText = sanitizedIngredients.Count > 0
            ? $"CHẾ ĐỘ GỢI Ý: Dựa trên {sanitizedIngredients.Count} nguyên liệu có sẵn: {string.Join(", ", sanitizedIngredients)}."
            : "CHẾ ĐỘ KHÁM PHÁ: Tủ lạnh đang trống. Hãy gợi ý những món ăn Việt Nam 'quốc dân' cực kỳ hấp dẫn, dễ làm và phổ biến.";

        var extraLines = new List<string>();
        if (!string.IsNullOrEmpty(dietary)) extraLines.Add($"Chế độ ăn đặc biệt: {dietary}");
        if (!string.IsNullOrEmpty(regionalSeasoning)) extraLines.Add($"Định hướng nêm vị theo vùng miền: {regionalSeasoning}");
        if (difficulty != "any") extraLines.Add($"Độ khó: {difficulty}");

        var extras = extraLines.Count > 0 ? string.Join("\n", extraLines) : string.Empty;

        var prompt = $$"""
            Bạn là một đầu bếp Việt Nam tài ba với kiến thức sâu rộng về ẩm thực 3 miền.

            {{statusText}}
            Phong cách ẩm thực yêu thích: {{cuisine}}
            {{extras}}

            NHIỆM VỤ: Đề xuất {{overGenerate}} món ăn KHÁC NHAU rõ ràng, không trùng lặp tên món.
            - CHẾ ĐỘ GỢI Ý: Ưu tiên các món sử dụng được nhiều nguyên liệu sẵn có nhất.
            - CHẾ ĐỘ KHÁM PHÁ: Chọn những món ngon nhất, dễ tìm nguyên liệu nhất.

            QUY ĐỊNH: Chỉ trả về JSON thuần, KHÔNG có markdown, KHÔNG dùng ```.
            {
                "recipes": [
                    {
                        "name": "Tên món ăn hấp dẫn",
                        "description": "Mô tả ngắn gọn 1-2 câu, thân thiện",
                        "image_url": "URL ảnh trực tiếp (kết thúc bằng .jpg/.jpeg/.png/.webp) từ images.pexels.com hoặc upload.wikimedia.org mà bạn CHẮC CHẮN tồn tại. Nếu không chắc → để null",
                        "image_search_query": "Từ khóa tiếng Anh ngắn để tìm ảnh, VD: 'vietnamese beef pho noodle soup bowl'",
                        "difficulty": "easy | medium | hard",
                        "prep_time": <số phút chuẩn bị>,
                        "cook_time": <số phút nấu>,
                        "servings": <số người>,
                        "ingredients_used": ["nguyên liệu đã có"],
                        "ingredients_missing": ["nguyên liệu cần mua"],
                        "match_score": <0.0–1.0>,
                        "instructions": ["Bước 1: ...", "Bước 2: ..."],
                        "tips": "Bí quyết nấu ngon"
                    }
                ]
            }
            Sắp xếp theo mức độ phù hợp giảm dần.
            """;

        var requestBody = new
        {
            contents = new[] { new { parts = new[] { new { text = prompt } } } }
        };

        var url = $"https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro:generateContent?key={_apiKey}";

        // FIX: use IHttpClientFactory; set timeout per-request via CancellationToken
        using var client = _httpClientFactory.CreateClient("Gemini");
        using var cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        cts.CancelAfter(TimeSpan.FromSeconds(20));

        string responseText;
        HttpResponseMessage response;

        try
        {
            var jsonContent = new StringContent(
                JsonSerializer.Serialize(requestBody), Encoding.UTF8, "application/json");

            response = await client.PostAsync(url, jsonContent, cts.Token);
            responseText = await response.Content.ReadAsStringAsync(cts.Token);
        }
        catch (OperationCanceledException ex) when (!ct.IsCancellationRequested)
        {
            // Our own 20-second timeout fired, not the caller's cancellation
            RecordGeminiFailure();
            throw new TimeoutException("AI phản hồi chậm, vui lòng thử lại sau ít phút.", ex);
        }
        catch (Exception)
        {
            RecordGeminiFailure();
            throw;
        }

        if (!response.IsSuccessStatusCode)
        {
            RecordGeminiFailure();
            throw new HttpRequestException(
                $"Gemini API trả về lỗi {(int)response.StatusCode}: {responseText[..Math.Min(200, responseText.Length)]}");
        }

        var parsed = ParseGeminiResponse(responseText);
        RecordGeminiSuccess();
        return NormalizeAndRankAiRecipes(parsed, ingredients, limit);
    }

    private static List<object> ParseGeminiResponse(string responseText)
    {
        using var doc = JsonDocument.Parse(responseText);
        var text = doc.RootElement
            .GetProperty("candidates")[0]
            .GetProperty("content")
            .GetProperty("parts")[0]
            .GetProperty("text")
            .GetString() ?? string.Empty;

        text = text.Trim();

        // Strip markdown fences if present
        if (text.StartsWith("```"))
        {
            var lines = text.Split('\n');
            text = string.Join('\n', lines.Skip(1).Take(lines.Length - 2));
        }

        // Try direct parse first, then regex fallback
        JsonElement recipesElement;
        if (TryParseRecipesElement(text, out recipesElement) ||
            TryExtractAndParseRecipesElement(text, out recipesElement))
        {
            return JsonSerializer.Deserialize<List<object>>(recipesElement.GetRawText())
                   ?? new List<object>();
        }

        throw new JsonException("Không thể parse phản hồi từ Gemini.");
    }

    private static bool TryParseRecipesElement(string text, out JsonElement element)
    {
        element = default;
        try
        {
            using var doc = JsonDocument.Parse(text);
            if (doc.RootElement.TryGetProperty("recipes", out element))
                return true;
        }
        catch { /* fall through */ }
        return false;
    }

    private static bool TryExtractAndParseRecipesElement(string text, out JsonElement element)
    {
        element = default;
        var match = Regex.Match(text, @"\{[\s\S]*\}");
        if (!match.Success) return false;
        try
        {
            using var doc = JsonDocument.Parse(match.Value);
            if (doc.RootElement.TryGetProperty("recipes", out element))
                return true;
        }
        catch { /* fall through */ }
        return false;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Circuit breaker
    // ═════════════════════════════════════════════════════════════════════════

    private static bool IsCircuitOpen(out TimeSpan retryAfter)
    {
        lock (_circuitLock)
        {
            var now = DateTime.UtcNow;
            if (_circuitOpenUntilUtc > now)
            {
                retryAfter = _circuitOpenUntilUtc - now;
                return true;
            }
            retryAfter = TimeSpan.Zero;
            return false;
        }
    }

    private static void RecordGeminiSuccess()
    {
        lock (_circuitLock)
        {
            _consecutiveGeminiFailures = 0;
            _circuitOpenUntilUtc = DateTime.MinValue;
        }
    }

    private static void RecordGeminiFailure()
    {
        lock (_circuitLock)
        {
            _consecutiveGeminiFailures++;
            if (_consecutiveGeminiFailures >= GeminiFailureThreshold)
            {
                _circuitOpenUntilUtc = DateTime.UtcNow.Add(CircuitOpenDuration);
                _consecutiveGeminiFailures = 0;
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Recipe normalization & ranking
    // ═════════════════════════════════════════════════════════════════════════

    private static List<object> NormalizeAndRankAiRecipes(
        List<object> rawRecipes,
        List<string> ingredients,
        int maxCount)
    {
        var normalizedIngredients = ingredients
            .Select(NormalizeText)
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .ToHashSet();

        var unique = new Dictionary<string, Dictionary<string, object>>(StringComparer.Ordinal);

        foreach (var raw in rawRecipes)
        {
            var map = ToDictionary(raw);
            if (map == null) continue;
            if (!IsRelevantRecipe(map, normalizedIngredients)) continue;

            var normalized = NormalizeRecipeMap(map, normalizedIngredients);
            var key = BuildRecipeKey(normalized);
            if (string.IsNullOrWhiteSpace(key)) continue;

            if (!unique.TryGetValue(key, out var existing) ||
                ParseDouble(normalized, "match_score", 0) > ParseDouble(existing, "match_score", 0))
            {
                unique[key] = normalized;
            }
        }

        return unique.Values
            .OrderByDescending(x => ParseDouble(x, "match_score", 0))
            .ThenBy(x => ParseInt(x, "prep_time", 0) + ParseInt(x, "cook_time", 0))
            .Take(maxCount)
            .Cast<object>()
            .ToList();
    }

    private static Dictionary<string, object> NormalizeRecipeMap(
        Dictionary<string, object> map,
        HashSet<string> normalizedIngredients)
    {
        var name = GetString(map, "name", "Món ngon Việt Nam");
        var description = GetString(map, "description", "Món ngon dễ làm, hợp vị gia đình.");

        var ingredientsUsed = NormalizeStringList(map, "ingredients_used");
        var ingredientsMissing = NormalizeStringList(map, "ingredients_missing");
        var instructions = NormalizeStringList(map, "instructions");

        // Fallback: infer used ingredients from name/description
        if (ingredientsUsed.Count == 0 && normalizedIngredients.Count > 0)
        {
            var normName = NormalizeText(name);
            var normDesc = NormalizeText(description);
            ingredientsUsed = normalizedIngredients
                .Where(i => normName.Contains(i) || normDesc.Contains(i))
                .Take(4)
                .ToList();
        }

        var prepTime = Math.Clamp(ParseInt(map, "prep_time", 8), 0, 180);
        var cookTime = Math.Clamp(ParseInt(map, "cook_time", 15), 1, 240);
        var servings = Math.Clamp(ParseInt(map, "servings", 2), 1, 12);
        var score = Math.Clamp(ParseDouble(map, "match_score", 0.55), 0.0, 1.0);

        var imageUrl = map.TryGetValue("image_url", out var imgObj) && IsValidRecipeImageUrl(imgObj?.ToString())
            ? imgObj!.ToString()!
            : null; // will be resolved later in EnsureRecipeImagesAsync

        // image_search_query: short English phrase Gemini provides for image lookup
        var imageSearchQuery = GetString(map, "image_search_query", null);

        return new Dictionary<string, object>
        {
            ["name"] = name,
            ["description"] = description,
            ["difficulty"] = NormalizeDifficulty(GetString(map, "difficulty", null)),
            ["prep_time"] = prepTime,
            ["cook_time"] = cookTime,
            ["servings"] = servings,
            ["ingredients_used"] = ingredientsUsed,
            ["ingredients_missing"] = ingredientsMissing,
            ["instructions"] = instructions,
            ["tips"] = GetString(map, "tips", "Nêm nếm vừa vị trước khi tắt bếp."),
            ["match_score"] = score,
            ["image_url"] = (object?)imageUrl ?? string.Empty,   // resolved in EnsureRecipeImagesAsync
            ["image_search_query"] = imageSearchQuery ?? string.Empty,
            ["ingredients_expiring_count"] = ParseInt(map, "ingredients_expiring_count", 0)
        };
    }

    private static bool IsRelevantRecipe(Dictionary<string, object> recipe, HashSet<string> pantry)
    {
        if (pantry.Count == 0) return true; // discovery mode — no filter

        var used = NormalizeStringList(recipe, "ingredients_used")
            .Select(NormalizeText)
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .ToList();

        if (used.Count == 0) return false;

        var matchCount = used.Count(i => pantry.Any(p => p.Contains(i) || i.Contains(p)));
        return matchCount >= 2;
    }

    private static string BuildRecipeKey(Dictionary<string, object> map)
    {
        var rawName = GetString(map, "name", string.Empty);
        var coreName = NormalizeText(rawName)
            .Split(' ', StringSplitOptions.RemoveEmptyEntries)
            .Where(t => t.Length >= 3 && !RecipeNameStopwords.Contains(t))
            .Distinct()
            .Take(4)
            .ToList();

        var anchor = NormalizeStringList(map, "ingredients_used")
            .Select(NormalizeText)
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .OrderBy(x => x)
            .Take(2)
            .ToList();

        var nameKey = coreName.Count > 0 ? string.Join(" ", coreName) : NormalizeText(rawName);
        return anchor.Count > 0 ? $"{nameKey}|{string.Join("|", anchor)}" : nameKey;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Response builder
    // ═════════════════════════════════════════════════════════════════════════

    private static Dictionary<string, object> BuildPagedSuccessResponse(
        List<object> allRecipes,
        string source,
        int limit,
        int offset)
    {
        var paged = allRecipes.Skip(offset).Take(limit).ToList();
        var nextOffset = offset + paged.Count;

        return new Dictionary<string, object>
        {
            ["success"] = true,
            ["source"] = source,
            ["recipes"] = paged,
            ["offset"] = offset,
            ["limit"] = limit,
            ["next_offset"] = nextOffset,
            ["has_more"] = nextOffset < allRecipes.Count,
            ["total_candidates"] = allRecipes.Count
        };
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Image helpers
    // ═════════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Fills image_url for every recipe concurrently.
    /// Priority: Wikimedia Commons (via image_search_query or dish name) → static fallback.
    /// Results are cached in _wikimediaImageCache for the process lifetime.
    /// </summary>
    private async Task<List<object>> EnsureRecipeImagesAsync(
        List<object> recipes,
        CancellationToken ct)
    {
        var maps = recipes
            .Select(r => ToDictionary(r) ?? new Dictionary<string, object>())
            .ToList();

        // Build a search query per recipe; deduplicate to avoid redundant API calls.
        var queryByIndex = maps
            .Select((m, i) =>
            {
                var q = GetString(m, "image_search_query", null);
                if (string.IsNullOrWhiteSpace(q))
                    q = BuildWikimediaQuery(GetString(m, "name", string.Empty)!);
                return (i, q);
            })
            .ToList();

        var uncached = queryByIndex
            .Select(x => x.q)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .Where(q => !_wikimediaImageCache.ContainsKey(q))
            .ToList();

        if (uncached.Count > 0)
            await Task.WhenAll(uncached.Select(q => FetchAndCacheWikimediaImageAsync(q, ct)));

        var result = new List<object>(maps.Count);
        foreach (var (i, query) in queryByIndex)
        {
            var map = maps[i];
            var name = GetString(map, "name", "Mon an Viet Nam")!;

            map["image_url"] =
                _wikimediaImageCache.TryGetValue(query, out var url) && !string.IsNullOrEmpty(url)
                    ? url
                    : BuildFallbackImageUrl(name);

            result.Add(map);
        }

        return result;
    }

    /// <summary>
    /// Two-step Wikimedia Commons lookup:
    ///   1. Search the File namespace for the query → get file title.
    ///   2. Resolve the title to a direct Wikimedia CDN URL via imageinfo.
    /// Never throws; on failure the cache entry is set to "" so the caller uses the fallback.
    /// </summary>
    private async Task FetchAndCacheWikimediaImageAsync(string query, CancellationToken ct)
    {
        if (_wikimediaImageCache.ContainsKey(query)) return;

        try
        {
            using var client = _httpClientFactory.CreateClient("Wikimedia");
            using var cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
            cts.CancelAfter(WikimediaTimeout);

            // ── Step 1: search File namespace ────────────────────────────────
            var searchUrl =
                WikimediaApiBase +
                "?action=query&list=search" +
                "&srsearch=" + Uri.EscapeDataString(query + " food dish") +
                "&srnamespace=6&srlimit=8&format=json&origin=*";

            using var searchResp = await client.GetAsync(searchUrl, cts.Token);
            if (!searchResp.IsSuccessStatusCode)
            {
                _wikimediaImageCache.TryAdd(query, string.Empty);
                return;
            }

            using var searchDoc = JsonDocument.Parse(
                await searchResp.Content.ReadAsStringAsync(cts.Token));

            var hits = searchDoc.RootElement
                .GetProperty("query")
                .GetProperty("search");

            // Keep first result that is a raster image
            string? fileTitle = null;
            foreach (var hit in hits.EnumerateArray())
            {
                var title = hit.GetProperty("title").GetString() ?? string.Empty;
                var lower = title.ToLowerInvariant();
                if (lower.EndsWith(".jpg") || lower.EndsWith(".jpeg") ||
                    lower.EndsWith(".png") || lower.EndsWith(".webp"))
                {
                    fileTitle = title;
                    break;
                }
            }

            if (fileTitle is null)
            {
                _wikimediaImageCache.TryAdd(query, string.Empty);
                return;
            }

            // ── Step 2: resolve file title → direct CDN URL ──────────────────
            var infoUrl =
                WikimediaApiBase +
                "?action=query" +
                "&titles=" + Uri.EscapeDataString(fileTitle) +
                "&prop=imageinfo&iiprop=url&format=json&origin=*";

            using var infoResp = await client.GetAsync(infoUrl, cts.Token);
            if (!infoResp.IsSuccessStatusCode)
            {
                _wikimediaImageCache.TryAdd(query, string.Empty);
                return;
            }

            using var infoDoc = JsonDocument.Parse(
                await infoResp.Content.ReadAsStringAsync(cts.Token));

            string? directUrl = null;
            foreach (var page in infoDoc.RootElement
                .GetProperty("query")
                .GetProperty("pages")
                .EnumerateObject())
            {
                if (page.Value.TryGetProperty("imageinfo", out var info))
                {
                    directUrl = info[0].GetProperty("url").GetString();
                    break;
                }
            }

            _wikimediaImageCache.TryAdd(query, directUrl ?? string.Empty);
            _logger.LogDebug("Wikimedia [{Query}] → {Url}", query, directUrl ?? "(none)");
        }
        catch (Exception ex)
        {
            _logger.LogDebug("Wikimedia fetch failed [{Query}]: {Msg}", query, ex.Message);
            _wikimediaImageCache.TryAdd(query, string.Empty);
        }
    }

    /// <summary>
    /// Converts a Vietnamese dish name (already NormalizeText'd) to a short English
    /// search query suitable for Wikimedia Commons.
    /// </summary>
    private static string BuildWikimediaQuery(string vietnameseName)
    {
        var ascii = NormalizeText(vietnameseName);

        // Common Vietnamese keyword → English food phrase
        var keywordMap = new[]
        {
            ("pho",  "pho noodle soup vietnamese"),
            ("bun",  "vietnamese noodle bowl"),
            ("com",  "vietnamese rice dish"),
            ("lau",  "vietnamese hot pot"),
            ("mi",   "vietnamese noodle"),
            ("banh", "vietnamese banh"),
            ("goi",  "vietnamese salad"),
            ("xoi",  "vietnamese sticky rice"),
            ("chao", "vietnamese congee porridge"),
            ("ga",   "vietnamese chicken"),
            ("bo",   "vietnamese beef"),
            ("heo",  "vietnamese pork"),
            ("ca",   "vietnamese fish"),
            ("tom",  "vietnamese shrimp prawn"),
            ("vit",  "vietnamese duck"),
            ("chay", "vietnamese vegetarian"),
        };

        foreach (var (key, phrase) in keywordMap)
            if (ascii.Contains(key))
                return phrase;

        return "vietnamese " + ascii + " dish";
    }

    // FIX: was instance method but uses only static data → now static
    private static string BuildFallbackImageUrl(string recipeName)
    {
        var normalized = NormalizeText(recipeName);

        foreach (var (key, url) in ExactDishFallbackImages)
            if (normalized.Contains(key)) return url;

        foreach (var (keyword, urls) in KeywordFallbackImages)
        {
            if (!normalized.Contains(keyword)) continue;
            return urls[Math.Abs(recipeName.GetHashCode()) % urls.Length];
        }

        return GenericFallbackImages[Math.Abs(recipeName.GetHashCode()) % GenericFallbackImages.Length];
    }

    private static bool IsValidRecipeImageUrl(string? imageUrl)
    {
        if (string.IsNullOrWhiteSpace(imageUrl)) return false;
        if (!Uri.TryCreate(imageUrl, UriKind.Absolute, out var uri)) return false;
        if (uri.Scheme is not ("http" or "https")) return false;
        if (BlockedImageHosts.Contains(uri.Host)) return false;

        var lower = imageUrl.ToLowerInvariant();
        return !lower.Contains("source.unsplash.com")
            && !lower.Contains("picsum.photos")
            && !lower.Contains("loremflickr.com")
            && !lower.Contains("imgur.com");
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Cache
    // ═════════════════════════════════════════════════════════════════════════

    private static string GenerateCacheKey(
        List<string> ingredients,
        Dictionary<string, object>? preferences,
        int limit)
    {
        var normalized = ingredients
            .Select(i => i.ToLowerInvariant().Trim())
            .OrderBy(i => i);

        var keyObj = new
        {
            ingredients = normalized,
            preferences = preferences ?? new Dictionary<string, object>(),
            limit
        };

        var json = JsonSerializer.Serialize(keyObj);
        var hashBytes = MD5.HashData(Encoding.UTF8.GetBytes(json));
        return Convert.ToHexString(hashBytes).ToLowerInvariant();
    }

    private async Task<List<object>?> GetFromCacheAsync(string cacheKey, CancellationToken ct)
    {
        try
        {
            var entry = await _db.AICache
                .AsNoTracking()
                .FirstOrDefaultAsync(c => c.CacheKey == cacheKey, ct);

            if (entry is null) return null;

            if (entry.ExpiresAt > DateTime.UtcNow)
                return JsonSerializer.Deserialize<List<object>>(entry.ResponseData);

            // Expired — remove asynchronously to not block the caller
            _db.AICache.Remove(entry);
            await _db.SaveChangesAsync(ct);
            return null;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Cache read error for key {CacheKey}", cacheKey);
            return null;
        }
    }

    private async Task SaveToCacheAsync(
        string cacheKey,
        List<object> recipes,
        int ttlHours = 24,
        CancellationToken ct = default)
    {
        try
        {
            var existing = await _db.AICache.FirstOrDefaultAsync(c => c.CacheKey == cacheKey, ct);
            if (existing != null) _db.AICache.Remove(existing);

            _db.AICache.Add(new AICache
            {
                CacheKey = cacheKey,
                ResponseData = JsonSerializer.Serialize(recipes),
                ExpiresAt = DateTime.UtcNow.AddHours(ttlHours)
            });

            await _db.SaveChangesAsync(ct);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Cache save error for key {CacheKey}", cacheKey);
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Local fallback recipes
    // ═════════════════════════════════════════════════════════════════════════

    private static List<object> BuildLocalFallbackRecipes(List<string> ingredients, int limit)
    {
        var pantry = ingredients
            .Select(i => i.Trim().ToLowerInvariant())
            .Where(i => !string.IsNullOrWhiteSpace(i))
            .ToHashSet();

        var templates = new[]
        {
            ("Trứng chiên hành",
             "Món nhanh gọn cho bữa sáng, dễ làm và rất bắt cơm.",
             "easy", 5, 7,
             new[] { "trứng", "hành tím", "nước mắm", "tiêu" },
             new[] { "Đập trứng vào tô, thêm nước mắm và tiêu rồi đánh đều.",
                     "Phi thơm hành tím với ít dầu.",
                     "Đổ trứng vào chảo, chiên lửa vừa đến khi vàng hai mặt." },
             "Chiên lửa vừa để trứng mềm và thơm hơn."),

            ("Thịt bò xào hành tây",
             "Bò mềm, đậm vị, hợp bữa trưa hoặc tối.",
             "easy", 10, 10,
             new[] { "thịt bò", "hành tây", "tỏi", "dầu ăn", "nước tương" },
             new[] { "Ướp thịt bò với tỏi băm, nước tương trong 10 phút.",
                     "Xào nhanh thịt bò trên lửa lớn rồi trút ra.",
                     "Xào hành tây, cho bò vào đảo đều và tắt bếp." },
             "Không xào bò quá lâu để tránh bị dai."),

            ("Canh cà chua trứng",
             "Canh thanh nhẹ, dễ ăn và rất hợp ngày nóng.",
             "easy", 8, 10,
             new[] { "cà chua", "trứng", "hành lá", "muối", "nước mắm" },
             new[] { "Cà chua cắt múi cau, hành lá cắt nhỏ.",
                     "Đun sôi nước, cho cà chua vào nấu mềm.",
                     "Đánh tan trứng rồi rót vòng tròn vào nồi, nêm nếm vừa ăn." },
             "Rót trứng từ từ để tạo vân đẹp cho canh."),

            ("Cơm chiên trứng",
             "Tận dụng cơm nguội, làm nhanh khi bận rộn.",
             "easy", 7, 10,
             new[] { "cơm nguội", "trứng", "hành lá", "nước mắm", "dầu ăn" },
             new[] { "Đánh trứng với chút nước mắm.",
                     "Phi hành, cho trứng vào đảo tơi rồi cho cơm nguội vào.",
                     "Nêm nếm lại, đảo đều đến khi hạt cơm săn." },
             "Dùng cơm nguội để hạt cơm chiên tơi ngon hơn."),

            ("Đậu hũ sốt cà",
             "Món chay dễ làm, vị chua ngọt hài hòa.",
             "easy", 8, 12,
             new[] { "đậu hũ", "cà chua", "hành tím", "muối", "đường" },
             new[] { "Chiên sơ đậu hũ vàng nhẹ.",
                     "Xào cà chua với hành tím đến khi sệt.",
                     "Cho đậu vào sốt cùng gia vị đến khi thấm." },
             "Thêm chút tiêu cuối cùng để dậy mùi.")
        };

        return templates
            .Select(t =>
            {
                var ingNorm = t.Item6.Select(x => x.ToLowerInvariant()).ToList();
                var used = ingNorm.Where(i => pantry.Any(h => h.Contains(i) || i.Contains(h))).Distinct().ToList();
                var missing = ingNorm.Except(used).Distinct().ToList();
                var score = ingNorm.Count == 0 ? 0.6
                    : Math.Min(0.98, Math.Max(0.35, (double)used.Count / ingNorm.Count));

                return (object)new Dictionary<string, object>
                {
                    ["name"] = t.Item1,
                    ["description"] = t.Item2,
                    ["image_url"] = BuildFallbackImageUrl(t.Item1),
                    ["difficulty"] = t.Item3,
                    ["prep_time"] = t.Item4,
                    ["cook_time"] = t.Item5,
                    ["servings"] = 2,
                    ["ingredients_used"] = used,
                    ["ingredients_missing"] = missing,
                    ["match_score"] = score,
                    ["instructions"] = t.Item7.ToList(),
                    ["tips"] = t.Item8,
                    ["ingredients_expiring_count"] = 0
                };
            })
            .OrderByDescending(r => ParseDouble((Dictionary<string, object>)r, "match_score", 0))
            .Take(Math.Max(1, limit))
            .ToList();
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Merge helpers
    // ═════════════════════════════════════════════════════════════════════════

    private static List<object> MergeUniqueRecipes(List<object> primary, List<object> secondary, int limit)
    {
        var seen = new HashSet<string>(StringComparer.Ordinal);
        var merged = new List<object>(limit);

        foreach (var recipe in primary.Concat(secondary))
        {
            if (merged.Count >= limit) break;

            var map = ToDictionary(recipe);
            if (map == null) { merged.Add(recipe); continue; }

            var key = BuildRecipeKey(map);
            if (string.IsNullOrWhiteSpace(key) || !seen.Add(key)) continue;

            merged.Add(map);
        }

        return merged;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Parsing / normalization utilities (all static)
    // ═════════════════════════════════════════════════════════════════════════

    private static string NormalizeText(string? input)
    {
        if (string.IsNullOrWhiteSpace(input)) return string.Empty;

        var nfd = input.Trim().ToLowerInvariant().Normalize(NormalizationForm.FormD);
        var sb = new StringBuilder(nfd.Length);

        foreach (var c in nfd)
        {
            if (CharUnicodeInfo.GetUnicodeCategory(c) == UnicodeCategory.NonSpacingMark) continue;
            sb.Append(c == 'đ' ? 'd' : c);
        }

        return Regex.Replace(sb.ToString(), @"\s+", " ").Trim();
    }

    private static string NormalizeDifficulty(string? raw) =>
        raw?.Trim().ToLowerInvariant() switch
        {
            "easy" => "easy",
            "medium" => "medium",
            "hard" => "hard",
            _ => "easy"
        };

    private static List<string> NormalizeStringList(Dictionary<string, object> map, string key)
    {
        if (!map.TryGetValue(key, out var value) || value is null)
            return new List<string>();

        IEnumerable<string?> items = value switch
        {
            JsonElement { ValueKind: JsonValueKind.Array } el =>
                el.EnumerateArray().Select(x => x.ToString()),
            IEnumerable<string> list => list,
            IEnumerable<object> list => list.Select(x => x?.ToString()),
            _ => value.ToString()?.Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries)
                 ?? Array.Empty<string>()
        };

        return items
            .Select(x => x?.Trim())
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Select(x => x!)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    private static int ParseInt(Dictionary<string, object> map, string key, int fallback)
    {
        if (!map.TryGetValue(key, out var value) || value is null) return fallback;
        if (value is JsonElement el)
        {
            if (el.ValueKind == JsonValueKind.Number && el.TryGetInt32(out var n)) return n;
            if (el.ValueKind == JsonValueKind.String && int.TryParse(el.GetString(), out var s)) return s;
        }
        return int.TryParse(value.ToString(), out var r) ? r : fallback;
    }

    private static double ParseDouble(Dictionary<string, object> map, string key, double fallback)
    {
        if (!map.TryGetValue(key, out var value) || value is null) return fallback;
        if (value is JsonElement el)
        {
            if (el.ValueKind == JsonValueKind.Number && el.TryGetDouble(out var n)) return n;
            if (el.ValueKind == JsonValueKind.String && double.TryParse(el.GetString(), out var s)) return s;
        }
        if (value is double d) return d;
        if (value is float f) return f;
        return double.TryParse(value.ToString(), out var r) ? r : fallback;
    }

    private static string? GetString(Dictionary<string, object> map, string key, string? fallback) =>
        map.TryGetValue(key, out var v) ? v?.ToString()?.Trim() ?? fallback : fallback;

    private static string? GetPref(Dictionary<string, object> prefs, string key, string? fallback = "") =>
        prefs.TryGetValue(key, out var v) ? v?.ToString() ?? fallback : fallback;

    private static Dictionary<string, object>? ToDictionary(object? value)
    {
        if (value is null) return null;
        if (value is Dictionary<string, object> d) return new Dictionary<string, object>(d);
        try
        {
            var json = value is JsonElement el ? el.GetRawText() : JsonSerializer.Serialize(value);
            return JsonSerializer.Deserialize<Dictionary<string, object>>(json);
        }
        catch { return null; }
    }
}