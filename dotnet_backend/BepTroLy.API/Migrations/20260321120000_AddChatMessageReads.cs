using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BepTroLy.API.Migrations
{
    /// <inheritdoc />
    public partial class AddChatMessageReads : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Use raw SQL with IF NOT EXISTS for MySQL compatibility
            migrationBuilder.Sql(@"
                CREATE TABLE IF NOT EXISTS `chat_message_reads` (
                    `message_id` int NOT NULL,
                    `user_id` int NOT NULL,
                    `read_at` datetime(6) NOT NULL,
                    PRIMARY KEY (`message_id`, `user_id`),
                    KEY `IX_chat_message_reads_user_id` (`user_id`),
                    CONSTRAINT `FK_chat_message_reads_chat_messages_message_id` FOREIGN KEY (`message_id`) REFERENCES `chat_messages` (`message_id`) ON DELETE CASCADE,
                    CONSTRAINT `FK_chat_message_reads_users_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            ");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "chat_message_reads");
        }
    }
}
