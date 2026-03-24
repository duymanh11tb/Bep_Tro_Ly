namespace BepTroLy.API.Services;

public interface IRecipeCatalogProvider
{
    Task<List<object>> SuggestRecipesAsync(
        List<string> ingredients,
        Dictionary<string, object>? preferences,
        int limit,
        CancellationToken cancellationToken = default);
}
