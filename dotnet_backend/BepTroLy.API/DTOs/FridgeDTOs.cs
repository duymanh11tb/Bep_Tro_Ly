using System.ComponentModel.DataAnnotations;

namespace BepTroLy.API.DTOs;

public class FridgeDto
{
    public int FridgeId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Location { get; set; }
    public int OwnerId { get; set; }
    public string Status { get; set; } = "active";
    public DateTime CreatedAt { get; set; }
    public List<FridgeMemberDto> Members { get; set; } = new();
}

public class FridgeMemberDto
{
    public int UserId { get; set; }
    public string? DisplayName { get; set; }
    public string? Email { get; set; }
    public string? PhotoUrl { get; set; }
    public string Role { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public DateTime InvitedAt { get; set; }
    public DateTime? JoinedAt { get; set; }
}

public class CreateFridgeRequest
{
    [Required]
    [MaxLength(100)]
    public string Name { get; set; } = string.Empty;

    [MaxLength(255)]
    public string? Location { get; set; }
}

public class UpdateFridgeRequest
{
    [Required]
    [MaxLength(100)]
    public string Name { get; set; } = string.Empty;

    [MaxLength(255)]
    public string? Location { get; set; }

    [MaxLength(20)]
    public string? Status { get; set; }
}

public class InviteMemberRequest
{
    [Required]
    public string Identifier { get; set; } = string.Empty; // Email or Phone
}
