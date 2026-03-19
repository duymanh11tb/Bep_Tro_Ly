using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BepTroLy.API.Migrations
{
    /// <inheritdoc />
    public partial class AddFridgeManagement : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "fridge_id",
                table: "pantry_items",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "fridges",
                columns: table => new
                {
                    fridge_id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    name = table.Column<string>(type: "varchar(100)", maxLength: 100, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    location = table.Column<string>(type: "varchar(255)", maxLength: 255, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    owner_id = table.Column<int>(type: "int", nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    updated_at = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_fridges", x => x.fridge_id);
                    table.ForeignKey(
                        name: "FK_fridges_users_owner_id",
                        column: x => x.owner_id,
                        principalTable: "users",
                        principalColumn: "user_id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "fridge_members",
                columns: table => new
                {
                    fridge_id = table.Column<int>(type: "int", nullable: false),
                    user_id = table.Column<int>(type: "int", nullable: false),
                    role = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    status = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    invited_at = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    joined_at = table.Column<DateTime>(type: "datetime(6)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_fridge_members", x => new { x.fridge_id, x.user_id });
                    table.ForeignKey(
                        name: "FK_fridge_members_fridges_fridge_id",
                        column: x => x.fridge_id,
                        principalTable: "fridges",
                        principalColumn: "fridge_id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_fridge_members_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "user_id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_pantry_items_fridge_id",
                table: "pantry_items",
                column: "fridge_id");

            migrationBuilder.CreateIndex(
                name: "IX_fridge_members_user_id",
                table: "fridge_members",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "IX_fridges_owner_id",
                table: "fridges",
                column: "owner_id");

            migrationBuilder.AddForeignKey(
                name: "FK_pantry_items_fridges_fridge_id",
                table: "pantry_items",
                column: "fridge_id",
                principalTable: "fridges",
                principalColumn: "fridge_id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_pantry_items_fridges_fridge_id",
                table: "pantry_items");

            migrationBuilder.DropTable(
                name: "fridge_members");

            migrationBuilder.DropTable(
                name: "fridges");

            migrationBuilder.DropIndex(
                name: "IX_pantry_items_fridge_id",
                table: "pantry_items");

            migrationBuilder.DropColumn(
                name: "fridge_id",
                table: "pantry_items");
        }
    }
}
