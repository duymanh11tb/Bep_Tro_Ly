using BepTroLy.API.DTOs;
using BepTroLy.API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace BepTroLy.API.Controllers;

[ApiController]
[Route("api/recipes")]
[Authorize]
public class BatchRecipeController : ControllerBase
{
    private readonly GeminiBatchService _batchService;

    public BatchRecipeController(GeminiBatchService batchService)
    {
        _batchService = batchService;
    }

    /// <summary>Tạo batch job gợi ý món ăn hàng loạt (tiết kiệm 50% chi phí).</summary>
    [HttpPost("batch-suggest")]
    [EnableRateLimiting("ai-heavy")]
    public async Task<IActionResult> CreateBatchSuggest([FromBody] CreateBatchRequest request)
    {
        var userId = GetCurrentUserId();
        if (userId == null) return Unauthorized();

        try
        {
            var job = await _batchService.CreateRecipeBatchForUserAsync(
                userId.Value,
                request.Preferences);

            return Ok(new
            {
                success = true,
                job_id = job.Id,
                batch_name = job.BatchName,
                state = job.State,
                request_count = job.RequestCount,
                created_at = job.CreatedAt,
                message = "Batch job đã được tạo. Dùng GET /batch-status/{jobId} để kiểm tra trạng thái."
            });
        }
        catch (Exception ex)
        {
            return BadRequest(new { success = false, error = ex.Message });
        }
    }

    /// <summary>Kiểm tra trạng thái batch job.</summary>
    [HttpGet("batch-status/{jobId:int}")]
    public async Task<IActionResult> GetBatchStatus(int jobId)
    {
        var userId = GetCurrentUserId();
        if (userId == null) return Unauthorized();

        var job = await _batchService.PollBatchStatusAsync(jobId);
        if (job == null) return NotFound(new { success = false, error = "Không tìm thấy batch job." });

        // Kiểm tra quyền sở hữu
        if (job.UserId != null && job.UserId != userId.Value)
            return Forbid();

        return Ok(new BatchStatusResponse
        {
            JobId = job.Id,
            State = job.State,
            DisplayName = job.DisplayName,
            RequestCount = job.RequestCount,
            SucceededCount = job.SucceededCount,
            FailedCount = job.FailedCount,
            CreatedAt = job.CreatedAt,
            CompletedAt = job.CompletedAt,
            ErrorMessage = job.ErrorMessage,
            HasResults = job.State == "JOB_STATE_SUCCEEDED" && !string.IsNullOrEmpty(job.ResultData),
        });
    }

    /// <summary>Lấy kết quả batch job (khi SUCCEEDED).</summary>
    [HttpGet("batch-results/{jobId:int}")]
    public async Task<IActionResult> GetBatchResults(int jobId)
    {
        var userId = GetCurrentUserId();
        if (userId == null) return Unauthorized();

        var results = await _batchService.GetBatchResultsAsync(jobId);
        if (results == null)
            return NotFound(new { success = false, error = "Chưa có kết quả. Kiểm tra state = JOB_STATE_SUCCEEDED trước." });

        return Ok(new
        {
            success = true,
            job_id = jobId,
            recipe_count = results.Count,
            recipes = results,
        });
    }

    /// <summary>Liệt kê batch jobs của user.</summary>
    [HttpGet("batch-list")]
    public async Task<IActionResult> ListBatchJobs([FromQuery] int limit = 10)
    {
        var userId = GetCurrentUserId();
        if (userId == null) return Unauthorized();

        var jobs = await _batchService.ListUserBatchJobsAsync(userId.Value, Math.Clamp(limit, 1, 50));

        return Ok(new
        {
            success = true,
            jobs = jobs.Select(j => new
            {
                job_id = j.Id,
                display_name = j.DisplayName,
                state = j.State,
                request_count = j.RequestCount,
                succeeded_count = j.SucceededCount,
                created_at = j.CreatedAt,
                completed_at = j.CompletedAt,
            }),
        });
    }

    private int? GetCurrentUserId()
    {
        var claim = User.FindFirst("user_id")?.Value;
        return claim != null ? int.Parse(claim) : null;
    }
}
