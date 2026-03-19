using BepTroLy.API.Data;
using BepTroLy.API.DTOs;
using BepTroLy.API.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace BepTroLy.API.Controllers;

[ApiController]
[Route("api/fridges")]
[Authorize]
public class FridgeController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly ILogger<FridgeController> _logger;

    public FridgeController(AppDbContext db, ILogger<FridgeController> logger)
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
    public async Task<IActionResult> GetFridges()
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        var fridges = await _db.FridgeMembers
            .Where(fm => fm.UserId == userId)
            .Include(fm => fm.Fridge)
                .ThenInclude(f => f!.Members)
                    .ThenInclude(m => m.User)
            .Select(fm => new FridgeDto
            {
                FridgeId = fm.FridgeId,
                Name = fm.Fridge!.Name,
                Location = fm.Fridge.Location,
                OwnerId = fm.Fridge.OwnerId,
                Status = fm.Fridge.Status,
                CreatedAt = fm.Fridge.CreatedAt,
                Members = fm.Fridge.Members.Select(m => new FridgeMemberDto
                {
                    UserId = m.UserId,
                    DisplayName = m.User!.DisplayName,
                    Email = m.User.Email,
                    PhotoUrl = m.User.PhotoUrl,
                    Role = m.Role,
                    Status = m.Status,
                    InvitedAt = m.InvitedAt,
                    JoinedAt = m.JoinedAt
                }).ToList()
            })
            .ToListAsync();

        return Ok(fridges);
    }

    [HttpPost]
    public async Task<IActionResult> CreateFridge([FromBody] CreateFridgeRequest request)
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        var strategy = _db.Database.CreateExecutionStrategy();
        return await strategy.ExecuteAsync(async () =>
        {
            using var transaction = await _db.Database.BeginTransactionAsync();
            try
            {
                var fridge = new Fridge
                {
                    Name = request.Name,
                    Location = request.Location,
                    OwnerId = userId,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                };

                _db.Fridges.Add(fridge);
                await _db.SaveChangesAsync(); // Get ID

                var member = new FridgeMember
                {
                    FridgeId = fridge.FridgeId,
                    UserId = userId,
                    Role = "owner",
                    Status = "accepted",
                    InvitedAt = DateTime.UtcNow,
                    JoinedAt = DateTime.UtcNow
                };

                _db.FridgeMembers.Add(member);
                await _db.SaveChangesAsync();

                await transaction.CommitAsync();

                return StatusCode(201, new FridgeDto
                {
                    FridgeId = fridge.FridgeId,
                    Name = fridge.Name,
                    Location = fridge.Location,
                    OwnerId = fridge.OwnerId,
                    Status = fridge.Status,
                    CreatedAt = fridge.CreatedAt
                });
            }
            catch (Exception ex)
            {
                await transaction.RollbackAsync();
                _logger.LogError(ex, "Error creating fridge");
                var innerMsg = ex.InnerException?.Message ?? "None";
                return StatusCode(500, new { error = $"Lỗi khi tạo tủ lạnh: {ex.Message}. Chi tiết: {innerMsg}" });
            }
        });
    }

    [HttpPost("{id}/members")]
    public async Task<IActionResult> InviteMember(int id, [FromBody] InviteMemberRequest request)
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        // Check if user is owner of fridge
        var isOwner = await _db.FridgeMembers.AnyAsync(fm => fm.FridgeId == id && fm.UserId == userId && fm.Role == "owner");
        if (!isOwner) return Forbid();

        var targetUser = await _db.Users.FirstOrDefaultAsync(u => u.Email == request.Identifier || u.PhoneNumber == request.Identifier);
        if (targetUser == null) return NotFound(new { error = "Không tìm thấy người dùng" });

        // Check if already a member
        if (await _db.FridgeMembers.AnyAsync(fm => fm.FridgeId == id && fm.UserId == targetUser.UserId))
        {
            return BadRequest(new { error = "Người dùng đã là thành viên của tủ lạnh này" });
        }

        var fridge = await _db.Fridges.FindAsync(id);
        var inviter = await _db.Users.FindAsync(userId);

        var member = new FridgeMember
        {
            FridgeId = id,
            UserId = targetUser.UserId,
            Role = "member",
            Status = "pending",
            InvitedAt = DateTime.UtcNow
        };

        _db.FridgeMembers.Add(member);

        // Create notification for target user
        var notification = new Notification
        {
            UserId = targetUser.UserId,
            Type = "fridge_invitation",
            Title = "Lời mời tham gia tủ lạnh",
            Body = $"{inviter?.DisplayName ?? "Ai đó"} đã mời bạn tham gia tủ lạnh \"{fridge?.Name ?? "bí ẩn"}\"",
            RelatedItemId = id,
            CreatedAt = DateTime.UtcNow
        };
        _db.Notifications.Add(notification);

        await _db.SaveChangesAsync();
 
         return Ok(new { message = "Đã gửi lời mời thành công" });
     }
 
     [HttpPost("{id}/members/accept")]
     public async Task<IActionResult> AcceptInvitation(int id)
     {
         var userId = GetUserId();
         if (userId == 0) return Unauthorized();
 
         var member = await _db.FridgeMembers.FirstOrDefaultAsync(fm => fm.FridgeId == id && fm.UserId == userId && fm.Status == "pending");
         if (member == null) return NotFound(new { error = "Không tìm thấy lời mời hoặc lời mời đã được xử lý" });
 
         member.Status = "accepted";
         member.JoinedAt = DateTime.UtcNow;
 
         await _db.SaveChangesAsync();
 
         return Ok(new { message = "Đã tham gia tủ lạnh thành công" });
     }
 
     [HttpGet("{id}/members")]
    public async Task<IActionResult> GetMembers(int id)
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        // Check if user has access to fridge
        var hasAccess = await _db.FridgeMembers.AnyAsync(fm => fm.FridgeId == id && fm.UserId == userId);
        if (!hasAccess) return Forbid();

        var members = await _db.FridgeMembers
            .Where(fm => fm.FridgeId == id)
            .Include(fm => fm.User)
            .Select(m => new FridgeMemberDto
            {
                UserId = m.UserId,
                DisplayName = m.User!.DisplayName,
                Email = m.User.Email,
                PhotoUrl = m.User.PhotoUrl,
                Role = m.Role,
                Status = m.Status,
                InvitedAt = m.InvitedAt,
                JoinedAt = m.JoinedAt
            })
            .ToListAsync();

        return Ok(members);
    }

    [HttpDelete("{id}/members/{targetUserId}")]
    public async Task<IActionResult> RemoveMember(int id, int targetUserId)
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        // Only owner can remove members, or user can remove themselves
        var currentMember = await _db.FridgeMembers.FirstOrDefaultAsync(fm => fm.FridgeId == id && fm.UserId == userId);
        if (currentMember == null) return Forbid();

        if (currentMember.Role != "owner" && userId != targetUserId)
        {
            return Forbid();
        }

        var targetMember = await _db.FridgeMembers.FirstOrDefaultAsync(fm => fm.FridgeId == id && fm.UserId == targetUserId);
        if (targetMember == null) return NotFound();

        if (targetMember.Role == "owner" && userId == targetUserId)
        {
             // Owner cannot remove themselves unless they transfer ownership (not implemented yet)
             return BadRequest(new { error = "Chủ tủ không thể tự rời khỏi tủ. Hãy chuyển quyền sở hữu trước." });
        }

        _db.FridgeMembers.Remove(targetMember);
        await _db.SaveChangesAsync();

        return Ok(new { message = "Đã xóa thành viên thành công" });
    }
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateFridge(int id, [FromBody] UpdateFridgeRequest request)
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        var fridge = await _db.Fridges.FirstOrDefaultAsync(f => f.FridgeId == id && f.OwnerId == userId);
        if (fridge == null) return NotFound(new { error = "Không tìm thấy tủ lạnh hoặc bạn không có quyền chỉnh sửa" });

        fridge.Name = request.Name;
        fridge.Location = request.Location;
        if (!string.IsNullOrEmpty(request.Status)) fridge.Status = request.Status;
        fridge.UpdatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();

        return Ok(new
        {
            message = "Cập nhật tủ lạnh thành công",
            fridge = new FridgeDto
            {
                FridgeId = fridge.FridgeId,
                Name = fridge.Name,
                Location = fridge.Location,
                OwnerId = fridge.OwnerId,
                Status = fridge.Status,
                CreatedAt = fridge.CreatedAt
            }
        });
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteFridge(int id)
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        var fridge = await _db.Fridges.FirstOrDefaultAsync(f => f.FridgeId == id && f.OwnerId == userId);
        if (fridge == null) return NotFound(new { error = "Không tìm thấy tủ lạnh hoặc bạn không có quyền xóa" });

        _db.Fridges.Remove(fridge);
        await _db.SaveChangesAsync();

        return Ok(new { message = "Đã xóa tủ lạnh thành công" });
    }
}
