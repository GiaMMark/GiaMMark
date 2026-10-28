-- Import into the SAME database used by es_extended / qb-core / qbx_core.
-- No ALTER to framework tables. Back up the database before installing resources.
CREATE TABLE IF NOT EXISTS `void_characters_identity` (
  `framework` VARCHAR(8) NOT NULL,
  `character_id` VARCHAR(100) NOT NULL,
  `owner` VARCHAR(80) NOT NULL,
  `nationality` VARCHAR(64) NOT NULL,
  `height` SMALLINT UNSIGNED NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`framework`, `character_id`),
  KEY `void_characters_owner` (`framework`, `owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
