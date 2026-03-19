using Microsoft.EntityFrameworkCore;
using BepTroLy.API.Models;

namespace BepTroLy.API.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
    {
    }

    public DbSet<User> Users { get; set; }
    public DbSet<Category> Categories { get; set; }
    public DbSet<PantryItem> PantryItems { get; set; }
    public DbSet<Recipe> Recipes { get; set; }
    public DbSet<RecipeIngredient> RecipeIngredients { get; set; }
    public DbSet<MealPlan> MealPlans { get; set; }
    public DbSet<MealPlanItem> MealPlanItems { get; set; }
    public DbSet<ShoppingList> ShoppingLists { get; set; }
    public DbSet<ShoppingListItem> ShoppingListItems { get; set; }
    public DbSet<Notification> Notifications { get; set; }
    public DbSet<ActivityLog> ActivityLogs { get; set; }
    public DbSet<UserFavorite> UserFavorites { get; set; }
    public DbSet<UserRating> UserRatings { get; set; }
    public DbSet<AICache> AICache { get; set; }
    public DbSet<BatchJob> BatchJobs { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Additional configuration if needed (e.g. composite keys, indexes)
        
        // Example: JSON column mapping for User.DietaryRestrictions if we used List<string>
        // Use standard conversion or rely on "json" column type + string property

        // Ensure proper charset/collation for TiDB/MySQL if needed
        // modelBuilder.HasCharSet("utf8mb4");

        // Relationships are already defined via attributes
    }
}
