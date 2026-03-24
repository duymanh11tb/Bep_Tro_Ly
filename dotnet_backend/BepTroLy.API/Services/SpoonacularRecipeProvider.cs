using System.Net;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace BepTroLy.API.Services;

public class SpoonacularRecipeProvider : IRecipeCatalogProvider
{
    private const int MaxCandidatesPerRequest = 8;

    private static readonly Dictionary<string, string> VietnameseToEnglishIngredientMap = new(StringComparer.OrdinalIgnoreCase)
    {
        ["thit bo"] = "beef",
        ["bo xay"] = "ground beef",
        ["thit bo xay"] = "ground beef",
        ["thit heo"] = "pork",
        ["thit lon"] = "pork",
        ["thit ba chi"] = "pork belly",
        ["suon heo"] = "pork ribs",
        ["thit ga"] = "chicken",
        ["uc ga"] = "chicken breast",
        ["canh ga"] = "chicken wings",
        ["ca"] = "fish",
        ["ca loc"] = "snakehead fish",
        ["ca hoi"] = "salmon",
        ["ca ngu"] = "tuna",
        ["tom"] = "shrimp",
        ["muc"] = "squid",
        ["cua"] = "crab",
        ["ngheu"] = "clam",
        ["hen"] = "clam",
        ["trung"] = "egg",
        ["trung ga"] = "egg",
        ["trung vit"] = "duck egg",
        ["dau hu"] = "tofu",
        ["dau phu"] = "tofu",
        ["nam"] = "mushroom",
        ["nam huong"] = "shiitake mushroom",
        ["nam kim cham"] = "enoki mushroom",
        ["nam rom"] = "straw mushroom",
        ["hanh"] = "onion",
        ["hanh tay"] = "onion",
        ["hanh tim"] = "shallot",
        ["hanh la"] = "scallion",
        ["toi"] = "garlic",
        ["gung"] = "ginger",
        ["sa"] = "lemongrass",
        ["ot"] = "chili pepper",
        ["ca chua"] = "tomato",
        ["dua leo"] = "cucumber",
        ["dua chuot"] = "cucumber",
        ["khoai tay"] = "potato",
        ["khoai lang"] = "sweet potato",
        ["ca rot"] = "carrot",
        ["bi do"] = "pumpkin",
        ["bi ngo"] = "zucchini",
        ["muop"] = "loofah",
        ["ca tim"] = "eggplant",
        ["bap cai"] = "cabbage",
        ["cai thao"] = "bok choy",
        ["cai thi"] = "mustard greens",
        ["rau cai"] = "greens",
        ["rau ngot"] = "sweet leaf",
        ["rau muong"] = "water spinach",
        ["rau den"] = "amaranth",
        ["dau que"] = "green beans",
        ["bong cai"] = "broccoli",
        ["sup lo"] = "cauliflower",
        ["dua"] = "pineapple",
        ["dua hau"] = "watermelon",
        ["chuoi"] = "banana",
        ["tao"] = "apple",
        ["cam"] = "orange",
        ["chanh"] = "lime",
        ["me"] = "tamarind",
        ["com"] = "rice",
        ["com nguoi"] = "cooked rice",
        ["bun"] = "rice noodles",
        ["pho"] = "rice noodles",
        ["mi"] = "noodles",
        ["mien"] = "glass noodles",
        ["mi quang"] = "turmeric noodles",
        ["gao lut"] = "brown rice",
        ["yen mach"] = "oats",
        ["sua chua"] = "yogurt",
        ["dau phong"] = "peanut",
        ["nuoc mam"] = "fish sauce",
        ["nuoc tuong"] = "soy sauce",
        ["dau hao"] = "oyster sauce",
        ["dau an"] = "cooking oil",
        ["nuoc dua"] = "coconut water",
        ["bo"] = "butter",
        ["xuc xich"] = "sausage"
    };

    private static readonly Dictionary<string, string> EnglishToVietnameseIngredientMap =
        VietnameseToEnglishIngredientMap
            .GroupBy(x => x.Value, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(g => g.Key, g => RestoreVietnameseDisplay(g.First().Key), StringComparer.OrdinalIgnoreCase);

    private readonly HttpClient _httpClient;
    private readonly ILogger<SpoonacularRecipeProvider> _logger;
    private readonly GeminiService _geminiService;
    private readonly string? _apiKey;
    private readonly string _baseUrl;

    public SpoonacularRecipeProvider(
        HttpClient httpClient,
        IConfiguration configuration,
        ILogger<SpoonacularRecipeProvider> logger,
        GeminiService geminiService)
    {
        _httpClient = httpClient;
        _logger = logger;
        _geminiService = geminiService;
        _apiKey = configuration["Spoonacular:ApiKey"];
        _baseUrl = (configuration["Spoonacular:BaseUrl"] ?? "https://api.spoonacular.com").Trim().TrimEnd('/');
    }

    public async Task<List<object>> SuggestRecipesAsync(
        List<string> ingredients,
        Dictionary<string, object>? preferences,
        int limit,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(_apiKey) || limit <= 0)
        {
            return new List<object>();
        }

        try
        {
            var effectiveLimit = Math.Clamp(limit, 1, MaxCandidatesPerRequest);
            return ingredients != null && ingredients.Any(x => !string.IsNullOrWhiteSpace(x))
                ? await SuggestFromIngredientsAsync(ingredients, preferences, effectiveLimit, cancellationToken)
                : await DiscoverRecipesAsync(preferences, effectiveLimit, cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Spoonacular provider failed");
            return new List<object>();
        }
    }

    private async Task<List<object>> SuggestFromIngredientsAsync(
        List<string> ingredients,
        Dictionary<string, object>? preferences,
        int limit,
        CancellationToken cancellationToken)
    {
        var translations = await BuildIngredientTranslationsAsync(ingredients, cancellationToken);
        var englishIngredients = translations
            .Select(x => x.English)
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .Take(12)
            .ToList();

        if (englishIngredients.Count == 0)
        {
            return new List<object>();
        }

        var json = await GetJsonAsync(
            "/recipes/findByIngredients",
            new Dictionary<string, string?>
            {
                ["ingredients"] = string.Join(",", englishIngredients),
                ["number"] = Math.Clamp(limit, limit, MaxCandidatesPerRequest).ToString(),
                ["ranking"] = "2",
                ["ignorePantry"] = "true"
            },
            cancellationToken);

        if (json == null || json.RootElement.ValueKind != JsonValueKind.Array)
        {
            return new List<object>();
        }

        var candidates = new List<SpoonacularCandidate>();
        foreach (var item in json.RootElement.EnumerateArray())
        {
            if (!item.TryGetProperty("id", out var idElement) || !idElement.TryGetInt32(out var id))
            {
                continue;
            }

            var usedIngredients = item.TryGetProperty("usedIngredients", out var usedElement)
                ? MapMatchedIngredients(usedElement, translations)
                : new List<string>();
            var missingIngredients = item.TryGetProperty("missedIngredients", out var missedElement)
                ? MapMissingIngredients(missedElement)
                : new List<string>();

            var usedCount = item.TryGetProperty("usedIngredientCount", out var usedCountElement) && usedCountElement.TryGetInt32(out var usedCountValue)
                ? usedCountValue
                : usedIngredients.Count;
            var missedCount = item.TryGetProperty("missedIngredientCount", out var missedCountElement) && missedCountElement.TryGetInt32(out var missedCountValue)
                ? missedCountValue
                : missingIngredients.Count;

            var denominator = Math.Max(1, usedCount + missedCount);
            var matchScore = Math.Min(0.99, Math.Max(0.35, (double)usedCount / denominator));

            candidates.Add(new SpoonacularCandidate
            {
                Id = id,
                Title = item.TryGetProperty("title", out var titleElement) ? titleElement.GetString() ?? string.Empty : string.Empty,
                ImageUrl = item.TryGetProperty("image", out var imageElement) ? imageElement.GetString() : null,
                UsedIngredients = usedIngredients,
                MissingIngredients = missingIngredients,
                MatchScore = matchScore
            });
        }

        return await BuildRecipesFromCandidatesAsync(candidates, cancellationToken);
    }

    private async Task<List<object>> DiscoverRecipesAsync(
        Dictionary<string, object>? preferences,
        int limit,
        CancellationToken cancellationToken)
    {
        preferences ??= new Dictionary<string, object>();

        var query = new Dictionary<string, string?>
        {
            ["number"] = Math.Clamp(limit, limit, MaxCandidatesPerRequest).ToString(),
            ["instructionsRequired"] = "true",
            ["addRecipeInformation"] = "true",
            ["fillIngredients"] = "true",
            ["sort"] = "popularity"
        };

        var cuisine = MapCuisinePreference(GetPreferenceString(preferences, "cuisine"));
        if (!string.IsNullOrWhiteSpace(cuisine))
        {
            query["cuisine"] = cuisine;
        }

        var diet = MapDietaryPreference(GetPreferenceString(preferences, "dietary_restrictions"));
        if (!string.IsNullOrWhiteSpace(diet))
        {
            query["diet"] = diet;
        }

        var mealType = MapMealTypePreference(
            GetPreferenceString(preferences, "meal_type") ??
            GetPreferenceString(preferences, "mealType") ??
            GetPreferenceString(preferences, "type"));
        if (!string.IsNullOrWhiteSpace(mealType))
        {
            query["type"] = mealType;
        }

        var maxReadyTime = GetPreferenceInt(preferences, "max_ready_time")
            ?? GetPreferenceInt(preferences, "maxReadyTime");
        if (maxReadyTime.HasValue && maxReadyTime.Value > 0)
        {
            query["maxReadyTime"] = maxReadyTime.Value.ToString();
        }

        var json = await GetJsonAsync("/recipes/complexSearch", query, cancellationToken);
        if (json == null ||
            !json.RootElement.TryGetProperty("results", out var resultsElement) ||
            resultsElement.ValueKind != JsonValueKind.Array)
        {
            return new List<object>();
        }

        var results = new List<object>();
        foreach (var item in resultsElement.EnumerateArray())
        {
            var mapped = await MapRecipeDetailToRecipeAsync(item, candidate: null, cancellationToken);
            if (mapped != null)
            {
                results.Add(mapped);
            }
        }

        return results;
    }

    private async Task<List<object>> BuildRecipesFromCandidatesAsync(
        List<SpoonacularCandidate> candidates,
        CancellationToken cancellationToken)
    {
        var recipes = new List<object>();
        foreach (var candidate in candidates)
        {
            var detail = await GetJsonAsync(
                $"/recipes/{candidate.Id}/information",
                new Dictionary<string, string?>
                {
                    ["includeNutrition"] = "false"
                },
                cancellationToken);

            if (detail == null)
            {
                continue;
            }

            var mapped = await MapRecipeDetailToRecipeAsync(detail.RootElement, candidate, cancellationToken);
            if (mapped != null)
            {
                recipes.Add(mapped);
            }
        }

        return recipes;
    }

    private async Task<Dictionary<string, object>?> MapRecipeDetailToRecipeAsync(
        JsonElement detail, 
        SpoonacularCandidate? candidate, 
        CancellationToken ct)
    {
        var instructionsEn = ExtractInstructions(detail);
        if (instructionsEn.Count == 0)
        {
            return null;
        }

        var id = TryGetInt32(detail, "id", out var parsedId)
            ? parsedId
            : candidate?.Id ?? 0;
            
        var titleEn = detail.TryGetProperty("title", out var titleElement)
            ? titleElement.GetString() ?? candidate?.Title ?? string.Empty
            : candidate?.Title ?? string.Empty;
            
        var summaryEn = detail.TryGetProperty("summary", out var summaryElement)
            ? summaryElement.GetString()
            : string.Empty;

        // Translate title and description
        var titleVi = await _geminiService.TranslateTextAsync(titleEn, ct);
        var descriptionVi = !string.IsNullOrWhiteSpace(summaryEn)
            ? await _geminiService.TranslateTextAsync(StripHtml(summaryEn), ct)
            : $"Món {titleVi} được lấy từ catalog công thức.";

        var imageUrl = detail.TryGetProperty("image", out var imageElement)
            ? imageElement.GetString() ?? candidate?.ImageUrl
            : candidate?.ImageUrl;

        var prepTime = TryGetInt32(detail, "preparationMinutes", out var prepValue) ? prepValue : 0;
        var cookTime = TryGetInt32(detail, "cookingMinutes", out var cookValue) ? cookValue : 0;
        var readyInMinutes = TryGetInt32(detail, "readyInMinutes", out var readyValue) ? readyValue : 0;

        if (prepTime <= 0 && cookTime <= 0 && readyInMinutes > 0)
        {
            cookTime = readyInMinutes;
        }
        else if (cookTime <= 0 && readyInMinutes > prepTime)
        {
            cookTime = Math.Max(0, readyInMinutes - prepTime);
        }

        var servings = TryGetInt32(detail, "servings", out var servingsValue) ? servingsValue : 2;

        var usedIngredients = candidate?.UsedIngredients ?? ExtractPrimaryIngredients(detail, take: 4);
        var missingIngredients = candidate?.MissingIngredients ?? new List<string>();
        
        var extIngredientsCount = detail.TryGetProperty("extendedIngredients", out var extElement) && extElement.ValueKind == JsonValueKind.Array
            ? extElement.GetArrayLength()
            : usedIngredients.Count + missingIngredients.Count;

        // Translate instructions
        var instructionsVi = new List<string>();
        foreach (var stepEn in instructionsEn)
        {
            var coreText = Regex.Replace(stepEn, @"^Bước \d+: ", "");
            var translatedStep = await _geminiService.TranslateTextAsync(coreText, ct);
            instructionsVi.Add(stepEn.Replace(coreText, translatedStep));
        }

        var cuisinesEn = ExtractCuisines(detail);
        var dishTypesEn = ExtractDishTypes(detail);
        
        var cuisinesVi = await _geminiService.TranslateTagsAsync(cuisinesEn, ct) ?? new List<string>();
        var dishTypesVi = await _geminiService.TranslateTagsAsync(dishTypesEn, ct) ?? new List<string>();

        return new Dictionary<string, object>
        {
            ["id"] = id,
            ["name"] = titleVi,
            ["description"] = descriptionVi,
            ["image_url"] = imageUrl ?? string.Empty,
            ["difficulty"] = InferDifficulty(prepTime + cookTime, instructionsVi.Count, extIngredientsCount),
            ["prep_time"] = prepTime,
            ["cook_time"] = cookTime,
            ["servings"] = servings,
            ["ingredients_used"] = usedIngredients,
            ["ingredients_missing"] = missingIngredients,
            ["match_score"] = candidate?.MatchScore ?? InferDiscoveryScore(prepTime + cookTime, instructionsVi.Count),
            ["instructions"] = instructionsVi,
            ["tips"] = await BuildTipsAsync(detail, ct) ?? string.Empty,
            ["cuisines"] = cuisinesVi,
            ["dish_types"] = dishTypesVi,
            ["ingredients_expiring_count"] = 0,
            ["source_provider"] = "spoonacular"
        };
    }

    private async Task<JsonDocument?> GetJsonAsync(
        string path,
        Dictionary<string, string?> query,
        CancellationToken cancellationToken)
    {
        var requestUri = BuildUri(path, query);
        using var response = await _httpClient.GetAsync(requestUri, cancellationToken);
        var responseText = await response.Content.ReadAsStringAsync(cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogWarning(
                "Spoonacular request failed {StatusCode} for {Path}: {Body}",
                (int)response.StatusCode,
                path,
                responseText);
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

    private static bool TryGetInt32(JsonElement element, string propertyName, out int value)
    {
        value = 0;

        if (!element.TryGetProperty(propertyName, out var property))
        {
            return false;
        }

        if (property.ValueKind == JsonValueKind.Number)
        {
            return property.TryGetInt32(out value);
        }

        if (property.ValueKind == JsonValueKind.String)
        {
            return int.TryParse(property.GetString(), out value);
        }

        return false;
    }

    private string BuildUri(string path, Dictionary<string, string?> query)
    {
        var builder = new StringBuilder();
        builder.Append(_baseUrl);
        builder.Append(path);
        builder.Append('?');
        builder.Append("apiKey=");
        builder.Append(Uri.EscapeDataString(_apiKey ?? string.Empty));

        foreach (var pair in query.Where(x => !string.IsNullOrWhiteSpace(x.Value)))
        {
            builder.Append('&');
            builder.Append(Uri.EscapeDataString(pair.Key));
            builder.Append('=');
            builder.Append(Uri.EscapeDataString(pair.Value!));
        }

        return builder.ToString();
    }

    private async Task<List<IngredientTranslation>> BuildIngredientTranslationsAsync(IEnumerable<string> ingredients, CancellationToken cancellationToken)
    {
        var result = new List<IngredientTranslation>();
        var distinctIngredients = ingredients
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Select(x => x.Trim())
            .Distinct(StringComparer.OrdinalIgnoreCase);

        foreach (var x in distinctIngredients)
        {
            var english = await TranslateIngredientToEnglishAsync(x, cancellationToken);
            result.Add(new IngredientTranslation(
                x,
                english,
                NormalizeText(x),
                NormalizeText(english)));
        }

        return result.Where(x => !string.IsNullOrWhiteSpace(x.NormalizedEnglish)).ToList();
    }

    private async Task<string> TranslateIngredientToEnglishAsync(string ingredient, CancellationToken cancellationToken)
    {
        var normalized = NormalizeText(ingredient);
        if (VietnameseToEnglishIngredientMap.TryGetValue(normalized, out var exact))
        {
            return exact;
        }

        var longestMatch = VietnameseToEnglishIngredientMap
            .OrderByDescending(x => x.Key.Length)
            .FirstOrDefault(x => normalized.Contains(x.Key, StringComparison.OrdinalIgnoreCase));
        if (!string.IsNullOrWhiteSpace(longestMatch.Key))
        {
            return longestMatch.Value;
        }

        // Fallback to Gemini for smart translation
        var geminiTranslated = await _geminiService.TranslateIngredientAsync(ingredient, cancellationToken);
        if (!string.IsNullOrWhiteSpace(geminiTranslated))
        {
            return geminiTranslated;
        }

        return Regex.Replace(normalized, @"\s+", " ").Trim();
    }

    private static List<string> MapMatchedIngredients(JsonElement usedElement, List<IngredientTranslation> translations)
    {
        var used = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var item in usedElement.EnumerateArray())
        {
            var name = item.TryGetProperty("name", out var nameElement) ? nameElement.GetString() ?? string.Empty : string.Empty;
            var normalizedName = NormalizeText(name);

            var matched = translations.FirstOrDefault(x =>
                normalizedName.Contains(x.NormalizedEnglish, StringComparison.OrdinalIgnoreCase) ||
                x.NormalizedEnglish.Contains(normalizedName, StringComparison.OrdinalIgnoreCase));

            if (matched != null)
            {
                used.Add(matched.Original);
            }
            else if (!string.IsNullOrWhiteSpace(name))
            {
                used.Add(MapIngredientDisplayName(name));
            }
        }

        return used.ToList();
    }

    private static List<string> MapMissingIngredients(JsonElement missedElement)
    {
        var missing = new List<string>();
        foreach (var item in missedElement.EnumerateArray())
        {
            var name = item.TryGetProperty("name", out var nameElement) ? nameElement.GetString() ?? string.Empty : string.Empty;
            if (!string.IsNullOrWhiteSpace(name))
            {
                missing.Add(MapIngredientDisplayName(name));
            }
        }

        return missing
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    private static List<string> ExtractPrimaryIngredients(JsonElement detail, int take)
    {
        if (!detail.TryGetProperty("extendedIngredients", out var ingredientsElement) ||
            ingredientsElement.ValueKind != JsonValueKind.Array)
        {
            return new List<string>();
        }

        return ingredientsElement
            .EnumerateArray()
            .Select(x => x.TryGetProperty("name", out var nameElement) ? nameElement.GetString() ?? string.Empty : string.Empty)
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Select(MapIngredientDisplayName)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .Take(take)
            .ToList();
    }

    private static List<string> ExtractInstructions(JsonElement detail)
    {
        var instructions = new List<string>();

        if (detail.TryGetProperty("analyzedInstructions", out var analyzedInstructions) &&
            analyzedInstructions.ValueKind == JsonValueKind.Array)
        {
            foreach (var instructionGroup in analyzedInstructions.EnumerateArray())
            {
                if (!instructionGroup.TryGetProperty("steps", out var stepsElement) ||
                    stepsElement.ValueKind != JsonValueKind.Array)
                {
                    continue;
                }

                foreach (var step in stepsElement.EnumerateArray())
                {
                    var number = step.TryGetProperty("number", out var numberElement) && numberElement.TryGetInt32(out var stepNumber)
                        ? stepNumber
                        : instructions.Count + 1;
                    var text = step.TryGetProperty("step", out var textElement) ? textElement.GetString() ?? string.Empty : string.Empty;
                    var cleaned = NormalizeSentence(text);
                    if (!string.IsNullOrWhiteSpace(cleaned))
                    {
                        instructions.Add($"Bước {number}: {cleaned}");
                    }
                }
            }
        }

        if (instructions.Count > 0)
        {
            return instructions;
        }

        if (!detail.TryGetProperty("instructions", out var instructionsElement))
        {
            return instructions;
        }

        var flattened = StripHtml(instructionsElement.GetString());
        if (string.IsNullOrWhiteSpace(flattened))
        {
            return instructions;
        }

        var parts = Regex.Split(flattened, @"(?<=[\.\!\?])\s+")
            .Select(NormalizeSentence)
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Take(8)
            .ToList();

        for (var i = 0; i < parts.Count; i++)
        {
            instructions.Add($"Bước {i + 1}: {parts[i]}");
        }

        return instructions;
    }

    private static List<string> ExtractCuisines(JsonElement detail)
    {
        if (detail.TryGetProperty("cuisines", out var cuisinesElement) &&
            cuisinesElement.ValueKind == JsonValueKind.Array)
        {
            return cuisinesElement
                .EnumerateArray()
                .Select(x => x.GetString() ?? string.Empty)
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .ToList();
        }
        return new List<string>();
    }

    private static List<string> ExtractDishTypes(JsonElement detail)
    {
        if (detail.TryGetProperty("dishTypes", out var dishTypesElement) &&
            dishTypesElement.ValueKind == JsonValueKind.Array)
        {
            return dishTypesElement
                .EnumerateArray()
                .Select(x => x.GetString() ?? string.Empty)
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .ToList();
        }
        return new List<string>();
    }

    private async Task<string?> BuildTipsAsync(JsonElement detail, CancellationToken ct)
    {
        if (detail.TryGetProperty("dishTypes", out var dishTypesElement) &&
            dishTypesElement.ValueKind == JsonValueKind.Array)
        {
            var firstTypeEn = dishTypesElement
                .EnumerateArray()
                .Select(x => x.GetString() ?? string.Empty)
                .FirstOrDefault(x => !string.IsNullOrWhiteSpace(x));
            
            if (!string.IsNullOrWhiteSpace(firstTypeEn))
            {
                var typeVi = await _geminiService.TranslateTextAsync(firstTypeEn, ct);
                return $"Mẹo nhỏ: món này rất tuyệt vời khi dùng làm {typeVi.ToLowerInvariant()}.";
            }
        }

        return null;
    }

    private static string BuildDescription(string? summary)
    {
        var cleaned = StripHtml(summary);
        if (string.IsNullOrWhiteSpace(cleaned))
        {
            return "Công thức được lấy từ catalog món ăn và đã có sẵn hướng dẫn nấu.";
        }

        cleaned = cleaned.Trim();
        return cleaned.Length <= 180 ? cleaned : cleaned[..177] + "...";
    }

    private static string InferDifficulty(int totalMinutes, int instructionCount, int ingredientCount)
    {
        if (totalMinutes <= 20 && instructionCount <= 4 && ingredientCount <= 8)
        {
            return "easy";
        }

        if (totalMinutes <= 45 && instructionCount <= 7 && ingredientCount <= 12)
        {
            return "medium";
        }

        return "hard";
    }

    private static double InferDiscoveryScore(int totalMinutes, int instructionCount)
    {
        var score = 0.72;
        if (totalMinutes > 0 && totalMinutes <= 20) score += 0.08;
        if (instructionCount > 0 && instructionCount <= 4) score += 0.05;
        return Math.Min(0.95, score);
    }

    private static string? MapDietaryPreference(string? dietary)
    {
        var normalized = NormalizeText(dietary);
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

    private static string? MapCuisinePreference(string? cuisine)
    {
        var normalized = NormalizeText(cuisine);
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

    private static string? MapMealTypePreference(string? mealType)
    {
        var normalized = NormalizeText(mealType);
        if (string.IsNullOrWhiteSpace(normalized))
        {
            return null;
        }

        if (normalized.Contains("breakfast") || normalized.Contains("sang"))
        {
            return "breakfast";
        }

        if (normalized.Contains("lunch") || normalized.Contains("trua"))
        {
            return "main course";
        }

        if (normalized.Contains("dinner") || normalized.Contains("toi"))
        {
            return "main course";
        }

        if (normalized.Contains("salad"))
        {
            return "salad";
        }

        if (normalized.Contains("soup") || normalized.Contains("canh"))
        {
            return "soup";
        }

        if (normalized.Contains("snack") || normalized.Contains("an vat"))
        {
            return "snack";
        }

        return null;
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
                _ => raw.ToString() ?? string.Empty
            };
        }

        return raw.ToString() ?? string.Empty;
    }

    private static int? GetPreferenceInt(Dictionary<string, object> preferences, string key)
    {
        if (!preferences.TryGetValue(key, out var raw) || raw == null)
        {
            return null;
        }

        if (raw is JsonElement element)
        {
            if (element.ValueKind == JsonValueKind.Number && element.TryGetInt32(out var number))
            {
                return number;
            }

            if (element.ValueKind == JsonValueKind.String &&
                int.TryParse(element.GetString(), out var parsedFromString))
            {
                return parsedFromString;
            }
        }

        return int.TryParse(raw.ToString(), out var parsed) ? parsed : null;
    }

    private static string MapIngredientDisplayName(string ingredient)
    {
        var normalized = NormalizeText(ingredient);
        if (EnglishToVietnameseIngredientMap.TryGetValue(normalized, out var exact))
        {
            return exact;
        }

        var longestMatch = EnglishToVietnameseIngredientMap
            .OrderByDescending(x => x.Key.Length)
            .FirstOrDefault(x => normalized.Contains(x.Key, StringComparison.OrdinalIgnoreCase));
        if (!string.IsNullOrWhiteSpace(longestMatch.Key))
        {
            return longestMatch.Value;
        }

        return ingredient.Trim();
    }

    private static string NormalizeText(string? input)
    {
        if (string.IsNullOrWhiteSpace(input))
        {
            return string.Empty;
        }

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

        var chars = value.Select(c => map.TryGetValue(c, out var replacement) ? replacement : c).ToArray();
        return Regex.Replace(new string(chars), @"\s+", " ").Trim();
    }

    private static string NormalizeSentence(string? text)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            return string.Empty;
        }

        return Regex.Replace(text.Trim(), @"\s+", " ");
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

    private static string RestoreVietnameseDisplay(string normalized)
    {
        return normalized switch
        {
            "thit bo" => "thịt bò",
            "bo xay" => "bò xay",
            "thit bo xay" => "thịt bò xay",
            "thit heo" => "thịt heo",
            "thit lon" => "thịt lợn",
            "thit ba chi" => "thịt ba chỉ",
            "suon heo" => "sườn heo",
            "thit ga" => "thịt gà",
            "uc ga" => "ức gà",
            "canh ga" => "cánh gà",
            "ca" => "cá",
            "ca loc" => "cá lóc",
            "ca hoi" => "cá hồi",
            "ca ngu" => "cá ngừ",
            "tom" => "tôm",
            "muc" => "mực",
            "cua" => "cua",
            "ngheu" => "nghêu",
            "hen" => "hến",
            "trung" => "trứng",
            "trung ga" => "trứng gà",
            "trung vit" => "trứng vịt",
            "dau hu" => "đậu hũ",
            "dau phu" => "đậu phụ",
            "nam" => "nấm",
            "nam huong" => "nấm hương",
            "nam kim cham" => "nấm kim châm",
            "nam rom" => "nấm rơm",
            "hanh" => "hành",
            "hanh tay" => "hành tây",
            "hanh tim" => "hành tím",
            "hanh la" => "hành lá",
            "toi" => "tỏi",
            "gung" => "gừng",
            "sa" => "sả",
            "ot" => "ớt",
            "ca chua" => "cà chua",
            "dua leo" => "dưa leo",
            "dua chuot" => "dưa chuột",
            "khoai tay" => "khoai tây",
            "khoai lang" => "khoai lang",
            "ca rot" => "cà rốt",
            "bi do" => "bí đỏ",
            "bi ngo" => "bí ngòi",
            "muop" => "mướp",
            "ca tim" => "cà tím",
            "bap cai" => "bắp cải",
            "cai thao" => "cải thìa",
            "cai thi" => "cải bẹ",
            "rau cai" => "rau cải",
            "rau ngot" => "rau ngót",
            "rau muong" => "rau muống",
            "rau den" => "rau dền",
            "dau que" => "đậu que",
            "bong cai" => "bông cải",
            "sup lo" => "súp lơ",
            "dua" => "dứa",
            "dua hau" => "dưa hấu",
            "chuoi" => "chuối",
            "tao" => "táo",
            "cam" => "cam",
            "chanh" => "chanh",
            "me" => "me",
            "com" => "cơm",
            "com nguoi" => "cơm nguội",
            "bun" => "bún",
            "pho" => "phở",
            "mi" => "mì",
            "mien" => "miến",
            "mi quang" => "mì Quảng",
            "gao lut" => "gạo lứt",
            "yen mach" => "yến mạch",
            "sua chua" => "sữa chua",
            "dau phong" => "đậu phộng",
            "nuoc mam" => "nước mắm",
            "nuoc tuong" => "nước tương",
            "dau hao" => "dầu hào",
            "dau an" => "dầu ăn",
            "nuoc dua" => "nước dừa",
            "bo" => "bơ",
            "xuc xich" => "xúc xích",
            _ => normalized
        };
    }

    private sealed record IngredientTranslation(
        string Original,
        string English,
        string NormalizedOriginal,
        string NormalizedEnglish);

    private sealed class SpoonacularCandidate
    {
        public int Id { get; init; }
        public string Title { get; init; } = string.Empty;
        public string? ImageUrl { get; init; }
        public List<string> UsedIngredients { get; init; } = new();
        public List<string> MissingIngredients { get; init; } = new();
        public double MatchScore { get; init; }
    }
}
