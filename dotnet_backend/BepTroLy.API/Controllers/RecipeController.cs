using BepTroLy.API.DTOs;
using BepTroLy.API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BepTroLy.API.Controllers;

[ApiController]
[Route("api/recipes")]
public class RecipeController : ControllerBase
{
    private static readonly TimeSpan SuggestionCooldown = TimeSpan.FromSeconds(10);
    private static readonly object CooldownLock = new();
    private static readonly Dictionary<string, DateTime> LastSuggestionAt = new();

    private readonly AIRecipeService _aiService;

    public RecipeController(AIRecipeService aiService)
    {
        _aiService = aiService;
    }

    /// <summary>Gợi ý món ăn dựa trên nguyên liệu.</summary>
    [HttpPost("suggest")]
    [Authorize]
    public async Task<IActionResult> SuggestRecipes([FromBody] SuggestRecipesRequest request)
    {
        var cooldownResult = CheckAndUpdateCooldown("suggest");
        if (cooldownResult != null)
        {
            return cooldownResult;
        }

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
    public async Task<IActionResult> SuggestFromPantry([FromBody] SuggestFromPantryRequest request)
    {
        var userId = GetCurrentUserId();
        if (userId == null) return Unauthorized();

        var cooldownResult = CheckAndUpdateCooldown("suggest-from-pantry");
        if (cooldownResult != null)
        {
            return cooldownResult;
        }

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

    private IActionResult? CheckAndUpdateCooldown(string endpoint)
    {
        var userId = GetCurrentUserId();
        if (userId == null)
        {
            return Unauthorized();
        }

        var now = DateTime.UtcNow;
        var key = $"{userId}:{endpoint}";

        lock (CooldownLock)
        {
            if (LastSuggestionAt.TryGetValue(key, out var lastCalledAt))
            {
                var elapsed = now - lastCalledAt;
                if (elapsed < SuggestionCooldown)
                {
                    var retryAfterSeconds = Math.Max(1, (int)Math.Ceiling((SuggestionCooldown - elapsed).TotalSeconds));
                    Response.Headers["Retry-After"] = retryAfterSeconds.ToString();
                    return StatusCode(StatusCodes.Status429TooManyRequests, new
                    {
                        success = false,
                        error = $"Bạn thao tác quá nhanh. Vui lòng thử lại sau {retryAfterSeconds} giây."
                    });
                }
            }

            LastSuggestionAt[key] = now;
        }

        return null;
    }
}
