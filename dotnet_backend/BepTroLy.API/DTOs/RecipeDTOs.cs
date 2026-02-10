namespace BepTroLy.API.DTOs;

public class SuggestRecipesRequest
{
    public List<string> Ingredients { get; set; } = new();
    public Dictionary<string, object>? Preferences { get; set; }
    public int Limit { get; set; } = 5;
}

public class SuggestFromPantryRequest
{
    public Dictionary<string, object>? Preferences { get; set; }
    public int Limit { get; set; } = 5;
}

public class RecipeSuggestionResponse
{
    public bool Success { get; set; }
    public string? Source { get; set; }
    public string? Error { get; set; }
    public List<object> Recipes { get; set; } = new();
}
