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
    public DbSet<RecipeSuggestionCache> RecipeSuggestionCaches { get; set; }
    public DbSet<Fridge> Fridges { get; set; }
    public DbSet<FridgeMember> FridgeMembers { get; set; }
    public DbSet<ChatMessage> ChatMessages { get; set; }
    public DbSet<ChatMessageRead> ChatMessageReads { get; set; }
    public DbSet<SuggestedRecipe> SuggestedRecipes { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Composite Keys
        modelBuilder.Entity<FridgeMember>()
            .HasKey(fm => new { fm.FridgeId, fm.UserId });

        modelBuilder.Entity<ChatMessageRead>()
            .HasKey(cmr => new { cmr.MessageId, cmr.UserId });

        // Cascade Delete for Fridge
        // When a fridge is deleted, all related members, pantry items, and chat messages are also deleted
        modelBuilder.Entity<FridgeMember>()
            .HasOne(fm => fm.Fridge)
            .WithMany(f => f.Members)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<PantryItem>()
            .HasOne(pi => pi.Fridge)
            .WithMany(f => f.PantryItems)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<ChatMessage>()
            .HasOne(cm => cm.Fridge)
            .WithMany()
            .OnDelete(DeleteBehavior.Cascade);
    }
}
