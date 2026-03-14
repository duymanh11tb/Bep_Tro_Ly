using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BepTroLy.API.Models;

[Table("notifications")]
public class Notification
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    [Column("notification_id")]
    public int NotificationId { get; set; }

    [Column("user_id")]
    public int UserId { get; set; }

    // Enum: 'expiry_alert', 'recipe_suggestion', 'system', 'meal_reminder'
    [Column("type")]
    public string Type { get; set; } = "expiry_alert";

    [Required]
    [MaxLength(255)]
    [Column("title")]
    public string Title { get; set; } = string.Empty;

    [Required]
    [Column("body", TypeName = "text")]
    public string Body { get; set; } = string.Empty;

    [Column("related_item_id")]
    public int? RelatedItemId { get; set; }

    [Column("related_recipe_ids", TypeName = "json")]
    public string? RelatedRecipeIds { get; set; }

    [Column("is_read")]
    public bool IsRead { get; set; } = false;

    [Column("is_sent")]
    public bool IsSent { get; set; } = false;

    [Column("sent_at")]
    public DateTime? SentAt { get; set; }

    [Column("read_at")]
    public DateTime? ReadAt { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey("UserId")]
    public User? User { get; set; }
}
