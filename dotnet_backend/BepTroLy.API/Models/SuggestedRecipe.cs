using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BepTroLy.API.Models;

[Table("suggested_recipes")]
public class SuggestedRecipe
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    [Column("suggestion_id")]
    public long SuggestionId { get; set; }

    [Column("user_id")]
    public int UserId { get; set; }

    [Required]
    [MaxLength(255)]
    [Column("recipe_name")]
    public string RecipeName { get; set; } = string.Empty;

    [Column("recipe_data", TypeName = "json")]
    public string RecipeData { get; set; } = string.Empty;

    [NotMapped]
    public string RecipeDataJson { get => RecipeData; set => RecipeData = value; }

    [Column("suggested_at")]
    public DateTime SuggestedAt { get; set; } = DateTime.UtcNow;

    [NotMapped]
    public DateTime CreatedAt { get => SuggestedAt; set => SuggestedAt = value; }

    // Status: 'suggested', 'cooked', 'liked', 'disliked', 'hidden'
    [Required]
    [MaxLength(20)]
    [Column("status")]
    public string Status { get; set; } = "suggested";

    [Column("context_data", TypeName = "json")]
    public string? ContextData { get; set; }

    [ForeignKey("UserId")]
    public User? User { get; set; }
}
