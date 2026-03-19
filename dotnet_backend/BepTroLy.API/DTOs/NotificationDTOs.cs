using System.ComponentModel.DataAnnotations;

namespace BepTroLy.API.DTOs;

public class NotificationDto
{
    public int NotificationId { get; set; }
    public string Type { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Body { get; set; } = string.Empty;
    public int? RelatedItemId { get; set; }
    public bool IsRead { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class RespondToInvitationRequest
{
    [Required]
    public bool Accept { get; set; }
}
