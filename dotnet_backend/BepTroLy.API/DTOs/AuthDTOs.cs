using System.Text.Json.Serialization;

namespace BepTroLy.API.DTOs;

// ==================== REQUEST DTOs ====================

public class RegisterRequest
{
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string? DisplayName { get; set; }
}

public class LoginRequest
{
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}

public class GoogleLoginRequest
{
    [JsonPropertyName("id_token")]
    public string? IdToken { get; set; }

    [JsonPropertyName("access_token")]
    public string? AccessToken { get; set; }

    // Backward compatibility: some clients send camelCase payload.
    [JsonPropertyName("idToken")]
    public string? IdTokenCamel
    {
        get => IdToken;
        set
        {
            if (string.IsNullOrWhiteSpace(IdToken))
                IdToken = value;
        }
    }

    // Backward compatibility: some clients send camelCase payload.
    [JsonPropertyName("accessToken")]
    public string? AccessTokenCamel
    {
        get => AccessToken;
        set
        {
            if (string.IsNullOrWhiteSpace(AccessToken))
                AccessToken = value;
        }
    }
}

public class UpdateProfileRequest
{
    public string? DisplayName { get; set; }
    public string? PhoneNumber { get; set; }
    public string? PhotoUrl { get; set; }
    public string? SkillLevel { get; set; }
    public string? DietaryRestrictions { get; set; }
    public string? CuisinePreferences { get; set; }
    public string? Allergies { get; set; }
    public bool? NotificationEnabled { get; set; }
}

public class ChangePasswordRequest
{
    public string CurrentPassword { get; set; } = string.Empty;
    public string NewPassword { get; set; } = string.Empty;
}

// ==================== RESPONSE DTOs ====================

public class AuthResponse
{
    public string Message { get; set; } = string.Empty;
    public UserDto? User { get; set; }
    public string? Token { get; set; }
}

public class UserDto
{
    public int UserId { get; set; }
    public string Email { get; set; } = string.Empty;
    public string? DisplayName { get; set; }
    public string? PhotoUrl { get; set; }
    public string? SkillLevel { get; set; }

    // Full profile fields (only included when requested)
    public string? PhoneNumber { get; set; }
    public string? DietaryRestrictions { get; set; }
    public string? CuisinePreferences { get; set; }
    public string? Allergies { get; set; }
    public bool? NotificationEnabled { get; set; }
    public string? CreatedAt { get; set; }
}

public class ErrorResponse
{
    public string Error { get; set; } = string.Empty;
}
