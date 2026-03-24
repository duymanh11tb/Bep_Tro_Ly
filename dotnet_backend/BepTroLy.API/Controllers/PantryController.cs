using BepTroLy.API.Data;
using BepTroLy.API.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace BepTroLy.API.Controllers;

[ApiController]
[Route("api/v1/pantry")]
[Authorize]
public class PantryController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly ILogger<PantryController> _logger;
    private readonly IWebHostEnvironment _env;

    public PantryController(AppDbContext db, ILogger<PantryController> logger, IWebHostEnvironment env)
    {
        _db = db;
        _logger = logger;
        _env = env;
    }

    private int GetUserId()
    {
        var claim = User.FindFirst(ClaimTypes.NameIdentifier)
                 ?? User.FindFirst("sub")
                 ?? User.FindFirst("user_id");
        return int.TryParse(claim?.Value, out var id) ? id : 0;
    }

    private async Task<bool> UserHasAccessToFridge(int userId, int fridgeId)
    {
        return await _db.FridgeMembers.AnyAsync(fm => fm.FridgeId == fridgeId && fm.UserId == userId && fm.Status == "accepted");
    }

    private async Task LogActivity(int userId, int? fridgeId, string type, string itemName, decimal quantity, string unit, int? itemId = null)
    {
        try
        {
            var log = new ActivityLog
            {
                UserId = userId,
                FridgeId = fridgeId,
                ActivityType = type,
                RelatedItemId = itemId,
                CreatedAt = DateTime.UtcNow,
                ExtraData = System.Text.Json.JsonSerializer.Serialize(new
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
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error logging activity");
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
                "add_item" => "đã thêm",
                "use_item" => "đã lấy",
                "discard_item" => "đã bỏ",
                "cook_recipe" => "đã nấu",
                _ => "đã tác động lên"
            };

            string title = "Hoạt động tủ lạnh";
            string body = (type == "cook_recipe") 
                ? $"{actorName} đã nấu món {itemName}"
                : $"{actorName} {action} {quantity} {unit} {itemName}";

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

    // GET /api/pantry - Lấy tất cả sản phẩm
    [HttpGet]
    public async Task<IActionResult> GetItems([FromQuery] string? status = "active", [FromQuery] int? fridgeId = null)
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        var query = _db.PantryItems.AsQueryable();

        if (fridgeId.HasValue)
        {
            if (!await UserHasAccessToFridge(userId, fridgeId.Value)) return Forbid();
            query = query.Where(p => p.FridgeId == fridgeId.Value);
        }
        else
        {
            query = query.Where(p => p.UserId == userId && p.FridgeId == null);
        }

        if (!string.IsNullOrEmpty(status))
            query = query.Where(p => p.Status == status);

        var items = await query
            .Include(p => p.Category)
            .OrderByDescending(p => p.CreatedAt)
            .Select(p => new
            {
                id = p.ItemId,
                name = p.NameVi,
                name_en = p.NameEn,
                quantity = p.Quantity,
                unit = p.Unit,
                category = p.Category != null ? p.Category.NameVi : "Khác",
                category_id = p.CategoryId,
                location = p.Location,
                purchase_date = p.PurchaseDate,
                expiry_date = p.ExpiryDate,
                image_url = p.ImageUrl,
                notes = p.Notes,
                status = p.Status,
                add_method = p.AddMethod,
                created_at = p.CreatedAt,
            })
            .ToListAsync();

        return Ok(items);
    }

    // GET /api/pantry/expiring?days=3 - Lấy sản phẩm sắp hết hạn
    [HttpGet("expiring")]
    public async Task<IActionResult> GetExpiringItems([FromQuery] int days = 3, [FromQuery] int? fridgeId = null)
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var expiryLimit = today.AddDays(days);

        var query = _db.PantryItems.AsQueryable();

        if (fridgeId.HasValue)
        {
            if (!await UserHasAccessToFridge(userId, fridgeId.Value)) return Forbid();
            query = query.Where(p => p.FridgeId == fridgeId.Value);
        }
        else
        {
            query = query.Where(p => p.UserId == userId && p.FridgeId == null);
        }

        var items = await query
            .Where(p => p.Status == "active"
                     && p.ExpiryDate.HasValue
                     && p.ExpiryDate.Value <= expiryLimit)
            .Include(p => p.Category)
            .OrderBy(p => p.ExpiryDate)
            .Select(p => new
            {
                id = p.ItemId,
                name = p.NameVi,
                quantity = p.Quantity,
                unit = p.Unit,
                category = p.Category != null ? p.Category.NameVi : "Khác",
                expiry_date = p.ExpiryDate,
                image_url = p.ImageUrl,
                status = p.Status,
            })
            .ToListAsync();

        return Ok(items);
    }

    // GET /api/pantry/stats - Dashboard stats
    [HttpGet("stats")]
    public async Task<IActionResult> GetStats([FromQuery] int? fridgeId = null)
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var expiryLimit = today.AddDays(3);

        var query = _db.PantryItems.AsQueryable();

        if (fridgeId.HasValue)
        {
            if (!await UserHasAccessToFridge(userId, fridgeId.Value)) return Forbid();
            query = query.Where(p => p.FridgeId == fridgeId.Value);
        }
        else
        {
            query = query.Where(p => p.UserId == userId && p.FridgeId == null);
        }

        var items = await query
            .Where(p => p.Status == "active")
            .Include(p => p.Category)
            .ToListAsync();

        var totalItems = items.Count;
        var expiringCount = items.Count(p => p.ExpiryDate.HasValue && p.ExpiryDate.Value <= expiryLimit);

        // Group by category
        var byCategory = items
            .GroupBy(p => p.Category?.NameVi ?? "Khác")
            .Select(g => new { category = g.Key, count = g.Count() })
            .OrderByDescending(g => g.count)
            .ToList();

        return Ok(new
        {
            total_items = totalItems,
            expiring_soon = expiringCount,
            by_category = byCategory,
        });
    }

    // POST /api/pantry - Thêm sản phẩm
    [HttpPost]
    public async Task<IActionResult> AddItem([FromBody] PantryItemRequest request)
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        if (string.IsNullOrWhiteSpace(request.NameVi))
            return BadRequest(new { error = "Tên sản phẩm là bắt buộc" });

        if (request.FridgeId.HasValue)
        {
            if (!await UserHasAccessToFridge(userId, request.FridgeId.Value))
                return BadRequest(new { error = "Bạn không có quyền truy cập tủ lạnh này" });
        }

        var item = new PantryItem
        {
            UserId = userId,
            FridgeId = request.FridgeId,
            NameVi = request.NameVi.Trim(),
            NameEn = request.NameEn,
            Quantity = request.Quantity > 0 ? request.Quantity : 1,
            Unit = string.IsNullOrWhiteSpace(request.Unit) ? "cái" : request.Unit,
            CategoryId = request.CategoryId,
            Location = request.Location ?? "fridge",
            PurchaseDate = request.PurchaseDate,
            ExpiryDate = request.ExpiryDate,
            Barcode = string.IsNullOrWhiteSpace(request.Barcode) ? null : request.Barcode.Trim(),
            ImageUrl = request.ImageUrl,
            Notes = request.Notes,
            AddMethod = string.IsNullOrWhiteSpace(request.AddMethod) ? "manual" : request.AddMethod.Trim(),
            Status = "active",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
        };

        _db.PantryItems.Add(item);
        await _db.SaveChangesAsync();

        // Log Activity
        await LogActivity(userId, item.FridgeId, "add_item", item.NameVi, item.Quantity, item.Unit, item.ItemId);

        return Ok(new
        {
            message = "Thêm sản phẩm thành công",
            id = item.ItemId,
        });
    }

    // POST /api/pantry/image - Upload ảnh sản phẩm
    [HttpPost("image")]
    public async Task<IActionResult> UploadPantryImage(IFormFile image)
    {
        if (image == null || image.Length == 0)
            return BadRequest(new { error = "Vui lòng chọn ảnh sản phẩm" });

        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        try
        {
            var webRoot = _env.WebRootPath ?? Path.Combine(_env.ContentRootPath, "wwwroot");
            var uploadsDir = Path.Combine(webRoot, "uploads", "pantry");
            if (!Directory.Exists(uploadsDir)) Directory.CreateDirectory(uploadsDir);

            var safeExtension = Path.GetExtension(image.FileName);
            if (string.IsNullOrWhiteSpace(safeExtension))
            {
                safeExtension = ".jpg";
            }

            var fileName = $"{userId}_{DateTime.UtcNow.Ticks}{safeExtension}";
            var filePath = Path.Combine(uploadsDir, fileName);

            await using (var stream = new FileStream(filePath, FileMode.Create))
            {
                await image.CopyToAsync(stream);
            }

            var imageUrl = $"/uploads/pantry/{fileName}";
            return Ok(new
            {
                message = "Tải ảnh sản phẩm thành công",
                image_url = imageUrl,
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error uploading pantry image for user {UserId}", userId);
            return StatusCode(500, new { error = "Lỗi hệ thống khi tải ảnh sản phẩm" });
        }
    }

    // PUT /api/pantry/{id} - Cập nhật sản phẩm
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateItem(int id, [FromBody] PantryItemRequest request)
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        var item = await _db.PantryItems.FirstOrDefaultAsync(p => p.ItemId == id);
        if (item == null) return NotFound(new { error = "Không tìm thấy sản phẩm" });

        if (item.UserId != userId && (!item.FridgeId.HasValue || !await UserHasAccessToFridge(userId, item.FridgeId.Value)))
            return Forbid();

        decimal oldQty = item.Quantity;
        string oldStatus = item.Status;

        if (!string.IsNullOrWhiteSpace(request.NameVi)) item.NameVi = request.NameVi.Trim();
        if (request.NameEn != null) item.NameEn = request.NameEn;
        if (request.Quantity > 0) item.Quantity = request.Quantity;
        if (!string.IsNullOrWhiteSpace(request.Unit)) item.Unit = request.Unit;
        if (request.CategoryId.HasValue) item.CategoryId = request.CategoryId;
        if (request.FridgeId.HasValue)
        {
             if (!await UserHasAccessToFridge(userId, request.FridgeId.Value))
                return BadRequest(new { error = "Bạn không có quyền chuyển vào tủ lạnh này" });
             item.FridgeId = request.FridgeId;
        }
        if (request.Location != null) item.Location = request.Location;
        if (request.ExpiryDate.HasValue) item.ExpiryDate = request.ExpiryDate;
        if (request.ImageUrl != null) item.ImageUrl = request.ImageUrl;
        if (request.Notes != null) item.Notes = request.Notes;
        if (request.Status != null) item.Status = request.Status;

        item.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        // Log Activity
        if (item.Status == "deleted" && oldStatus != "deleted")
        {
            await LogActivity(userId, item.FridgeId, "discard_item", item.NameVi, item.Quantity, item.Unit, item.ItemId);
        }
        else if (item.Quantity != oldQty)
        {
            string logType = item.Quantity < oldQty ? "use_item" : "add_item";
            decimal diff = Math.Abs(item.Quantity - oldQty);
            await LogActivity(userId, item.FridgeId, logType, item.NameVi, diff, item.Unit, item.ItemId);
        }

        return Ok(new { message = "Cập nhật thành công" });
    }

    // POST /api/pantry/cleanup-expired - Tự động chuyển SP hết hạn sang trạng thái "expired"
    [HttpPost("cleanup-expired")]
    public async Task<IActionResult> CleanupExpired([FromQuery] int? fridgeId = null)
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        var today = DateOnly.FromDateTime(DateTime.UtcNow);

        var query = _db.PantryItems.AsQueryable();

        if (fridgeId.HasValue)
        {
            if (!await UserHasAccessToFridge(userId, fridgeId.Value)) return Forbid();
            query = query.Where(p => p.FridgeId == fridgeId.Value);
        }
        else
        {
            // Cleanup across all fridges the user has access to
            var userFridgeIds = await _db.FridgeMembers
                .Where(fm => fm.UserId == userId && fm.Status == "accepted")
                .Select(fm => fm.FridgeId)
                .ToListAsync();

            query = query.Where(p => p.UserId == userId || (p.FridgeId.HasValue && userFridgeIds.Contains(p.FridgeId.Value)));
        }

        var expiredItems = await query
            .Where(p => p.Status == "active"
                     && p.ExpiryDate.HasValue
                     && p.ExpiryDate.Value < today)
            .ToListAsync();

        if (!expiredItems.Any())
        {
            return Ok(new { cleaned_count = 0, items = new List<object>() });
        }

        var cleanedNames = new List<string>();
        foreach (var item in expiredItems)
        {
            item.Status = "expired";
            item.UpdatedAt = DateTime.UtcNow;
            cleanedNames.Add(item.NameVi);
        }

        await _db.SaveChangesAsync();

        return Ok(new
        {
            cleaned_count = expiredItems.Count,
            items = cleanedNames,
        });
    }

    // DELETE /api/pantry/{id} - Xóa sản phẩm
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteItem(int id)
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        var item = await _db.PantryItems.FirstOrDefaultAsync(p => p.ItemId == id);
        if (item == null) return NotFound(new { error = "Không tìm thấy sản phẩm" });

        if (item.UserId != userId && (!item.FridgeId.HasValue || !await UserHasAccessToFridge(userId, item.FridgeId.Value)))
            return Forbid();

        item.Status = "deleted";
        item.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        // Log Activity
        await LogActivity(userId, item.FridgeId, "discard_item", item.NameVi, item.Quantity, item.Unit, item.ItemId);

        return Ok(new { message = "Đã xóa sản phẩm" });
    }
}

// DTO
public class PantryItemRequest
{
    public string NameVi { get; set; } = string.Empty;
    public string? NameEn { get; set; }
    public decimal Quantity { get; set; } = 1;
    public string Unit { get; set; } = "cái";
    public int? CategoryId { get; set; }
    public int? FridgeId { get; set; }
    public string? Location { get; set; }
    public DateOnly? PurchaseDate { get; set; }
    public DateOnly? ExpiryDate { get; set; }
    public string? Barcode { get; set; }
    public string? ImageUrl { get; set; }
    public string? Notes { get; set; }
    public string? AddMethod { get; set; }
    public string? Status { get; set; }
}
