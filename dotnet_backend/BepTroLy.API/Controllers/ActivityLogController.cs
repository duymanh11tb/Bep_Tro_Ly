using BepTroLy.API.Data;
using BepTroLy.API.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace BepTroLy.API.Controllers;

[ApiController]
[Route("api/v1/activity")]
[Authorize]
public class ActivityLogController : ControllerBase
{
    private readonly AppDbContext _db;

    public ActivityLogController(AppDbContext db)
    {
        _db = db;
    }

    private int GetUserId()
    {
        var claim = User.FindFirst(ClaimTypes.NameIdentifier)
                 ?? User.FindFirst("sub")
                 ?? User.FindFirst("user_id");
        return int.TryParse(claim?.Value, out var id) ? id : 0;
    }

    [HttpGet]
    public async Task<IActionResult> GetFridgeActivities([FromQuery] int fridgeId, [FromQuery] string type = "all", [FromQuery] int limit = 50)
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        // Check permission
        var isMember = await _db.FridgeMembers.AnyAsync(fm => fm.FridgeId == fridgeId && fm.UserId == userId && fm.Status == "accepted");
        if (!isMember) return Forbid();

        var query = _db.ActivityLogs
            .Where(a => a.FridgeId == fridgeId)
            .Include(a => a.User)
            .AsQueryable();

        if (type != "all")
        {
            query = query.Where(a => a.ActivityType == type);
        }

        var logs = await query
            .OrderByDescending(a => a.CreatedAt)
            .Take(limit)
            .Select(a => new
            {
                log_id = a.LogId,
                user_id = a.UserId,
                user_name = a.User != null ? a.User.DisplayName : "Người dùng",
                user_photo = a.User != null ? a.User.PhotoUrl : null,
                activity_type = a.ActivityType,
                extra_data = a.ExtraData,
                created_at = a.CreatedAt
            })
            .ToListAsync();

        return Ok(logs);
    }
}
