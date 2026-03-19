using BepTroLy.API.Data;
using Microsoft.EntityFrameworkCore;

namespace BepTroLy.API.Services;

/// <summary>
/// Background service tự động poll trạng thái batch jobs mỗi 30 giây.
/// Khi job SUCCEEDED, parse kết quả và lưu vào DB.
/// </summary>
public class BatchPollingService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<BatchPollingService> _logger;
    private static readonly TimeSpan PollInterval = TimeSpan.FromSeconds(30);

    public BatchPollingService(
        IServiceProvider serviceProvider,
        ILogger<BatchPollingService> logger)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("BatchPollingService started — polling every {Interval}s", PollInterval.TotalSeconds);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await PollPendingJobsAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in batch polling loop");
            }

            await Task.Delay(PollInterval, stoppingToken);
        }
    }

    private async Task PollPendingJobsAsync(CancellationToken ct)
    {
        using var scope = _serviceProvider.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var batchService = scope.ServiceProvider.GetRequiredService<GeminiBatchService>();

        // Tìm tất cả jobs chưa hoàn thành
        var pendingJobs = await db.BatchJobs
            .Where(j => j.State == "JOB_STATE_PENDING" || j.State == "JOB_STATE_RUNNING")
            .OrderBy(j => j.CreatedAt)
            .Take(20) // Giới hạn để tránh quá tải
            .ToListAsync(ct);

        if (pendingJobs.Count == 0) return;

        _logger.LogDebug("Polling {Count} pending batch jobs", pendingJobs.Count);

        foreach (var job in pendingJobs)
        {
            if (ct.IsCancellationRequested) break;

            // Bỏ qua jobs quá cũ (48h+)
            if ((DateTime.UtcNow - job.CreatedAt).TotalHours > 48)
            {
                job.State = "JOB_STATE_EXPIRED";
                job.CompletedAt = DateTime.UtcNow;
                job.ErrorMessage = "Job hết hạn sau 48 giờ.";
                await db.SaveChangesAsync(ct);
                _logger.LogWarning("Batch job {BatchName} expired after 48h", job.BatchName);
                continue;
            }

            await batchService.PollAndUpdateAsync(job, ct);

            // Tránh rate limit
            await Task.Delay(500, ct);
        }
    }
}
