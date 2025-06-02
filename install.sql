CREATE TABLE IF NOT EXISTS `tb_waterwagon_levels` (
  `wagon_id` int(11) NOT NULL,
  `water_level` int(11) NOT NULL DEFAULT 0,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`wagon_id`),
  FOREIGN KEY (`wagon_id`) REFERENCES `kd_wagons`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci; 