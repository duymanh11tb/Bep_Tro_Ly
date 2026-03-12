using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.Tokens;

namespace BepTroLy.API.Services;

public class JwtService
{
    private readonly string _secretKey;
    private readonly int _expirationDays;

    public JwtService(IConfiguration configuration)
    {
        _secretKey = configuration["Jwt:SecretKey"] ?? "bep-tro-ly-secret-key-2024-super-secure-jwt-token-key";
        _expirationDays = int.Parse(configuration["Jwt:ExpirationDays"] ?? "30");
        Console.WriteLine($"[JWT DEBUG] SecretKey length: {_secretKey.Length}, value: {_secretKey.Substring(0, Math.Min(5, _secretKey.Length))}..., bytes: {Encoding.UTF8.GetBytes(_secretKey).Length}");
    }

    public string GenerateToken(int userId)
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_secretKey));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256Signature);

        var claims = new[]
        {
            new Claim("user_id", userId.ToString()),
            new Claim(JwtRegisteredClaimNames.Iat, 
                new DateTimeOffset(DateTime.UtcNow).ToUnixTimeSeconds().ToString(),
                ClaimValueTypes.Integer64)
        };

        var token = new JwtSecurityToken(
            claims: claims,
            expires: DateTime.UtcNow.AddDays(_expirationDays),
            signingCredentials: creds
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    public int? ValidateToken(string token)
    {
        try
        {
            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_secretKey));
            var handler = new JwtSecurityTokenHandler();

            var principal = handler.ValidateToken(token, new TokenValidationParameters
            {
                ValidateIssuer = false,
                ValidateAudience = false,
                ValidateLifetime = true,
                IssuerSigningKey = key,
                ClockSkew = TimeSpan.Zero
            }, out _);

            var userIdClaim = principal.FindFirst("user_id")?.Value;
            return userIdClaim != null ? int.Parse(userIdClaim) : null;
        }
        catch
        {
            return null;
        }
    }
}
