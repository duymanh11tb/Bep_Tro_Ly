namespace BepTroLy.API.DTOs;

public class SuggestRecipesRequest
{
    public List<string> Ingredients { get; set; } = new();
    public Dictionary<string, object>? Preferences { get; set; }
    public int Limit { get; set; } = 8;
    public int Offset { get; set; } = 0;
}

public class SuggestFromPantryRequest
{
    public Dictionary<string, object>? Preferences { get; set; }
    public int Limit { get; set; } = 8;
    public int Offset { get; set; } = 0;
}

public class RecipeSuggestionResponse
{
    public bool Success { get; set; }
    public string? Source { get; set; }
    public string? Error { get; set; }
    public List<object> Recipes { get; set; } = new();
}

// ── Batch API DTOs ──

public class CreateBatchRequest
{
    public Dictionary<string, object>? Preferences { get; set; }
}

public class BatchStatusResponse
{
    public int JobId { get; set; }
    public string State { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public int RequestCount { get; set; }
    public int SucceededCount { get; set; }
    public int FailedCount { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
    public string? ErrorMessage { get; set; }
    public bool HasResults { get; set; }
}

