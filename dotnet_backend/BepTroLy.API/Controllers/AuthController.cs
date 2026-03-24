using BepTroLy.API.Data;
using BepTroLy.API.DTOs;
using BepTroLy.API.Models;
using BepTroLy.API.Services;
using Google.Apis.Auth;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;

namespace BepTroLy.API.Controllers;

[ApiController]
[Route("api/v1/auth")]
public class AuthController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly JwtService _jwt;
    private readonly ILogger<AuthController> _logger;
    private readonly IWebHostEnvironment _env;

    public AuthController(AppDbContext db, JwtService jwt, ILogger<AuthController> logger, IWebHostEnvironment env)
    {
        _db = db;
        _jwt = jwt;
        _logger = logger;
        _env = env;
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
            string email = string.Empty;
            string? displayName = null;
            string? photoUrl = null;
            var validatedByIdToken = false;

            if (!string.IsNullOrWhiteSpace(request.IdToken))
            {
                try
                {
                    var audiences = GetGoogleAudiences();

                    var payload = await GoogleJsonWebSignature.ValidateAsync(request.IdToken, new GoogleJsonWebSignature.ValidationSettings
                    {
                        Audience = audiences.Length > 0 ? audiences : null
                    });

                    email = payload.Email.Trim().ToLower();
                    displayName = payload.Name;
                    photoUrl = payload.Picture;
                    validatedByIdToken = true;
                }
                catch (InvalidJwtException ex)
                {
                    _logger.LogWarning(ex, "Invalid Google IdToken; fallback to AccessToken if available");

                    if (string.IsNullOrWhiteSpace(request.AccessToken))
                    {
                        return Unauthorized(new ErrorResponse { Error = "Token Google không hợp lệ hoặc đã hết hạn" });
                    }
                }
            }

            if (!validatedByIdToken)
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
        catch (InvalidJwtException ex)
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

    /// <summary>Tìm kiếm người dùng bằng email hoặc số điện thoại.</summary>
    [HttpGet("search")]
    [Authorize]
    public async Task<IActionResult> SearchUser([FromQuery] string query)
    {
        if (string.IsNullOrWhiteSpace(query))
            return BadRequest(new ErrorResponse { Error = "Vui lòng nhập email hoặc số điện thoại" });

        var term = query.Trim().ToLower();
        var user = await _db.Users.FirstOrDefaultAsync(u => 
            u.Email == term || u.PhoneNumber == term);

        if (user == null)
            return NotFound(new ErrorResponse { Error = "Không tìm thấy người dùng" });

        return Ok(new { user = MapUser(user, full: false) });
    }
    
    /// <summary>Upload ảnh đại diện.</summary>
    [HttpPost("avatar")]
    [Authorize]
    public async Task<IActionResult> UploadAvatar(IFormFile avatar)
    {
        if (avatar == null || avatar.Length == 0)
            return BadRequest(new ErrorResponse { Error = "Vui lòng chọn ảnh" });

        var userId = GetCurrentUserId();
        if (userId == null) return Unauthorized();

        var user = await _db.Users.FindAsync(userId);
        if (user == null) return NotFound();

        try
        {
            // Tạo thư mục nếu chưa có (Sử dụng WebRootPath để phục vụ file tĩnh)
            var webRoot = _env.WebRootPath ?? Path.Combine(_env.ContentRootPath, "wwwroot");
            var uploadsDir = Path.Combine(webRoot, "uploads", "avatars");
            if (!Directory.Exists(uploadsDir)) Directory.CreateDirectory(uploadsDir);

            // Tên file duy nhất
            var fileName = $"{userId}_{DateTime.Now.Ticks}{Path.GetExtension(avatar.FileName)}";
            var filePath = Path.Combine(uploadsDir, fileName);

            using (var stream = new FileStream(filePath, FileMode.Create))
            {
                await avatar.CopyToAsync(stream);
            }

            // Lưu URL (tương đối) vào DB
            var photoUrl = $"/uploads/avatars/{fileName}";
            user.PhotoUrl = photoUrl;
            user.UpdatedAt = DateTime.UtcNow;
            await _db.SaveChangesAsync();

            return Ok(new { message = "Đã cập nhật ảnh đại diện", user = MapUser(user, full: true) });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error uploading avatar for user {UserId}", userId);
            return StatusCode(500, new ErrorResponse { Error = "Lỗi hệ thống khi tải ảnh lên" });
        }
    }

    [HttpPost("change-password")]
    [Authorize]
    public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.CurrentPassword) || string.IsNullOrWhiteSpace(request.NewPassword))
            return BadRequest(new ErrorResponse { Error = "Mật khẩu hiện tại và mật khẩu mới là bắt buộc" });

        if (request.NewPassword.Length < 6)
            return BadRequest(new ErrorResponse { Error = "Mật khẩu mới phải có ít nhất 6 ký tự" });

        var userId = GetCurrentUserId();
        if (userId == null) return Unauthorized();

        var user = await _db.Users.FindAsync(userId);
        if (user == null) return NotFound();

        // Kiểm tra mật khẩu hiện tại (Chỉ áp dụng cho user có pass, không áp dụng cho Google Auth trực tiếp nếu chưa đặt pass)
        if (user.PasswordHash.StartsWith("GOOGLE_AUTH_"))
        {
            // Nếu là user Google chưa đặt mật khẩu bao giờ, có thể cho phép đặt mật khẩu mới mà không cần pass cũ
            // Nhưng thiết kế đơn giản nhất là yêu cầu họ dùng tính năng khác hoặc báo lỗi
            return BadRequest(new ErrorResponse { Error = "Tài khoản đăng nhập bằng Google không thể đổi mật khẩu theo cách này" });
        }

        try
        {
            if (!BCrypt.Net.BCrypt.Verify(request.CurrentPassword, user.PasswordHash))
                return BadRequest(new ErrorResponse { Error = "Mật khẩu hiện tại không chính xác" });
        }
        catch (Exception)
        {
            return BadRequest(new ErrorResponse { Error = "Lỗi xác thực mật khẩu" });
        }

        // Cập nhật mật khẩu mới
        user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.NewPassword);
        user.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        return Ok(new { message = "Đổi mật khẩu thành công!" });
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

    private string[] GetGoogleAudiences()
    {
        var config = new ConfigurationBuilder()
            .SetBasePath(Directory.GetCurrentDirectory())
            .AddJsonFile("appsettings.json")
            .AddEnvironmentVariables()
            .Build();

        var rawValues = new[]
        {
            config["GOOGLE_CLIENT_ID"],
            config["GOOGLE_CLIENT_IDS"],
            config["GoogleAuth:ClientId"],
            config["GoogleAuth:ClientIds"]
        };

        return rawValues
            .Where(v => !string.IsNullOrWhiteSpace(v))
            .SelectMany(v => v!.Split(',', ';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            .Distinct(StringComparer.Ordinal)
            .ToArray();
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
