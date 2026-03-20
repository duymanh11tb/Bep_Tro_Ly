using BepTroLy.API.Data;
using BepTroLy.API.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace BepTroLy.API.Controllers;

[ApiController]
[Route("api/v1/chat")]
public class ChatController : ControllerBase
{
    private readonly AppDbContext _db;

    public ChatController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet("{fridgeId}")]
    [Authorize]
    public async Task<IActionResult> GetChatHistory(int fridgeId, [FromQuery] int limit = 50)
    {
        var userId = GetCurrentUserId();
        if (userId == null) return Unauthorized();

        // Check if user is member of fridge
        var isMember = await _db.FridgeMembers.AnyAsync(m => m.FridgeId == fridgeId && m.UserId == userId.Value && m.Status == "accepted");
        if (!isMember) return Forbid();

        var messages = await _db.ChatMessages
            .Where(m => m.FridgeId == fridgeId)
            .Include(m => m.User)
            .OrderByDescending(m => m.CreatedAt)
            .Take(limit)
            .Select(m => new {
                message_id = m.MessageId,
                fridge_id = m.FridgeId,
                user_id = m.UserId,
                display_name = m.User != null ? m.User.DisplayName : "Unknown",
                photo_url = m.User != null ? m.User.PhotoUrl : null,
                content = m.Content,
                created_at = m.CreatedAt
            })
            .ToListAsync();

        return Ok(messages.OrderBy(m => m.created_at).ToList());
    }

    [HttpGet("latest")]
    [Authorize]
    public async Task<IActionResult> GetLatestMessages([FromQuery] string fridgeIds)
    {
        var userId = GetCurrentUserId();
        if (userId == null) return Unauthorized();

        if (string.IsNullOrEmpty(fridgeIds)) return Ok(new List<object>());

        var ids = fridgeIds.Split(',').Select(int.Parse).ToList();
        
        var latestMessages = await _db.ChatMessages
            .Where(m => ids.Contains(m.FridgeId))
            .GroupBy(m => m.FridgeId)
            .Select(g => new {
                fridge_id = g.Key,
                latest_message_id = g.Max(m => m.MessageId),
                latest_timestamp = g.Max(m => m.CreatedAt)
            })
            .ToListAsync();

        return Ok(latestMessages);
    }

    private int? GetCurrentUserId()
    {
        var claim = User.FindFirst("user_id")?.Value;
        return claim != null ? int.Parse(claim) : null;
    }
}
