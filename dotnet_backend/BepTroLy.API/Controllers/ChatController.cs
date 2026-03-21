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
            .Select(m => new
            {
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
            .Select(g => new
            {
                fridge_id = g.Key,
                latest_message_id = g.Max(m => m.MessageId),
                latest_timestamp = g.Max(m => m.CreatedAt)
            })
            .ToListAsync();

        return Ok(latestMessages);
    }

    [HttpPost("{fridgeId}/messages/{messageId}/mark-as-read")]
    [Authorize]
    public async Task<IActionResult> MarkMessageAsRead(int fridgeId, int messageId)
    {
        var userId = GetCurrentUserId();
        if (userId == null) return Unauthorized();

        // Check if user is member of fridge
        var isMember = await _db.FridgeMembers.AnyAsync(m => m.FridgeId == fridgeId && m.UserId == userId.Value && m.Status == "accepted");
        if (!isMember) return Forbid();

        // Check if message exists
        var message = await _db.ChatMessages.FirstOrDefaultAsync(m => m.MessageId == messageId && m.FridgeId == fridgeId);
        if (message == null) return NotFound();

        // Check if already marked
        var existing = await _db.ChatMessageReads.FirstOrDefaultAsync(r => r.MessageId == messageId && r.UserId == userId.Value);
        if (existing != null)
            return Ok(new { status = "already_read" });

        // Mark as read
        var readRecord = new ChatMessageRead
        {
            MessageId = messageId,
            UserId = userId.Value,
            ReadAt = DateTime.UtcNow
        };

        _db.ChatMessageReads.Add(readRecord);
        await _db.SaveChangesAsync();

        return Ok(new { status = "marked_as_read" });
    }

    [HttpPost("{fridgeId}/mark-all-as-read")]
    [Authorize]
    public async Task<IActionResult> MarkAllAsRead(int fridgeId, [FromBody] Dictionary<string, int> body)
    {
        var userId = GetCurrentUserId();
        if (userId == null) return Unauthorized();

        // Check if user is member of fridge
        var isMember = await _db.FridgeMembers.AnyAsync(m => m.FridgeId == fridgeId && m.UserId == userId.Value && m.Status == "accepted");
        if (!isMember) return Forbid();

        var lastMessageId = body.ContainsKey("last_message_id") ? body["last_message_id"] : 0;
        if (lastMessageId == 0) return BadRequest(new { error = "last_message_id required" });

        // Get all unread messages up to lastMessageId
        var unreadMessages = await _db.ChatMessages
            .Where(m => m.FridgeId == fridgeId && m.MessageId <= lastMessageId)
            .Select(m => m.MessageId)
            .ToListAsync();

        // Get already read messages
        var alreadyRead = await _db.ChatMessageReads
            .Where(r => r.UserId == userId.Value && unreadMessages.Contains(r.MessageId))
            .Select(r => r.MessageId)
            .ToListAsync();

        // Filter messages to mark
        var toMark = unreadMessages.Except(alreadyRead).ToList();

        // Bulk insert
        foreach (var msgId in toMark)
        {
            _db.ChatMessageReads.Add(new ChatMessageRead
            {
                MessageId = msgId,
                UserId = userId.Value,
                ReadAt = DateTime.UtcNow
            });
        }

        await _db.SaveChangesAsync();

        return Ok(new { status = "marked", count = toMark.Count });
    }

    [HttpPatch("messages/{messageId}")]
    [Authorize]
    public async Task<IActionResult> EditMessage(int messageId, [FromBody] Dictionary<string, string> body)
    {
        var userId = GetCurrentUserId();
        if (userId == null) return Unauthorized();

        if (!body.ContainsKey("content") || string.IsNullOrWhiteSpace(body["content"]))
            return BadRequest(new { error = "content required" });

        var message = await _db.ChatMessages.FirstOrDefaultAsync(m => m.MessageId == messageId);
        if (message == null) return NotFound();

        // Check if user is message owner
        if (message.UserId != userId.Value) return Forbid();

        message.Content = body["content"].Trim();
        message.Status = "sent"; // Mark as edited

        _db.ChatMessages.Update(message);
        await _db.SaveChangesAsync();

        return Ok(new
        {
            message_id = message.MessageId,
            content = message.Content,
            edited_at = DateTime.UtcNow
        });
    }

    [HttpDelete("messages/{messageId}")]
    [Authorize]
    public async Task<IActionResult> DeleteMessage(int messageId)
    {
        var userId = GetCurrentUserId();
        if (userId == null) return Unauthorized();

        var message = await _db.ChatMessages.FirstOrDefaultAsync(m => m.MessageId == messageId);
        if (message == null) return NotFound();

        // Check if user is message owner
        if (message.UserId != userId.Value) return Forbid();

        _db.ChatMessages.Remove(message);
        await _db.SaveChangesAsync();

        return Ok(new { status = "deleted", message_id = messageId });
    }

    private int? GetCurrentUserId()
    {
        var claim = User.FindFirst("user_id")?.Value;
        return claim != null ? int.Parse(claim) : null;
    }
}
