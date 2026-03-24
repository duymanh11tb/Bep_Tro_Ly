using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BepTroLy.API.Models;

[Table("shopping_lists")]
public class ShoppingList
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    [Column("list_id")]
    public int ListId { get; set; }

    [Column("user_id")]
    public int UserId { get; set; }

    [Required]
    [MaxLength(255)]
    [Column("title")]
    public string Title { get; set; } = string.Empty;

    // Enum: 'active', 'completed', 'archived'
    [Column("status")]
    public string Status { get; set; } = "active";

    [Column("total_items")]
    public int TotalItems { get; set; } = 0;

    [Column("purchased_items")]
    public int PurchasedItems { get; set; } = 0;

    [Column("estimated_total", TypeName = "decimal(10, 2)")]
    public decimal EstimatedTotal { get; set; } = 0.00m;

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [Column("updated_at")]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    // Navigation
    [ForeignKey("UserId")]
    public User? User { get; set; }

    public ICollection<ShoppingListItem> Items { get; set; } = new List<ShoppingListItem>();
}

[Table("shopping_list_items")]
public class ShoppingListItem
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    [Column("item_id")]
    public int ItemId { get; set; }

    [Column("list_id")]
    public int ListId { get; set; }

    [Required]
    [MaxLength(200)]
    [Column("name_vi")]
    public string NameVi { get; set; } = string.Empty;

    [MaxLength(200)]
    [Column("name_en")]
    public string? NameEn { get; set; }

    [Column("quantity", TypeName = "decimal(10, 2)")]
    public decimal? Quantity { get; set; }

    [MaxLength(20)]
    [Column("unit")]
    public string? Unit { get; set; }

    [MaxLength(50)]
    [Column("category_code")]
    public string? CategoryCode { get; set; }

    [Column("is_purchased")]
    public bool IsPurchased { get; set; } = false;

    [Column("purchased_at")]
    public DateTime? PurchasedAt { get; set; }

    [Column("from_recipe_id")]
    public int? FromRecipeId { get; set; }

    [MaxLength(255)]
    [Column("from_recipe_title")]
    public string? FromRecipeTitle { get; set; }

    [Column("estimated_price", TypeName = "decimal(10, 2)")]
    public decimal? EstimatedPrice { get; set; }

    [Column("actual_price", TypeName = "decimal(10, 2)")]
    public decimal? ActualPrice { get; set; }

    [Column("notes", TypeName = "text")]
    public string? Notes { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey("ListId")]
    public ShoppingList? ShoppingList { get; set; }
}
