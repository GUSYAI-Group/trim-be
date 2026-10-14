-- ==============================================================================
-- ALL-IN-ONE PRODUCTION DATABASE SCRIPT: TRIM
-- AI-POWERED INTEGRATED BARBERSHOP SYSTEM
-- Dokumen Acuan: TRIM_TRD.md, TRIM_PRD.md & TRIM_FSD.md
-- Target Engine: MySQL 8.0+ / MariaDB 10.5+
-- ==============================================================================

CREATE DATABASE IF NOT EXISTS `trim_db` 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE `trim_db`;

SET FOREIGN_KEY_CHECKS = 0;

-- Drop views
DROP VIEW IF EXISTS `v_dashboard_kpis`;
DROP VIEW IF EXISTS `v_ai_conversion_analytics`;
DROP VIEW IF EXISTS `v_barber_leaderboard`;
DROP VIEW IF EXISTS `v_popular_hairstyles`;
DROP VIEW IF EXISTS `v_inventory_stock_alerts`;

-- Drop tables
DROP TABLE IF EXISTS `customer_haircut_history`;
DROP TABLE IF EXISTS `notifications`;
DROP TABLE IF EXISTS `promotion_usages`;
DROP TABLE IF EXISTS `promotions`;
DROP TABLE IF EXISTS `loyalty_transactions`;
DROP TABLE IF EXISTS `inventory_transactions`;
DROP TABLE IF EXISTS `products`;
DROP TABLE IF EXISTS `ai_recommendations`;
DROP TABLE IF EXISTS `ai_analyses`;
DROP TABLE IF EXISTS `reviews`;
DROP TABLE IF EXISTS `payments`;
DROP TABLE IF EXISTS `queues`;
DROP TABLE IF EXISTS `booking_services`;
DROP TABLE IF EXISTS `bookings`;
DROP TABLE IF EXISTS `hairstyle_face_shapes`;
DROP TABLE IF EXISTS `face_shapes`;
DROP TABLE IF EXISTS `hairstyles`;
DROP TABLE IF EXISTS `services`;
DROP TABLE IF EXISTS `barber_schedules`;
DROP TABLE IF EXISTS `barbers`;
DROP TABLE IF EXISTS `customers`;
DROP TABLE IF EXISTS `memberships`;
DROP TABLE IF EXISTS `users`;
DROP TABLE IF EXISTS `store_holidays`;
DROP TABLE IF EXISTS `store_schedules`;
DROP TABLE IF EXISTS `store_settings`;

SET FOREIGN_KEY_CHECKS = 1;

-- 1. USERS & MEMBERSHIPS (RBAC: Owner, Manager, Admin, Barber, Customer)
CREATE TABLE `users` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `email` VARCHAR(191) NOT NULL,
    `password_hash` VARCHAR(255) NOT NULL,
    `role` ENUM('owner', 'manager', 'admin', 'barber', 'customer') NOT NULL DEFAULT 'customer',
    `is_active` BOOLEAN NOT NULL DEFAULT TRUE,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_users_email` (`email`),
    INDEX `idx_users_role` (`role`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `memberships` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `tier_name` VARCHAR(50) NOT NULL,
    `discount_percentage` DECIMAL(5, 2) NOT NULL DEFAULT 0.00,
    `minimum_points_required` INT UNSIGNED NOT NULL DEFAULT 0,
    `point_multiplier` DECIMAL(3, 2) NOT NULL DEFAULT 1.00,
    `priority_booking` BOOLEAN NOT NULL DEFAULT FALSE,
    `free_service_quota` INT UNSIGNED NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_memberships_tier` (`tier_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `face_shapes` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `shape_name` VARCHAR(50) NOT NULL,
    `description` TEXT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_face_shapes_name` (`shape_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `barbers` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `user_id` CHAR(36) NOT NULL,
    `full_name` VARCHAR(100) NOT NULL,
    `phone_number` VARCHAR(20) NOT NULL,
    `profile_picture_url` VARCHAR(255) NULL,
    `specialty` VARCHAR(100) NOT NULL,
    `experience_years` INT UNSIGNED NOT NULL DEFAULT 1,
    `is_active` BOOLEAN NOT NULL DEFAULT TRUE,
    `average_rating` DECIMAL(3, 2) NOT NULL DEFAULT 0.00,
    `total_reviews` INT UNSIGNED NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_barbers_user_id` (`user_id`),
    UNIQUE KEY `uk_barbers_phone` (`phone_number`),
    INDEX `idx_barbers_active` (`is_active`),
    CONSTRAINT `fk_barbers_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `services` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `name` VARCHAR(100) NOT NULL,
    `category` VARCHAR(50) NOT NULL DEFAULT 'Haircut',
    `duration_minutes` INT UNSIGNED NOT NULL DEFAULT 30,
    `price` DECIMAL(12, 2) NOT NULL,
    `description` TEXT NULL,
    `image_url` VARCHAR(255) NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT TRUE,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_services_active` (`is_active`),
    INDEX `idx_services_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `hairstyles` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `name` VARCHAR(100) NOT NULL,
    `image_url` VARCHAR(255) NULL,
    `description` TEXT NULL,
    `hair_type` VARCHAR(50) NULL,
    `maintenance_level` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `related_service_id` CHAR(36) NULL,
    `estimated_duration_minutes` INT UNSIGNED NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT TRUE,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_hairstyles_active` (`is_active`),
    CONSTRAINT `fk_hairstyles_service` FOREIGN KEY (`related_service_id`) REFERENCES `services` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `hairstyle_face_shapes` (
    `hairstyle_id` CHAR(36) NOT NULL,
    `face_shape_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`hairstyle_id`, `face_shape_id`),
    CONSTRAINT `fk_hfs_hairstyle` FOREIGN KEY (`hairstyle_id`) REFERENCES `hairstyles` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_hfs_face_shape` FOREIGN KEY (`face_shape_id`) REFERENCES `face_shapes` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `customers` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `user_id` CHAR(36) NOT NULL,
    `full_name` VARCHAR(100) NOT NULL,
    `phone_number` VARCHAR(20) NOT NULL,
    `profile_picture_url` VARCHAR(255) NULL,
    `loyalty_points` INT UNSIGNED NOT NULL DEFAULT 0,
    `membership_id` CHAR(36) NULL,
    `favorite_barber_id` CHAR(36) NULL,
    `favorite_hairstyle_id` CHAR(36) NULL,
    `detected_face_shape_id` INT UNSIGNED NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_customers_user_id` (`user_id`),
    UNIQUE KEY `uk_customers_phone` (`phone_number`),
    INDEX `idx_customers_name` (`full_name`),
    CONSTRAINT `fk_customers_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_customers_membership` FOREIGN KEY (`membership_id`) REFERENCES `memberships` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT `fk_customers_fav_barber` FOREIGN KEY (`favorite_barber_id`) REFERENCES `barbers` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT `fk_customers_fav_hairstyle` FOREIGN KEY (`favorite_hairstyle_id`) REFERENCES `hairstyles` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT `fk_customers_face_shape` FOREIGN KEY (`detected_face_shape_id`) REFERENCES `face_shapes` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `barber_schedules` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `barber_id` CHAR(36) NOT NULL,
    `day_of_week` ENUM('Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu') NOT NULL,
    `start_time` TIME NULL,
    `end_time` TIME NULL,
    `is_off` BOOLEAN NOT NULL DEFAULT FALSE,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_barber_schedule_day` (`barber_id`, `day_of_week`),
    CONSTRAINT `fk_schedules_barber` FOREIGN KEY (`barber_id`) REFERENCES `barbers` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. AI ANALYSES & RECOMMENDATIONS
CREATE TABLE `ai_analyses` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `customer_id` CHAR(36) NULL,
    `detected_face_shape_id` INT UNSIGNED NOT NULL,
    `confidence_score` DECIMAL(5, 2) NOT NULL,
    `uploaded_image_url` VARCHAR(255) NULL,
    `analyzed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_ai_customer` (`customer_id`),
    CONSTRAINT `fk_ai_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT `fk_ai_face_shape` FOREIGN KEY (`detected_face_shape_id`) REFERENCES `face_shapes` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `ai_recommendations` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `analysis_id` CHAR(36) NOT NULL,
    `hairstyle_id` CHAR(36) NOT NULL,
    `match_percentage` DECIMAL(5, 2) NOT NULL,
    PRIMARY KEY (`id`),
    INDEX `idx_air_analysis` (`analysis_id`),
    CONSTRAINT `fk_air_analysis` FOREIGN KEY (`analysis_id`) REFERENCES `ai_analyses` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_air_hairstyle` FOREIGN KEY (`hairstyle_id`) REFERENCES `hairstyles` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. BOOKINGS, QUEUES, PAYMENTS, REVIEWS & HISTORY
CREATE TABLE `bookings` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `booking_code` VARCHAR(20) NOT NULL,
    `customer_id` CHAR(36) NOT NULL,
    `barber_id` CHAR(36) NOT NULL,
    `requested_hairstyle_id` CHAR(36) NULL,
    `booking_date` DATE NOT NULL,
    `start_time` TIME NOT NULL,
    `end_time` TIME NOT NULL,
    `status` ENUM('pending', 'confirmed', 'checked_in', 'in_queue', 'in_service', 'completed', 'cancelled', 'no_show') NOT NULL DEFAULT 'pending',
    `check_in_method` ENUM('none', 'gps_geofence', 'qr_scan_cashier', 'manual_cashier') NOT NULL DEFAULT 'none',
    `checked_in_at` TIMESTAMP NULL,
    `service_started_at` TIMESTAMP NULL,
    `service_completed_at` TIMESTAMP NULL,
    `total_price` DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `notes` TEXT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_bookings_code` (`booking_code`),
    INDEX `idx_bookings_customer` (`customer_id`),
    INDEX `idx_bookings_barber_date` (`barber_id`, `booking_date`),
    INDEX `idx_bookings_status` (`status`),
    INDEX `idx_bookings_date` (`booking_date`),
    CONSTRAINT `fk_bookings_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_bookings_barber` FOREIGN KEY (`barber_id`) REFERENCES `barbers` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_bookings_requested_style` FOREIGN KEY (`requested_hairstyle_id`) REFERENCES `hairstyles` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `booking_services` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `booking_id` CHAR(36) NOT NULL,
    `service_id` CHAR(36) NOT NULL,
    `price_at_booking` DECIMAL(12, 2) NOT NULL,
    PRIMARY KEY (`id`),
    INDEX `idx_bs_booking` (`booking_id`),
    CONSTRAINT `fk_bs_booking` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_bs_service` FOREIGN KEY (`service_id`) REFERENCES `services` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `queues` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `booking_id` CHAR(36) NOT NULL,
    `queue_number` VARCHAR(20) NOT NULL,
    `estimated_wait_time_mins` INT UNSIGNED NOT NULL DEFAULT 0,
    `people_before_count` INT UNSIGNED NOT NULL DEFAULT 0,
    `status` ENUM('waiting', 'in_progress', 'completed', 'skipped') NOT NULL DEFAULT 'waiting',
    `joined_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `called_at` TIMESTAMP NULL,
    `completed_at` TIMESTAMP NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_queues_booking` (`booking_id`),
    INDEX `idx_queues_status` (`status`),
    INDEX `idx_queues_joined` (`joined_at`),
    CONSTRAINT `fk_queues_booking` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `payments` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `booking_id` CHAR(36) NOT NULL,
    `payment_method` VARCHAR(30) NOT NULL DEFAULT 'QRIS',
    `qris_reference_id` VARCHAR(100) NULL,
    `qris_invoice_url` VARCHAR(255) NULL,
    `amount` DECIMAL(12, 2) NOT NULL,
    `status` ENUM('pending', 'paid', 'failed', 'expired', 'refunded') NOT NULL DEFAULT 'pending',
    `expires_at` TIMESTAMP NOT NULL,
    `paid_at` TIMESTAMP NULL DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_payments_booking` (`booking_id`),
    INDEX `idx_payments_qris_ref` (`qris_reference_id`),
    INDEX `idx_payments_status` (`status`),
    CONSTRAINT `fk_payments_booking` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `reviews` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `booking_id` CHAR(36) NOT NULL,
    `customer_id` CHAR(36) NOT NULL,
    `barber_id` CHAR(36) NOT NULL,
    `rating_barber` TINYINT UNSIGNED NOT NULL,
    `rating_service` TINYINT UNSIGNED NOT NULL,
    `hairstyle_satisfaction` TINYINT UNSIGNED NULL,
    `review_text` TEXT NULL,
    `haircut_result_image_url` VARCHAR(255) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_reviews_booking` (`booking_id`),
    INDEX `idx_reviews_barber` (`barber_id`),
    INDEX `idx_reviews_customer` (`customer_id`),
    CONSTRAINT `chk_rating_barber` CHECK (`rating_barber` BETWEEN 1 AND 5),
    CONSTRAINT `chk_rating_service` CHECK (`rating_service` BETWEEN 1 AND 5),
    CONSTRAINT `fk_reviews_booking` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_reviews_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_reviews_barber` FOREIGN KEY (`barber_id`) REFERENCES `barbers` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `customer_haircut_history` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `customer_id` CHAR(36) NOT NULL,
    `booking_id` CHAR(36) NOT NULL,
    `barber_id` CHAR(36) NOT NULL,
    `hairstyle_id` CHAR(36) NULL,
    `cut_date` DATE NOT NULL,
    `photo_url` VARCHAR(255) NULL,
    `notes` TEXT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_history_customer` (`customer_id`, `cut_date`),
    CONSTRAINT `fk_chh_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_chh_booking` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_chh_barber` FOREIGN KEY (`barber_id`) REFERENCES `barbers` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_chh_hairstyle` FOREIGN KEY (`hairstyle_id`) REFERENCES `hairstyles` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. PRODUCTS & INVENTORY
CREATE TABLE `products` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `sku` VARCHAR(50) NULL,
    `name` VARCHAR(100) NOT NULL,
    `category` VARCHAR(50) NOT NULL,
    `unit` VARCHAR(20) NOT NULL DEFAULT 'pcs',
    `stock_quantity` INT NOT NULL DEFAULT 0,
    `minimum_stock_alert` INT UNSIGNED NOT NULL DEFAULT 5,
    `unit_price` DECIMAL(12, 2) NOT NULL,
    `cost_price` DECIMAL(12, 2) NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT TRUE,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_products_sku` (`sku`),
    INDEX `idx_products_category` (`category`),
    INDEX `idx_products_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `inventory_transactions` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `product_id` CHAR(36) NOT NULL,
    `transaction_type` ENUM('stock_in', 'stock_out', 'adjustment') NOT NULL,
    `quantity` INT NOT NULL,
    `unit_price_at_transaction` DECIMAL(12, 2) NULL,
    `notes` TEXT NULL,
    `created_by_user_id` CHAR(36) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_inv_product` (`product_id`),
    INDEX `idx_inv_type` (`transaction_type`),
    CONSTRAINT `fk_inv_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_inv_creator` FOREIGN KEY (`created_by_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. LOYALTY, PROMOTIONS & NOTIFICATIONS
CREATE TABLE `loyalty_transactions` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `customer_id` CHAR(36) NOT NULL,
    `points` INT NOT NULL,
    `transaction_type` ENUM('earn', 'redeem', 'adjustment') NOT NULL,
    `reference_id` CHAR(36) NULL,
    `description` VARCHAR(255) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_loyalty_customer` (`customer_id`),
    CONSTRAINT `fk_loyalty_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `promotions` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `code` VARCHAR(50) NOT NULL,
    `title` VARCHAR(100) NOT NULL,
    `promo_category` ENUM('general', 'voucher', 'event', 'first_visit', 'birthday', 'membership') NOT NULL DEFAULT 'general',
    `discount_type` ENUM('percentage', 'fixed') NOT NULL,
    `discount_value` DECIMAL(12, 2) NOT NULL,
    `min_order_amount` DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `max_discount_amount` DECIMAL(12, 2) NULL,
    `quota` INT UNSIGNED NULL,
    `used_count` INT UNSIGNED NOT NULL DEFAULT 0,
    `target_membership_tier_id` CHAR(36) NULL,
    `start_date` DATE NOT NULL,
    `end_date` DATE NOT NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT TRUE,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_promotions_code` (`code`),
    INDEX `idx_promotions_active` (`is_active`, `start_date`, `end_date`),
    CONSTRAINT `fk_promotions_tier` FOREIGN KEY (`target_membership_tier_id`) REFERENCES `memberships` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `promotion_usages` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `promotion_id` CHAR(36) NOT NULL,
    `customer_id` CHAR(36) NOT NULL,
    `booking_id` CHAR(36) NOT NULL,
    `discount_applied` DECIMAL(12, 2) NOT NULL,
    `used_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_pu_customer` (`customer_id`),
    INDEX `idx_pu_booking` (`booking_id`),
    CONSTRAINT `fk_pu_promotion` FOREIGN KEY (`promotion_id`) REFERENCES `promotions` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_pu_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_pu_booking` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `notifications` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `user_id` CHAR(36) NOT NULL,
    `title` VARCHAR(150) NOT NULL,
    `body` TEXT NOT NULL,
    `type` ENUM('booking', 'reminder', 'queue', 'promotion', 'rebooking', 'system') NOT NULL DEFAULT 'system',
    `is_read` BOOLEAN NOT NULL DEFAULT FALSE,
    `data_payload` JSON NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_notifications_user` (`user_id`, `is_read`),
    CONSTRAINT `fk_notifications_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 6. STORE SETTINGS & SCHEDULES
CREATE TABLE `store_settings` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `setting_key` VARCHAR(100) NOT NULL,
    `setting_value` TEXT NOT NULL,
    `description` VARCHAR(255) NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_store_settings_key` (`setting_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `store_schedules` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `day_of_week` VARCHAR(20) NOT NULL,
    `status` ENUM('buka', 'tutup') NOT NULL DEFAULT 'buka',
    `open_time` TIME NULL,
    `close_time` TIME NULL,
    `is_locked` BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_store_schedules_day` (`day_of_week`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `store_holidays` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `start_date` DATE NOT NULL,
    `end_date` DATE NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    `type` ENUM('tanggal-libur', 'rentang-libur') NOT NULL DEFAULT 'tanggal-libur',
    `description` TEXT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_holidays_dates` (`start_date`, `end_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 7. ANALYTICAL VIEWS
CREATE OR REPLACE VIEW `v_dashboard_kpis` AS
SELECT 
    CURDATE() AS `date`,
    COALESCE(SUM(CASE WHEN p.`status` = 'paid' AND DATE(p.`paid_at`) = CURDATE() THEN p.`amount` ELSE 0 END), 0) AS `today_revenue`,
    COUNT(DISTINCT CASE WHEN b.`booking_date` = CURDATE() THEN b.`id` END) AS `today_appointments`,
    COUNT(DISTINCT CASE WHEN b.`booking_date` = CURDATE() THEN b.`customer_id` END) AS `today_customers`,
    COUNT(DISTINCT CASE WHEN b.`booking_date` = CURDATE() AND b.`status` = 'completed' THEN b.`id` END) AS `completed_services`,
    COUNT(DISTINCT CASE WHEN q.`status` = 'waiting' THEN q.`id` END) AS `currently_in_queue`
FROM `bookings` b
LEFT JOIN `payments` p ON b.`id` = p.`booking_id`
LEFT JOIN `queues` q ON b.`id` = q.`booking_id`;

CREATE OR REPLACE VIEW `v_ai_conversion_analytics` AS
SELECT 
    COUNT(a.`id`) AS `total_ai_scans`,
    COUNT(DISTINCT b.`id`) AS `converted_bookings`,
    ROUND(
        (COUNT(DISTINCT b.`id`) / NULLIF(COUNT(a.`id`), 0)) * 100, 
        2
    ) AS `ai_to_booking_conversion_rate_pct`
FROM `ai_analyses` a
LEFT JOIN `bookings` b ON a.`customer_id` = b.`customer_id` 
    AND b.`booking_date` >= DATE(a.`analyzed_at`)
    AND b.`status` IN ('confirmed', 'checked_in', 'in_queue', 'in_service', 'completed');

CREATE OR REPLACE VIEW `v_barber_leaderboard` AS
SELECT 
    b.`id` AS `barber_id`,
    b.`full_name` AS `barber_name`,
    b.`specialty`,
    b.`average_rating`,
    COUNT(DISTINCT CASE WHEN bk.`status` = 'completed' THEN bk.`id` END) AS `total_completed_services`,
    COALESCE(SUM(CASE WHEN bk.`status` = 'completed' AND p.`status` = 'paid' THEN p.`amount` ELSE 0 END), 0) AS `total_revenue_generated`
FROM `barbers` b
LEFT JOIN `bookings` bk ON b.`id` = bk.`barber_id`
LEFT JOIN `payments` p ON bk.`id` = p.`booking_id`
WHERE b.`is_active` = TRUE
GROUP BY b.`id`, b.`full_name`, b.`specialty`, b.`average_rating`
ORDER BY `total_completed_services` DESC, b.`average_rating` DESC;

CREATE OR REPLACE VIEW `v_popular_hairstyles` AS
SELECT 
    h.`id` AS `hairstyle_id`,
    h.`name` AS `hairstyle_name`,
    COUNT(DISTINCT ar.`id`) AS `times_recommended_by_ai`,
    COUNT(DISTINCT bk.`id`) AS `times_booked_by_customers`
FROM `hairstyles` h
LEFT JOIN `ai_recommendations` ar ON h.`id` = ar.`hairstyle_id`
LEFT JOIN `bookings` bk ON h.`id` = bk.`requested_hairstyle_id`
GROUP BY h.`id`, h.`name`
ORDER BY `times_booked_by_customers` DESC, `times_recommended_by_ai` DESC;

CREATE OR REPLACE VIEW `v_inventory_stock_alerts` AS
SELECT 
    `id` AS `product_id`,
    `sku`,
    `name` AS `product_name`,
    `category`,
    `stock_quantity`,
    `minimum_stock_alert`,
    (`minimum_stock_alert` - `stock_quantity`) AS `deficit_quantity`
FROM `products`
WHERE `stock_quantity` <= `minimum_stock_alert` AND `is_active` = TRUE
ORDER BY `stock_quantity` ASC;

-- ==============================================================================
-- INITIAL SEED DATA
-- ==============================================================================

INSERT INTO `face_shapes` (`id`, `shape_name`, `description`) VALUES
(1, 'Oval', 'Bentuk wajah proporsional dengan dagu sedikit melengkung. Cocok hampir untuk semua model rambut.'),
(2, 'Round', 'Wajah bulat dengan garis rahang lembut dan pipi penuh. Cocok dengan gaya bertingkat/volume di atas.'),
(3, 'Square', 'Garis rahang tegas dan lebar dahi seimbang. Cocok dengan model fade pendek atau texture crop.'),
(4, 'Heart', 'Dahi lebar dan dagu runcing menyerupai segitiga terbalik. Cocok dengan gaya poni samping.'),
(5, 'Diamond', 'Tulang pipi tinggi dan lebar dengan dahi serta dagu yang sempit. Cocok dengan fringe atau taper cut.'),
(6, 'Oblong', 'Bentuk wajah panjang/lonjong. Cocok dengan model yang memiliki volume samping seimbang.')
ON DUPLICATE KEY UPDATE `shape_name` = VALUES(`shape_name`), `description` = VALUES(`description`);

INSERT INTO `memberships` (`id`, `tier_name`, `discount_percentage`, `minimum_points_required`, `point_multiplier`, `priority_booking`, `free_service_quota`) VALUES
('m0000000-0000-0000-0000-000000000001', 'Silver', 5.00, 100, 1.00, FALSE, 0),
('m0000000-0000-0000-0000-000000000002', 'Gold', 10.00, 500, 1.25, TRUE, 1),
('m0000000-0000-0000-0000-000000000003', 'Platinum', 15.00, 1500, 1.50, TRUE, 3)
ON DUPLICATE KEY UPDATE `tier_name` = VALUES(`tier_name`);

INSERT INTO `users` (`id`, `email`, `password_hash`, `role`) VALUES
('u0000000-0000-0000-0000-000000000001', 'aditya@trim.id', '$2a$12$e8yM2dK5WvA8qKqj8/5Gzeu0uXk7n0Xk8vK3/b1q7w6YdC6Vf2d2i', 'owner'),
('u0000000-0000-0000-0000-000000000002', 'dimas@trim.id', '$2a$12$e8yM2dK5WvA8qKqj8/5Gzeu0uXk7n0Xk8vK3/b1q7w6YdC6Vf2d2i', 'admin'),
('u0000000-0000-0000-0000-000000000003', 'raka@trim.id', '$2a$12$e8yM2dK5WvA8qKqj8/5Gzeu0uXk7n0Xk8vK3/b1q7w6YdC6Vf2d2i', 'barber'),
('u0000000-0000-0000-0000-000000000004', 'alya@trim.id', '$2a$12$e8yM2dK5WvA8qKqj8/5Gzeu0uXk7n0Xk8vK3/b1q7w6YdC6Vf2d2i', 'customer')
ON DUPLICATE KEY UPDATE `email` = VALUES(`email`);

INSERT INTO `barbers` (`id`, `user_id`, `full_name`, `phone_number`, `specialty`, `experience_years`, `is_active`, `average_rating`, `total_reviews`) VALUES
('b0000000-0000-0000-0000-000000000001', 'u0000000-0000-0000-0000-000000000003', 'Raka Putra', '081234567890', 'Fade & taper', 4, TRUE, 4.90, 48)
ON DUPLICATE KEY UPDATE `full_name` = VALUES(`full_name`);

INSERT INTO `services` (`id`, `name`, `category`, `duration_minutes`, `price`, `description`, `is_active`) VALUES
('s0000000-0000-0000-0000-000000000001', 'Gentleman Haircut & Wash', 'Haircut', 45, 60000.00, 'Potongan rambut presisi, cuci rambut, dan pijat kepala rileks.', TRUE),
('s0000000-0000-0000-0000-000000000002', 'Classic Shave & Hot Towel', 'Grooming', 30, 40000.00, 'Cukur jenggot/kumis tradisional menggunakan pisau cukur dan handuk hangat.', TRUE),
('s0000000-0000-0000-0000-000000000003', 'Hair Styling & Pomade', 'Styling', 20, 25000.00, 'Penataan rambut profesional menggunakan pomade premium.', TRUE),
('s0000000-0000-0000-0000-000000000004', 'Full Grooming Combo', 'Package', 75, 100000.00, 'Paket komplit pangkas, cuci, cukur jenggot, dan styling.', TRUE)
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);

INSERT INTO `hairstyles` (`id`, `name`, `image_url`, `description`, `hair_type`, `maintenance_level`, `related_service_id`, `estimated_duration_minutes`, `is_active`) VALUES
('h0000000-0000-0000-0000-000000000001', 'Low Fade with Textured Crop', 'https://images.unsplash.com/photo-1622286342621-4bd786c2447c', 'Gradasi samping rendah dengan tekstur crop modern di bagian atas.', 'Lurus / Bergelombang', 2, 's0000000-0000-0000-0000-000000000001', 45, TRUE),
('h0000000-0000-0000-0000-000000000002', 'Classic Pompadour', 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1', 'Gaya klasik bervolume tinggi disisir ke belakang rapi.', 'Lurus / Tebal', 4, 's0000000-0000-0000-0000-000000000001', 45, TRUE),
('h0000000-0000-0000-0000-000000000003', 'Modern Mullet & Taper', 'https://images.unsplash.com/photo-1605497788044-5a32c7078486', 'Rambut samping taper bersih dengan rambut bagian belakang panjang berkarakter.', 'Bergelombang / Keriting', 3, 's0000000-0000-0000-0000-000000000001', 45, TRUE)
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);

INSERT INTO `hairstyle_face_shapes` (`hairstyle_id`, `face_shape_id`) VALUES
('h0000000-0000-0000-0000-000000000001', 1),
('h0000000-0000-0000-0000-000000000001', 3),
('h0000000-0000-0000-0000-000000000002', 2),
('h0000000-0000-0000-0000-000000000002', 3),
('h0000000-0000-0000-0000-000000000003', 1),
('h0000000-0000-0000-0000-000000000003', 4)
ON DUPLICATE KEY UPDATE `hairstyle_id` = VALUES(`hairstyle_id`);

INSERT INTO `customers` (`id`, `user_id`, `full_name`, `phone_number`, `loyalty_points`, `membership_id`, `favorite_barber_id`, `favorite_hairstyle_id`, `detected_face_shape_id`) VALUES
('c0000000-0000-0000-0000-000000000001', 'u0000000-0000-0000-0000-000000000004', 'Alya Lestari', '081298765432', 150, 'm0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'h0000000-0000-0000-0000-000000000001', 1)
ON DUPLICATE KEY UPDATE `full_name` = VALUES(`full_name`);

INSERT INTO `products` (`id`, `sku`, `name`, `category`, `unit`, `stock_quantity`, `minimum_stock_alert`, `unit_price`, `cost_price`, `is_active`) VALUES
('p0000000-0000-0000-0000-000000000001', 'POM-MATTE-01', 'Suavecito Matte Pomade 4oz', 'Pomade', 'jar', 25, 5, 140000.00, 95000.00, TRUE),
('p0000000-0000-0000-0000-000000000002', 'BRD-OIL-02', 'Beard Oil Peppermint 30ml', 'Beard Care', 'bottle', 18, 4, 85000.00, 50000.00, TRUE),
('p0000000-0000-0000-0000-000000000003', 'TNC-COOL-03', 'Menthol Cooling Tonic 250ml', 'Hair Tonic', 'bottle', 30, 8, 75000.00, 45000.00, TRUE)
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);

INSERT INTO `store_settings` (`setting_key`, `setting_value`, `description`) VALUES
('is_store_closed', 'false', 'Status buka/tutup darurat toko (true/false)'),
('holiday_date', '2026-12-25', 'Tanggal libur khusus toko terdekat (YYYY-MM-DD)'),
('store_name', 'TRIM Barbershop', 'Nama resmi barbershop'),
('store_address', 'Jl. Braga No. 45, Bandung, Jawa Barat', 'Alamat toko fisik'),
('store_phone', '081234567890', 'Nomor WhatsApp kontak customer service'),
('qris_merchant_name', 'TRIM Barbershop Bandung', 'Nama merchant yang tertera pada Pakkasir QRIS')
ON DUPLICATE KEY UPDATE `setting_value` = VALUES(`setting_value`);

INSERT INTO `store_schedules` (`day_of_week`, `status`, `open_time`, `close_time`, `is_locked`) VALUES
('Senin', 'buka', '08:00:00', '18:00:00', FALSE),
('Selasa', 'buka', '08:00:00', '18:00:00', FALSE),
('Rabu', 'buka', '08:00:00', '18:00:00', FALSE),
('Kamis', 'buka', '08:00:00', '18:00:00', FALSE),
('Jumat', 'buka', '08:00:00', '19:00:00', FALSE),
('Sabtu', 'buka', '09:00:00', '20:00:00', FALSE),
('Minggu', 'tutup', NULL, NULL, TRUE)
ON DUPLICATE KEY UPDATE `status` = VALUES(`status`), `open_time` = VALUES(`open_time`), `close_time` = VALUES(`close_time`);

INSERT INTO `store_holidays` (`id`, `start_date`, `end_date`, `name`, `type`, `description`) VALUES
(1, '2026-12-25', '2026-12-25', 'Hari Raya Natal', 'tanggal-libur', 'Libur Nasional — Hari Raya Natal'),
(2, '2027-01-01', '2027-01-01', 'Tahun Baru 2027', 'tanggal-libur', 'Libur Nasional — Tahun Baru Masehi')
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);
