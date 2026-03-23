namespace BepTroLy.API.DTOs;

public class SuggestRecipesRequest
{
    public List<string> Ingredients { get; set; } = new();
    public Dictionary<string, object>? Preferences { get; set; }
    public string? Region { get; set; }
    public string? RefreshToken { get; set; }
    public List<string>? ExcludeRecipeNames { get; set; }
    public int Limit { get; set; } = 5;
}

public class SuggestFromPantryRequest
{
    public int? FridgeId { get; set; }
    public Dictionary<string, object>? Preferences { get; set; }
    public string? Region { get; set; }
    public string? RefreshToken { get; set; }
    public List<string>? ExcludeRecipeNames { get; set; }
    public int Limit { get; set; } = 5;
}

public class SuggestByRegionRequest
{
    public string? Region { get; set; }
    public Dictionary<string, object>? Preferences { get; set; }
    public string? RefreshToken { get; set; }
    public List<string>? ExcludeRecipeNames { get; set; }
    public int Limit { get; set; } = 5;
}

public class RecipeSuggestionResponse
{
    public bool Success { get; set; }
    public string? Source { get; set; }
    public string? Error { get; set; }
    public List<object> Recipes { get; set; } = new();
}

public class CookRecipeRequest
{
    public int? FridgeId { get; set; }
    public int? RecipeId { get; set; }
    public string RecipeName { get; set; } = string.Empty;
}

public class SuggestionFeedbackRequest
{
    public string RecipeName { get; set; } = string.Empty;
    public string Feedback { get; set; } = string.Empty; // liked, disliked, hidden
}
