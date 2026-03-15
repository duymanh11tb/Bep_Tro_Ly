using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BepTroLy.API.Models;

[Table("virtual_fridges")]
public class VirtualFridge
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    [Column("fridge_id")]
    public int FridgeId { get; set; }

    [Required]
    [MaxLength(100)]
    [Column("name")]
    public string Name { get; set; } = string.Empty;

    [MaxLength(500)]
    [Column("description")]
    public string? Description { get; set; }

    [Column("owner_id")]
    public int OwnerId { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [Column("updated_at")]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    // Navigation properties
    [ForeignKey("OwnerId")]
    public User? Owner { get; set; }

    public ICollection<FridgeMember> Members { get; set; } = new List<FridgeMember>();
    public ICollection<PantryItem> PantryItems { get; set; } = new List<PantryItem>();
}

[Table("fridge_members")]
public class FridgeMember
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    [Column("id")]
    public int Id { get; set; }

    [Column("fridge_id")]
    public int FridgeId { get; set; }

    [Column("user_id")]
    public int UserId { get; set; }

    // Enum: 'owner', 'member'
    [Required]
    [MaxLength(20)]
    [Column("role")]
    public string Role { get; set; } = "member";

    // Enum: 'active', 'invited', 'rejected'
    [Required]
    [MaxLength(20)]
    [Column("status")]
    public string Status { get; set; } = "active";

    [Column("joined_at")]
    public DateTime JoinedAt { get; set; } = DateTime.UtcNow;

    // Navigation properties
    [ForeignKey("FridgeId")]
    public VirtualFridge? Fridge { get; set; }

    [ForeignKey("UserId")]
    public User? User { get; set; }
}
