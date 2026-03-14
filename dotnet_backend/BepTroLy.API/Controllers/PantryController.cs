using BepTroLy.API.Data;
using BepTroLy.API.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace BepTroLy.API.Controllers;

[ApiController]
[Route("api/pantry")]
[Authorize]
public class PantryController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly ILogger<PantryController> _logger;

    public PantryController(AppDbContext db, ILogger<PantryController> logger)
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

    // GET /api/pantry - Lấy tất cả sản phẩm
    [HttpGet]
    public async Task<IActionResult> GetItems([FromQuery] string? status = "active")
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        var query = _db.PantryItems
            .Where(p => p.UserId == userId);

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
    public async Task<IActionResult> GetExpiringItems([FromQuery] int days = 3)
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var expiryLimit = today.AddDays(days);

        var items = await _db.PantryItems
            .Where(p => p.UserId == userId
                     && p.Status == "active"
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
    public async Task<IActionResult> GetStats()
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var expiryLimit = today.AddDays(3);

        var items = await _db.PantryItems
            .Where(p => p.UserId == userId && p.Status == "active")
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

        var item = new PantryItem
        {
            UserId = userId,
            NameVi = request.NameVi.Trim(),
            NameEn = request.NameEn,
            Quantity = request.Quantity > 0 ? request.Quantity : 1,
            Unit = string.IsNullOrWhiteSpace(request.Unit) ? "cái" : request.Unit,
            CategoryId = request.CategoryId,
            Location = request.Location ?? "fridge",
            PurchaseDate = request.PurchaseDate,
            ExpiryDate = request.ExpiryDate,
            ImageUrl = request.ImageUrl,
            Notes = request.Notes,
            AddMethod = request.AddMethod ?? "manual",
            Status = "active",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
        };

        _db.PantryItems.Add(item);
        await _db.SaveChangesAsync();

        return Ok(new
        {
            message = "Thêm sản phẩm thành công",
            id = item.ItemId,
        });
    }

    // PUT /api/pantry/{id} - Cập nhật sản phẩm
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateItem(int id, [FromBody] PantryItemRequest request)
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        var item = await _db.PantryItems.FirstOrDefaultAsync(p => p.ItemId == id && p.UserId == userId);
        if (item == null) return NotFound(new { error = "Không tìm thấy sản phẩm" });

        if (!string.IsNullOrWhiteSpace(request.NameVi)) item.NameVi = request.NameVi.Trim();
        if (request.NameEn != null) item.NameEn = request.NameEn;
        if (request.Quantity > 0) item.Quantity = request.Quantity;
        if (!string.IsNullOrWhiteSpace(request.Unit)) item.Unit = request.Unit;
        if (request.CategoryId.HasValue) item.CategoryId = request.CategoryId;
        if (request.Location != null) item.Location = request.Location;
        if (request.ExpiryDate.HasValue) item.ExpiryDate = request.ExpiryDate;
        if (request.ImageUrl != null) item.ImageUrl = request.ImageUrl;
        if (request.Notes != null) item.Notes = request.Notes;
        if (request.Status != null) item.Status = request.Status;

        item.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        return Ok(new { message = "Cập nhật thành công" });
    }

    // DELETE /api/pantry/{id} - Xóa sản phẩm
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteItem(int id)
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        var item = await _db.PantryItems.FirstOrDefaultAsync(p => p.ItemId == id && p.UserId == userId);
        if (item == null) return NotFound(new { error = "Không tìm thấy sản phẩm" });

        item.Status = "deleted";
        item.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

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
    public string? Location { get; set; }
    public DateOnly? PurchaseDate { get; set; }
    public DateOnly? ExpiryDate { get; set; }
    public string? ImageUrl { get; set; }
    public string? Notes { get; set; }
    public string? AddMethod { get; set; }
    public string? Status { get; set; }
}
