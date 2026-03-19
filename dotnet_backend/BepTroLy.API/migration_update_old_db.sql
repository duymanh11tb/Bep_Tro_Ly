START TRANSACTION;

CREATE TABLE `batch_jobs` (
    `id` int NOT NULL AUTO_INCREMENT,
    `batch_name` varchar(256) CHARACTER SET utf8mb4 NOT NULL,
    `display_name` varchar(128) CHARACTER SET utf8mb4 NOT NULL,
    `state` varchar(32) CHARACTER SET utf8mb4 NOT NULL,
    `input_data` json NULL,
    `result_data` json NULL,
    `user_id` int NULL,
    `request_count` int NOT NULL,
    `succeeded_count` int NOT NULL,
    `failed_count` int NOT NULL,
    `error_message` longtext CHARACTER SET utf8mb4 NULL,
    `created_at` datetime(6) NOT NULL,
    `completed_at` datetime(6) NULL,
    CONSTRAINT `PK_batch_jobs` PRIMARY KEY (`id`)
) CHARACTER SET=utf8mb4;

INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
VALUES ('20260319102801_AddBatchJobsTable', '8.0.0');

COMMIT;

