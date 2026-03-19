using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BepTroLy.API.Migrations
{
    /// <inheritdoc />
    public partial class AddFridgeIdToActivityLog : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "fridge_id",
                table: "activity_logs",
                type: "int",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "fridge_id",
                table: "activity_logs");
        }
    }
}
