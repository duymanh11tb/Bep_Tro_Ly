using BepTroLy.API.Data;
using BepTroLy.API.DTOs;
using BepTroLy.API.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace BepTroLy.API.Controllers;

[ApiController]
[Route("api/v1/fridges")]
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

    [HttpGet("{id}")]
    public async Task<IActionResult> GetFridge(int id)
    {
        try
        {
            var userId = GetUserId();
            if (userId == 0) return Unauthorized();

            // Check if user has access
            var hasAccess = await _db.FridgeMembers.AnyAsync(fm => fm.FridgeId == id && fm.UserId == userId);
            if (!hasAccess) return Forbid();

            var fridge = await _db.Fridges
                .Include(f => f.Members)
                    .ThenInclude(m => m.User)
                .FirstOrDefaultAsync(f => f.FridgeId == id);

            if (fridge == null) return NotFound(new { error = "Không tìm thấy tủ lạnh" });

            return Ok(new FridgeDto
            {
                FridgeId = fridge.FridgeId,
                Name = fridge.Name,
                Location = fridge.Location,
                OwnerId = fridge.OwnerId,
                Status = fridge.Status,
                CreatedAt = fridge.CreatedAt,
                Members = fridge.Members.Select(m => new FridgeMemberDto
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
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting fridge {FridgeId}", id);
            return StatusCode(500, new { error = $"Lỗi khi lấy thông tin tủ lạnh: {ex.Message}" });
        }
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
        try
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
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error inviting member to fridge {FridgeId}", id);
            return StatusCode(500, new { error = $"Lỗi khi mời thành viên: {ex.Message}" });
        }
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
        try
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
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating fridge {FridgeId}", id);
            return StatusCode(500, new { error = $"Lỗi khi cập nhật tủ lạnh: {ex.Message}" });
        }
    }

    [HttpDelete("{id}")]
    [Authorize]
    public async Task<IActionResult> DeleteFridge(int id)
    {
        try
        {
            var userId = GetUserId();
            if (userId == 0) return Unauthorized();

            var fridge = await _db.Fridges.FirstOrDefaultAsync(f => f.FridgeId == id && f.OwnerId == userId);
            if (fridge == null)
                return NotFound(new { error = "Không tìm thấy tủ lạnh hoặc bạn không có quyền xóa" });

            // Sử dụng Raw SQL Transaction để ép xóa toàn bộ dính dáng đến khóa ngoại (Cascade Delete)
            var strategy = _db.Database.CreateExecutionStrategy();
            await strategy.ExecuteAsync(async () =>
            {
                using var transaction = await _db.Database.BeginTransactionAsync();
                try
                {
                    // 1. Xóa tất cả các lượt đọc tin nhắn thuộc về các tin nhắn trong tủ lạnh này
                    await _db.Database.ExecuteSqlRawAsync(@"
                        DELETE cmr FROM chat_message_reads cmr
                        INNER JOIN chat_messages cm ON cmr.message_id = cm.message_id
                        WHERE cm.fridge_id = {0}", id);

                    // 2. Xóa tất cả tin nhắn chat của tủ lạnh
                    await _db.Database.ExecuteSqlRawAsync("DELETE FROM chat_messages WHERE fridge_id = {0}", id);

                    // 3. Xóa tất cả nguyên liệu trong tủ lạnh
                    await _db.Database.ExecuteSqlRawAsync("DELETE FROM pantry_items WHERE fridge_id = {0}", id);

                    // 4. Xóa tất cả thành viên trong tủ lạnh
                    await _db.Database.ExecuteSqlRawAsync("DELETE FROM fridge_members WHERE fridge_id = {0}", id);

                    // 5. Cuối cùng mới xóa tủ lạnh
                    await _db.Database.ExecuteSqlRawAsync("DELETE FROM fridges WHERE fridge_id = {0}", id);

                    await transaction.CommitAsync();
                }
                catch (Exception)
                {
                    await transaction.RollbackAsync();
                    throw; // Ném lại lỗi ra ngoài block catch bên dưới
                }
            });

            return Ok(new { message = "Đã xóa tủ lạnh thành công" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting fridge {FridgeId}", id);
            var innerMessage = ex.InnerException != null ? ex.InnerException.Message : "";
            return StatusCode(500, new { error = $"Lỗi khi xóa tủ lạnh: {ex.Message} {innerMessage}" });
        }
    }
}
