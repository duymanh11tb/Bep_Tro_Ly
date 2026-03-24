using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Collections.Concurrent;
using BepTroLy.API.Data;
using BepTroLy.API.Models;
using Microsoft.EntityFrameworkCore;

namespace BepTroLy.API.Services;

/// <summary>
/// Recipe suggestion service backed by Spoonacular, cache, and local fallbacks.
/// </summary>
public class RecipeSuggestionService
{
    private static readonly ConcurrentDictionary<string, SemaphoreSlim> _cacheKeyLocks = new();
    private const int RecentSuggestionsPerUser = 40;
    private static readonly ConcurrentDictionary<int, LinkedList<string>> _recentRecipeNamesByUser = new();

    private readonly string? _spoonacularApiKey;
    private readonly string _spoonacularBaseUrl;
    private readonly HttpClient _httpClient;
    private readonly IRecipeCatalogProvider _catalogProvider;
    private readonly AppDbContext _db;
    private readonly ILogger<RecipeSuggestionService> _logger;

    public RecipeSuggestionService(
        IConfiguration configuration,
        AppDbContext db,
        IRecipeCatalogProvider catalogProvider,
        ILogger<RecipeSuggestionService> logger)
    {
        _spoonacularApiKey = configuration["Spoonacular:ApiKey"];
        _spoonacularBaseUrl = configuration["Spoonacular:BaseUrl"] ?? "https://api.spoonacular.com";
        _httpClient = new HttpClient { Timeout = TimeSpan.FromSeconds(20) };
        _catalogProvider = catalogProvider;
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
        int? userId = null,
        int limit = 5,
        bool allowTemplateFallback = true,
        bool requirePantryIngredientMatch = false)
    {
        limit = Math.Clamp(limit, 1, 20);

        // If no ingredients, we enter "Discovery" mode
        ingredients ??= new List<string>();

        // Ensure preferences is not null and include limit so cache key
        // differentiates between different requested recipe counts.
        preferences ??= new Dictionary<string, object>();
        await ApplyUserPersonalizationAsync(preferences, userId);
        ApplyRegionalPreferences(preferences, region);
        if (!string.IsNullOrWhiteSpace(refreshToken))
        {
            // Let clients request a fresh batch on demand ("Gợi ý mới").
            preferences["refresh_token"] = refreshToken;
        }
        else
        {
            // Refresh suggestions automatically once per day unless the user explicitly asks for a new batch.
            var timeSlot = DateTime.UtcNow.Ticks / TimeSpan.TicksPerDay;
            preferences["_auto_refresh_slot"] = timeSlot;
        }
        if (excludeRecipeNames != null && excludeRecipeNames.Count > 0)
        {
            preferences["exclude_recipe_names"] = excludeRecipeNames
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .Select(x => x.Trim())
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();
        }
        preferences["allow_template_fallback"] = allowTemplateFallback;
        preferences["require_pantry_ingredient_match"] = requirePantryIngredientMatch;
        preferences["limit"] = limit;

        await ApplyUserPersonalizationAsync(preferences, userId);

        // Check cache
        var cacheKey = GenerateCacheKey(ingredients, preferences);
        var cached = await GetFromCacheAsync(cacheKey);
        if (cached != null)
        {
            var cachedWithImages = await EnsureRecipeImagesAsync(cached);
            return new Dictionary<string, object>
            {
                ["success"] = true,
                ["source"] = "cache",
                ["recipes"] = cachedWithImages
            };
        }

        // Prevent thundering herd: same cache key should generate suggestions only once at a time.
        var keyLock = _cacheKeyLocks.GetOrAdd(cacheKey, _ => new SemaphoreSlim(1, 1));
        await keyLock.WaitAsync();

        try
        {
            var recentNames = GetRecentRecipeNames(userId);

            // Re-check cache after acquiring lock because another request may have filled it.
            cached = await GetFromCacheAsync(cacheKey);
            if (cached != null)
            {
                var cachedWithImages = await EnsureRecipeImagesAsync(cached);
                return new Dictionary<string, object>
                {
                    ["success"] = true,
                    ["source"] = "cache",
                    ["recipes"] = cachedWithImages
                };
            }

            if (string.IsNullOrWhiteSpace(_spoonacularApiKey))
            {
                _logger.LogInformation(
                    "Spoonacular API key is missing; recipe suggestions may rely on fallback sources. BaseUrl: {BaseUrl}",
                    _spoonacularBaseUrl);
            }

            var catalogRecipes = await _catalogProvider.SuggestRecipesAsync(
                ingredients,
                preferences,
                limit);

            var prioritizedCatalogRecipes = PrioritizePantryRelevantRecipes(
                catalogRecipes,
                ingredients,
                requirePantryIngredientMatch
            );
            var finalRecipes = ApplyExcludeAndFillRecipes(
                prioritizedCatalogRecipes,
                excludeRecipeNames,
                ingredients,
                region,
                refreshToken,
                recentNames,
                preferences,
                limit,
                allowTemplateFallback
            );
            if (finalRecipes.Count == 0)
            {
                if (!allowTemplateFallback)
                {
                    return new Dictionary<string, object>
                    {
                        ["success"] = true,
                        ["source"] = ingredients.Any() ? "catalog_empty_pantry" : "catalog_empty",
                        ["recipes"] = new List<object>()
                    };
                }

                finalRecipes = BuildLocalFallbackRecipes(
                    ingredients,
                    region,
                    excludeRecipeNames,
                    limit,
                    refreshToken,
                    recentNames,
                    preferences
                );
            }

            var source = "spoonacular";
            var ttlHours = 1;

            if (finalRecipes.Count == 0)
            {
                if (!allowTemplateFallback)
                {
                    return new Dictionary<string, object>
                    {
                        ["success"] = true,
                        ["source"] = ingredients.Any() ? "catalog_empty_pantry" : "catalog_empty",
                        ["recipes"] = new List<object>()
                    };
                }

                var localRecipes = BuildLocalFallbackRecipes(
                    ingredients,
                    region,
                    excludeRecipeNames,
                    limit,
                    refreshToken,
                    recentNames,
                    preferences
                );

                localRecipes = PrioritizePantryRelevantRecipes(
                    localRecipes,
                    ingredients,
                    requirePantryIngredientMatch
                );

                finalRecipes = localRecipes
                    .Take(limit)
                    .ToList();

                source = "local_fallback";
                ttlHours = 2;
            }

            await FinalizeSuggestionResultAsync(
                cacheKey,
                finalRecipes,
                userId,
                preferences,
                ttlHours: ttlHours);

            return new Dictionary<string, object>
            {
                ["success"] = true,
                ["source"] = source,
                ["recipes"] = finalRecipes
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Recipe catalog suggestion error");

            if (!allowTemplateFallback)
            {
                return new Dictionary<string, object>
                {
                    ["success"] = false,
                    ["error"] = $"Lỗi recipe catalog: {ex.Message}",
                    ["recipes"] = new List<object>()
                };
            }

            var fallbackRecentNames = GetRecentRecipeNames(userId);
            var fallbackRecipes = BuildLocalFallbackRecipes(
                ingredients,
                region,
                excludeRecipeNames,
                limit,
                refreshToken,
                fallbackRecentNames,
                preferences
            );
            if (fallbackRecipes.Count > 0)
            {
                await FinalizeSuggestionResultAsync(
                    cacheKey,
                    fallbackRecipes,
                    userId,
                    preferences,
                    ttlHours: 2);
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
                ["error"] = $"Lỗi recipe catalog: {ex.Message}",
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
        if (pantryItems.Count == 0)
        {
            return new Dictionary<string, object>
            {
                ["success"] = true,
                ["source"] = "empty_pantry",
                ["recipes"] = new List<object>(),
                ["message"] = "Tủ lạnh hiện chưa có nguyên liệu để gợi ý."
            };
        }

        var ingredients = pantryItems.Select(p => p.NameVi).ToList();
        return await SuggestRecipesAsync(
            ingredients,
            preferences,
            region,
            refreshToken,
            excludeRecipeNames,
            userId,
            limit,
            allowTemplateFallback: true,
            requirePantryIngredientMatch: true
        );
    }

    /// <summary>
    /// Gợi ý món ăn theo vùng miền (không phụ thuộc tủ lạnh).
    /// </summary>
    public async Task<Dictionary<string, object>> SuggestByRegionAsync(
        string? region,
        Dictionary<string, object>? preferences = null,
        string? refreshToken = null,
        List<string>? excludeRecipeNames = null,
        int? userId = null,
        int limit = 5)
    {
        return await SuggestRecipesAsync(
            new List<string>(),
            preferences,
            region,
            refreshToken,
            excludeRecipeNames,
            userId,
            limit,
            allowTemplateFallback: true
        );
    }

    private async Task FinalizeSuggestionResultAsync(
        string cacheKey,
        List<object> recipes,
        int? userId,
        Dictionary<string, object> preferences,
        int ttlHours)
    {
        await SaveToCacheAsync(cacheKey, recipes, ttlHours);
        RecordRecentRecipeNames(userId, recipes);

        if (!userId.HasValue)
        {
            return;
        }

        var contextData = new
        {
            time = GetTimeOfDayContext(),
            season = GetSeasonContext(),
            weather = preferences.TryGetValue("weather", out var w) ? w?.ToString() : "normal"
        };
        await SaveSuggestedRecipesAsync(userId.Value, recipes, JsonSerializer.Serialize(contextData));
    }

    private async Task<List<object>> FetchRecipesFromSpoonacularAsync(
        List<string> ingredients,
        Dictionary<string, object>? preferences,
        int limit,
        string historyText = "")
    {
        if (string.IsNullOrEmpty(_spoonacularApiKey))
        {
            throw new InvalidOperationException("Spoonacular API key chưa được cấu hình");
        }

        var cleanedIngredients = ingredients
            .Where(i => !string.IsNullOrWhiteSpace(i))
            .Select(i => i.Trim())
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

        if (cleanedIngredients.Count == 0)
        {
            return new List<object>();
        }

        var ingredientsParam = string.Join(",", cleanedIngredients.Select(Uri.EscapeDataString));
        var number = Math.Clamp(limit, 1, 20);
        const int ranking = 1;

        var maxReadyTime = 0;
        if (preferences != null && preferences.TryGetValue("difficulty", out var diff))
        {
            var diffStr = diff?.ToString()?.ToLowerInvariant();
            if (diffStr == "easy") maxReadyTime = 20;
            else if (diffStr == "medium") maxReadyTime = 45;
            else if (diffStr == "hard") maxReadyTime = 90;
        }

        var url =
            $"{_spoonacularBaseUrl}/recipes/findByIngredients?apiKey={Uri.EscapeDataString(_spoonacularApiKey)}" +
            $"&ingredients={ingredientsParam}&number={number}&ranking={ranking}";

        if (maxReadyTime > 0)
        {
            url += $"&maxReadyTime={maxReadyTime}";
        }

        if (preferences != null)
        {
            if (preferences.TryGetValue("dietary_restrictions", out var diet))
            {
                var dietStr = ExtractStringList(diet).FirstOrDefault()?.ToLowerInvariant()
                    ?? diet?.ToString()?.ToLowerInvariant();
                var mappedDiet = MapDietary(dietStr);
                if (!string.IsNullOrWhiteSpace(mappedDiet))
                {
                    url += $"&diet={Uri.EscapeDataString(mappedDiet)}";
                }
            }

            if (preferences.TryGetValue("cuisine", out var cuisine))
            {
                var cuisineStr = cuisine?.ToString()?.ToLowerInvariant();
                var mappedCuisine = MapCuisine(cuisineStr);
                if (!string.IsNullOrWhiteSpace(mappedCuisine))
                {
                    url += $"&cuisine={Uri.EscapeDataString(mappedCuisine)}";
                }
            }
        }

        using var response = await _httpClient.GetAsync(url);
        var responseText = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogError(
                "Spoonacular error: {StatusCode} - {Response}",
                response.StatusCode,
                responseText);
            throw new Exception($"Spoonacular API error: {response.StatusCode}");
        }

        using var doc = JsonDocument.Parse(responseText);
        var result = new List<object>();
        foreach (var recipeElem in doc.RootElement.EnumerateArray())
        {
            var recipeDict = new Dictionary<string, object>();

            var recipeId = recipeElem.TryGetProperty("id", out var idElement) && idElement.TryGetInt32(out var parsedId)
                ? parsedId
                : 0;
            var title = recipeElem.TryGetProperty("title", out var titleElement)
                ? titleElement.GetString() ?? string.Empty
                : string.Empty;
            if (string.IsNullOrWhiteSpace(title))
            {
                continue;
            }

            var imageUrl = recipeElem.TryGetProperty("image", out var imageElement)
                ? imageElement.GetString()
                : null;

            var usedIngredients = recipeElem.TryGetProperty("usedIngredients", out var usedElement) &&
                                  usedElement.ValueKind == JsonValueKind.Array
                ? usedElement.EnumerateArray()
                    .Select(ing => ing.TryGetProperty("name", out var nameElement) ? nameElement.GetString() ?? string.Empty : string.Empty)
                    .Where(x => !string.IsNullOrWhiteSpace(x))
                    .Distinct(StringComparer.OrdinalIgnoreCase)
                    .ToList()
                : new List<string>();

            var missedIngredients = recipeElem.TryGetProperty("missedIngredients", out var missedElement) &&
                                    missedElement.ValueKind == JsonValueKind.Array
                ? missedElement.EnumerateArray()
                    .Select(ing => ing.TryGetProperty("name", out var nameElement) ? nameElement.GetString() ?? string.Empty : string.Empty)
                    .Where(x => !string.IsNullOrWhiteSpace(x))
                    .Distinct(StringComparer.OrdinalIgnoreCase)
                    .ToList()
                : new List<string>();

            var total = usedIngredients.Count + missedIngredients.Count;
            var matchScore = total == 0 ? 0.5 : (double)usedIngredients.Count / total;

            recipeDict["id"] = recipeId;
            recipeDict["name"] = title;
            recipeDict["description"] = $"Món {title} được đề xuất dựa trên nguyên liệu bạn có.";
            recipeDict["image_url"] = imageUrl ?? string.Empty;
            recipeDict["difficulty"] = "medium";
            recipeDict["prep_time"] = 10;
            recipeDict["cook_time"] = 20;
            recipeDict["servings"] = 2;
            recipeDict["ingredients_used"] = usedIngredients;
            recipeDict["ingredients_missing"] = missedIngredients;
            recipeDict["match_score"] = matchScore;
            recipeDict["instructions"] = new List<string> { "Xem hướng dẫn chi tiết trong ứng dụng." };
            recipeDict["tips"] = "Chúc bạn ngon miệng!";
            recipeDict["source_provider"] = "spoonacular";

            result.Add(recipeDict);
        }

        return result;
    }

    private string GenerateCacheKey(List<string> ingredients, Dictionary<string, object>? preferences)
    {
        var normalized = ingredients.Select(i => i.ToLower().Trim()).OrderBy(i => i).ToList();
        var keyData = new { ingredients = normalized, preferences = preferences ?? new Dictionary<string, object>() };
        var keyString = JsonSerializer.Serialize(keyData, new JsonSerializerOptions { WriteIndented = false });
        var hashBytes = MD5.HashData(Encoding.UTF8.GetBytes(keyString));
        return Convert.ToHexString(hashBytes).ToLower();
    }

    private Task<List<object>> EnsureRecipeImagesAsync(List<object> recipes)
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

            var imageUrl = map.TryGetValue("image_url", out var imageObj)
                ? imageObj?.ToString()
                : null;

            if (ShouldResolveImageUrl(imageUrl))
            {
                map["image_url"] = string.Empty;
            }

            result.Add(map);
        }

        return Task.FromResult(result);
    }

    private bool ShouldResolveImageUrl(string? imageUrl)
    {
        if (string.IsNullOrWhiteSpace(imageUrl) || !Uri.IsWellFormedUriString(imageUrl, UriKind.Absolute))
        {
            return true;
        }

        if (!Uri.TryCreate(imageUrl, UriKind.Absolute, out var imageUri))
        {
            return true;
        }

        var host = imageUri.Host.ToLowerInvariant();
        return host.Contains("source.unsplash.com") ||
               host.Contains("imgur.com") ||
               host.Contains("picsum.photos") ||
               host.Contains("loremflickr.com");
    }

    private List<object> PrioritizePantryRelevantRecipes(
        List<object> recipes,
        List<string> pantryIngredients,
        bool requireMatch)
    {
        var normalizedPantry = pantryIngredients
            .Select(NormalizeVietnameseText)
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Distinct()
            .ToList();

        if (normalizedPantry.Count == 0)
        {
            return recipes;
        }

        var ranked = new List<(Dictionary<string, object> Map, int Overlap, double Score)>();
        foreach (var recipe in recipes)
        {
            var map = ToDictionary(recipe);
            if (map == null) continue;

            var usedIngredients = map.TryGetValue("ingredients_used", out var rawUsed)
                ? ExtractStringList(rawUsed)
                : new List<string>();

            var overlap = CountIngredientOverlap(normalizedPantry, usedIngredients);
            if (overlap == 0 && map.TryGetValue("name", out var rawName))
            {
                overlap = CountIngredientOverlap(normalizedPantry, new[] { rawName?.ToString() ?? string.Empty });
            }

            if (requireMatch && overlap == 0)
            {
                continue;
            }

            var score = GetDoubleValue(map.TryGetValue("match_score", out var rawScore) ? rawScore : null);
            if (overlap > 0)
            {
                map["match_score"] = Math.Min(0.99, score + Math.Min(0.18, overlap * 0.06));
            }

            ranked.Add((map, overlap, GetDoubleValue(map["match_score"])));
        }

        return ranked
            .OrderByDescending(x => x.Overlap)
            .ThenByDescending(x => x.Score)
            .Select(x => (object)x.Map)
            .ToList();
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

    private static List<string> ExtractStringList(object? value)
    {
        if (value == null) return new List<string>();

        if (value is JsonElement element)
        {
            if (element.ValueKind == JsonValueKind.Array)
            {
                return element
                    .EnumerateArray()
                    .Select(x => x.GetString() ?? string.Empty)
                    .Where(x => !string.IsNullOrWhiteSpace(x))
                    .ToList();
            }

            if (element.ValueKind == JsonValueKind.String)
            {
                var single = element.GetString();
                return string.IsNullOrWhiteSpace(single)
                    ? new List<string>()
                    : new List<string> { single };
            }
        }

        if (value is IEnumerable<object> objectItems)
        {
            return objectItems
                .Select(x => x?.ToString() ?? string.Empty)
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .ToList();
        }

        if (value is IEnumerable<string> stringItems)
        {
            return stringItems
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .ToList();
        }

        var text = value.ToString();
        return string.IsNullOrWhiteSpace(text)
            ? new List<string>()
            : new List<string> { text };
    }

    private static int CountIngredientOverlap(IEnumerable<string> pantryIngredients, IEnumerable<string> recipeIngredients)
    {
        var normalizedRecipe = recipeIngredients
            .Select(NormalizeVietnameseText)
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Distinct()
            .ToList();

        if (normalizedRecipe.Count == 0) return 0;

        var matched = new HashSet<string>();
        foreach (var pantryIngredient in pantryIngredients)
        {
            if (normalizedRecipe.Any(recipeIngredient =>
                recipeIngredient.Contains(pantryIngredient) ||
                pantryIngredient.Contains(recipeIngredient)))
            {
                matched.Add(pantryIngredient);
            }
        }

        return matched.Count;
    }

    private static double GetDoubleValue(object? value)
    {
        try
        {
            if (value is JsonElement element)
            {
                if (element.ValueKind == JsonValueKind.Number && element.TryGetDouble(out var number))
                {
                    return number;
                }

                if (element.ValueKind == JsonValueKind.String &&
                    double.TryParse(element.GetString(), out var parsed))
                {
                    return parsed;
                }
            }

            return Convert.ToDouble(value);
        }
        catch
        {
            return 0;
        }
    }

    private async Task<List<object>?> GetFromCacheAsync(string cacheKey)
    {
        try
        {
            var entry = await _db.RecipeSuggestionCaches.FirstOrDefaultAsync(c => c.CacheKey == cacheKey);
            if (entry != null && entry.ExpiresAt > DateTime.UtcNow)
            {
                return JsonSerializer.Deserialize<List<object>>(entry.ResponseData);
            }
            if (entry != null)
            {
                _db.RecipeSuggestionCaches.Remove(entry);
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
            var existing = await _db.RecipeSuggestionCaches.FirstOrDefaultAsync(c => c.CacheKey == cacheKey);
            if (existing != null) _db.RecipeSuggestionCaches.Remove(existing);

            _db.RecipeSuggestionCaches.Add(new RecipeSuggestionCache
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
        int limit,
        string? refreshToken = null,
        HashSet<string>? recentRecipeNames = null,
        Dictionary<string, object>? preferences = null)
    {
        var normalizedIngredients = ingredients
            .Select(i => i.Trim().ToLower())
            .Where(i => !string.IsNullOrWhiteSpace(i))
            .ToHashSet();
        var normalizedExcludes = (excludeRecipeNames ?? new List<string>())
            .Select(NormalizeVietnameseText)
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .ToHashSet();
        var normalizedRecent = recentRecipeNames ?? new HashSet<string>();
        preferences ??= new Dictionary<string, object>();
        var skillLevel = preferences.TryGetValue("user_skill_level", out var rawSkill)
            ? rawSkill?.ToString()?.ToLowerInvariant() ?? "beginner"
            : "beginner";
        var cuisineFocus = preferences.TryGetValue("user_cuisine_focus", out var rawCuisine)
            ? NormalizeVietnameseText(rawCuisine?.ToString() ?? string.Empty)
            : string.Empty;
        var avoidIngredients = preferences.TryGetValue("user_avoid_ingredients", out var rawAvoid)
            ? rawAvoid?.ToString() ?? string.Empty
            : string.Empty;
        var userSeed = preferences.TryGetValue("user_personalization_seed", out var rawSeed)
            ? rawSeed?.ToString() ?? "default-user"
            : "default-user";
        var flavorProfile = preferences.TryGetValue("user_flavor_profile", out var rawFlavor)
            ? NormalizeVietnameseText(rawFlavor?.ToString() ?? string.Empty)
            : string.Empty;

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
                "Gà kho gừng",
                "Món kho thơm nồng, rất hợp bữa cơm gia đình.",
                "easy",
                12,
                25,
                new[] { "thịt gà", "gừng", "hành tím", "nước mắm", "đường" },
                new[]
                {
                    "Ướp gà với gừng và gia vị.",
                    "Phi hành, cho gà vào đảo săn.",
                    "Kho nhỏ lửa đến khi thịt gà thấm vị."
                },
                "Thêm chút tiêu sau cùng để dậy mùi."
            ),
            (
                "Đậu que xào tỏi",
                "Món rau nhanh gọn, giữ độ giòn ngọt tự nhiên.",
                "easy",
                7,
                8,
                new[] { "đậu que", "tỏi", "muối", "dầu ăn" },
                new[]
                {
                    "Đậu que rửa sạch, cắt khúc.",
                    "Phi thơm tỏi rồi cho đậu vào xào lửa lớn.",
                    "Nêm nhẹ và đảo nhanh để rau xanh giòn."
                },
                "Không xào quá lâu để giữ màu xanh đẹp."
            ),
            (
                "Canh rau ngót thịt bằm",
                "Canh ngọt mát, dễ ăn cho cả nhà.",
                "easy",
                8,
                12,
                new[] { "rau ngót", "thịt bằm", "hành tím", "nước mắm" },
                new[]
                {
                    "Ướp thịt bằm với chút mắm.",
                    "Xào thơm hành rồi cho thịt vào đảo.",
                    "Thêm nước, đun sôi rồi cho rau ngót vào nấu chín."
                },
                "Vò nhẹ rau ngót để canh ngọt hơn."
            ),
            (
                "Cà tím xào thịt bằm",
                "Món xào mềm thơm, ăn cơm rất hợp.",
                "easy",
                10,
                12,
                new[] { "cà tím", "thịt bằm", "tỏi", "nước tương" },
                new[]
                {
                    "Cà tím cắt miếng ngâm nước muối loãng.",
                    "Xào thịt bằm với tỏi cho thơm.",
                    "Cho cà tím vào đảo mềm, nêm vừa ăn."
                },
                "Có thể thêm chút ớt để tăng vị."
            ),
            (
                "Trứng hấp thịt",
                "Món mềm mịn, đậm đà và rất nhanh làm.",
                "easy",
                8,
                15,
                new[] { "trứng", "thịt bằm", "nước mắm", "hành lá" },
                new[]
                {
                    "Đánh trứng cùng thịt bằm và gia vị.",
                    "Lọc hỗn hợp để món mịn hơn.",
                    "Hấp lửa vừa đến khi trứng chín."
                },
                "Phủ màng bọc chịu nhiệt để mặt trứng đẹp."
            ),
            (
                "Bắp cải cuộn thịt sốt cà",
                "Món đủ chất, vị sốt cà chua nhẹ rất đưa cơm.",
                "medium",
                15,
                20,
                new[] { "bắp cải", "thịt bằm", "cà chua", "hành tím" },
                new[]
                {
                    "Chần lá bắp cải cho mềm để cuộn.",
                    "Cuộn thịt bằm vào lá bắp cải.",
                    "Nấu sốt cà chua rồi rim cuộn bắp cải."
                },
                "Cuộn chắc tay để không bung khi nấu."
            ),
            (
                "Mướp xào trứng",
                "Món xào mềm ngọt tự nhiên, nấu rất nhanh.",
                "easy",
                6,
                8,
                new[] { "mướp", "trứng", "hành tím", "muối" },
                new[]
                {
                    "Mướp gọt vỏ, cắt lát vừa.",
                    "Xào trứng tơi rồi để riêng.",
                    "Xào mướp nhanh, cho trứng vào đảo đều."
                },
                "Nêm nhẹ để giữ vị ngọt của mướp."
            ),
            (
                "Thịt heo rang cháy cạnh",
                "Món mặn đậm đà, thơm mùi nước mắm.",
                "easy",
                10,
                18,
                new[] { "thịt heo", "hành tím", "nước mắm", "đường" },
                new[]
                {
                    "Thịt thái mỏng, ướp nhẹ gia vị.",
                    "Rang thịt lửa vừa cho săn cạnh.",
                    "Nêm lại nước mắm và chút đường cho cân vị."
                },
                "Rang đủ lâu để thịt xém nhẹ thơm hơn."
            ),
            (
                "Cải thìa sốt nấm",
                "Món rau thanh vị, hợp bữa cơm nhẹ nhàng.",
                "easy",
                8,
                10,
                new[] { "cải thìa", "nấm", "tỏi", "dầu hào" },
                new[]
                {
                    "Chần cải thìa qua nước sôi.",
                    "Xào nấm với tỏi cho thơm.",
                    "Rưới sốt nấm lên cải thìa đã chần."
                },
                "Giữ cải thìa vừa chín để còn độ giòn."
            ),
            (
                "Bò lúc lắc",
                "Món bò mềm thơm, phù hợp cho cả bữa chính và tiệc nhỏ.",
                "medium",
                12,
                12,
                new[] { "thịt bò", "ớt chuông", "hành tây", "bơ" },
                new[]
                {
                    "Cắt bò miếng vuông, ướp nhanh gia vị.",
                    "Áp chảo bò lửa lớn cho săn mặt.",
                    "Xào ớt chuông, hành tây rồi trộn cùng bò."
                },
                "Không xào quá lâu để bò mềm mọng."
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

        var candidates = templates
            .Where(t =>
            {
                var normalizedName = NormalizeVietnameseText(t.Name);
                return !normalizedExcludes.Contains(normalizedName) && !normalizedRecent.Contains(normalizedName);
            })
            .Select(t =>
            {
                var ing = t.Ingredients.Select(x => x.ToLower()).ToList();
                var used = ing.Where(i => normalizedIngredients.Any(h => h.Contains(i) || i.Contains(h))).Distinct().ToList();
                var missing = ing.Where(i => !used.Contains(i)).Distinct().ToList();

                var matchScore = ing.Count == 0
                    ? 0.6
                    : Math.Min(0.98, Math.Max(0.35, (double)used.Count / ing.Count));

                var personalizationBoost = 0.0;
                var normalizedName = NormalizeVietnameseText(t.Name);

                if (skillLevel == "beginner" && t.Difficulty == "easy") personalizationBoost += 0.08;
                if (skillLevel == "intermediate" && t.Difficulty == "medium") personalizationBoost += 0.05;
                if (skillLevel == "advanced" && t.Difficulty == "hard") personalizationBoost += 0.06;

                if (!string.IsNullOrWhiteSpace(cuisineFocus) &&
                    (cuisineFocus.Contains("viet") || cuisineFocus.Contains("mien") || cuisineFocus.Contains("com")))
                {
                    personalizationBoost += 0.03;
                }

                if (!string.IsNullOrWhiteSpace(flavorProfile))
                {
                    if (flavorProfile.Contains("thanh") &&
                        (normalizedName.Contains("canh") || normalizedName.Contains("bun")))
                    {
                        personalizationBoost += 0.05;
                    }
                    if (flavorProfile.Contains("dam") &&
                        (normalizedName.Contains("kho") || normalizedName.Contains("xao")))
                    {
                        personalizationBoost += 0.05;
                    }
                    if (flavorProfile.Contains("ngot") &&
                        (normalizedName.Contains("kho tau") || normalizedName.Contains("canh chua")))
                    {
                        personalizationBoost += 0.04;
                    }
                }

                if (!string.IsNullOrWhiteSpace(avoidIngredients))
                {
                    foreach (var ingredient in ing)
                    {
                        if (NormalizeVietnameseText(avoidIngredients).Contains(NormalizeVietnameseText(ingredient)))
                        {
                            personalizationBoost -= 0.12;
                        }
                    }
                }

                var deterministicNudge = (Math.Abs($"{userSeed}|{t.Name}".GetHashCode()) % 11) / 100.0;
                var finalScore = Math.Max(0.05, Math.Min(0.99, matchScore + personalizationBoost + deterministicNudge));

                return new
                {
                    Template = t,
                    Used = used,
                    Missing = missing,
                    Score = finalScore
                };
            })
            .ToList();

        if (!string.IsNullOrWhiteSpace(refreshToken))
        {
            var topCandidates = candidates
                .OrderByDescending(x => x.Score)
                .ThenBy(x => x.Template.Prep + x.Template.Cook)
                .Take(Math.Max(limit * 3, 12))
                .ToList();
            var seed = refreshToken.GetHashCode();
            var rng = new Random(seed);

            return topCandidates
                .OrderBy(_ => rng.Next())
                .Take(Math.Max(1, limit))
                .Select(x => (object)BuildLocalFallbackRecipeMap(x.Template, x.Used, x.Missing, x.Score))
                .ToList();
        }

        return candidates
            .OrderByDescending(x => x.Score)
            .ThenBy(x => x.Template.Prep + x.Template.Cook)
            .Take(Math.Max(1, limit))
            .Select(x => (object)BuildLocalFallbackRecipeMap(x.Template, x.Used, x.Missing, x.Score))
            .ToList();
    }

    private static Dictionary<string, object> BuildLocalFallbackRecipeMap(
        (string Name, string Description, string Difficulty, int Prep, int Cook, string[] Ingredients, string[] Steps, string Tips) template,
        List<string> used,
        List<string> missing,
        double score)
    {
        return new Dictionary<string, object>
        {
            ["name"] = template.Name,
            ["description"] = template.Description,
            ["image_url"] = string.Empty,
            ["difficulty"] = template.Difficulty,
            ["prep_time"] = template.Prep,
            ["cook_time"] = template.Cook,
            ["servings"] = 2,
            ["ingredients_used"] = used,
            ["ingredients_missing"] = missing,
            ["match_score"] = score,
            ["instructions"] = template.Steps,
            ["tips"] = template.Tips,
            ["ingredients_expiring_count"] = 0
        };
    }

    private static int BuildShuffleSeed(Dictionary<string, object> preferences)
    {
        var refreshToken = preferences.TryGetValue("refresh_token", out var rt) ? rt?.ToString() ?? string.Empty : string.Empty;
        var slot = preferences.TryGetValue("_auto_refresh_slot", out var ars) ? ars?.ToString() ?? string.Empty : string.Empty;
        var userSeed = preferences.TryGetValue("user_personalization_seed", out var ups) ? ups?.ToString() ?? "default-user" : "default-user";
        var composite = $"{userSeed}|{refreshToken}|{slot}|{Guid.NewGuid():N}";
        return composite.GetHashCode();
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

    private static string? MapDietary(string? dietary)
    {
        var normalized = NormalizeVietnameseText(dietary ?? string.Empty);
        if (string.IsNullOrWhiteSpace(normalized))
        {
            return null;
        }

        if (normalized.Contains("an chay") || normalized.Contains("chay") || normalized.Contains("vegetarian"))
        {
            return "vegetarian";
        }

        if (normalized.Contains("vegan"))
        {
            return "vegan";
        }

        if (normalized.Contains("gluten"))
        {
            return "gluten free";
        }

        return null;
    }

    private static string? MapCuisine(string? cuisine)
    {
        var normalized = NormalizeVietnameseText(cuisine ?? string.Empty);
        if (string.IsNullOrWhiteSpace(normalized))
        {
            return null;
        }

        if (normalized.Contains("viet") || normalized.Contains("mien") || normalized.Contains("bac") ||
            normalized.Contains("trung") || normalized.Contains("nam"))
        {
            return "vietnamese";
        }

        var knownCuisines = new[]
        {
            "italian", "chinese", "thai", "japanese", "indian", "mexican",
            "french", "mediterranean", "korean", "american"
        };

        return knownCuisines.FirstOrDefault(normalized.Contains);
    }

    private List<object> ApplyExcludeAndFillRecipes(
        List<object> generatedRecipes,
        List<string>? excludeRecipeNames,
        List<string> ingredients,
        string? region,
        string? refreshToken,
        HashSet<string> recentNames,
        Dictionary<string, object>? preferences,
        int limit,
        bool allowTemplateFallback)
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
            if (recentNames.Contains(normalizedName)) continue;
            if (!seen.Add(normalizedName)) continue;
            result.Add(map);
            if (result.Count >= limit) return result;
        }

        if (result.Count >= limit) return result;
        if (!allowTemplateFallback) return result;

        var fallback = BuildLocalFallbackRecipes(
            ingredients,
            region,
            excludeRecipeNames,
            limit * 2,
            refreshToken,
            recentNames,
            preferences
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

    private HashSet<string> GetRecentRecipeNames(int? userId)
    {
        if (!userId.HasValue) return new HashSet<string>();
        if (!_recentRecipeNamesByUser.TryGetValue(userId.Value, out var list) || list.Count == 0)
        {
            return new HashSet<string>();
        }
        return list.ToHashSet();
    }

    private void RecordRecentRecipeNames(int? userId, List<object> recipes)
    {
        if (!userId.HasValue || recipes.Count == 0) return;
        var list = _recentRecipeNamesByUser.GetOrAdd(userId.Value, _ => new LinkedList<string>());
        lock (list)
        {
            var existing = list.ToHashSet();
            foreach (var item in recipes)
            {
                var map = ToDictionary(item);
                if (map == null) continue;
                var name = map.TryGetValue("name", out var raw) ? raw?.ToString() ?? string.Empty : string.Empty;
                var normalized = NormalizeVietnameseText(name);
                if (string.IsNullOrWhiteSpace(normalized)) continue;
                if (existing.Contains(normalized)) continue;
                list.AddLast(normalized);
                existing.Add(normalized);
            }

            while (list.Count > RecentSuggestionsPerUser)
            {
                list.RemoveFirst();
            }
        }
    }

    private async Task ApplyUserPersonalizationAsync(Dictionary<string, object> preferences, int? userId)
    {
        if (!userId.HasValue) return;

        preferences["user_personalization_seed"] = $"user-{userId.Value}";

        var user = await _db.Users
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.UserId == userId.Value);
        if (user == null) return;

        preferences["user_skill_level"] = string.IsNullOrWhiteSpace(user.SkillLevel)
            ? "beginner"
            : user.SkillLevel;

        var dietary = ParseJsonStringArray(user.DietaryRestrictions);
        if (dietary.Count > 0 && !preferences.ContainsKey("dietary_restrictions"))
        {
            preferences["dietary_restrictions"] = string.Join(", ", dietary);
        }

        var cuisinePreferences = ParseJsonStringArray(user.CuisinePreferences);
        if (cuisinePreferences.Count > 0)
        {
            if (!preferences.ContainsKey("cuisine"))
            {
                preferences["cuisine"] = cuisinePreferences[0];
            }
            preferences["user_cuisine_focus"] = string.Join(", ", cuisinePreferences);
        }

        var allergies = ParseJsonStringArray(user.Allergies);
        if (allergies.Count > 0)
        {
            preferences["user_avoid_ingredients"] = string.Join(", ", allergies);
        }

        preferences["user_flavor_profile"] = await BuildEnhancedFlavorProfileAsync(user, cuisinePreferences, dietary);
        preferences["user_variant_hint"] = BuildUserVariantHint(user.UserId);
        
        // Add info about liked/cooked recipes
        var favorites = await _db.UserFavorites
            .Where(f => f.UserId == userId.Value)
            .Include(f => f.Recipe)
            .OrderByDescending(f => f.CreatedAt)
            .Take(5)
            .Select(f => f.Recipe!.TitleVi)
            .ToListAsync();
        if (favorites.Any())
        {
            preferences["user_favorite_dishes"] = string.Join(", ", favorites);
            preferences["user_flavor_profile"] += "; thích các món như " + string.Join(", ", favorites);
        }

        var recentCooked = await _db.ActivityLogs
            .Where(l => l.UserId == userId.Value && l.ActivityType == "cook_recipe")
            .OrderByDescending(l => l.CreatedAt)
            .Take(3)
            .Select(l => l.ExtraData) // extra_data contains itemName
            .ToListAsync();
        
        if (recentCooked.Any())
        {
            var cookedNames = recentCooked
                .Select(ed => {
                    try {
                        using var doc = JsonDocument.Parse(ed ?? "{}");
                        return doc.RootElement.TryGetProperty("itemName", out var p) ? p.GetString() : null;
                    } catch { return null; }
                })
                .Where(n => n != null)
                .Cast<string>()
                .ToList();
            if (cookedNames.Any())
            {
                preferences["user_recent_cooked"] = string.Join(", ", cookedNames);
                // Hint the suggestion generator to avoid these for variety
                preferences["refresh_token"] = (preferences.TryGetValue("refresh_token", out var rt) ? rt?.ToString() ?? "" : "") 
                    + " avoid:" + string.Join(",", cookedNames);
            }
        }
    }

    private async Task<string> BuildEnhancedFlavorProfileAsync(User user, List<string> cuisines, List<string> dietary)
    {
        var parts = new List<string>();

        if (user.SkillLevel == "beginner") parts.Add("uu tien mon de nau, it buoc");
        else if (user.SkillLevel == "advanced") parts.Add("co the thu mon cau ky hon");

        if (cuisines.Any()) parts.Add($"thich {string.Join(", ", cuisines.Take(2))}");
        if (dietary.Any()) parts.Add($"uu tien che do {string.Join(", ", dietary.Take(2))}");

        // Add more specific flavor profile based on ratings
        var highRatings = await _db.UserRatings
            .Where(r => r.UserId == user.UserId && r.Rating >= 4)
            .Include(r => r.Recipe)
            .Take(3)
            .Select(r => r.Recipe!.TitleVi)
            .ToListAsync();
        
        if (highRatings.Any())
        {
            parts.Add($"da thich va danh gia cao: {string.Join(", ", highRatings)}");
        }

        var variant = user.UserId % 3;
        if (variant == 0) parts.Add("nghieng ve vi thanh va mon canh");
        if (variant == 1) parts.Add("nghieng ve mon xao kho dua com");
        if (variant == 2) parts.Add("nghieng ve mon nhanh gon cho bua hang ngay");

        return string.Join("; ", parts);
    }

    private static List<string> ParseJsonStringArray(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw)) return new List<string>();
        try
        {
            using var doc = JsonDocument.Parse(raw);
            if (doc.RootElement.ValueKind == JsonValueKind.Array)
            {
                return doc.RootElement
                    .EnumerateArray()
                    .Select(x => x.GetString() ?? string.Empty)
                    .Where(x => !string.IsNullOrWhiteSpace(x))
                    .ToList();
            }
            if (doc.RootElement.ValueKind == JsonValueKind.String)
            {
                var single = doc.RootElement.GetString();
                return string.IsNullOrWhiteSpace(single) ? new List<string>() : new List<string> { single };
            }
        }
        catch
        {
            return raw
                .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .ToList();
        }

        return new List<string>();
    }

    private static string BuildUserVariantHint(int userId)
    {
        return (userId % 4) switch
        {
            0 => "uu tien bua com canh - kho - rau",
            1 => "uu tien mon nhanh gon duoi 30 phut",
            2 => "uu tien mon xao va mon nuoc xen ke",
            _ => "uu tien bua an can bang va it lap lai"
        };
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

    private async Task SaveSuggestedRecipesAsync(int userId, List<object> recipes, string contextData)
    {
        try
        {
            var suggestedRecipes = recipes.Select(r => {
                var map = ToDictionary(r);
                return new SuggestedRecipe
                {
                    UserId = userId,
                    RecipeName = map?.TryGetValue("name", out var n) == true ? n?.ToString() ?? "Unknown" : "Unknown",
                    RecipeDataJson = JsonSerializer.Serialize(r),
                    SuggestedAt = DateTime.Now,
                    Status = "suggested",
                    ContextData = contextData
                };
            }).ToList();

            _db.SuggestedRecipes.AddRange(suggestedRecipes);
            await _db.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi lưu lịch sử gợi ý món ăn");
        }
    }

    private static string GetTimeOfDayContext()
    {
        var hour = DateTime.Now.Hour;
        if (hour >= 5 && hour < 10) return "Buổi sáng (Bữa sáng)";
        if (hour >= 10 && hour < 14) return "Buổi trưa (Bữa trưa)";
        if (hour >= 14 && hour < 17) return "Buổi chiều (Bữa xế/Bữa tối sớm)";
        if (hour >= 17 && hour < 22) return "Buổi tối (Bữa tối)";
        return "Ban đêm (Bữa khuya)";
    }

    private static string GetSeasonContext()
    {
        var month = DateTime.Now.Month;
        // Simplified for Vietnam (more or less)
        if (month >= 2 && month <= 4) return "Mùa Xuân (Thời tiết ấm áp, tươi mới)";
        if (month >= 5 && month <= 7) return "Mùa Hè (Thời tiết nóng bức, ưu tiên món thanh mát)";
        if (month >= 8 && month <= 10) return "Mùa Thu (Thời tiết mát mẻ, dễ chịu)";
        return "Mùa Đông (Thời tiết lạnh, ưu tiên món nóng sốt, đậm đà)";
    }
}
