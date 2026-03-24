using System.Security.Claims;
using System.Text.Json.Serialization;
using BepTroLy.API.Data;
using BepTroLy.API.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace BepTroLy.API.Controllers;

[ApiController]
[Route("api/v1/shopping")]
[Authorize]
public class ShoppingController : ControllerBase
{
    private readonly AppDbContext _db;

    public ShoppingController(AppDbContext db)
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

    private async Task<ShoppingList> GetOrCreateActiveListAsync(int userId)
    {
        var list = await _db.ShoppingLists
            .Include(l => l.Items)
            .Where(l => l.UserId == userId && l.Status == "active")
            .OrderByDescending(l => l.UpdatedAt)
            .FirstOrDefaultAsync();

        if (list != null) return list;

        list = new ShoppingList
        {
            UserId = userId,
            Title = "Danh sach mua sam",
            Status = "active",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
        };

        _db.ShoppingLists.Add(list);
        await _db.SaveChangesAsync();

        return await _db.ShoppingLists
            .Include(l => l.Items)
            .FirstAsync(l => l.ListId == list.ListId);
    }

    // GET /api/shopping/current
    [HttpGet("current")]
    public async Task<IActionResult> GetCurrentShoppingList()
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        var list = await GetOrCreateActiveListAsync(userId);

        var purchasedItems = list.Items.Count(i => i.IsPurchased);
        var totalItems = list.Items.Count;
        if (list.PurchasedItems != purchasedItems || list.TotalItems != totalItems)
        {
            list.PurchasedItems = purchasedItems;
            list.TotalItems = totalItems;
            list.UpdatedAt = DateTime.UtcNow;
            await _db.SaveChangesAsync();
        }

        return Ok(new
        {
            list_id = list.ListId,
            title = list.Title,
            status = list.Status,
            total_items = list.TotalItems,
            purchased_items = list.PurchasedItems,
            updated_at = list.UpdatedAt,
            items = list.Items
                .OrderBy(i => i.IsPurchased)
                .ThenBy(i => i.NameVi)
                .Select(i => new
                {
                    item_id = i.ItemId,
                    list_id = i.ListId,
                    name_vi = i.NameVi,
                    name_en = i.NameEn,
                    quantity = i.Quantity,
                    unit = i.Unit,
                    category_code = i.CategoryCode,
                    is_purchased = i.IsPurchased,
                    purchased_at = i.PurchasedAt,
                    from_recipe_id = i.FromRecipeId,
                    from_recipe_title = i.FromRecipeTitle,
                    estimated_price = i.EstimatedPrice,
                    actual_price = i.ActualPrice,
                    notes = i.Notes,
                    created_at = i.CreatedAt,
                })
                .ToList(),
        });
    }

    // POST /api/shopping/items
    [HttpPost("items")]
    public async Task<IActionResult> AddItem([FromBody] AddShoppingItemRequest request)
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        if (string.IsNullOrWhiteSpace(request.NameVi))
            return BadRequest(new { error = "Ten san pham la bat buoc" });

        var list = await GetOrCreateActiveListAsync(userId);

        var item = new ShoppingListItem
        {
            ListId = list.ListId,
            NameVi = request.NameVi.Trim(),
            NameEn = string.IsNullOrWhiteSpace(request.NameEn) ? null : request.NameEn.Trim(),
            Quantity = request.Quantity,
            Unit = string.IsNullOrWhiteSpace(request.Unit) ? null : request.Unit.Trim(),
            CategoryCode = string.IsNullOrWhiteSpace(request.CategoryCode) ? null : request.CategoryCode.Trim(),
            IsPurchased = request.IsPurchased ?? false,
            PurchasedAt = (request.IsPurchased ?? false) ? DateTime.UtcNow : null,
            FromRecipeId = request.FromRecipeId,
            FromRecipeTitle = string.IsNullOrWhiteSpace(request.FromRecipeTitle) ? null : request.FromRecipeTitle.Trim(),
            EstimatedPrice = request.EstimatedPrice,
            ActualPrice = request.ActualPrice,
            Notes = string.IsNullOrWhiteSpace(request.Notes) ? null : request.Notes.Trim(),
            CreatedAt = DateTime.UtcNow,
        };

        _db.ShoppingListItems.Add(item);
        await _db.SaveChangesAsync();

        list.TotalItems = await _db.ShoppingListItems.CountAsync(i => i.ListId == list.ListId);
        list.PurchasedItems = await _db.ShoppingListItems.CountAsync(i => i.ListId == list.ListId && i.IsPurchased);
        list.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        return Ok(new
        {
            message = "Them item thanh cong",
            item_id = item.ItemId,
            list_id = list.ListId,
            total_items = list.TotalItems,
            purchased_items = list.PurchasedItems,
        });
    }

    // PUT /api/shopping/items/{itemId}/purchase
    // PUT /api/shopping/items/{itemId}/toggle (backward compatibility)
    [HttpPut("items/{itemId}/purchase")]
    [HttpPut("items/{itemId}/toggle")]
    public async Task<IActionResult> UpdatePurchaseState(int itemId, [FromBody] PurchaseStateRequest? request)
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        var item = await _db.ShoppingListItems
            .Include(i => i.ShoppingList)
            .FirstOrDefaultAsync(i => i.ItemId == itemId && i.ShoppingList != null && i.ShoppingList.UserId == userId);

        if (item == null) return NotFound(new { error = "Khong tim thay shopping item" });

        var nextState = request?.IsPurchased ?? !item.IsPurchased;
        item.IsPurchased = nextState;
        item.PurchasedAt = nextState ? DateTime.UtcNow : null;

        var list = item.ShoppingList!;
        list.PurchasedItems = list.Items.Count(i => i.IsPurchased);
        list.TotalItems = list.Items.Count;
        list.UpdatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();

        return Ok(new
        {
            message = "Cap nhat trang thai thanh cong",
            item_id = item.ItemId,
            is_purchased = item.IsPurchased,
            purchased_at = item.PurchasedAt,
            list_id = list.ListId,
            purchased_items = list.PurchasedItems,
            total_items = list.TotalItems,
        });
    }
}

public class PurchaseStateRequest
{
    [JsonPropertyName("is_purchased")]
    public bool? IsPurchased { get; set; }

    // Backward compatibility: some clients send camelCase body.
    [JsonPropertyName("isPurchased")]
    public bool? IsPurchasedCamel
    {
        get => IsPurchased;
        set
        {
            if (!IsPurchased.HasValue)
                IsPurchased = value;
        }
    }
}

public class AddShoppingItemRequest
{
    public string NameVi { get; set; } = string.Empty;
    public string? NameEn { get; set; }
    public decimal? Quantity { get; set; }
    public string? Unit { get; set; }
    public string? CategoryCode { get; set; }
    public bool? IsPurchased { get; set; }
    public int? FromRecipeId { get; set; }
    public string? FromRecipeTitle { get; set; }
    public decimal? EstimatedPrice { get; set; }
    public decimal? ActualPrice { get; set; }
    public string? Notes { get; set; }
}
