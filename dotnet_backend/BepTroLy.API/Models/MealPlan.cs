using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BepTroLy.API.Models;

[Table("meal_plans")]
public class MealPlan
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    [Column("plan_id")]
    public int PlanId { get; set; }

    [Column("user_id")]
    public int UserId { get; set; }

    [Required]
    [Column("week_start")]
    public DateOnly WeekStart { get; set; }

    [Required]
    [Column("week_end")]
    public DateOnly WeekEnd { get; set; }

    [MaxLength(255)]
    [Column("title")]
    public string Title { get; set; } = "Meal Plan";

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [Column("updated_at")]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    // Navigation properties
    [ForeignKey("UserId")]
    public User? User { get; set; }

    public ICollection<MealPlanItem> Items { get; set; } = new List<MealPlanItem>();
}

[Table("meal_plan_items")]
public class MealPlanItem
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    [Column("item_id")]
    public int ItemId { get; set; }

    [Column("plan_id")]
    public int PlanId { get; set; }

    [Column("recipe_id")]
    public int RecipeId { get; set; }

    [Required]
    [Column("meal_date")]
    public DateOnly MealDate { get; set; }

    // Enum: 'breakfast', 'lunch', 'dinner', 'snack'
    [Required]
    [Column("meal_type")]
    public string MealType { get; set; } = string.Empty;

    [Column("is_cooked")]
    public bool IsCooked { get; set; } = false;

    [Column("cooked_at")]
    public DateTime? CookedAt { get; set; }

    [Column("notes", TypeName = "text")]
    public string? Notes { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // Navigation properties
    [ForeignKey("PlanId")]
    public MealPlan? MealPlan { get; set; }

    [ForeignKey("RecipeId")]
    public Recipe? Recipe { get; set; }
}
