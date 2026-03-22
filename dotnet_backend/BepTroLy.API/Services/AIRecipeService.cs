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
        string? region = null,
        string? refreshToken = null,
        List<string>? excludeRecipeNames = null,
        int limit = 5)
    {
        // If no ingredients, we enter "Discovery" mode
        ingredients ??= new List<string>();

        // Ensure preferences is not null and include limit so cache key
        // differentiates between different requested recipe counts.
        preferences ??= new Dictionary<string, object>();
        ApplyRegionalPreferences(preferences, region);
        if (!string.IsNullOrWhiteSpace(refreshToken))
        {
            // Let clients request a fresh batch on demand ("Gợi ý mới").
            preferences["refresh_token"] = refreshToken;
        }
        if (excludeRecipeNames != null && excludeRecipeNames.Count > 0)
        {
            preferences["exclude_recipe_names"] = excludeRecipeNames
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .Select(x => x.Trim())
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();
        }
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
            var finalRecipes = ApplyExcludeAndFillRecipes(
                recipesWithImages,
                excludeRecipeNames,
                ingredients,
                region,
                limit
            );
            if (finalRecipes.Count == 0)
            {
                finalRecipes = BuildLocalFallbackRecipes(ingredients, region, excludeRecipeNames, limit);
            }
            await SaveToCacheAsync(cacheKey, finalRecipes);

            return new Dictionary<string, object>
            {
                ["success"] = true,
                ["source"] = "ai",
                ["recipes"] = finalRecipes
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "AI suggestion error");

            var fallbackRecipes = BuildLocalFallbackRecipes(ingredients, region, excludeRecipeNames, limit);
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
        string? region = null,
        string? refreshToken = null,
        List<string>? excludeRecipeNames = null,
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
        return await SuggestRecipesAsync(ingredients, preferences, region, refreshToken, excludeRecipeNames, limit);
    }

    /// <summary>
    /// Gợi ý món ăn theo vùng miền (không phụ thuộc tủ lạnh).
    /// </summary>
    public async Task<Dictionary<string, object>> SuggestByRegionAsync(
        string? region,
        Dictionary<string, object>? preferences = null,
        string? refreshToken = null,
        List<string>? excludeRecipeNames = null,
        int limit = 5)
    {
        return await SuggestRecipesAsync(new List<string>(), preferences, region, refreshToken, excludeRecipeNames, limit);
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
        var regionLabel = preferences.TryGetValue("region_label", out var r) ? r?.ToString() ?? "Toàn quốc" : "Toàn quốc";
        var seasoningStyle = preferences.TryGetValue("seasoning_preference", out var s) ? s?.ToString() ?? "" : "";
        var refreshToken = preferences.TryGetValue("refresh_token", out var rt) ? rt?.ToString() ?? "" : "";
        var excludedRecipeNames = ExtractExcludeRecipeNames(preferences);

        var dietaryText = !string.IsNullOrEmpty(dietary) ? $"Chế độ ăn đặc biệt: {dietary}" : "";
        var difficultyText = difficulty != "any" ? $"Độ khó: {difficulty}" : "";
        var seasoningText = !string.IsNullOrEmpty(seasoningStyle) ? $"Khẩu vị vùng miền ưu tiên: {seasoningStyle}" : "";
        var refreshHintText = !string.IsNullOrWhiteSpace(refreshToken)
            ? $"Yêu cầu làm mới phiên gợi ý: {refreshToken}. Hãy ưu tiên danh sách đa dạng, hạn chế lặp lại các món quá phổ biến."
            : "";
        var excludedText = excludedRecipeNames.Count > 0
            ? $"KHÔNG ĐƯỢC gợi ý lại các món sau: {string.Join(", ", excludedRecipeNames)}."
            : "";

        var statusText = ingredients.Any()
            ? $"CHẾ ĐỘ GỢI Ý: Dựa trên {ingredients.Count} nguyên liệu có sẵn: {string.Join(", ", ingredients)}."
            : $"CHẾ ĐỘ KHÁM PHÁ: Hãy gợi ý thực đơn hằng ngày phù hợp với vùng miền ưu tiên: {regionLabel}.";

        var prompt = $$"""
            Bạn là một đầu bếp Việt Nam tài ba với kiến thức sâu rộng về ẩm thực 3 miền.
            
            {{statusText}}
            Phong cách ẩm thực yêu thích: {{cuisine}}
            Vùng miền ưu tiên: {{regionLabel}}
            {{seasoningText}}
            {{dietaryText}}
            {{difficultyText}}
            {{refreshHintText}}
            {{excludedText}}

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

        var url = $"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={_apiKey}";

        var requestBody = new
        {
            contents = new[]
            {
                new { parts = new[] { new { text = prompt } } }
            },
            generationConfig = new
            {
                responseMimeType = "application/json",
                temperature = 0.95,
                topP = 0.95
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

    private List<object> BuildLocalFallbackRecipes(
        List<string> ingredients,
        string? region,
        List<string>? excludeRecipeNames,
        int limit)
    {
        var normalizedIngredients = ingredients
            .Select(i => i.Trim().ToLower())
            .Where(i => !string.IsNullOrWhiteSpace(i))
            .ToHashSet();
        var normalizedExcludes = (excludeRecipeNames ?? new List<string>())
            .Select(NormalizeVietnameseText)
            .Where(x => !string.IsNullOrWhiteSpace(x))
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

        if (!string.IsNullOrWhiteSpace(region))
        {
            var normalizedRegion = region.Trim().ToLowerInvariant();
            if (normalizedRegion is "north" or "bac")
            {
                templates.Add((
                    "Bún thang Hà Nội",
                    "Món bún thanh nhẹ kiểu Bắc, hợp bữa sáng hoặc trưa.",
                    "medium",
                    15,
                    25,
                    new[] { "bún", "trứng", "thịt gà", "nấm hương", "hành lá" },
                    new[]
                    {
                        "Luộc gà và xé nhỏ, tráng trứng thái sợi.",
                        "Nấu nước dùng với nấm hương và hành.",
                        "Xếp bún, gà, trứng rồi chan nước dùng nóng."
                    },
                    "Giữ nước dùng trong để món có vị thanh đặc trưng."
                ));
                templates.Add((
                    "Cá rô đồng kho tộ",
                    "Món kho đậm đà kiểu Bắc, ăn cùng cơm trắng rất đưa cơm.",
                    "easy",
                    12,
                    25,
                    new[] { "cá rô", "nước mắm", "hành tím", "tiêu", "đường" },
                    new[]
                    {
                        "Sơ chế cá sạch, ướp gia vị 10 phút.",
                        "Thắng nhẹ nước màu rồi cho cá vào kho.",
                        "Kho lửa nhỏ đến khi cá săn và thấm."
                    },
                    "Kho lửa nhỏ để cá chắc thịt và dậy mùi."
                ));
            }
            else if (normalizedRegion is "central" or "trung")
            {
                templates.Add((
                    "Mì Quảng gà",
                    "Món miền Trung nổi bật với nước dùng đậm vừa phải, thơm nghệ.",
                    "medium",
                    18,
                    25,
                    new[] { "mì quảng", "thịt gà", "nghệ", "đậu phộng", "hành lá" },
                    new[]
                    {
                        "Ướp gà với nghệ và gia vị.",
                        "Xào săn gà rồi thêm nước nấu sệt nhẹ.",
                        "Chan lên mì, rắc đậu phộng và rau sống."
                    },
                    "Nước dùng chỉ xâm xấp để đúng kiểu mì Quảng."
                ));
                templates.Add((
                    "Bún bò Huế",
                    "Bún đậm vị miền Trung, thơm sả và chút cay nồng hấp dẫn.",
                    "medium",
                    20,
                    35,
                    new[] { "bún", "thịt bò", "sả", "ớt", "hành tím" },
                    new[]
                    {
                        "Hầm nước dùng với sả để tạo hương.",
                        "Luộc bò vừa chín, thái lát mỏng.",
                        "Trụng bún, xếp thịt và chan nước dùng."
                    },
                    "Thêm sa tế tùy khẩu vị để tăng độ cay chuẩn vị Huế."
                ));
            }
            else if (normalizedRegion is "south" or "nam")
            {
                templates.Add((
                    "Canh chua cá",
                    "Món canh chua miền Nam thanh mát, cân bằng vị chua ngọt.",
                    "easy",
                    12,
                    20,
                    new[] { "cá", "cà chua", "dứa", "bạc hà", "đậu bắp" },
                    new[]
                    {
                        "Sơ chế cá và các loại rau.",
                        "Đun nước sôi, cho cá và dứa vào nấu.",
                        "Nêm chua ngọt rồi thêm rau vào trước khi tắt bếp."
                    },
                    "Cho rau sau cùng để giữ độ giòn và màu đẹp."
                ));
                templates.Add((
                    "Thịt kho tàu",
                    "Món kho miền Nam vị mặn ngọt hài hòa, ăn với cơm rất hợp.",
                    "easy",
                    15,
                    35,
                    new[] { "thịt ba chỉ", "trứng", "nước dừa", "nước mắm", "đường" },
                    new[]
                    {
                        "Ướp thịt với gia vị 15 phút.",
                        "Đảo săn thịt rồi cho nước dừa vào kho.",
                        "Thêm trứng luộc, kho nhỏ lửa đến khi thấm."
                    },
                    "Kho liu riu để nước kho trong và thịt mềm."
                ));
            }
        }

        var ranked = templates
            .Where(t => !normalizedExcludes.Contains(NormalizeVietnameseText(t.Name)))
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

    private static List<string> ExtractExcludeRecipeNames(Dictionary<string, object> preferences)
    {
        if (!preferences.TryGetValue("exclude_recipe_names", out var raw) || raw == null)
        {
            return new List<string>();
        }

        try
        {
            if (raw is JsonElement element && element.ValueKind == JsonValueKind.Array)
            {
                return element
                    .EnumerateArray()
                    .Select(x => x.GetString() ?? string.Empty)
                    .Where(x => !string.IsNullOrWhiteSpace(x))
                    .Distinct(StringComparer.OrdinalIgnoreCase)
                    .ToList();
            }

            if (raw is IEnumerable<object> list)
            {
                return list
                    .Select(x => x?.ToString() ?? string.Empty)
                    .Where(x => !string.IsNullOrWhiteSpace(x))
                    .Distinct(StringComparer.OrdinalIgnoreCase)
                    .ToList();
            }

            var text = raw.ToString() ?? string.Empty;
            if (string.IsNullOrWhiteSpace(text)) return new List<string>();
            return text
                .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();
        }
        catch
        {
            return new List<string>();
        }
    }

    private static string NormalizeVietnameseText(string input)
    {
        var value = input.ToLowerInvariant().Trim();
        var map = new Dictionary<char, char>
        {
            ['à'] = 'a', ['á'] = 'a', ['ạ'] = 'a', ['ả'] = 'a', ['ã'] = 'a',
            ['â'] = 'a', ['ầ'] = 'a', ['ấ'] = 'a', ['ậ'] = 'a', ['ẩ'] = 'a', ['ẫ'] = 'a',
            ['ă'] = 'a', ['ằ'] = 'a', ['ắ'] = 'a', ['ặ'] = 'a', ['ẳ'] = 'a', ['ẵ'] = 'a',
            ['è'] = 'e', ['é'] = 'e', ['ẹ'] = 'e', ['ẻ'] = 'e', ['ẽ'] = 'e',
            ['ê'] = 'e', ['ề'] = 'e', ['ế'] = 'e', ['ệ'] = 'e', ['ể'] = 'e', ['ễ'] = 'e',
            ['ì'] = 'i', ['í'] = 'i', ['ị'] = 'i', ['ỉ'] = 'i', ['ĩ'] = 'i',
            ['ò'] = 'o', ['ó'] = 'o', ['ọ'] = 'o', ['ỏ'] = 'o', ['õ'] = 'o',
            ['ô'] = 'o', ['ồ'] = 'o', ['ố'] = 'o', ['ộ'] = 'o', ['ổ'] = 'o', ['ỗ'] = 'o',
            ['ơ'] = 'o', ['ờ'] = 'o', ['ớ'] = 'o', ['ợ'] = 'o', ['ở'] = 'o', ['ỡ'] = 'o',
            ['ù'] = 'u', ['ú'] = 'u', ['ụ'] = 'u', ['ủ'] = 'u', ['ũ'] = 'u',
            ['ư'] = 'u', ['ừ'] = 'u', ['ứ'] = 'u', ['ự'] = 'u', ['ử'] = 'u', ['ữ'] = 'u',
            ['ỳ'] = 'y', ['ý'] = 'y', ['ỵ'] = 'y', ['ỷ'] = 'y', ['ỹ'] = 'y',
            ['đ'] = 'd'
        };

        var chars = value.Select(c => map.TryGetValue(c, out var to) ? to : c).ToArray();
        return new string(chars);
    }

    private List<object> ApplyExcludeAndFillRecipes(
        List<object> generatedRecipes,
        List<string>? excludeRecipeNames,
        List<string> ingredients,
        string? region,
        int limit)
    {
        var excludes = (excludeRecipeNames ?? new List<string>())
            .Select(NormalizeVietnameseText)
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .ToHashSet();

        var result = new List<object>();
        var seen = new HashSet<string>();

        foreach (var item in generatedRecipes)
        {
            var map = ToDictionary(item);
            if (map == null) continue;

            var name = map.TryGetValue("name", out var nameObj)
                ? nameObj?.ToString() ?? string.Empty
                : string.Empty;
            var normalizedName = NormalizeVietnameseText(name);
            if (string.IsNullOrWhiteSpace(normalizedName)) continue;
            if (excludes.Contains(normalizedName)) continue;
            if (!seen.Add(normalizedName)) continue;
            result.Add(map);
            if (result.Count >= limit) return result;
        }

        if (result.Count >= limit) return result;

        var fallback = BuildLocalFallbackRecipes(
            ingredients,
            region,
            excludeRecipeNames,
            limit * 2
        );

        foreach (var item in fallback)
        {
            var map = ToDictionary(item);
            if (map == null) continue;
            var name = map.TryGetValue("name", out var nameObj)
                ? nameObj?.ToString() ?? string.Empty
                : string.Empty;
            var normalizedName = NormalizeVietnameseText(name);
            if (string.IsNullOrWhiteSpace(normalizedName)) continue;
            if (excludes.Contains(normalizedName)) continue;
            if (!seen.Add(normalizedName)) continue;
            result.Add(map);
            if (result.Count >= limit) break;
        }

        return result;
    }

    private static void ApplyRegionalPreferences(Dictionary<string, object> preferences, string? region)
    {
        if (string.IsNullOrWhiteSpace(region)) return;

        var normalized = region.Trim().ToLowerInvariant();
        if (normalized is "bac" or "north")
        {
            preferences["region_code"] = "north";
            preferences["region_label"] = "Miền Bắc";
            preferences["cuisine"] = "Ẩm thực miền Bắc Việt Nam";
            preferences["seasoning_preference"] = "Nêm vị thanh, cân bằng, không quá ngọt.";
            return;
        }

        if (normalized is "trung" or "central")
        {
            preferences["region_code"] = "central";
            preferences["region_label"] = "Miền Trung";
            preferences["cuisine"] = "Ẩm thực miền Trung Việt Nam";
            preferences["seasoning_preference"] = "Nêm đậm đà hơn, có thể cay và mặn nhẹ tùy món.";
            return;
        }

        if (normalized is "nam" or "south")
        {
            preferences["region_code"] = "south";
            preferences["region_label"] = "Miền Nam";
            preferences["cuisine"] = "Ẩm thực miền Nam Việt Nam";
            preferences["seasoning_preference"] = "Nêm hài hòa thiên ngọt nhẹ, hương vị tròn đầy.";
            return;
        }

        preferences["region_code"] = normalized;
        preferences["region_label"] = region.Trim();
    }
}
