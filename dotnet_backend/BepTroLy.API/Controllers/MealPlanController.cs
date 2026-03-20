using System.Text.Json;
using BepTroLy.API.Data;
using BepTroLy.API.DTOs;
using BepTroLy.API.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace BepTroLy.API.Controllers;

[ApiController]
[Route("api/v1/meal-plan")]
[Authorize]
public class MealPlanController : ControllerBase
{
    private readonly AppDbContext _db;

    public MealPlanController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet("current")]
    public async Task<IActionResult> GetCurrentPlan()
    {
        var userId = GetCurrentUserId();
        if (userId == null) return Unauthorized();

        var latest = await _db.ActivityLogs
            .Where(l => l.UserId == userId.Value && l.ActivityType == "meal_plan_state")
            .OrderByDescending(l => l.CreatedAt)
            .FirstOrDefaultAsync();

        if (latest == null || string.IsNullOrWhiteSpace(latest.ExtraData))
        {
            return Ok(new
            {
                success = true,
                source = "empty",
                planData = new Dictionary<string, object>()
            });
        }

        try
        {
            using var doc = JsonDocument.Parse(latest.ExtraData);
            var root = doc.RootElement;
            var planData = root.TryGetProperty("plan_data", out var plan)
                ? plan.Clone()
                : default;

            if (planData.ValueKind == JsonValueKind.Undefined)
            {
                return Ok(new
                {
                    success = true,
                    source = "legacy",
                    planData = new Dictionary<string, object>()
                });
            }

            return Ok(new
            {
                success = true,
                source = "server",
                planData
            });
        }
        catch
        {
            return Ok(new
            {
                success = true,
                source = "parse_error",
                planData = new Dictionary<string, object>()
            });
        }
    }

    [HttpPut("current")]
    public async Task<IActionResult> UpsertCurrentPlan([FromBody] UpsertMealPlanRequest request)
    {
        var userId = GetCurrentUserId();
        if (userId == null) return Unauthorized();

        var payload = JsonSerializer.Serialize(new
        {
            plan_data = request.PlanData,
            updated_at = DateTime.UtcNow
        });

        var log = new ActivityLog
        {
            UserId = userId.Value,
            ActivityType = "meal_plan_state",
            ExtraData = payload,
            CreatedAt = DateTime.UtcNow
        };

        _db.ActivityLogs.Add(log);
        await _db.SaveChangesAsync();

        return Ok(new
        {
            success = true,
            message = "Đã lưu lịch ăn uống"
        });
    }

    private int? GetCurrentUserId()
    {
        var claim = User.FindFirst("user_id")?.Value;
        if (claim == null) return null;
        return int.Parse(claim);
    }
}
