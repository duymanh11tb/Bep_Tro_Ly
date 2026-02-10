using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BepTroLy.API.Models;

[Table("categories")]
public class Category
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    [Column("category_id")]
    public int CategoryId { get; set; }

    [Required]
    [MaxLength(50)]
    [Column("category_code")]
    public string CategoryCode { get; set; } = string.Empty;

    [Required]
    [MaxLength(100)]
    [Column("name_vi")]
    public string NameVi { get; set; } = string.Empty;

    [Required]
    [MaxLength(100)]
    [Column("name_en")]
    public string NameEn { get; set; } = string.Empty;

    [MaxLength(10)]
    [Column("icon")]
    public string? Icon { get; set; }

    [MaxLength(7)]
    [Column("color")]
    public string? Color { get; set; }

    [Column("default_fridge_days")]
    public int DefaultFridgeDays { get; set; } = 7;

    [Column("default_freezer_days")]
    public int DefaultFreezerDays { get; set; } = 90;

    [Column("default_pantry_days")]
    public int DefaultPantryDays { get; set; } = 365;

    [Column("sort_order")]
    public int SortOrder { get; set; } = 0;

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // Navigation properties
    public ICollection<PantryItem> PantryItems { get; set; } = new List<PantryItem>();
}
