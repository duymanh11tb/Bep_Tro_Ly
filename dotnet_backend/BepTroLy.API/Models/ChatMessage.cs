using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BepTroLy.API.Models;

[Table("chat_messages")]
public class ChatMessage
{
    [Key]
    [Column("message_id")]
    public int MessageId { get; set; }

    [Required]
    [Column("fridge_id")]
    public int FridgeId { get; set; }

    [Required]
    [Column("user_id")]
    public int UserId { get; set; }

    [Required]
    [Column("content")]
    public string Content { get; set; } = string.Empty;

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // Navigation properties
    [ForeignKey("FridgeId")]
    public virtual Fridge? Fridge { get; set; }

    [ForeignKey("UserId")]
    public virtual User? User { get; set; }
}
