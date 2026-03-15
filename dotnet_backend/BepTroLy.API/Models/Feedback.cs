using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BepTroLy.API.Models;

[Table("feedbacks")]
public class Feedback
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    [Column("feedback_id")]
    public int FeedbackId { get; set; }

    [Column("user_id")]
    public int UserId { get; set; }

    [Required]
    [MaxLength(200)]
    [Column("subject")]
    public string Subject { get; set; } = string.Empty;

    [Required]
    [Column("content", TypeName = "text")]
    public string Content { get; set; } = string.Empty;

    // Enum: 'pending', 'processed', 'resolved'
    [Required]
    [MaxLength(20)]
    [Column("status")]
    public string Status { get; set; } = "pending";

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // Navigation properties
    [ForeignKey("UserId")]
    public User? User { get; set; }
}
