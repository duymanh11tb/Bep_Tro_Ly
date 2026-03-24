using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using BepTroLy.API.Data;
using BepTroLy.API.Models;
using Microsoft.EntityFrameworkCore;

namespace BepTroLy.API.Services;

/// <summary>
/// Hybrid recipe suggestion service:
/// - Spoonacular is primary source for recipe suggestion.
/// - Gemini is used only for Vietnamese translation when requested.
/// </summary>
public class AIRecipeService
{
    private const int DemoDefaultLimit = 2;
    private const int DemoMaxLimit = 2;
    private const int CacheTtlHours = 72;

    private readonly string? _geminiApiKey;
    private readonly string? _spoonacularApiKey;
    private readonly string _spoonacularBaseUrl;
    private readonly HttpClient _httpClient;
    private readonly AppDbContext _db;
    private readonly ILogger<AIRecipeService> _logger;

    public AIRecipeService(IConfiguration configuration, AppDbContext db, ILogger<AIRecipeService> logger)
    {
        _geminiApiKey = configuration["Gemini:ApiKey"];
        _spoonacularApiKey = configuration["Spoonacular:ApiKey"];
        _spoonacularBaseUrl = (configuration["Spoonacular:BaseUrl"] ?? "https://api.spoonacular.com").Trim().TrimEnd('/');
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
        int limit = DemoDefaultLimit)
    {
        // If no ingredients, we enter "Discovery" mode
        ingredients ??= new List<string>();
        limit = Math.Clamp(limit, 1, DemoMaxLimit);

        // Ensure preferences is not null and include limit so cache key
        // differentiates between different requested recipe counts.
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

        // Spoonacular as primary provider
        try
        {
            var recipes = await GenerateSuggestionsAsync(ingredients, preferences, limit);
            await SaveToCacheAsync(cacheKey, recipes, CacheTtlHours);

            return new Dictionary<string, object>
            {
                ["success"] = true,
                ["source"] = "spoonacular",
                ["recipes"] = recipes
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Recipe suggestion error");
            return new Dictionary<string, object>
            {
                ["success"] = false,
                ["error"] = $"Lỗi gợi ý công thức: {ex.Message}",
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
        int limit = DemoDefaultLimit)
    {
        var pantryItems = await _db.PantryItems
            .Where(p => p.UserId == userId && p.Status == "active")
            .ToListAsync();

        var ingredients = pantryItems.Select(p => p.NameVi).ToList();
        return await SuggestRecipesAsync(ingredients, preferences, limit);
    }

    private async Task<List<object>> GenerateSuggestionsAsync(
        List<string> ingredients,
        Dictionary<string, object>? preferences,
        int limit)
    {
        if (string.IsNullOrWhiteSpace(_spoonacularApiKey))
            throw new InvalidOperationException("Spoonacular API key chưa được cấu hình");

        preferences ??= new Dictionary<string, object>();
        var viRequested = IsVietnameseRequested(preferences);

        var normalizedIngredients = ingredients
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Select(x => x.Trim())
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .Take(12)
            .ToList();

        if (normalizedIngredients.Count == 0)
        {
            return new List<object>();
        }

        var findJson = await GetJsonAsync(
            "/recipes/findByIngredients",
            new Dictionary<string, string?>
            {
                ["ingredients"] = string.Join(",", normalizedIngredients),
                ["number"] = limit.ToString(),
                ["ranking"] = "2",
                ["ignorePantry"] = "true"
            });

        if (findJson == null || findJson.RootElement.ValueKind != JsonValueKind.Array)
        {
            return new List<object>();
        }

        var recipes = new List<object>();
        foreach (var item in findJson.RootElement.EnumerateArray())
        {
            if (!item.TryGetProperty("id", out var idElement) || !idElement.TryGetInt32(out var recipeId))
            {
                continue;
            }

            var infoJson = await GetJsonAsync(
                $"/recipes/{recipeId}/information",
                new Dictionary<string, string?>
                {
                    ["includeNutrition"] = "false"
                });

            if (infoJson == null)
            {
                continue;
            }

            var mapped = await MapSpoonacularRecipeAsync(
                item,
                infoJson.RootElement,
                normalizedIngredients,
                viRequested);

            recipes.Add(mapped);
            if (recipes.Count >= limit)
            {
                break;
            }
        }

        return recipes;
    }

    private async Task<Dictionary<string, object>> MapSpoonacularRecipeAsync(
        JsonElement findItem,
        JsonElement infoItem,
        List<string> requestedIngredients,
        bool viRequested)
    {
        var titleEn = infoItem.TryGetProperty("title", out var titleElement)
            ? titleElement.GetString() ?? "Recipe"
            : "Recipe";
        var summaryEn = StripHtml(infoItem.TryGetProperty("summary", out var summaryElement) ? summaryElement.GetString() : null);

        var prepTime = TryGetInt32(infoItem, "preparationMinutes");
        var cookTime = TryGetInt32(infoItem, "cookingMinutes");
        var readyIn = TryGetInt32(infoItem, "readyInMinutes");
        if (prepTime <= 0 && cookTime <= 0 && readyIn > 0)
        {
            cookTime = readyIn;
        }
        else if (cookTime <= 0 && readyIn > prepTime)
        {
            cookTime = Math.Max(0, readyIn - prepTime);
        }

        var servings = Math.Max(1, TryGetInt32(infoItem, "servings"));
        var imageUrl = infoItem.TryGetProperty("image", out var imageElement) ? imageElement.GetString() ?? string.Empty : string.Empty;

        var instructionsEn = ExtractInstructions(infoItem);
        if (instructionsEn.Count == 0 && !string.IsNullOrWhiteSpace(summaryEn))
        {
            instructionsEn.Add("Step 1: Follow the preparation guidance in the description.");
        }

        var ingredientsUsed = ExtractUsedIngredients(findItem, requestedIngredients);
        var ingredientsMissing = ExtractMissingIngredients(findItem);

        var baseRecipe = new Dictionary<string, object>
        {
            ["name"] = titleEn,
            ["description"] = string.IsNullOrWhiteSpace(summaryEn) ? "Recipe from Spoonacular catalog." : summaryEn,
            ["image_url"] = imageUrl,
            ["difficulty"] = InferDifficulty(prepTime + cookTime, instructionsEn.Count),
            ["prep_time"] = prepTime,
            ["cook_time"] = cookTime,
            ["servings"] = servings,
            ["ingredients_used"] = ingredientsUsed,
            ["ingredients_missing"] = ingredientsMissing,
            ["match_score"] = CalculateMatchScore(findItem),
            ["instructions"] = instructionsEn,
            ["tips"] = "Taste and adjust seasoning to your preference."
        };

        if (viRequested && !string.IsNullOrWhiteSpace(_geminiApiKey))
        {
            await TranslateRecipeToVietnameseAsync(baseRecipe);
        }

        return baseRecipe;
    }

    private async Task TranslateRecipeToVietnameseAsync(Dictionary<string, object> recipe)
    {
        try
        {
            var instructions = recipe["instructions"] as List<string> ?? new List<string>();
            var payload = new
            {
                name = recipe["name"]?.ToString() ?? string.Empty,
                description = recipe["description"]?.ToString() ?? string.Empty,
                tips = recipe["tips"]?.ToString() ?? string.Empty,
                instructions
            };

            var prompt = $$"""
            Dịch nội dung sau sang tiếng Việt tự nhiên, giữ nguyên JSON schema.
            Không thêm markdown, không thêm giải thích.
            JSON đầu vào:
            {{JsonSerializer.Serialize(payload)}}
            Trả về JSON duy nhất theo schema:
            {"name":"...","description":"...","tips":"...","instructions":["..."]}
            """;

            var translatedText = await CallGeminiTextAsync(prompt);
            using var doc = JsonDocument.Parse(translatedText);
            var root = doc.RootElement;
            recipe["name"] = root.TryGetProperty("name", out var nameEl) ? nameEl.GetString() ?? payload.name : payload.name;
            recipe["description"] = root.TryGetProperty("description", out var descEl) ? descEl.GetString() ?? payload.description : payload.description;
            recipe["tips"] = root.TryGetProperty("tips", out var tipsEl) ? tipsEl.GetString() ?? payload.tips : payload.tips;
            if (root.TryGetProperty("instructions", out var insEl) && insEl.ValueKind == JsonValueKind.Array)
            {
                recipe["instructions"] = insEl.EnumerateArray().Select(x => x.GetString() ?? string.Empty).Where(x => !string.IsNullOrWhiteSpace(x)).ToList();
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to translate recipe to Vietnamese, keeping English content");
        }
    }

    private async Task<string> CallGeminiTextAsync(string prompt)
    {
        if (string.IsNullOrWhiteSpace(_geminiApiKey))
            throw new InvalidOperationException("Gemini API key chưa được cấu hình");

        var url = $"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={_geminiApiKey}";
        var requestBody = new
        {
            contents = new[] { new { parts = new[] { new { text = prompt } } } }
        };

        var json = JsonSerializer.Serialize(requestBody);
        using var content = new StringContent(json, Encoding.UTF8, "application/json");
        using var response = await _httpClient.PostAsync(url, content);
        var responseText = await response.Content.ReadAsStringAsync();
        if (!response.IsSuccessStatusCode)
            throw new Exception($"Gemini API error: {response.StatusCode} - {responseText}");

        using var doc = JsonDocument.Parse(responseText);
        var text = doc.RootElement.GetProperty("candidates")[0].GetProperty("content").GetProperty("parts")[0].GetProperty("text").GetString() ?? string.Empty;
        text = text.Trim();
        if (text.StartsWith("```"))
        {
            var lines = text.Split('\n');
            text = string.Join('\n', lines.Skip(1).Take(Math.Max(0, lines.Length - 2)));
        }

        // Best effort: extract json object block if model adds extra text.
        var match = Regex.Match(text, @"\{[\s\S]*\}");
        return match.Success ? match.Value : text;
    }

    private async Task<JsonDocument?> GetJsonAsync(string path, Dictionary<string, string?> query)
    {
        var requestUri = BuildSpoonacularUri(path, query);
        using var response = await _httpClient.GetAsync(requestUri);
        var responseText = await response.Content.ReadAsStringAsync();
        if (!response.IsSuccessStatusCode)
        {
            _logger.LogWarning("Spoonacular request failed {StatusCode} for {Path}: {Body}", (int)response.StatusCode, path, responseText);
            return null;
        }

        try
        {
            return JsonDocument.Parse(responseText);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Cannot parse Spoonacular response for {Path}", path);
            return null;
        }
    }

    private string BuildSpoonacularUri(string path, Dictionary<string, string?> query)
    {
        var builder = new StringBuilder();
        builder.Append(_spoonacularBaseUrl);
        builder.Append(path);
        builder.Append('?');
        builder.Append("apiKey=");
        builder.Append(Uri.EscapeDataString(_spoonacularApiKey ?? string.Empty));

        foreach (var pair in query.Where(x => !string.IsNullOrWhiteSpace(x.Value)))
        {
            builder.Append('&');
            builder.Append(Uri.EscapeDataString(pair.Key));
            builder.Append('=');
            builder.Append(Uri.EscapeDataString(pair.Value!));
        }

        return builder.ToString();
    }

    private static bool IsVietnameseRequested(Dictionary<string, object>? preferences)
    {
        if (preferences == null) return true; // default to Vietnamese for existing app behavior
        var language = GetPreferenceString(preferences, "language")
            ?? GetPreferenceString(preferences, "lang")
            ?? GetPreferenceString(preferences, "locale");
        if (string.IsNullOrWhiteSpace(language)) return true;

        var normalized = language.Trim().ToLowerInvariant();
        return normalized.StartsWith("vi");
    }

    private static string? GetPreferenceString(Dictionary<string, object> preferences, string key)
    {
        if (!preferences.TryGetValue(key, out var raw) || raw == null)
        {
            return null;
        }

        if (raw is JsonElement element)
        {
            return element.ValueKind switch
            {
                JsonValueKind.String => element.GetString(),
                JsonValueKind.Number => element.GetRawText(),
                _ => raw.ToString()
            };
        }

        return raw.ToString();
    }

    private static int TryGetInt32(JsonElement element, string propertyName)
    {
        if (!element.TryGetProperty(propertyName, out var property)) return 0;
        if (property.ValueKind == JsonValueKind.Number && property.TryGetInt32(out var n)) return n;
        if (property.ValueKind == JsonValueKind.String && int.TryParse(property.GetString(), out var s)) return s;
        return 0;
    }

    private static List<string> ExtractInstructions(JsonElement detail)
    {
        var instructions = new List<string>();
        if (detail.TryGetProperty("analyzedInstructions", out var analyzed) && analyzed.ValueKind == JsonValueKind.Array)
        {
            foreach (var group in analyzed.EnumerateArray())
            {
                if (!group.TryGetProperty("steps", out var steps) || steps.ValueKind != JsonValueKind.Array) continue;
                foreach (var step in steps.EnumerateArray())
                {
                    var number = step.TryGetProperty("number", out var nEl) && nEl.TryGetInt32(out var n) ? n : instructions.Count + 1;
                    var text = step.TryGetProperty("step", out var tEl) ? tEl.GetString() ?? string.Empty : string.Empty;
                    text = Regex.Replace(text.Trim(), @"\s+", " ");
                    if (!string.IsNullOrWhiteSpace(text))
                    {
                        instructions.Add($"Step {number}: {text}");
                    }
                }
            }
        }
        return instructions;
    }

    private static List<string> ExtractUsedIngredients(JsonElement findItem, List<string> fallback)
    {
        if (findItem.TryGetProperty("usedIngredients", out var used) && used.ValueKind == JsonValueKind.Array)
        {
            return used.EnumerateArray()
                .Select(x => x.TryGetProperty("name", out var n) ? n.GetString() ?? string.Empty : string.Empty)
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();
        }
        return fallback.Take(4).ToList();
    }

    private static List<string> ExtractMissingIngredients(JsonElement findItem)
    {
        if (findItem.TryGetProperty("missedIngredients", out var missed) && missed.ValueKind == JsonValueKind.Array)
        {
            return missed.EnumerateArray()
                .Select(x => x.TryGetProperty("name", out var n) ? n.GetString() ?? string.Empty : string.Empty)
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();
        }
        return new List<string>();
    }

    private static double CalculateMatchScore(JsonElement findItem)
    {
        var usedCount = findItem.TryGetProperty("usedIngredientCount", out var usedEl) && usedEl.TryGetInt32(out var used) ? used : 0;
        var missedCount = findItem.TryGetProperty("missedIngredientCount", out var missEl) && missEl.TryGetInt32(out var miss) ? miss : 0;
        var denominator = Math.Max(1, usedCount + missedCount);
        return Math.Min(0.99, Math.Max(0.35, (double)usedCount / denominator));
    }

    private static string InferDifficulty(int totalMinutes, int instructionCount)
    {
        if (totalMinutes <= 20 && instructionCount <= 4) return "easy";
        if (totalMinutes <= 45 && instructionCount <= 7) return "medium";
        return "hard";
    }

    private static string StripHtml(string? html)
    {
        if (string.IsNullOrWhiteSpace(html))
        {
            return string.Empty;
        }
        var withoutTags = Regex.Replace(html, "<.*?>", " ");
        return WebUtility.HtmlDecode(Regex.Replace(withoutTags, @"\s+", " ")).Trim();
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
