using BepTroLy.API.Data;
using BepTroLy.API.DTOs;
using BepTroLy.API.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace BepTroLy.API.Controllers;

[ApiController]
[Route("api/notifications")]
[Authorize]
public class NotificationController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly ILogger<NotificationController> _logger;

    public NotificationController(AppDbContext db, ILogger<NotificationController> logger)
    {
        _db = db;
        _logger = logger;
    }

    private int GetUserId()
    {
        var claim = User.FindFirst(ClaimTypes.NameIdentifier)
                 ?? User.FindFirst("sub")
                 ?? User.FindFirst("user_id");
        return int.TryParse(claim?.Value, out var id) ? id : 0;
    }

    [HttpGet]
    public async Task<IActionResult> GetNotifications()
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        var notifications = await _db.Notifications
            .Where(n => n.UserId == userId)
            .OrderByDescending(n => n.CreatedAt)
            .Select(n => new NotificationDto
            {
                NotificationId = n.NotificationId,
                Type = n.Type,
                Title = n.Title,
                Body = n.Body,
                RelatedItemId = n.RelatedItemId,
                IsRead = n.IsRead,
                CreatedAt = n.CreatedAt
            })
            .ToListAsync();

        return Ok(notifications);
    }

    [HttpPut("{id}/read")]
    public async Task<IActionResult> MarkAsRead(int id)
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        var notification = await _db.Notifications.FirstOrDefaultAsync(n => n.NotificationId == id && n.UserId == userId);
        if (notification == null) return NotFound();

        notification.IsRead = true;
        notification.ReadAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        return Ok(new { message = "Đã đánh dấu là đã đọc" });
    }

    [HttpPost("{id}/respond")]
    public async Task<IActionResult> RespondToInvitation(int id, [FromBody] RespondToInvitationRequest request)
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        var notification = await _db.Notifications.FirstOrDefaultAsync(n => n.NotificationId == id && n.UserId == userId);
        if (notification == null) return NotFound();

        if (notification.Type != "fridge_invitation")
        {
            return BadRequest(new { error = "Thông báo này không phải là lời mời tham gia tủ lạnh" });
        }

        var fridgeId = notification.RelatedItemId ?? 0;
        var member = await _db.FridgeMembers.FirstOrDefaultAsync(fm => fm.FridgeId == fridgeId && fm.UserId == userId);

        if (member == null) return NotFound(new { error = "Không tìm thấy thông tin thành viên" });

        if (request.Accept)
        {
            member.Status = "accepted";
            member.JoinedAt = DateTime.UtcNow;
        }
        else
        {
            _db.FridgeMembers.Remove(member);
        }

        // Mark notification as read anyway
        notification.IsRead = true;
        notification.ReadAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();

        return Ok(new { message = request.Accept ? "Đã chấp nhận lời mời" : "Đã từ chối lời mời" });
    }
}
