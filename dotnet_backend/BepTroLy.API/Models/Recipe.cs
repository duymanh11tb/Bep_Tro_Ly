using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BepTroLy.API.Models;

[Table("recipes")]
public class Recipe
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    [Column("recipe_id")]
    public int RecipeId { get; set; }

    [Required]
    [MaxLength(255)]
    [Column("title_vi")]
    public string TitleVi { get; set; } = string.Empty;

    [MaxLength(255)]
    [Column("title_en")]
    public string? TitleEn { get; set; }

    [Column("description", TypeName = "text")]
    public string? Description { get; set; }

    [MaxLength(50)]
    [Column("cuisine")]
    public string? Cuisine { get; set; }

    [Column("meal_types", TypeName = "json")]
    public string? MealTypes { get; set; }

    // Enum: 'easy', 'medium', 'hard'
    [Column("difficulty")]
    public string Difficulty { get; set; } = "easy";

    [Column("prep_time")]
    public int? PrepTime { get; set; }

    [Column("cook_time")]
    public int? CookTime { get; set; }

    [Column("total_time")]
    public int? TotalTime { get; set; }

    [Column("servings")]
    public int Servings { get; set; } = 2;

    [MaxLength(500)]
    [Column("main_image_url")]
    public string? MainImageUrl { get; set; }

    [MaxLength(500)]
    [Column("video_url")]
    public string? VideoUrl { get; set; }

    [Column("instructions", TypeName = "json")]
    public string? Instructions { get; set; }

    [Column("calories")]
    public int? Calories { get; set; }

    [Column("protein", TypeName = "decimal(5, 1)")]
    public decimal? Protein { get; set; }

    [Column("carbs", TypeName = "decimal(5, 1)")]
    public decimal? Carbs { get; set; }

    [Column("fat", TypeName = "decimal(5, 1)")]
    public decimal? Fat { get; set; }

    [Column("fiber", TypeName = "decimal(5, 1)")]
    public decimal? Fiber { get; set; }

    [Column("tags", TypeName = "json")]
    public string? Tags { get; set; }

    [Column("is_vegetarian")]
    public bool IsVegetarian { get; set; } = false;

    [Column("is_vegan")]
    public bool IsVegan { get; set; } = false;

    [Column("is_dairy_free")]
    public bool IsDairyFree { get; set; } = false;

    [Column("is_gluten_free")]
    public bool IsGlutenFree { get; set; } = false;

    // Enum: 'api', 'user_generated', 'admin'
    [Column("source")]
    public string Source { get; set; } = "api";

    [MaxLength(50)]
    [Column("source_api")]
    public string? SourceApi { get; set; }

    [Column("author_user_id")]
    public int? AuthorUserId { get; set; }

    [Column("is_public")]
    public bool IsPublic { get; set; } = true;

    [Column("view_count")]
    public int ViewCount { get; set; } = 0;

    [Column("favorite_count")]
    public int FavoriteCount { get; set; } = 0;

    [Column("rating_average", TypeName = "decimal(3, 2)")]
    public decimal RatingAverage { get; set; } = 0.00m;

    [Column("rating_count")]
    public int RatingCount { get; set; } = 0;

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [Column("updated_at")]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    // Navigation properties
    public ICollection<RecipeIngredient> Ingredients { get; set; } = new List<RecipeIngredient>();
    public ICollection<MealPlanItem> MealPlanItems { get; set; } = new List<MealPlanItem>();
    public ICollection<UserFavorite> Favorites { get; set; } = new List<UserFavorite>();
    public ICollection<UserRating> Ratings { get; set; } = new List<UserRating>();
}

[Table("recipe_ingredients")]
public class RecipeIngredient
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    [Column("ingredient_id")]
    public int IngredientId { get; set; }

    [Column("recipe_id")]
    public int RecipeId { get; set; }

    [Required]
    [MaxLength(200)]
    [Column("name_vi")]
    public string NameVi { get; set; } = string.Empty;

    [MaxLength(200)]
    [Column("name_en")]
    public string? NameEn { get; set; }

    [Column("quantity", TypeName = "decimal(10, 2)")]
    public decimal? Quantity { get; set; }

    [MaxLength(20)]
    [Column("unit")]
    public string? Unit { get; set; }

    [Column("is_optional")]
    public bool IsOptional { get; set; } = false;

    [MaxLength(50)]
    [Column("category_code")]
    public string? CategoryCode { get; set; }

    [Column("display_order")]
    public int DisplayOrder { get; set; } = 0;

    [ForeignKey("RecipeId")]
    public Recipe? Recipe { get; set; }
}
