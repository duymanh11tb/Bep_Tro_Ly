using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BepTroLy.API.Models;

[Table("chat_message_reads")]
public class ChatMessageRead
{
    [Required]
    [Column("message_id")]
    public int MessageId { get; set; }

    [Required]
    [Column("user_id")]
    public int UserId { get; set; }

    [Column("read_at")]
    public DateTime ReadAt { get; set; } = DateTime.UtcNow;

    // Navigation properties
    [ForeignKey("MessageId")]
    public virtual ChatMessage? ChatMessage { get; set; }

    [ForeignKey("UserId")]
    public virtual User? User { get; set; }
}
