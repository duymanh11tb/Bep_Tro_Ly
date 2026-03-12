using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using BepTroLy.API.Data;
using BepTroLy.API.Models;
using Microsoft.EntityFrameworkCore;

namespace BepTroLy.API.Services;

/// <summary>
/// AI Recipe Suggestion Service using Google Gemini API.
/// Mirrors Python's AIRecipeService.
/// </summary>
public class AIRecipeService
{
    private readonly string? _apiKey;
    private readonly HttpClient _httpClient;
    private readonly AppDbContext _db;
    private readonly ILogger<AIRecipeService> _logger;

    public AIRecipeService(IConfiguration configuration, AppDbContext db, ILogger<AIRecipeService> logger)
    {
        _apiKey = configuration["Gemini:ApiKey"];
        _httpClient = new HttpClient();
        _db = db;
        _logger = logger;
    }

    /// <summary>
    /// Gợi ý món ăn dựa trên nguyên liệu (mirrors Python suggest_recipes).
    /// </summary>
    public async Task<Dictionary<string, object>> SuggestRecipesAsync(
        List<string> ingredients,
        Dictionary<string, object>? preferences = null,
        int limit = 5)
    {
        // If no ingredients, we enter "Discovery" mode
        ingredients ??= new List<string>();

        // Đưa limit vào preferences để cache key phân biệt theo số lượng món
        preferences ??= new Dictionary<string, object>();
        preferences["limit"] = limit;

        // Check cache
        var cacheKey = GenerateCacheKey(ingredients, preferences);
        var cached = await GetFromCacheAsync(cacheKey);
        if (cached != null)
        {
            return new Dictionary<string, object>
            {
                ["success"] = true,
                ["source"] = "cache",
                ["recipes"] = cached
            };
        }

        // Call Gemini AI
        try
        {
            var aiRecipes = await GenerateAISuggestionsAsync(ingredients, preferences, limit);
            await SaveToCacheAsync(cacheKey, aiRecipes);

            return new Dictionary<string, object>
            {
                ["success"] = true,
                ["source"] = "ai",
                ["recipes"] = aiRecipes
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "AI suggestion error");
            return new Dictionary<string, object>
            {
                ["success"] = false,
                ["error"] = $"Lỗi AI: {ex.Message}",
                ["recipes"] = new List<object>()
            };
        }
    }

    /// <summary>
    /// Gợi ý từ pantry (mirrors Python suggest_from_pantry).
    /// </summary>
    public async Task<Dictionary<string, object>> SuggestFromPantryAsync(
        int userId,
        Dictionary<string, object>? preferences = null,
        int limit = 5)
    {
        var pantryItems = await _db.PantryItems
            .Where(p => p.UserId == userId && p.Status == "active")
            .ToListAsync();

        var ingredients = pantryItems.Select(p => p.NameVi).ToList();
        return await SuggestRecipesAsync(ingredients, preferences, limit);
    }

    private async Task<List<object>> GenerateAISuggestionsAsync(
        List<string> ingredients,
        Dictionary<string, object>? preferences,
        int limit)
    {
        if (string.IsNullOrEmpty(_apiKey))
            throw new InvalidOperationException("Gemini API key chưa được cấu hình");

        preferences ??= new Dictionary<string, object>();

        var dietary = preferences.TryGetValue("dietary_restrictions", out var d) ? d?.ToString() ?? "" : "";
        var cuisine = preferences.TryGetValue("cuisine", out var c) ? c?.ToString() ?? "Việt Nam" : "Việt Nam";
        var difficulty = preferences.TryGetValue("difficulty", out var diff) ? diff?.ToString() ?? "any" : "any";

        var dietaryText = !string.IsNullOrEmpty(dietary) ? $"Chế độ ăn đặc biệt: {dietary}" : "";
        var difficultyText = difficulty != "any" ? $"Độ khó: {difficulty}" : "";

        var statusText = ingredients.Any() 
            ? $"CHẾ ĐỘ GỢI Ý: Dựa trên {ingredients.Count} nguyên liệu có sẵn: {string.Join(", ", ingredients)}."
            : "CHẾ ĐỘ KHÁM PHÁ: Tủ lạnh đang trống. Hãy gợi ý những món ăn Việt Nam 'quốc dân' cực kỳ hấp dẫn, dễ làm và phổ biến.";

        var prompt = $$"""
            Bạn là một đầu bếp Việt Nam tài ba với kiến thức sâu rộng về ẩm thực 3 miền.
            
            {{statusText}}
            Phong cách ẩm thực yêu thích: {{cuisine}}
            {{dietaryText}}
            {{difficultyText}}

            NHIỆM VỤ: Đề xuất {{limit}} món ăn. 
            - Nếu đang ở CHẾ ĐỘ GỢI Ý: Hãy ưu tiên các món sử dụng được nhiều nguyên liệu sẵn có nhất.
            - Nếu đang ở CHẾ ĐỘ KHÁM PHÁ: Hãy chọn những món ngon nhất, dễ tìm mua nguyên liệu nhất.

            QUY ĐỊNH TRẢ VỀ (CHỈ TRẢ VỀ JSON THUẦN, KHÔNG CÓ MARKDOWN, KHÔNG DÙNG ```):
            {
                "recipes": [
                    {
                        "name": "Tên món ăn hấp dẫn",
                        "description": "Mô tả ngắn gọn khiến người dùng muốn ăn ngay (1-2 câu, thân thiện, gần gũi người Việt)",
                        "image_url": "URL ảnh minh họa món ăn (ưu tiên ảnh giống món Việt thực tế, nếu không chắc hãy để null)",
                        "difficulty": "easy hoặc medium hoặc hard",
                        "prep_time": thời gian chuẩn bị (phút),
                        "cook_time": thời gian nấu (phút),
                        "servings": cho mấy người ăn (nguyên số),
                        "ingredients_used": ["những thứ đã có trong tủ"],
                        "ingredients_missing": ["những thứ cần mua thêm"],
                        "match_score": độ phù hợp từ 0.0 đến 1.0 (float),
                        "instructions": [
                           "Bước 1: Sơ chế...",
                           "Bước 2: Chế biến...",
                           "Bước 3: Hoàn thiện..."
                        ],
                        "tips": "Bí quyết nấu món này ngon nhất"
                    }
                ]
            }

            Sắp xếp theo thứ tự ưu tiên nhất lên đầu.
            """;

        // Call Gemini REST API
        // Use Gemini 2.5 Flash (free tier in current project)
        var url = $"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={_apiKey}";

        var requestBody = new
        {
            contents = new[]
            {
                new { parts = new[] { new { text = prompt } } }
            }
        };

        var json = JsonSerializer.Serialize(requestBody);
        var content = new StringContent(json, Encoding.UTF8, "application/json");
        var response = await _httpClient.PostAsync(url, content);
        var responseText = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
            throw new Exception($"Gemini API error: {response.StatusCode} - {responseText}");

        // Parse response
        using var doc = JsonDocument.Parse(responseText);
        var text = doc.RootElement
            .GetProperty("candidates")[0]
            .GetProperty("content")
            .GetProperty("parts")[0]
            .GetProperty("text")
            .GetString() ?? "";

        // Strip markdown code block
        text = text.Trim();
        if (text.StartsWith("```"))
        {
            var lines = text.Split('\n');
            text = string.Join('\n', lines.Skip(1).Take(lines.Length - 2));
        }

        // Parse JSON
        try
        {
            using var resultDoc = JsonDocument.Parse(text);
            var recipes = resultDoc.RootElement.GetProperty("recipes");
            return JsonSerializer.Deserialize<List<object>>(recipes.GetRawText()) ?? new List<object>();
        }
        catch (JsonException)
        {
            // Try regex extraction
            var match = Regex.Match(text, @"\{[\s\S]*\}");
            if (match.Success)
            {
                using var resultDoc = JsonDocument.Parse(match.Value);
                var recipes = resultDoc.RootElement.GetProperty("recipes");
                return JsonSerializer.Deserialize<List<object>>(recipes.GetRawText()) ?? new List<object>();
            }
            throw new Exception("Không thể parse AI response");
        }
    }

    private string GenerateCacheKey(List<string> ingredients, Dictionary<string, object>? preferences)
    {
        var normalized = ingredients.Select(i => i.ToLower().Trim()).OrderBy(i => i).ToList();
        var keyData = new { ingredients = normalized, preferences = preferences ?? new Dictionary<string, object>() };
        var keyString = JsonSerializer.Serialize(keyData, new JsonSerializerOptions { WriteIndented = false });
        var hashBytes = MD5.HashData(Encoding.UTF8.GetBytes(keyString));
        return Convert.ToHexString(hashBytes).ToLower();
    }

    private async Task<List<object>?> GetFromCacheAsync(string cacheKey)
    {
        try
        {
            var entry = await _db.AICache.FirstOrDefaultAsync(c => c.CacheKey == cacheKey);
            if (entry != null && entry.ExpiresAt > DateTime.UtcNow)
            {
                return JsonSerializer.Deserialize<List<object>>(entry.ResponseData);
            }
            if (entry != null)
            {
                _db.AICache.Remove(entry);
                await _db.SaveChangesAsync();
            }
            return null;
        }
        catch { return null; }
    }

    private async Task SaveToCacheAsync(string cacheKey, List<object> recipes, int ttlHours = 24)
    {
        try
        {
            var existing = await _db.AICache.FirstOrDefaultAsync(c => c.CacheKey == cacheKey);
            if (existing != null) _db.AICache.Remove(existing);

            _db.AICache.Add(new AICache
            {
                CacheKey = cacheKey,
                ResponseData = JsonSerializer.Serialize(recipes),
                ExpiresAt = DateTime.UtcNow.AddHours(ttlHours)
            });
            await _db.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Cache save error");
        }
    }
}
