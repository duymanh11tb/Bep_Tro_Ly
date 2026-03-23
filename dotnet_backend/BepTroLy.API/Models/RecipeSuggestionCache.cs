using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BepTroLy.API.Models;

[Table("ai_recipe_cache")]
public class RecipeSuggestionCache
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    [Column("cache_id")]
    public int CacheId { get; set; }

    [Required]
    [MaxLength(64)]
    [Column("cache_key")]
    public string CacheKey { get; set; } = string.Empty;

    [Required]
    [Column("response_data", TypeName = "json")]
    public string ResponseData { get; set; } = string.Empty;

    [Column("expires_at")]
    public DateTime ExpiresAt { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
