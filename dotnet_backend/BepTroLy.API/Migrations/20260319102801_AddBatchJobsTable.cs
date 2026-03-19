using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BepTroLy.API.Migrations
{
    /// <inheritdoc />
    public partial class AddBatchJobsTable : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "batch_jobs",
                columns: table => new
                {
                    id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    batch_name = table.Column<string>(type: "varchar(256)", maxLength: 256, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    display_name = table.Column<string>(type: "varchar(128)", maxLength: 128, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    state = table.Column<string>(type: "varchar(32)", maxLength: 32, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    input_data = table.Column<string>(type: "json", nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    result_data = table.Column<string>(type: "json", nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    user_id = table.Column<int>(type: "int", nullable: true),
                    request_count = table.Column<int>(type: "int", nullable: false),
                    succeeded_count = table.Column<int>(type: "int", nullable: false),
                    failed_count = table.Column<int>(type: "int", nullable: false),
                    error_message = table.Column<string>(type: "longtext", nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    created_at = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    completed_at = table.Column<DateTime>(type: "datetime(6)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_batch_jobs", x => x.id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "batch_jobs");
        }
    }
}
