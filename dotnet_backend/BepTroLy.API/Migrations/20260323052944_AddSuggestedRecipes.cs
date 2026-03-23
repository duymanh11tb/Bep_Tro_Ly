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
            migrationBuilder.Sql(@"
                CREATE TABLE IF NOT EXISTS `suggested_recipes` (
                    `suggestion_id` bigint NOT NULL AUTO_INCREMENT,
                    `user_id` int NOT NULL,
                    `recipe_name` varchar(255) NOT NULL,
                    `recipe_data` json NOT NULL,
                    `suggested_at` datetime(6) NOT NULL,
                    `status` varchar(20) NOT NULL,
                    `context_data` json NULL,
                    PRIMARY KEY (`suggestion_id`),
                    KEY `IX_suggested_recipes_user_id` (`user_id`),
                    CONSTRAINT `FK_suggested_recipes_users_user_id`
                        FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            ");

            migrationBuilder.Sql(@"
                DROP PROCEDURE IF EXISTS RecreatePantryFridgeFk;
                CREATE PROCEDURE RecreatePantryFridgeFk()
                BEGIN
                    DECLARE existing_fk VARCHAR(255);

                    SELECT CONSTRAINT_NAME INTO existing_fk
                    FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
                    WHERE TABLE_SCHEMA = DATABASE()
                      AND TABLE_NAME = 'pantry_items'
                      AND COLUMN_NAME = 'fridge_id'
                      AND REFERENCED_TABLE_NAME = 'fridges'
                      AND REFERENCED_COLUMN_NAME = 'fridge_id'
                    LIMIT 1;

                    IF existing_fk IS NOT NULL AND existing_fk <> '' THEN
                        SET @drop_fk_sql = CONCAT(
                            'ALTER TABLE `pantry_items` DROP FOREIGN KEY `',
                            existing_fk,
                            '`'
                        );
                        PREPARE drop_fk_stmt FROM @drop_fk_sql;
                        EXECUTE drop_fk_stmt;
                        DEALLOCATE PREPARE drop_fk_stmt;
                    END IF;

                    IF NOT EXISTS (
                        SELECT 1
                        FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
                        WHERE CONSTRAINT_SCHEMA = DATABASE()
                          AND TABLE_NAME = 'pantry_items'
                          AND CONSTRAINT_NAME = 'FK_pantry_items_fridges_fridge_id'
                          AND CONSTRAINT_TYPE = 'FOREIGN KEY'
                    ) THEN
                        ALTER TABLE `pantry_items`
                            ADD CONSTRAINT `FK_pantry_items_fridges_fridge_id`
                            FOREIGN KEY (`fridge_id`) REFERENCES `fridges` (`fridge_id`)
                            ON DELETE CASCADE;
                    END IF;
                END;
            ");
            migrationBuilder.Sql("CALL RecreatePantryFridgeFk();");
            migrationBuilder.Sql("DROP PROCEDURE RecreatePantryFridgeFk;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(@"
                DROP PROCEDURE IF EXISTS RestorePantryFridgeFk;
                CREATE PROCEDURE RestorePantryFridgeFk()
                BEGIN
                    DECLARE existing_fk VARCHAR(255);

                    SELECT CONSTRAINT_NAME INTO existing_fk
                    FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
                    WHERE TABLE_SCHEMA = DATABASE()
                      AND TABLE_NAME = 'pantry_items'
                      AND COLUMN_NAME = 'fridge_id'
                      AND REFERENCED_TABLE_NAME = 'fridges'
                      AND REFERENCED_COLUMN_NAME = 'fridge_id'
                    LIMIT 1;

                    IF existing_fk IS NOT NULL AND existing_fk <> '' THEN
                        SET @drop_fk_sql = CONCAT(
                            'ALTER TABLE `pantry_items` DROP FOREIGN KEY `',
                            existing_fk,
                            '`'
                        );
                        PREPARE drop_fk_stmt FROM @drop_fk_sql;
                        EXECUTE drop_fk_stmt;
                        DEALLOCATE PREPARE drop_fk_stmt;
                    END IF;

                    ALTER TABLE `pantry_items`
                        ADD CONSTRAINT `FK_pantry_items_fridges_fridge_id`
                        FOREIGN KEY (`fridge_id`) REFERENCES `fridges` (`fridge_id`);
                END;
            ");
            migrationBuilder.Sql("CALL RestorePantryFridgeFk();");
            migrationBuilder.Sql("DROP PROCEDURE RestorePantryFridgeFk;");

            migrationBuilder.Sql("DROP TABLE IF EXISTS `suggested_recipes`;");
        }
    }
}
