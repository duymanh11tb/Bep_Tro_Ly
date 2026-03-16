using BepTroLy.API.Data;
using BepTroLy.API.DTOs;
using BepTroLy.API.Models;
using BepTroLy.API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Text.Json;

namespace BepTroLy.API.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly JwtService _jwt;
    private readonly ILogger<AuthController> _logger;

    public AuthController(AppDbContext db, JwtService jwt, ILogger<AuthController> logger)
    {
        _db = db;
        _jwt = jwt;
        _logger = logger;
    }

    /// <summary>Đăng ký tài khoản mới.</summary>
    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Email) || string.IsNullOrWhiteSpace(request.Password))
            return BadRequest(new ErrorResponse { Error = "Email và mật khẩu là bắt buộc" });

        if (request.Password.Length < 6)
            return BadRequest(new ErrorResponse { Error = "Mật khẩu phải có ít nhất 6 ký tự" });

        var email = request.Email.Trim().ToLower();

        if (await _db.Users.AnyAsync(u => u.Email == email))
            return Conflict(new ErrorResponse { Error = "Email đã được sử dụng" });

        try
        {
            var user = new User
            {
                Email = email,
                DisplayName = string.IsNullOrWhiteSpace(request.DisplayName)
                    ? email.Split('@')[0]
                    : request.DisplayName,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password),
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                LastActive = DateTime.UtcNow
            };

            _db.Users.Add(user);
            await _db.SaveChangesAsync();

            return StatusCode(201, new AuthResponse
            {
                Message = "Đăng ký thành công!",
                User = MapUser(user),
                Token = _jwt.GenerateToken(user.UserId)
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Register error for {Email}", request.Email);
            var innerMsg = ex.InnerException?.Message ?? "None";
            return StatusCode(500, new ErrorResponse { Error = $"Lỗi đăng ký hệ thống: {ex.Message}. Chi tiết: {innerMsg}" });
        }
    }

    /// <summary>Đăng nhập bằng Google.</summary>
    [HttpPost("google-login")]
    public async Task<IActionResult> GoogleLogin([FromBody] GoogleLoginRequest request)
    {
        request.IdToken = NormalizeToken(request.IdToken);
        request.AccessToken = NormalizeToken(request.AccessToken);

        if (string.IsNullOrWhiteSpace(request.IdToken) && string.IsNullOrWhiteSpace(request.AccessToken))
            return BadRequest(new ErrorResponse { Error = "IdToken hoặc AccessToken không được để trống" });

        try
        {
            string email;
            string? displayName = null;
            string? photoUrl = null;

            if (!string.IsNullOrWhiteSpace(request.IdToken))
            {
                var config = new ConfigurationBuilder()
                    .SetBasePath(Directory.GetCurrentDirectory())
                    .AddJsonFile("appsettings.json")
                    .AddEnvironmentVariables()
                    .Build();

                var googleClientId = config["GOOGLE_CLIENT_ID"] ?? config["GoogleAuth:ClientId"];

                var payload = await Google.Apis.Auth.GoogleJsonWebSignature.ValidateAsync(request.IdToken, new Google.Apis.Auth.GoogleJsonWebSignature.ValidationSettings
                {
                    Audience = new[] { googleClientId }
                });

                email = payload.Email.Trim().ToLower();
                displayName = payload.Name;
                photoUrl = payload.Picture;
            }
            else
            {
                using var httpClient = new HttpClient();
                using var userInfoRequest = new HttpRequestMessage(HttpMethod.Get, "https://www.googleapis.com/oauth2/v3/userinfo");
                userInfoRequest.Headers.TryAddWithoutValidation("Authorization", $"Bearer {request.AccessToken}");
                using var userInfoResponse = await httpClient.SendAsync(userInfoRequest);

                if (!userInfoResponse.IsSuccessStatusCode)
                {
                    return Unauthorized(new ErrorResponse { Error = "AccessToken Google không hợp lệ hoặc đã hết hạn" });
                }

                await using var responseStream = await userInfoResponse.Content.ReadAsStreamAsync();
                using var userInfoJson = await JsonDocument.ParseAsync(responseStream);
                var root = userInfoJson.RootElement;

                if (!root.TryGetProperty("email", out var emailProperty) || string.IsNullOrWhiteSpace(emailProperty.GetString()))
                {
                    return Unauthorized(new ErrorResponse { Error = "Không lấy được email từ Google" });
                }

                email = emailProperty.GetString()!.Trim().ToLower();
                displayName = root.TryGetProperty("name", out var nameProperty) ? nameProperty.GetString() : null;
                photoUrl = root.TryGetProperty("picture", out var pictureProperty) ? pictureProperty.GetString() : null;
            }
            var user = await _db.Users.FirstOrDefaultAsync(u => u.Email == email);

            if (user == null)
            {
                // Tạo user mới nếu chưa tồn tại
                user = new User
                {
                    Email = email,
                    DisplayName = displayName ?? email.Split('@')[0],
                    PhotoUrl = photoUrl,
                    PasswordHash = "GOOGLE_AUTH_" + Guid.NewGuid().ToString("N"), // Không dùng pass này để login thường
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow,
                    LastActive = DateTime.UtcNow
                };
                _db.Users.Add(user);
                await _db.SaveChangesAsync();
            }
            else
            {
                user.LastActive = DateTime.UtcNow;
                if (string.IsNullOrEmpty(user.PhotoUrl) && !string.IsNullOrEmpty(photoUrl))
                {
                    user.PhotoUrl = photoUrl;
                }
                await _db.SaveChangesAsync();
            }

            return Ok(new AuthResponse
            {
                Message = "Đăng nhập Google thành công!",
                User = MapUser(user),
                Token = _jwt.GenerateToken(user.UserId)
            });
        }
        catch (Google.Apis.Auth.InvalidJwtException ex)
        {
            _logger.LogWarning(ex, "Invalid Google IdToken");
            return Unauthorized(new ErrorResponse { Error = "Token Google không hợp lệ hoặc đã hết hạn" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Google Login error");
            return StatusCode(500, new ErrorResponse { Error = "Lỗi hệ thống khi đăng nhập Google" });
        }
    }

    /// <summary>Đăng nhập.</summary>
    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Email) || string.IsNullOrWhiteSpace(request.Password))
            return BadRequest(new ErrorResponse { Error = "Email và mật khẩu là bắt buộc" });

        var email = request.Email.Trim().ToLower();
        var user = await _db.Users.FirstOrDefaultAsync(u => u.Email == email);

        if (user == null)
            return Unauthorized(new ErrorResponse { Error = "Email hoặc mật khẩu không đúng" });

        // Check if hash is BCrypt format ($2a$ or $2b$ or $2y$)
        if (user.PasswordHash.StartsWith("$2"))
        {
            try
            {
                if (!BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash))
                    return Unauthorized(new ErrorResponse { Error = "Email hoặc mật khẩu không đúng" });
            }
            catch
            {
                return Unauthorized(new ErrorResponse { Error = "Email hoặc mật khẩu không đúng" });
            }
        }
        else
        {
            // Old werkzeug/scrypt hash from Python backend — rehash with BCrypt
            // For now, just reject and ask user to re-register
            return Unauthorized(new ErrorResponse { Error = "Tài khoản cũ, vui lòng đăng ký lại" });
        }

        user.LastActive = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        return Ok(new AuthResponse
        {
            Message = "Đăng nhập thành công!",
            User = MapUser(user),
            Token = _jwt.GenerateToken(user.UserId)
        });
    }

    /// <summary>Lấy thông tin user hiện tại (cần token).</summary>
    [HttpGet("me")]
    [Authorize]
    public async Task<IActionResult> GetMe()
    {
        var userId = GetCurrentUserId();
        if (userId == null)
            return Unauthorized(new ErrorResponse { Error = "Token không hợp lệ" });

        var user = await _db.Users.FindAsync(userId);
        if (user == null)
            return Unauthorized(new ErrorResponse { Error = "User không tồn tại" });

        return Ok(new { user = MapUser(user, full: true) });
    }

    /// <summary>Cập nhật profile.</summary>
    [HttpPut("profile")]
    [Authorize]
    public async Task<IActionResult> UpdateProfile([FromBody] UpdateProfileRequest request)
    {
        var userId = GetCurrentUserId();
        if (userId == null) return Unauthorized();

        var user = await _db.Users.FindAsync(userId);
        if (user == null) return NotFound();

        if (request.DisplayName != null) user.DisplayName = request.DisplayName;
        if (request.PhoneNumber != null) user.PhoneNumber = request.PhoneNumber;
        if (request.PhotoUrl != null) user.PhotoUrl = request.PhotoUrl;
        if (request.SkillLevel != null) user.SkillLevel = request.SkillLevel;
        if (request.DietaryRestrictions != null) user.DietaryRestrictions = request.DietaryRestrictions;
        if (request.CuisinePreferences != null) user.CuisinePreferences = request.CuisinePreferences;
        if (request.Allergies != null) user.Allergies = request.Allergies;
        if (request.NotificationEnabled.HasValue) user.NotificationEnabled = request.NotificationEnabled.Value;

        user.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        return Ok(new { message = "Cập nhật thành công!", user = MapUser(user, full: true) });
    }

    // ==================== Helpers ====================

    private int? GetCurrentUserId()
    {
        var claim = User.FindFirst("user_id")?.Value;
        return claim != null ? int.Parse(claim) : null;
    }

    private static string? NormalizeToken(string? token)
    {
        if (string.IsNullOrWhiteSpace(token))
            return null;

        return token.Replace("\r", string.Empty)
                    .Replace("\n", string.Empty)
                    .Trim();
    }

    private static UserDto MapUser(User user, bool full = false)
    {
        var dto = new UserDto
        {
            UserId = user.UserId,
            Email = user.Email,
            DisplayName = user.DisplayName,
            PhotoUrl = user.PhotoUrl,
            SkillLevel = user.SkillLevel
        };

        if (full)
        {
            dto.PhoneNumber = user.PhoneNumber;
            dto.DietaryRestrictions = user.DietaryRestrictions;
            dto.CuisinePreferences = user.CuisinePreferences;
            dto.Allergies = user.Allergies;
            dto.NotificationEnabled = user.NotificationEnabled;
            dto.CreatedAt = user.CreatedAt.ToString("o");
        }

        return dto;
    }
}
