using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BepTroLy.API.Models;

[Table("batch_jobs")]
public class BatchJob
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    [Column("id")]
    public int Id { get; set; }

    /// <summary>Gemini batch name, e.g. "batches/123456"</summary>
    [Required]
    [MaxLength(256)]
    [Column("batch_name")]
    public string BatchName { get; set; } = string.Empty;

    [MaxLength(128)]
    [Column("display_name")]
    public string DisplayName { get; set; } = string.Empty;

    /// <summary>JOB_STATE_PENDING, JOB_STATE_RUNNING, JOB_STATE_SUCCEEDED, JOB_STATE_FAILED, JOB_STATE_CANCELLED, JOB_STATE_EXPIRED</summary>
    [Required]
    [MaxLength(32)]
    [Column("state")]
    public string State { get; set; } = "JOB_STATE_PENDING";

    /// <summary>JSON: array of prompts / inline requests sent to Gemini</summary>
    [Column("input_data", TypeName = "json")]
    public string? InputData { get; set; }

    /// <summary>JSON: parsed recipe results from Gemini response</summary>
    [Column("result_data", TypeName = "json")]
    public string? ResultData { get; set; }

    [Column("user_id")]
    public int? UserId { get; set; }

    [Column("request_count")]
    public int RequestCount { get; set; }

    [Column("succeeded_count")]
    public int SucceededCount { get; set; }

    [Column("failed_count")]
    public int FailedCount { get; set; }

    [Column("error_message")]
    public string? ErrorMessage { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [Column("completed_at")]
    public DateTime? CompletedAt { get; set; }

    // ── Helpers ──
    public bool IsTerminal => State is
        "JOB_STATE_SUCCEEDED" or "JOB_STATE_FAILED" or
        "JOB_STATE_CANCELLED" or "JOB_STATE_EXPIRED";
}
