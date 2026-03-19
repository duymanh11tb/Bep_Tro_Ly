using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BepTroLy.API.Models;

[Table("fridges")]
public class Fridge
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    [Column("fridge_id")]
    public int FridgeId { get; set; }

    [Required]
    [MaxLength(100)]
    [Column("name")]
    public string Name { get; set; } = string.Empty;

    [MaxLength(255)]
    [Column("location")]
    public string? Location { get; set; }

    [Column("owner_id")]
    public int OwnerId { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [Column("updated_at")]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    [MaxLength(20)]
    [Column("status")]
    public string Status { get; set; } = "active";

    // Navigation properties
    [ForeignKey("OwnerId")]
    public User? Owner { get; set; }

    public ICollection<FridgeMember> Members { get; set; } = new List<FridgeMember>();
    public ICollection<PantryItem> PantryItems { get; set; } = new List<PantryItem>();
}
