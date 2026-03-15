using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using BepTroLy.API.Data;
using BepTroLy.API.Services;

var builder = WebApplication.CreateBuilder(args);

// ==================== Services ====================

// Controllers with snake_case JSON (matches Flask API format)
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.PropertyNamingPolicy = 
            System.Text.Json.JsonNamingPolicy.SnakeCaseLower;
    });

// Swagger
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Database (MySQL/TiDB via Pomelo)
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
var mysqlServerVersion = builder.Configuration["Database:ServerVersion"] ?? "8.0.36-mysql";
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseMySql(connectionString, ServerVersion.Parse(mysqlServerVersion)));

// JWT Authentication
var jwtSecret = builder.Configuration["Jwt:SecretKey"] ?? "bep-tro-ly-secret-key-2024-super-secure-jwt-token-key";
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = false,
            ValidateAudience = false,
            ValidateLifetime = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSecret)),
            ClockSkew = TimeSpan.Zero
        };
    });

// Custom services
builder.Services.AddSingleton<JwtService>();
builder.Services.AddHttpClient<AIRecipeService>(); 

// CORS (cho Flutter app)
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

// Apply Database Migrations on Startup automatically
using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;
    var logger = services.GetRequiredService<ILogger<Program>>();
    try
    {
        var context = services.GetRequiredService<AppDbContext>();
        context.Database.Migrate();
        
        // Add a simple connection test
        if (context.Database.CanConnect())
        {
            Console.WriteLine("==================================================");
            Console.WriteLine("✅ DATABASE CONNECTED SUCCESSFULLY");
            Console.WriteLine("==================================================");
        }
        else
        {
            Console.WriteLine("==================================================");
            Console.WriteLine("❌ DATABASE CONNECTION FAILED!");
            Console.WriteLine("==================================================");
        }
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "An error occurred while migrating the database.");
        Console.WriteLine($"❌ DATABASE ERROR: {ex.Message}");
        throw;
    }
}

// ==================== Middleware ====================

// Swagger (all environments for now)
app.UseSwagger();
app.UseSwaggerUI();

app.UseCors();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

// ==================== Root & Health Endpoints ====================

app.MapGet("/", () => Results.Ok(new
{
    app = "Bếp Trợ Lý API",
    version = "2.0.0",
    status = "running",
    framework = ".NET 8"
}));

app.MapGet("/health", async (AppDbContext db) =>
{
    try
    {
        await db.Database.ExecuteSqlRawAsync("SELECT 1");
        return Results.Ok(new { status = "healthy", db = "ok" });
    }
    catch (Exception ex)
    {
        return Results.Json(new { status = "unhealthy", db = ex.Message }, statusCode: 503);
    }
});

app.MapGet("/debug/jwt", (JwtService jwt) =>
{
    try
    {
        var token = jwt.GenerateToken(99999, "user");
        return Results.Ok(new { success = true, token = token.Substring(0, 20) + "..." });
    }
    catch (Exception ex)
    {
        return Results.Json(new { success = false, error = ex.Message, type = ex.GetType().Name, inner = ex.InnerException?.Message, stack = ex.StackTrace?.Substring(0, Math.Min(500, ex.StackTrace?.Length ?? 0)) }, statusCode: 500);
    }
});

app.Run();
