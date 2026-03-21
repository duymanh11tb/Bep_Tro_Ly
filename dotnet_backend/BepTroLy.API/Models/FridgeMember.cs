using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BepTroLy.API.Models;

[Table("fridge_members")]
public class FridgeMember
{
    [Column("fridge_id")]
    public int FridgeId { get; set; }

    [Column("user_id")]
    public int UserId { get; set; }

    // Roles: 'owner', 'member'
    [Required]
    [MaxLength(20)]
    [Column("role")]
    public string Role { get; set; } = "member";

    // Status: 'pending', 'accepted'
    [Required]
    [MaxLength(20)]
    [Column("status")]
    public string Status { get; set; } = "accepted";

    [Column("invited_at")]
    public DateTime InvitedAt { get; set; } = DateTime.UtcNow;

    [Column("joined_at")]
    public DateTime? JoinedAt { get; set; }

    // Navigation properties
    [ForeignKey("FridgeId")]
    public Fridge? Fridge { get; set; }

    [ForeignKey("UserId")]
    public User? User { get; set; }
}
