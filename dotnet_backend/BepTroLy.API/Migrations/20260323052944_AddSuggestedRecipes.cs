using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BepTroLy.API.Migrations
{
    /// <inheritdoc />
    public partial class AddSuggestedRecipes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_pantry_items_fridges_fridge_id",
                table: "pantry_items");

            migrationBuilder.AddColumn<string>(
                name: "status",
                table: "chat_messages",
                type: "longtext",
                nullable: false)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "chat_message_reads",
                columns: table => new
                {
                    message_id = table.Column<int>(type: "int", nullable: false),
                    user_id = table.Column<int>(type: "int", nullable: false),
                    read_at = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_chat_message_reads", x => new { x.message_id, x.user_id });
                    table.ForeignKey(
                        name: "FK_chat_message_reads_chat_messages_message_id",
                        column: x => x.message_id,
                        principalTable: "chat_messages",
                        principalColumn: "message_id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_chat_message_reads_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "user_id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "suggested_recipes",
                columns: table => new
                {
                    suggestion_id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    user_id = table.Column<int>(type: "int", nullable: false),
                    recipe_name = table.Column<string>(type: "varchar(255)", maxLength: 255, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    recipe_data = table.Column<string>(type: "json", nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    suggested_at = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    status = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    context_data = table.Column<string>(type: "json", nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_suggested_recipes", x => x.suggestion_id);
                    table.ForeignKey(
                        name: "FK_suggested_recipes_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "user_id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_chat_message_reads_user_id",
                table: "chat_message_reads",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "IX_suggested_recipes_user_id",
                table: "suggested_recipes",
                column: "user_id");

            migrationBuilder.AddForeignKey(
                name: "FK_pantry_items_fridges_fridge_id",
                table: "pantry_items",
                column: "fridge_id",
                principalTable: "fridges",
                principalColumn: "fridge_id",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_pantry_items_fridges_fridge_id",
                table: "pantry_items");

            migrationBuilder.DropTable(
                name: "chat_message_reads");

            migrationBuilder.DropTable(
                name: "suggested_recipes");

            migrationBuilder.DropColumn(
                name: "status",
                table: "chat_messages");

            migrationBuilder.AddForeignKey(
                name: "FK_pantry_items_fridges_fridge_id",
                table: "pantry_items",
                column: "fridge_id",
                principalTable: "fridges",
                principalColumn: "fridge_id");
        }
    }
}
