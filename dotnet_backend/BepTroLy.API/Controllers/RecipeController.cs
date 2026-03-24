using BepTroLy.API.Data;
using BepTroLy.API.Models;
using BepTroLy.API.DTOs;
using BepTroLy.API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using System.Text.Json;

namespace BepTroLy.API.Controllers;

[ApiController]
[Route("api/v1/recipes")]
public class RecipeController : ControllerBase
{
    private readonly RecipeSuggestionService _recipeService;
    private readonly AppDbContext _db;

    public RecipeController(RecipeSuggestionService recipeService, AppDbContext db)
    {
        _recipeService = recipeService;
        _db = db;
    }

    /// <summary>Gợi ý món ăn dựa trên nguyên liệu.</summary>
    [HttpPost("suggest")]
    [Authorize]
    [EnableRateLimiting("recipe-heavy")]
    public async Task<IActionResult> SuggestRecipes([FromBody] SuggestRecipesRequest request)
    {
        var result = await _recipeService.SuggestRecipesAsync(
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
    [EnableRateLimiting("recipe-heavy")]
    public async Task<IActionResult> SuggestFromPantry([FromBody] SuggestFromPantryRequest request)
    {
        var userId = GetCurrentUserId();
        if (userId == null) return Unauthorized();

        var result = await _recipeService.SuggestFromPantryAsync(
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
    [EnableRateLimiting("recipe-heavy")]
    public async Task<IActionResult> SuggestFromPantryGet(
        [FromQuery] int? fridgeId,
        [FromQuery] int limit = 5,
        [FromQuery] string? region = null,
        [FromQuery] string? refreshToken = null,
        [FromQuery] string? excludeRecipeNames = null,
        [FromQuery] string? dietary = null)
    {
        var userId = GetCurrentUserId();
        if (userId == null) return Unauthorized();
        var excludes = ParseExcludeRecipeNames(excludeRecipeNames);
        var preferences = BuildQueryPreferences(dietary);

        var result = await _recipeService.SuggestFromPantryAsync(
            userId.Value,
            fridgeId,
            preferences,
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
    [EnableRateLimiting("recipe-heavy")]
    public async Task<IActionResult> SuggestByRegionGet(
        [FromQuery] string? region,
        [FromQuery] int limit = 5,
        [FromQuery] string? refreshToken = null,
        [FromQuery] string? excludeRecipeNames = null,
        [FromQuery] string? dietary = null)
    {
        var excludes = ParseExcludeRecipeNames(excludeRecipeNames);
        var preferences = BuildQueryPreferences(dietary);
        var result = await _recipeService.SuggestByRegionAsync(
            region,
            preferences,
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
        try
        {
            var log = new ActivityLog
            {
                UserId = userId,
                FridgeId = fridgeId,
                ActivityType = type,
                RelatedRecipeId = recipeId,
                CreatedAt = DateTime.UtcNow,
                ExtraData = JsonSerializer.Serialize(new
                {
                    itemName = itemName,
                    quantity = quantity,
                    unit = unit
                })
            };
            _db.ActivityLogs.Add(log);
            await _db.SaveChangesAsync();

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
        try
        {
            var actor = await _db.Users.FindAsync(actorId);
            var actorName = actor?.DisplayName ?? "Một thành viên";
            
            var members = await _db.FridgeMembers
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
                _db.Notifications.Add(new Notification
                {
                    UserId = memberId,
                    Type = "fridge_activity",
                    Title = title,
                    Body = body,
                    CreatedAt = DateTime.UtcNow,
                    IsRead = false
                });
            }
            await _db.SaveChangesAsync();
        }
        catch (Exception) { /* Ignore */ }
    }

    [Authorize]
    [HttpPost("suggestion-feedback")]
    public async Task<IActionResult> RecordSuggestionFeedback([FromBody] SuggestionFeedbackRequest request)
    {
        var userId = GetCurrentUserId();
        if (userId == null) return Unauthorized();

        var suggestion = await _db.SuggestedRecipes
            .FirstOrDefaultAsync(s => s.UserId == userId && s.RecipeName == request.RecipeName);

        if (suggestion == null)
        {
            // Create a record if it doesn't exist
            suggestion = new SuggestedRecipe
            {
                UserId = userId.Value,
                RecipeName = request.RecipeName,
                SuggestedAt = DateTime.Now,
                RecipeDataJson = "{}"
            };
            _db.SuggestedRecipes.Add(suggestion);
        }

        suggestion.Status = request.Feedback; // "liked", "disliked", "hidden"
        await _db.SaveChangesAsync();

        // If disliked, add to activity log to help future recipe ranking
        if (request.Feedback == "disliked")
        {
            await LogDislikeActivityAsync(userId.Value, request.RecipeName);
        }

        return Ok(new { success = true });
    }

    private async Task LogDislikeActivityAsync(int userId, string recipeName)
    {
        try
        {
            var activity = new ActivityLog
            {
                UserId = userId,
                ActivityType = "dislike_recipe",
                ItemName = recipeName,
                ExtraData = JsonSerializer.Serialize(new { recipeName }),
                CreatedAt = DateTime.Now
            };
            _db.ActivityLogs.Add(activity);
            await _db.SaveChangesAsync();
        }
        catch (Exception) { /* Best effort */ }
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

    private static Dictionary<string, object>? BuildQueryPreferences(string? dietary)
    {
        if (string.IsNullOrWhiteSpace(dietary)) return null;

        var normalized = dietary.Trim().ToLowerInvariant();
        var preferences = new Dictionary<string, object>();
        if (normalized is "vegetarian" or "an_chay" or "ăn chay")
        {
            preferences["dietary_restrictions"] = "Ăn chay";
            preferences["cuisine"] = "Món chay Việt Nam";
            return preferences;
        }

        if (normalized is "weight_loss" or "giam_can" or "giảm cân")
        {
            preferences["dietary_restrictions"] = "Giảm cân";
            preferences["difficulty"] = "easy";
            preferences["cuisine"] = "Món Việt nhẹ bụng, ít dầu mỡ";
            return preferences;
        }

        if (normalized is "eat_clean" or "eat clean")
        {
            preferences["dietary_restrictions"] = "Eat Clean";
            preferences["difficulty"] = "easy";
            preferences["cuisine"] = "Món Việt Eat Clean";
            return preferences;
        }

        preferences["dietary_restrictions"] = dietary.Trim();
        return preferences;
    }
}
