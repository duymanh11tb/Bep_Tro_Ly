using BepTroLy.API.Data;
using BepTroLy.API.Models;
using BepTroLy.API.DTOs;
using BepTroLy.API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

namespace BepTroLy.API.Controllers;

[ApiController]
[Route("api/v1/recipes")]
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
            request.Region,
            request.RefreshToken,
            request.ExcludeRecipeNames,
            GetCurrentUserId(),
            request.Limit
        );

        var success = (bool)result["success"];
        return success ? Ok(result) : StatusCode(500, result);
    }

    /// <summary>Gợi ý món ăn từ nguyên liệu trong tủ lạnh (POST).</summary>
    [HttpPost("suggest-from-pantry")]
    [Authorize]
    [EnableRateLimiting("ai-heavy")]
    public async Task<IActionResult> SuggestFromPantry([FromBody] SuggestFromPantryRequest request)
    {
        var userId = GetCurrentUserId();
        if (userId == null) return Unauthorized();

        var result = await _aiService.SuggestFromPantryAsync(
            userId.Value,
            request.FridgeId,
            request.Preferences,
            request.Region,
            request.RefreshToken,
            request.ExcludeRecipeNames,
            request.Limit
        );

        var success = (bool)result["success"];
        return success ? Ok(result) : BadRequest(result);
    }

    /// <summary>Gợi ý món ăn từ nguyên liệu trong tủ lạnh (GET — dùng bởi Flutter).</summary>
    [HttpGet("suggest-from-pantry")]
    [Authorize]
    [EnableRateLimiting("ai-heavy")]
    public async Task<IActionResult> SuggestFromPantryGet(
        [FromQuery] int? fridgeId,
        [FromQuery] int limit = 5,
        [FromQuery] string? region = null,
        [FromQuery] string? refreshToken = null,
        [FromQuery] string? excludeRecipeNames = null)
    {
        var userId = GetCurrentUserId();
        if (userId == null) return Unauthorized();
        var excludes = ParseExcludeRecipeNames(excludeRecipeNames);

        var result = await _aiService.SuggestFromPantryAsync(
            userId.Value,
            fridgeId,
            null,
            region,
            refreshToken,
            excludes,
            limit
        );

        var success = (bool)result["success"];
        return success ? Ok(result) : BadRequest(result);
    }

    /// <summary>Gợi ý món theo vùng miền (GET).</summary>
    [HttpGet("suggest-by-region")]
    [Authorize]
    [EnableRateLimiting("ai-heavy")]
    public async Task<IActionResult> SuggestByRegionGet(
        [FromQuery] string? region,
        [FromQuery] int limit = 5,
        [FromQuery] string? refreshToken = null,
        [FromQuery] string? excludeRecipeNames = null)
    {
        var excludes = ParseExcludeRecipeNames(excludeRecipeNames);
        var result = await _aiService.SuggestByRegionAsync(
            region,
            null,
            refreshToken,
            excludes,
            GetCurrentUserId(),
            limit
        );

        var success = (bool)result["success"];
        return success ? Ok(result) : BadRequest(result);
    }

    [HttpPost("cook")]
    [Authorize]
    public async Task<IActionResult> CookRecipe([FromBody] CookRecipeRequest request)
    {
        var userId = GetCurrentUserId();
        if (userId == null) return Unauthorized();

        // Log Activity
        await LogActivity(userId.Value, request.FridgeId, "cook_recipe", request.RecipeName, 1, "món", request.RecipeId);

        return Ok(new { message = "Đã ghi nhận nấu ăn thành công" });
    }

    private async Task LogActivity(int userId, int? fridgeId, string type, string itemName, decimal quantity, string unit, int? recipeId = null)
    {
        using var scope = HttpContext.RequestServices.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        try
        {
            var log = new ActivityLog
            {
                UserId = userId,
                FridgeId = fridgeId,
                ActivityType = type,
                RelatedRecipeId = recipeId,
                CreatedAt = DateTime.UtcNow,
                ExtraData = System.Text.Json.JsonSerializer.Serialize(new
                {
                    itemName = itemName,
                    quantity = quantity,
                    unit = unit
                })
            };
            db.ActivityLogs.Add(log);
            await db.SaveChangesAsync();

            // Send Notifications to other members
            if (fridgeId.HasValue)
            {
                await NotifyFridgeMembers(userId, fridgeId.Value, type, itemName, quantity, unit);
            }
        }
        catch (Exception)
        {
            // Ignore for now
        }
    }

    private async Task NotifyFridgeMembers(int actorId, int fridgeId, string type, string itemName, decimal quantity, string unit)
    {
        using var scope = HttpContext.RequestServices.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        try
        {
            var actor = await db.Users.FindAsync(actorId);
            var actorName = actor?.DisplayName ?? "Một thành viên";
            
            var members = await db.FridgeMembers
                .Where(m => m.FridgeId == fridgeId && m.UserId != actorId && m.Status == "accepted")
                .Select(m => m.UserId)
                .ToListAsync();

            if (!members.Any()) return;

            string action = type switch
            {
                "cook_recipe" => "đã nấu",
                _ => "đã thao tác"
            };

            string title = "Hoạt động tủ lạnh";
            string body = $"{actorName} {action} món {itemName}";

            foreach (var memberId in members)
            {
                db.Notifications.Add(new Notification
                {
                    UserId = memberId,
                    Type = "fridge_activity",
                    Title = title,
                    Body = body,
                    CreatedAt = DateTime.UtcNow,
                    IsRead = false
                });
            }
            await db.SaveChangesAsync();
        }
        catch (Exception) { /* Ignore */ }
    }

    private int? GetCurrentUserId()
    {
        var claim = User.FindFirst("user_id")?.Value;
        return claim != null ? int.Parse(claim) : null;
    }

    private static List<string> ParseExcludeRecipeNames(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw)) return new List<string>();

        return raw
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
    }
}
