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
/// Mirrors Python's AIRecipeService.
/// </summary>
public class AIRecipeService
{
    private static readonly ConcurrentDictionary<string, SemaphoreSlim> _cacheKeyLocks = new();
    private static readonly object _circuitLock = new();
    private static readonly HashSet<string> _blockedImageHosts = new(StringComparer.OrdinalIgnoreCase)
    {
        "imgur.com",
        "i.imgur.com",
        "m.imgur.com",
        "source.unsplash.com",
        "picsum.photos",
        "loremflickr.com"
    };

    private static readonly Dictionary<string, string> _exactDishFallbackImages = new(StringComparer.OrdinalIgnoreCase)
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

    private static readonly Dictionary<string, string[]> _keywordFallbackImages = new(StringComparer.OrdinalIgnoreCase)
    {
        ["bo"] = new[]
        {
            "https://images.pexels.com/photos/1860204/pexels-photo-1860204.jpeg?auto=compress&cs=tinysrgb&w=1200",
            "https://images.pexels.com/photos/361184/asparagus-steak-veal-steak-veal-361184.jpeg?auto=compress&cs=tinysrgb&w=1200",
            "https://images.pexels.com/photos/769289/pexels-photo-769289.jpeg?auto=compress&cs=tinysrgb&w=1200"
        },
        ["ga"] = new[]
        {
            "https://images.pexels.com/photos/616354/pexels-photo-616354.jpeg?auto=compress&cs=tinysrgb&w=1200",
            "https://images.pexels.com/photos/2338407/pexels-photo-2338407.jpeg?auto=compress&cs=tinysrgb&w=1200"
        },
        ["ca"] = new[]
        {
            "https://images.pexels.com/photos/262959/pexels-photo-262959.jpeg?auto=compress&cs=tinysrgb&w=1200",
            "https://images.pexels.com/photos/1516415/pexels-photo-1516415.jpeg?auto=compress&cs=tinysrgb&w=1200"
        },
        ["tom"] = new[]
        {
            "https://images.pexels.com/photos/3296277/pexels-photo-3296277.jpeg?auto=compress&cs=tinysrgb&w=1200",
            "https://images.pexels.com/photos/725991/pexels-photo-725991.jpeg?auto=compress&cs=tinysrgb&w=1200"
        },
        ["bun"] = new[]
        {
            "https://images.pexels.com/photos/884600/pexels-photo-884600.jpeg?auto=compress&cs=tinysrgb&w=1200",
            "https://images.pexels.com/photos/723198/pexels-photo-723198.jpeg?auto=compress&cs=tinysrgb&w=1200"
        },
        ["pho"] = new[]
        {
            "https://images.pexels.com/photos/6646035/pexels-photo-6646035.jpeg?auto=compress&cs=tinysrgb&w=1200"
        },
        ["mi"] = new[]
        {
            "https://images.pexels.com/photos/1279330/pexels-photo-1279330.jpeg?auto=compress&cs=tinysrgb&w=1200"
        },
        ["lau"] = new[]
        {
            "https://images.pexels.com/photos/699953/pexels-photo-699953.jpeg?auto=compress&cs=tinysrgb&w=1200"
        },
        ["com"] = new[]
        {
            "https://images.pexels.com/photos/723198/pexels-photo-723198.jpeg?auto=compress&cs=tinysrgb&w=1200"
        },
        ["chay"] = new[]
        {
            "https://images.pexels.com/photos/1640774/pexels-photo-1640774.jpeg?auto=compress&cs=tinysrgb&w=1200"
        }
    };

    private static readonly string[] _genericFallbackImages =
    {
        "https://images.pexels.com/photos/1640774/pexels-photo-1640774.jpeg?auto=compress&cs=tinysrgb&w=1200",
        "https://images.pexels.com/photos/958545/pexels-photo-958545.jpeg?auto=compress&cs=tinysrgb&w=1200",
        "https://images.pexels.com/photos/958547/pexels-photo-958547.jpeg?auto=compress&cs=tinysrgb&w=1200"
    };

    private static int _consecutiveGeminiFailures;
    private static DateTime _circuitOpenUntilUtc = DateTime.MinValue;
    private static readonly TimeSpan _geminiTimeout = TimeSpan.FromSeconds(20);
    private static readonly TimeSpan _circuitOpenDuration = TimeSpan.FromSeconds(45);
    private const int GeminiFailureThreshold = 5;

    private readonly string? _apiKey;
    private readonly HttpClient _httpClient;
    private readonly AppDbContext _db;
    private readonly ILogger<AIRecipeService> _logger;

    public AIRecipeService(IConfiguration configuration, AppDbContext db, ILogger<AIRecipeService> logger)
    {
        _apiKey = configuration["Gemini:ApiKey"];
        _httpClient = new HttpClient { Timeout = _geminiTimeout };
        _db = db;
        _logger = logger;
    }

    /// <summary>
    /// Gợi ý món ăn dựa trên nguyên liệu (mirrors Python suggest_recipes).
    /// </summary>
    public async Task<Dictionary<string, object>> SuggestRecipesAsync(
        List<string> ingredients,
        Dictionary<string, object>? preferences = null,
        int limit = 8,
        int offset = 0)
    {
        limit = Math.Clamp(limit, 1, 24);
        offset = Math.Max(0, offset);
        const int generationLimit = 24;

        // If no ingredients, we enter "Discovery" mode
        ingredients ??= new List<string>();

        // Ensure preferences is not null.
        preferences ??= new Dictionary<string, object>();

        // Check cache
        var cacheKey = GenerateCacheKey(ingredients, preferences, generationLimit);
        var cached = await GetFromCacheAsync(cacheKey);
        if (cached != null)
        {
            var cachedWithImages = EnsureRecipeImages(cached);
            return BuildPagedSuccessResponse(cachedWithImages, "cache", limit, offset);
        }

        // Prevent thundering herd: same cache key should generate AI only once at a time.
        var keyLock = _cacheKeyLocks.GetOrAdd(cacheKey, _ => new SemaphoreSlim(1, 1));
        await keyLock.WaitAsync();

        try
        {
            // Re-check cache after acquiring lock because another request may have filled it.
            cached = await GetFromCacheAsync(cacheKey);
            if (cached != null)
            {
                var cachedWithImages = EnsureRecipeImages(cached);
                return BuildPagedSuccessResponse(cachedWithImages, "cache", limit, offset);
            }

            var aiRecipes = await GenerateAISuggestionsAsync(ingredients, preferences, generationLimit);
            if (aiRecipes.Count < generationLimit)
            {
                var fallback = BuildLocalFallbackRecipes(ingredients, generationLimit);
                aiRecipes = MergeUniqueRecipes(aiRecipes, fallback, generationLimit);
            }

            var recipesWithImages = EnsureRecipeImages(aiRecipes);
            await SaveToCacheAsync(cacheKey, recipesWithImages);

            return BuildPagedSuccessResponse(recipesWithImages, "ai", limit, offset);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "AI suggestion error");

            var fallbackRecipes = BuildLocalFallbackRecipes(ingredients, generationLimit);
            if (fallbackRecipes.Count > 0)
            {
                await SaveToCacheAsync(cacheKey, fallbackRecipes, ttlHours: 2);
                return BuildPagedSuccessResponse(fallbackRecipes, "local_fallback", limit, offset);
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
            keyLock.Release();
            if (keyLock.CurrentCount > 0)
            {
                _cacheKeyLocks.TryRemove(cacheKey, out _);
            }
        }
    }

    /// <summary>
    /// Gợi ý từ pantry (mirrors Python suggest_from_pantry).
    /// </summary>
    public async Task<Dictionary<string, object>> SuggestFromPantryAsync(
        int userId,
        Dictionary<string, object>? preferences = null,
        int limit = 8,
        int offset = 0)
    {
        var pantryItems = await _db.PantryItems
            .Where(p => p.UserId == userId && p.Status == "active")
            .ToListAsync();

        var ingredients = pantryItems.Select(p => p.NameVi).ToList();
        return await SuggestRecipesAsync(ingredients, preferences, limit, offset);
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
        var regionalSeasoning = preferences.TryGetValue("regional_seasoning", out var rs) ? rs?.ToString() ?? "" : "";
        var difficulty = preferences.TryGetValue("difficulty", out var diff) ? diff?.ToString() ?? "any" : "any";

        var dietaryText = !string.IsNullOrEmpty(dietary) ? $"Chế độ ăn đặc biệt: {dietary}" : "";
        var regionalSeasoningText = !string.IsNullOrEmpty(regionalSeasoning)
            ? $"Định hướng nêm vị theo vùng miền: {regionalSeasoning}"
            : "";
        var difficultyText = difficulty != "any" ? $"Độ khó: {difficulty}" : "";

        var statusText = ingredients.Any()
            ? $"CHẾ ĐỘ GỢI Ý: Dựa trên {ingredients.Count} nguyên liệu có sẵn: {string.Join(", ", ingredients)}."
            : "CHẾ ĐỘ KHÁM PHÁ: Tủ lạnh đang trống. Hãy gợi ý những món ăn Việt Nam 'quốc dân' cực kỳ hấp dẫn, dễ làm và phổ biến.";

        var overGenerateLimit = Math.Min(24, Math.Max(limit + 4, limit * 2));

        var prompt = $$"""
            Bạn là một đầu bếp Việt Nam tài ba với kiến thức sâu rộng về ẩm thực 3 miền.
            
            {{statusText}}
            Phong cách ẩm thực yêu thích: {{cuisine}}
            {{regionalSeasoningText}}
            {{dietaryText}}
            {{difficultyText}}

            NHIỆM VỤ: Đề xuất {{overGenerateLimit}} món ăn KHÁC NHAU rõ ràng, không trùng lặp tên món.
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
        if (IsCircuitOpen(out var retryAfter))
        {
            var waitSeconds = Math.Max(1, (int)Math.Ceiling(retryAfter.TotalSeconds));
            throw new InvalidOperationException($"AI đang quá tải, vui lòng thử lại sau {waitSeconds} giây.");
        }

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
        string responseText;
        HttpResponseMessage response;

        try
        {
            response = await _httpClient.PostAsync(url, content);
            responseText = await response.Content.ReadAsStringAsync();
        }
        catch (TaskCanceledException ex)
        {
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
            throw new Exception($"Gemini API error: {response.StatusCode} - {responseText}");
        }

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
            var parsed = JsonSerializer.Deserialize<List<object>>(recipes.GetRawText()) ?? new List<object>();
            RecordGeminiSuccess();
            return NormalizeAndRankAiRecipes(parsed, ingredients, limit);
        }
        catch (JsonException)
        {
            // Try regex extraction
            var match = Regex.Match(text, @"\{[\s\S]*\}");
            if (match.Success)
            {
                using var resultDoc = JsonDocument.Parse(match.Value);
                var recipes = resultDoc.RootElement.GetProperty("recipes");
                var parsed = JsonSerializer.Deserialize<List<object>>(recipes.GetRawText()) ?? new List<object>();
                RecordGeminiSuccess();
                return NormalizeAndRankAiRecipes(parsed, ingredients, limit);
            }

            RecordGeminiFailure();
            throw new Exception("Không thể parse AI response");
        }
    }

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
            _consecutiveGeminiFailures += 1;
            if (_consecutiveGeminiFailures >= GeminiFailureThreshold)
            {
                _circuitOpenUntilUtc = DateTime.UtcNow.Add(_circuitOpenDuration);
                _consecutiveGeminiFailures = 0;
            }
        }
    }

    private string GenerateCacheKey(List<string> ingredients, Dictionary<string, object>? preferences, int limit)
    {
        var normalized = ingredients.Select(i => i.ToLower().Trim()).OrderBy(i => i).ToList();
        var keyData = new
        {
            ingredients = normalized,
            preferences = preferences ?? new Dictionary<string, object>(),
            limit
        };
        var keyString = JsonSerializer.Serialize(keyData, new JsonSerializerOptions { WriteIndented = false });
        var hashBytes = MD5.HashData(Encoding.UTF8.GetBytes(keyString));
        return Convert.ToHexString(hashBytes).ToLower();
    }

    private List<object> NormalizeAndRankAiRecipes(List<object> rawRecipes, List<string> ingredients, int maxCount)
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

            var normalized = NormalizeRecipeMap(map, normalizedIngredients);
            var key = BuildRecipeKey(normalized);
            if (string.IsNullOrWhiteSpace(key)) continue;

            if (!unique.TryGetValue(key, out var existing))
            {
                unique[key] = normalized;
                continue;
            }

            var oldScore = ParseDouble(existing, "match_score", 0.0);
            var newScore = ParseDouble(normalized, "match_score", 0.0);
            if (newScore > oldScore)
            {
                unique[key] = normalized;
            }
        }

        return unique.Values
            .OrderByDescending(x => ParseDouble(x, "match_score", 0.0))
            .ThenBy(x => ParseInt(x, "prep_time", 0) + ParseInt(x, "cook_time", 0))
            .Take(maxCount)
            .Select(x => (object)x)
            .ToList();
    }

    private Dictionary<string, object> BuildPagedSuccessResponse(
        List<object> allRecipes,
        string source,
        int limit,
        int offset)
    {
        var normalized = EnsureRecipeImages(allRecipes);
        var paged = normalized.Skip(offset).Take(limit).ToList();
        var nextOffset = offset + paged.Count;
        var hasMore = nextOffset < normalized.Count;

        return new Dictionary<string, object>
        {
            ["success"] = true,
            ["source"] = source,
            ["recipes"] = paged,
            ["offset"] = offset,
            ["limit"] = limit,
            ["next_offset"] = nextOffset,
            ["has_more"] = hasMore,
            ["total_candidates"] = normalized.Count
        };
    }

    private Dictionary<string, object> NormalizeRecipeMap(
        Dictionary<string, object> map,
        HashSet<string> normalizedIngredients)
    {
        var normalized = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);

        var name = map.TryGetValue("name", out var rawName)
            ? rawName?.ToString()?.Trim() ?? "Món ngon Việt Nam"
            : "Món ngon Việt Nam";

        var description = map.TryGetValue("description", out var rawDescription)
            ? rawDescription?.ToString()?.Trim() ?? "Món ngon dễ làm, hợp vị gia đình."
            : "Món ngon dễ làm, hợp vị gia đình.";

        var ingredientsUsed = NormalizeStringList(map, "ingredients_used");
        var ingredientsMissing = NormalizeStringList(map, "ingredients_missing");
        var instructions = NormalizeStringList(map, "instructions");

        if (ingredientsUsed.Count == 0 && normalizedIngredients.Count > 0)
        {
            var matching = normalizedIngredients
                .Where(i => NormalizeText(name).Contains(i) || NormalizeText(description).Contains(i))
                .Take(4)
                .ToList();
            ingredientsUsed = matching;
        }

        var prepTime = Math.Clamp(ParseInt(map, "prep_time", 8), 0, 180);
        var cookTime = Math.Clamp(ParseInt(map, "cook_time", 15), 1, 240);
        var servings = Math.Clamp(ParseInt(map, "servings", 2), 1, 12);
        var score = Math.Clamp(ParseDouble(map, "match_score", 0.55), 0.0, 1.0);

        normalized["name"] = name;
        normalized["description"] = description;
        normalized["difficulty"] = NormalizeDifficulty(map.TryGetValue("difficulty", out var rawDifficulty)
            ? rawDifficulty?.ToString()
            : null);
        normalized["prep_time"] = prepTime;
        normalized["cook_time"] = cookTime;
        normalized["servings"] = servings;
        normalized["ingredients_used"] = ingredientsUsed;
        normalized["ingredients_missing"] = ingredientsMissing;
        normalized["instructions"] = instructions;
        normalized["tips"] = map.TryGetValue("tips", out var rawTips)
            ? rawTips?.ToString() ?? "Nêm nếm vừa vị trước khi tắt bếp."
            : "Nêm nếm vừa vị trước khi tắt bếp.";
        normalized["match_score"] = score;
        normalized["ingredients_expiring_count"] = ParseInt(map, "ingredients_expiring_count", 0);

        if (map.TryGetValue("image_url", out var imageObj) && IsValidRecipeImageUrl(imageObj?.ToString()))
        {
            normalized["image_url"] = imageObj!.ToString()!;
        }
        else
        {
            normalized["image_url"] = BuildFallbackImageUrl(name);
        }

        return normalized;
    }

    private static List<string> NormalizeStringList(Dictionary<string, object> map, string key)
    {
        if (!map.TryGetValue(key, out var value) || value == null)
        {
            return new List<string>();
        }

        if (value is JsonElement element && element.ValueKind == JsonValueKind.Array)
        {
            return element.EnumerateArray()
                .Select(x => x.ToString().Trim())
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();
        }

        if (value is IEnumerable<string> stringList)
        {
            return stringList
                .Select(x => x.Trim())
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();
        }

        if (value is IEnumerable<object> list)
        {
            return list
                .Select(x => x?.ToString()?.Trim())
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .Select(x => x!)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();
        }

        var single = value.ToString()?.Trim();
        if (string.IsNullOrWhiteSpace(single))
        {
            return new List<string>();
        }

        return single
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    private static int ParseInt(Dictionary<string, object> map, string key, int fallback)
    {
        if (!map.TryGetValue(key, out var value) || value == null)
        {
            return fallback;
        }

        if (value is JsonElement element)
        {
            if (element.ValueKind == JsonValueKind.Number && element.TryGetInt32(out var numeric))
            {
                return numeric;
            }

            if (element.ValueKind == JsonValueKind.String && int.TryParse(element.GetString(), out var fromString))
            {
                return fromString;
            }
        }

        if (value is int i) return i;
        if (int.TryParse(value.ToString(), out var parsed)) return parsed;
        return fallback;
    }

    private static double ParseDouble(Dictionary<string, object> map, string key, double fallback)
    {
        if (!map.TryGetValue(key, out var value) || value == null)
        {
            return fallback;
        }

        if (value is JsonElement element)
        {
            if (element.ValueKind == JsonValueKind.Number && element.TryGetDouble(out var numeric))
            {
                return numeric;
            }

            if (element.ValueKind == JsonValueKind.String && double.TryParse(element.GetString(), out var fromString))
            {
                return fromString;
            }
        }

        if (value is double d) return d;
        if (value is float f) return f;
        if (double.TryParse(value.ToString(), out var parsed)) return parsed;
        return fallback;
    }

    private static string NormalizeDifficulty(string? raw)
    {
        var value = raw?.Trim().ToLowerInvariant();
        return value switch
        {
            "easy" => "easy",
            "medium" => "medium",
            "hard" => "hard",
            _ => "easy"
        };
    }

    private static string BuildRecipeKey(Dictionary<string, object> map)
    {
        var name = map.TryGetValue("name", out var rawName)
            ? NormalizeText(rawName?.ToString() ?? string.Empty)
            : string.Empty;

        var used = NormalizeStringList(map, "ingredients_used")
            .Select(NormalizeText)
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .OrderBy(x => x)
            .Take(4);

        return $"{name}|{string.Join("|", used)}";
    }

    private static string NormalizeText(string input)
    {
        if (string.IsNullOrWhiteSpace(input)) return string.Empty;

        var normalized = input.Trim().ToLowerInvariant().Normalize(NormalizationForm.FormD);
        var sb = new StringBuilder(normalized.Length);

        foreach (var c in normalized)
        {
            var category = CharUnicodeInfo.GetUnicodeCategory(c);
            if (category == UnicodeCategory.NonSpacingMark) continue;

            if (c == 'đ')
            {
                sb.Append('d');
                continue;
            }

            sb.Append(c);
        }

        return Regex.Replace(sb.ToString(), "\\s+", " ").Trim();
    }

    private static List<object> MergeUniqueRecipes(List<object> primary, List<object> secondary, int limit)
    {
        var merged = new List<object>();
        var seen = new HashSet<string>(StringComparer.Ordinal);

        foreach (var recipe in primary.Concat(secondary))
        {
            if (recipe is not Dictionary<string, object> map)
            {
                merged.Add(recipe);
                if (merged.Count >= limit) break;
                continue;
            }

            var key = BuildRecipeKey(map);
            if (string.IsNullOrWhiteSpace(key) || seen.Contains(key))
            {
                continue;
            }

            seen.Add(key);
            merged.Add(recipe);

            if (merged.Count >= limit)
            {
                break;
            }
        }

        return merged;
    }

    private List<object> EnsureRecipeImages(List<object> recipes)
    {
        var result = new List<object>();

        foreach (var recipe in recipes)
        {
            var map = ToDictionary(recipe);
            if (map == null)
            {
                result.Add(recipe);
                continue;
            }

            var name = map.TryGetValue("name", out var nameObj)
                ? nameObj?.ToString() ?? "Mon an Viet Nam"
                : "Mon an Viet Nam";

            var imageUrl = map.TryGetValue("image_url", out var imageObj)
                ? imageObj?.ToString()
                : null;

            if (!IsValidRecipeImageUrl(imageUrl))
            {
                map["image_url"] = BuildFallbackImageUrl(name);
            }

            result.Add(map);
        }

        return result;
    }

    private Dictionary<string, object>? ToDictionary(object? value)
    {
        if (value == null) return null;

        if (value is Dictionary<string, object> dict)
        {
            return new Dictionary<string, object>(dict);
        }

        try
        {
            if (value is JsonElement element)
            {
                return JsonSerializer.Deserialize<Dictionary<string, object>>(element.GetRawText());
            }

            var json = JsonSerializer.Serialize(value);
            return JsonSerializer.Deserialize<Dictionary<string, object>>(json);
        }
        catch
        {
            return null;
        }
    }

    private string BuildFallbackImageUrl(string recipeName)
    {
        var normalized = NormalizeText(recipeName);

        foreach (var pair in _exactDishFallbackImages)
        {
            if (normalized.Contains(pair.Key))
            {
                return pair.Value;
            }
        }

        foreach (var pair in _keywordFallbackImages)
        {
            if (!normalized.Contains(pair.Key)) continue;

            var options = pair.Value;
            var index = Math.Abs(recipeName.GetHashCode()) % options.Length;
            return options[index];
        }

        var genericIndex = Math.Abs(recipeName.GetHashCode()) % _genericFallbackImages.Length;
        return _genericFallbackImages[genericIndex];
    }

    private static bool IsValidRecipeImageUrl(string? imageUrl)
    {
        if (string.IsNullOrWhiteSpace(imageUrl)) return false;

        if (!Uri.TryCreate(imageUrl, UriKind.Absolute, out var uri)) return false;
        if (!(uri.Scheme == Uri.UriSchemeHttp || uri.Scheme == Uri.UriSchemeHttps)) return false;

        if (_blockedImageHosts.Contains(uri.Host)) return false;

        var url = imageUrl.ToLowerInvariant();
        if (url.Contains("source.unsplash.com") ||
            url.Contains("picsum.photos") ||
            url.Contains("loremflickr.com") ||
            url.Contains("imgur.com"))
        {
            return false;
        }

        return true;
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

    private List<object> BuildLocalFallbackRecipes(List<string> ingredients, int limit)
    {
        var normalizedIngredients = ingredients
            .Select(i => i.Trim().ToLower())
            .Where(i => !string.IsNullOrWhiteSpace(i))
            .ToHashSet();

        var templates = new List<(string Name, string Description, string Difficulty, int Prep, int Cook, string[] Ingredients, string[] Steps, string Tips)>
        {
            (
                "Trứng chiên hành",
                "Món nhanh gọn cho bữa sáng, dễ làm và rất bắt cơm.",
                "easy",
                5,
                7,
                new[] { "trứng", "hành tím", "nước mắm", "tiêu" },
                new[]
                {
                    "Đập trứng vào tô, thêm nước mắm và tiêu rồi đánh đều.",
                    "Phi thơm hành tím với ít dầu.",
                    "Đổ trứng vào chảo, chiên lửa vừa đến khi vàng hai mặt."
                },
                "Chiên lửa vừa để trứng mềm và thơm hơn."
            ),
            (
                "Thịt bò xào hành tây",
                "Bò mềm, đậm vị, hợp bữa trưa hoặc tối.",
                "easy",
                10,
                10,
                new[] { "thịt bò", "hành tây", "tỏi", "dầu ăn", "nước tương" },
                new[]
                {
                    "Ướp thịt bò với tỏi băm, nước tương trong 10 phút.",
                    "Xào nhanh thịt bò trên lửa lớn rồi trút ra.",
                    "Xào hành tây, cho bò vào đảo đều và tắt bếp."
                },
                "Không xào bò quá lâu để tránh bị dai."
            ),
            (
                "Canh cà chua trứng",
                "Canh thanh nhẹ, dễ ăn và rất hợp ngày nóng.",
                "easy",
                8,
                10,
                new[] { "cà chua", "trứng", "hành lá", "muối", "nước mắm" },
                new[]
                {
                    "Cà chua cắt múi cau, hành lá cắt nhỏ.",
                    "Đun sôi nước, cho cà chua vào nấu mềm.",
                    "Đánh tan trứng rồi rót vòng tròn vào nồi, nêm nếm vừa ăn."
                },
                "Rót trứng từ từ để tạo vân đẹp cho canh."
            ),
            (
                "Cơm chiên trứng",
                "Tận dụng cơm nguội, làm nhanh khi bận rộn.",
                "easy",
                7,
                10,
                new[] { "cơm nguội", "trứng", "hành lá", "nước mắm", "dầu ăn" },
                new[]
                {
                    "Đánh trứng với chút nước mắm.",
                    "Phi hành, cho trứng vào đảo tơi rồi cho cơm nguội vào.",
                    "Nêm nếm lại, đảo đều đến khi hạt cơm săn."
                },
                "Dùng cơm nguội để hạt cơm chiên tơi ngon hơn."
            ),
            (
                "Đậu hũ sốt cà",
                "Món chay dễ làm, vị chua ngọt hài hòa.",
                "easy",
                8,
                12,
                new[] { "đậu hũ", "cà chua", "hành tím", "muối", "đường" },
                new[]
                {
                    "Chiên sơ đậu hũ vàng nhẹ.",
                    "Xào cà chua với hành tím đến khi sệt.",
                    "Cho đậu vào sốt cùng gia vị đến khi thấm."
                },
                "Thêm chút tiêu cuối cùng để dậy mùi."
            )
        };

        var ranked = templates
            .Select(t =>
            {
                var ing = t.Ingredients.Select(x => x.ToLower()).ToList();
                var used = ing.Where(i => normalizedIngredients.Any(h => h.Contains(i) || i.Contains(h))).Distinct().ToList();
                var missing = ing.Where(i => !used.Contains(i)).Distinct().ToList();

                var matchScore = ing.Count == 0
                    ? 0.6
                    : Math.Min(0.98, Math.Max(0.35, (double)used.Count / ing.Count));

                return new
                {
                    Template = t,
                    Used = used,
                    Missing = missing,
                    Score = matchScore
                };
            })
            .OrderByDescending(x => x.Score)
            .ThenBy(x => x.Template.Prep + x.Template.Cook)
            .Take(Math.Max(1, limit))
            .Select(x =>
            {
                var recipe = new Dictionary<string, object>
                {
                    ["name"] = x.Template.Name,
                    ["description"] = x.Template.Description,
                    ["image_url"] = BuildFallbackImageUrl(x.Template.Name),
                    ["difficulty"] = x.Template.Difficulty,
                    ["prep_time"] = x.Template.Prep,
                    ["cook_time"] = x.Template.Cook,
                    ["servings"] = 2,
                    ["ingredients_used"] = x.Used,
                    ["ingredients_missing"] = x.Missing,
                    ["match_score"] = x.Score,
                    ["instructions"] = x.Template.Steps,
                    ["tips"] = x.Template.Tips,
                    ["ingredients_expiring_count"] = 0
                };
                return (object)recipe;
            })
            .ToList();

        return ranked;
    }
}
