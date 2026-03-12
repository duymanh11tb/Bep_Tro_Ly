using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BepTroLy.API.Models;

[Table("users")]
public class User
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    [Column("user_id")]
    public int UserId { get; set; }

    [Required]
    [MaxLength(255)]
    [Column("email")]
    public string Email { get; set; } = string.Empty;

    [Required]
    [MaxLength(255)]
    [Column("password_hash")]
    public string PasswordHash { get; set; } = string.Empty;

    [MaxLength(100)]
    [Column("display_name")]
    public string? DisplayName { get; set; }

    [MaxLength(20)]
    [Column("phone_number")]
    public string? PhoneNumber { get; set; }

    [MaxLength(500)]
    [Column("photo_url")]
    public string? PhotoUrl { get; set; }

    // JSON columns - mapped as string for flexibility, or configure value conversion in DbContext
    [Column("dietary_restrictions", TypeName = "json")]
    public string? DietaryRestrictions { get; set; }

    [Column("cuisine_preferences", TypeName = "json")]
    public string? CuisinePreferences { get; set; }

    [Column("allergies", TypeName = "json")]
    public string? Allergies { get; set; }

    // Enum in DB ('beginner', 'intermediate', 'advanced')
    [Column("skill_level")]
    public string SkillLevel { get; set; } = "beginner";

    [Column("notification_enabled")]
    public bool NotificationEnabled { get; set; } = true;

    [Column("notification_time")]
    public TimeSpan? NotificationTime { get; set; }

    [Column("expiry_alert_days")]
    public int ExpiryAlertDays { get; set; } = 2;

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [Column("updated_at")]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    [Column("last_active")]
    public DateTime LastActive { get; set; } = DateTime.UtcNow;

    // Navigation properties
    public ICollection<PantryItem> PantryItems { get; set; } = new List<PantryItem>();
    public ICollection<MealPlan> MealPlans { get; set; } = new List<MealPlan>();
    public ICollection<ShoppingList> ShoppingLists { get; set; } = new List<ShoppingList>();
    public ICollection<Notification> Notifications { get; set; } = new List<Notification>();
    public ICollection<UserFavorite> Favorites { get; set; } = new List<UserFavorite>();
    public ICollection<UserRating> Ratings { get; set; } = new List<UserRating>();
    public ICollection<ActivityLog> ActivityLogs { get; set; } = new List<ActivityLog>();
}
