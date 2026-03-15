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
    public DbSet<VirtualFridge> VirtualFridges { get; set; }
    public DbSet<FridgeMember> FridgeMembers { get; set; }
    public DbSet<Feedback> Feedbacks { get; set; }
    public DbSet<AICache> AICache { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Additional configuration if needed (e.g. composite keys, indexes)
        
        // Example: JSON column mapping for User.DietaryRestrictions if we used List<string>
        // Use standard conversion or rely on "json" column type + string property

        // Ensure proper charset/collation for TiDB/MySQL if needed
        // modelBuilder.HasCharSet("utf8mb4");

        // Relationships and constraints
        modelBuilder.Entity<VirtualFridge>()
            .HasOne(f => f.Owner)
            .WithMany()
            .HasForeignKey(f => f.OwnerId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<FridgeMember>()
            .HasOne(m => m.Fridge)
            .WithMany(f => f.Members)
            .HasForeignKey(m => m.FridgeId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<FridgeMember>()
            .HasOne(m => m.User)
            .WithMany()
            .HasForeignKey(m => m.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<PantryItem>()
            .HasOne(p => p.VirtualFridge)
            .WithMany(f => f.PantryItems)
            .HasForeignKey(p => p.FridgeId)
            .OnDelete(DeleteBehavior.SetNull);
    }
}
