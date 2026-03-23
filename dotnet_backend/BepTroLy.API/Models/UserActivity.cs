using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BepTroLy.API.Models;

[Table("activity_logs")]
public class ActivityLog
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    [Column("log_id")]
    public long LogId { get; set; }

    [Column("user_id")]
    public int UserId { get; set; }

    // Enum: 'view_recipe', 'cook_recipe', 'add_ingredient', 'use_ingredient', 'search'
    [Required]
    [Column("activity_type")]
    public string ActivityType { get; set; } = string.Empty;

    [Column("fridge_id")]
    public int? FridgeId { get; set; }

    [Column("related_recipe_id")]
    public int? RelatedRecipeId { get; set; }

    [Column("related_item_id")]
    public int? RelatedItemId { get; set; }

    [Column("item_name")]
    public string? ItemName { get; set; }

    [Column("extra_data", TypeName = "json")]
    public string? ExtraData { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey("UserId")]
    public User? User { get; set; }
}

[Table("user_favorites")]
public class UserFavorite
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    [Column("favorite_id")]
    public int FavoriteId { get; set; }

    [Column("user_id")]
    public int UserId { get; set; }

    [Column("recipe_id")]
    public int RecipeId { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey("UserId")]
    public User? User { get; set; }

    [ForeignKey("RecipeId")]
    public Recipe? Recipe { get; set; }
}

[Table("user_ratings")]
public class UserRating
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    [Column("rating_id")]
    public int RatingId { get; set; }

    [Column("user_id")]
    public int UserId { get; set; }

    [Column("recipe_id")]
    public int RecipeId { get; set; }

    [Column("rating")]
    public int Rating { get; set; }

    [Column("review", TypeName = "text")]
    public string? Review { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [Column("updated_at")]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey("UserId")]
    public User? User { get; set; }

    [ForeignKey("RecipeId")]
    public Recipe? Recipe { get; set; }
}
