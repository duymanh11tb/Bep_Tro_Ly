using BepTroLy.API.DTOs;
using BepTroLy.API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace BepTroLy.API.Controllers;

[ApiController]
[Route("api/recipes")]
public class RecipeController : ControllerBase
{
    private readonly AIRecipeService _aiService;

    public RecipeController(AIRecipeService aiService)
    {
        _aiService = aiService;
    }

    /// <summary>Gợi ý món ăn dựa trên nguyên liệu.</summary>
    [HttpPost("suggest")]
    [Authorize]
    [EnableRateLimiting("ai-heavy")]
    public async Task<IActionResult> SuggestRecipes([FromBody] SuggestRecipesRequest request)
    {
        var result = await _aiService.SuggestRecipesAsync(
            request.Ingredients ?? new List<string>(),
            request.Preferences,
            request.Limit
        );

        var success = (bool)result["success"];
        return success ? Ok(result) : StatusCode(500, result);
    }

    /// <summary>Gợi ý món ăn từ nguyên liệu trong tủ lạnh.</summary>
    [HttpPost("suggest-from-pantry")]
    [Authorize]
    [EnableRateLimiting("ai-heavy")]
    public async Task<IActionResult> SuggestFromPantry([FromBody] SuggestFromPantryRequest request)
    {
        var userId = GetCurrentUserId();
        if (userId == null) return Unauthorized();

        var result = await _aiService.SuggestFromPantryAsync(
            userId.Value,
            request.Preferences,
            request.Limit
        );

        var success = (bool)result["success"];
        return success ? Ok(result) : BadRequest(result);
    }

    private int? GetCurrentUserId()
    {
        var claim = User.FindFirst("user_id")?.Value;
        return claim != null ? int.Parse(claim) : null;
    }
}
