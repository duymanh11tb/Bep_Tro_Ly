using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BepTroLy.API.Models;

[Table("pantry_items")]
public class PantryItem
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    [Column("item_id")]
    public int ItemId { get; set; }

    [Column("user_id")]
    public int UserId { get; set; }

    [Column("category_id")]
    public int? CategoryId { get; set; }

    [Required]
    [MaxLength(200)]
    [Column("name_vi")]
    public string NameVi { get; set; } = string.Empty;

    [MaxLength(200)]
    [Column("name_en")]
    public string? NameEn { get; set; }

    [Column("quantity", TypeName = "decimal(10, 2)")]
    public decimal Quantity { get; set; }

    [Required]
    [MaxLength(20)]
    [Column("unit")]
    public string Unit { get; set; } = string.Empty;

    [Column("purchase_date")]
    public DateOnly? PurchaseDate { get; set; }

    [Column("expiry_date")]
    public DateOnly? ExpiryDate { get; set; }

    // Enum: 'fridge', 'freezer', 'pantry'
    [Column("location")]
    public string Location { get; set; } = "fridge";

    // Enum: 'manual', 'barcode', 'ocr'
    [Column("add_method")]
    public string AddMethod { get; set; } = "manual";

    [MaxLength(50)]
    [Column("barcode")]
    public string? Barcode { get; set; }

    [MaxLength(500)]
    [Column("image_url")]
    public string? ImageUrl { get; set; }

    [Column("notes", TypeName = "text")]
    public string? Notes { get; set; }

    // Enum: 'active', 'used', 'expired', 'deleted'
    [Column("status")]
    public string Status { get; set; } = "active";

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [Column("updated_at")]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    // Navigation properties
    [ForeignKey("UserId")]
    public User? User { get; set; }

    [ForeignKey("CategoryId")]
    public Category? Category { get; set; }
}
