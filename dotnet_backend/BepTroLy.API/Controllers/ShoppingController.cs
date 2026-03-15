using System.Security.Claims;
using BepTroLy.API.Data;
using BepTroLy.API.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace BepTroLy.API.Controllers;

[ApiController]
[Route("api/shopping")]
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

    // GET /api/shopping/current
    [HttpGet("current")]
    public async Task<IActionResult> GetCurrentShoppingList()
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        var list = await _db.ShoppingLists
            .Include(l => l.Items)
            .Where(l => l.UserId == userId && l.Status == "active")
            .OrderByDescending(l => l.UpdatedAt)
            .FirstOrDefaultAsync();

        if (list == null)
        {
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

            list = await _db.ShoppingLists
                .Include(l => l.Items)
                .FirstAsync(l => l.ListId == list.ListId);
        }

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

    // PUT /api/shopping/items/{itemId}/purchase
    [HttpPut("items/{itemId}/purchase")]
    public async Task<IActionResult> UpdatePurchaseState(int itemId, [FromBody] PurchaseStateRequest request)
    {
        var userId = GetUserId();
        if (userId == 0) return Unauthorized();

        var item = await _db.ShoppingListItems
            .Include(i => i.ShoppingList)
            .FirstOrDefaultAsync(i => i.ItemId == itemId && i.ShoppingList != null && i.ShoppingList.UserId == userId);

        if (item == null) return NotFound(new { error = "Khong tim thay shopping item" });

        var nextState = request.IsPurchased ?? !item.IsPurchased;
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
    public bool? IsPurchased { get; set; }
}
