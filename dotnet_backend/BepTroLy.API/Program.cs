using System.Text;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.AspNetCore.RateLimiting;
using BepTroLy.API.Data;
using BepTroLy.API.Services;
using BepTroLy.API.Hubs;

var builder = WebApplication.CreateBuilder(args);

// Đảm bảo WebRootPath được thiết lập (quan trọng để UseStaticFiles hoạt động)
if (string.IsNullOrEmpty(builder.Environment.WebRootPath))
{
    builder.Environment.WebRootPath = Path.Combine(builder.Environment.ContentRootPath, "wwwroot");
}
if (!Directory.Exists(builder.Environment.WebRootPath))
{
    Directory.CreateDirectory(builder.Environment.WebRootPath);
}

// ==================== Services ====================

// Controllers with snake_case JSON (matches Flask API format)
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.PropertyNamingPolicy =
            System.Text.Json.JsonNamingPolicy.SnakeCaseLower;
    });

builder.Services.AddSignalR();

// Swagger
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.AddSecurityDefinition("Bearer", new Microsoft.OpenApi.Models.OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = Microsoft.OpenApi.Models.SecuritySchemeType.Http,
        Scheme = "Bearer",
        BearerFormat = "JWT",
        In = Microsoft.OpenApi.Models.ParameterLocation.Header,
        Description = "Nhập JWT Token của bạn vào đây (không cần gõ chữ Bearer)"
    });
    c.AddSecurityRequirement(new Microsoft.OpenApi.Models.OpenApiSecurityRequirement
    {
        {
            new Microsoft.OpenApi.Models.OpenApiSecurityScheme
            {
                Reference = new Microsoft.OpenApi.Models.OpenApiReference
                {
                    Type = Microsoft.OpenApi.Models.ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            new string[] {}
        }
    });
});

// Database (MySQL/TiDB via Pomelo)
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
var mysqlServerVersion = builder.Configuration["Database:ServerVersion"] ?? "8.0.36-mysql";
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseMySql(
        connectionString,
        ServerVersion.Parse(mysqlServerVersion),
        mysqlOptions => mysqlOptions.EnableRetryOnFailure(5, TimeSpan.FromSeconds(2), null)));

// Rate limiting to protect API from burst traffic/abuse.
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.OnRejected = async (context, token) =>
    {
        if (context.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retryAfter))
        {
            context.HttpContext.Response.Headers["Retry-After"] =
                Math.Max(1, (int)Math.Ceiling(retryAfter.TotalSeconds)).ToString();
        }

        context.HttpContext.Response.ContentType = "application/json";
        await context.HttpContext.Response.WriteAsync(
            "{\"success\":false,\"error\":\"Quá nhiều yêu cầu, vui lòng thử lại sau vài giây.\"}",
            token);
    };

    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(httpContext =>
    {
        var userKey = httpContext.User.FindFirst("user_id")?.Value;
        var ipKey = httpContext.Connection.RemoteIpAddress?.ToString();
        var key = userKey != null ? $"user:{userKey}" : $"ip:{ipKey ?? "unknown"}";

        return RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: key,
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 120,
                Window = TimeSpan.FromMinutes(1),
                QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
                QueueLimit = 20
            });
    });

    options.AddPolicy("recipe-heavy", httpContext =>
    {
        var userKey = httpContext.User.FindFirst("user_id")?.Value;
        var ipKey = httpContext.Connection.RemoteIpAddress?.ToString();
        var key = userKey != null ? $"ai-user:{userKey}" : $"ai-ip:{ipKey ?? "unknown"}";

        return RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: key,
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 20,
                Window = TimeSpan.FromMinutes(1),
                QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
                QueueLimit = 5
            });
    });
});

// JWT Authentication
var jwtSecret = builder.Configuration["Jwt:SecretKey"] ?? "bep-tro-ly-secret-key-2026-super-secure-jwt-token-key";
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

        // Kỹ thuật này cho phép SignalR nhận token từ query string
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                var accessToken = context.Request.Query["access_token"];
                var path = context.HttpContext.Request.Path;
                if (!string.IsNullOrEmpty(accessToken) &&
                    (path.StartsWithSegments("/chatHub")))
                {
                    context.Token = accessToken;
                }
                return Task.CompletedTask;
            }
        };
    });

// Custom services
builder.Services.AddSingleton<JwtService>();
builder.Services.AddHttpClient<IRecipeCatalogProvider, SpoonacularRecipeProvider>(client =>
{
    client.Timeout = TimeSpan.FromSeconds(20);
});
builder.Services.AddScoped<AIRecipeService>();

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

        // [HOTFIX] Bắt buộc chạy sửa lỗi bảng do Migration trước đó bị đánh dấu là "đã chạy" nhưng chưa được thực thi trên VPS.
        try
        {
            var sql1 = @"
                CREATE TABLE IF NOT EXISTS `chat_message_reads` (
                    `message_id` int NOT NULL,
                    `user_id` int NOT NULL,
                    `read_at` datetime(6) NOT NULL,
                    PRIMARY KEY (`message_id`, `user_id`),
                    KEY `IX_chat_message_reads_user_id` (`user_id`),
                    CONSTRAINT `FK_chat_message_reads_chat_messages_message_id_fixed` FOREIGN KEY (`message_id`) REFERENCES `chat_messages` (`message_id`) ON DELETE CASCADE,
                    CONSTRAINT `FK_chat_message_reads_users_user_id_fixed` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            ";
            context.Database.ExecuteSqlRaw(sql1);

            var sql2 = @"
                DROP PROCEDURE IF EXISTS AddStatusColumnFixed;
                CREATE PROCEDURE AddStatusColumnFixed()
                BEGIN
                    IF NOT EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'chat_messages' AND COLUMN_NAME = 'status') THEN
                        ALTER TABLE `chat_messages` ADD COLUMN `status` varchar(50) NOT NULL DEFAULT 'sent';
                    END IF;
                END;
            ";
            context.Database.ExecuteSqlRaw(sql2);
            context.Database.ExecuteSqlRaw("CALL AddStatusColumnFixed();");
            context.Database.ExecuteSqlRaw("DROP PROCEDURE AddStatusColumnFixed;");
            
            Console.WriteLine("[HOTFIX] Xử lý CSDL thành công cho `chat_messages` và `chat_message_reads`!");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[HOTFIX ERROR] {ex.Message}");
        }

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

Console.WriteLine($"[DEBUG] ContentRootPath: {app.Environment.ContentRootPath}");
Console.WriteLine($"[DEBUG] WebRootPath: {app.Environment.WebRootPath}");

// Logging middleware để debug
app.Use(async (context, next) =>
{
    if (context.Request.Path.Value?.Contains("/uploads/") == true)
    {
        Console.WriteLine($"[DEBUG] File Request: {context.Request.Method} {context.Request.Path}");
    }
    await next();
    if (context.Request.Path.Value?.Contains("/uploads/") == true)
    {
        Console.WriteLine($"[DEBUG] File Response: {context.Response.StatusCode}");
    }
});

app.UseStaticFiles(); // Phục vụ từ wwwroot mặc định

app.UseCors();
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();
app.MapHub<ChatHub>("/chatHub");
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
        var token = jwt.GenerateToken(99999);
        return Results.Ok(new { success = true, token = token });
    }
    catch (Exception ex)
    {
        return Results.Json(new { success = false, error = ex.Message, type = ex.GetType().Name, inner = ex.InnerException?.Message, stack = ex.StackTrace?.Substring(0, Math.Min(500, ex.StackTrace?.Length ?? 0)) }, statusCode: 500);
    }
});

// Tôn trọng ASPNETCORE_URLS / launchSettings để tránh lệch cổng giữa local và Docker.
app.Run();
