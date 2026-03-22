using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Collections.Concurrent;
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
        int limit = 5)
    {
        // If no ingredients, we enter "Discovery" mode
        ingredients ??= new List<string>();

        // Ensure preferences is not null and include limit so cache key
        // differentiates between different requested recipe counts.
        preferences ??= new Dictionary<string, object>();
        preferences["limit"] = limit;

        // Check cache
        var cacheKey = GenerateCacheKey(ingredients, preferences);
        var cached = await GetFromCacheAsync(cacheKey);
        if (cached != null)
        {
            var cachedWithImages = EnsureRecipeImages(cached);
            return new Dictionary<string, object>
            {
                ["success"] = true,
                ["source"] = "cache",
                ["recipes"] = cachedWithImages
            };
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
                return new Dictionary<string, object>
                {
                    ["success"] = true,
                    ["source"] = "cache",
                    ["recipes"] = cachedWithImages
                };
            }

            var aiRecipes = await GenerateAISuggestionsAsync(ingredients, preferences, limit);
            var recipesWithImages = EnsureRecipeImages(aiRecipes);
            await SaveToCacheAsync(cacheKey, recipesWithImages);

            return new Dictionary<string, object>
            {
                ["success"] = true,
                ["source"] = "ai",
                ["recipes"] = recipesWithImages
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "AI suggestion error");

            var fallbackRecipes = BuildLocalFallbackRecipes(ingredients, limit);
            if (fallbackRecipes.Count > 0)
            {
                await SaveToCacheAsync(cacheKey, fallbackRecipes, ttlHours: 2);
                return new Dictionary<string, object>
                {
                    ["success"] = true,
                    ["source"] = "local_fallback",
                    ["recipes"] = fallbackRecipes
                };
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
        int? fridgeId = null,
        Dictionary<string, object>? preferences = null,
        int limit = 5)
    {
        var query = _db.PantryItems
            .Where(p => p.UserId == userId && p.Status == "active");

        if (fridgeId.HasValue)
        {
            query = query.Where(p => p.FridgeId == fridgeId.Value);
        }

        var pantryItems = await query.ToListAsync();

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
            - Nếu đang ở CHẾ ĐỘ GỢI Ý: Hãy ưu tiên các món sử dụng được nhiều nguyên liệu sẵn có nhất, mang tính ứng dụng cao cho bữa ăn gia đình hàng ngày.
            - Nếu đang ở CHẾ ĐỘ KHÁM PHÁ: Hãy đề xuất những mâm cơm nhà hoặc món ăn thường ngày phong phú, sáng tạo, không lặp lại nhàm chán. Món ngon nhưng phải dễ nấu.

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

        var url = $"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={_apiKey}";

        var requestBody = new
        {
            contents = new[]
            {
                new { parts = new[] { new { text = prompt } } }
            },
            generationConfig = new
            {
                responseMimeType = "application/json"
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

        // Remove markdown stripping since generationConfig handles it
        text = text.Trim();

        // Parse JSON
        try
        {
            using var resultDoc = JsonDocument.Parse(text);
            var recipes = resultDoc.RootElement.GetProperty("recipes");
            var parsed = JsonSerializer.Deserialize<List<object>>(recipes.GetRawText()) ?? new List<object>();
            RecordGeminiSuccess();
            return parsed;
        }
        catch (JsonException ex)
        {
            _logger.LogError(ex, "Lỗi parse JSON trả về từ AI: {Text}", text);
            
            // Try regex extraction
            var match = Regex.Match(text, @"\{[\s\S]*\}");
            if (match.Success)
            {
                using var resultDoc = JsonDocument.Parse(match.Value);
                var recipes = resultDoc.RootElement.GetProperty("recipes");
                var parsed = JsonSerializer.Deserialize<List<object>>(recipes.GetRawText()) ?? new List<object>();
                RecordGeminiSuccess();
                return parsed;
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

    private string GenerateCacheKey(List<string> ingredients, Dictionary<string, object>? preferences)
    {
        var normalized = ingredients.Select(i => i.ToLower().Trim()).OrderBy(i => i).ToList();
        var keyData = new { ingredients = normalized, preferences = preferences ?? new Dictionary<string, object>() };
        var keyString = JsonSerializer.Serialize(keyData, new JsonSerializerOptions { WriteIndented = false });
        var hashBytes = MD5.HashData(Encoding.UTF8.GetBytes(keyString));
        return Convert.ToHexString(hashBytes).ToLower();
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

            if (string.IsNullOrWhiteSpace(imageUrl) || !Uri.IsWellFormedUriString(imageUrl, UriKind.Absolute))
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
        var query = Uri.EscapeDataString($"vietnamese food {recipeName}");
        return $"https://source.unsplash.com/1200x800/?{query}";
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
