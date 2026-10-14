-- ==============================================================================
-- DATABASE SCHEMA & ANALYTICS: TRIM - AI-POWERED BARBERSHOP SYSTEM
-- Dokumen Acuan: TRIM_TRD.md, TRIM_PRD.md & TRIM_FSD.md
-- Target DBMS: MySQL 8.0+ / MariaDB 10.5+
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

-- ==============================================================================
-- 1. USERS, MEMBERSHIPS & PROFILES (RBAC)
-- ==============================================================================

-- Tabel Users: Akun login sentral (PRD 6, TRD 30: Owner, Manager, Admin, Barber, Customer)
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

-- Tabel Memberships: Tingkatan keanggotaan (FSD 23: Silver, Gold, Platinum)
CREATE TABLE `memberships` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `tier_name` VARCHAR(50) NOT NULL,
    `discount_percentage` DECIMAL(5, 2) NOT NULL DEFAULT 0.00,
    `minimum_points_required` INT UNSIGNED NOT NULL DEFAULT 0,
    `point_multiplier` DECIMAL(3, 2) NOT NULL DEFAULT 1.00 COMMENT 'Bonus poin untuk member',
    `priority_booking` BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Hak istimewa antrean prioritas',
    `free_service_quota` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Kouta gratis servis per tahun',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_memberships_tier` (`tier_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabel Master Bentuk Wajah (FSD 11: Oval, Round, Square, Oblong, Heart, Diamond)
CREATE TABLE `face_shapes` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `shape_name` VARCHAR(50) NOT NULL,
    `description` TEXT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_face_shapes_name` (`shape_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabel Barbers: Profil kapster (FSD 14, Epic 3)
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

-- Tabel Services: Katalog paket dan layanan pangkas (FSD 13)
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

-- Tabel Hairstyles: Katalog model gaya rambut (FSD 12)
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

-- Pivot Table: Model rambut yang sesuai dengan bentuk wajah (FSD 11 & 12)
CREATE TABLE `hairstyle_face_shapes` (
    `hairstyle_id` CHAR(36) NOT NULL,
    `face_shape_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`hairstyle_id`, `face_shape_id`),
    CONSTRAINT `fk_hfs_hairstyle` FOREIGN KEY (`hairstyle_id`) REFERENCES `hairstyles` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_hfs_face_shape` FOREIGN KEY (`face_shape_id`) REFERENCES `face_shapes` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabel Customers: Profil pelanggan (FSD 10: favorit barber, favorit gaya, bentuk wajah, poin)
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

-- Tabel Barber Schedules: Shift kerja berkala kapster (FSD 15)
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

-- ==============================================================================
-- 2. MODUL AI HAIR ADVISOR (FSD 11, PRD 25 & FSD 40 EPIC 1)
-- ==============================================================================

-- Tabel AI Analyses: Riwayat deteksi computer vision
CREATE TABLE `ai_analyses` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `customer_id` CHAR(36) NULL,
    `detected_face_shape_id` INT UNSIGNED NOT NULL,
    `confidence_score` DECIMAL(5, 2) NOT NULL,
    `uploaded_image_url` VARCHAR(255) NULL COMMENT 'Foto diproses sementara & dihapus sesuai etika privasi',
    `analyzed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_ai_customer` (`customer_id`),
    INDEX `idx_ai_date` (`analyzed_at`),
    CONSTRAINT `fk_ai_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT `fk_ai_face_shape` FOREIGN KEY (`detected_face_shape_id`) REFERENCES `face_shapes` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabel AI Recommendations: Rekomendasi gaya rambut teratas
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

-- ==============================================================================
-- 3. BOOKINGS, QUEUES, PAYMENTS & REVIEWS (FSD 16-21, EPIC 2 & 3)
-- ==============================================================================

-- Tabel Bookings: Reservasi pangkas rambut
CREATE TABLE `bookings` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `booking_code` VARCHAR(20) NOT NULL,
    `customer_id` CHAR(36) NOT NULL,
    `barber_id` CHAR(36) NOT NULL,
    `requested_hairstyle_id` CHAR(36) NULL COMMENT 'Gaya rambut yang di-request diawal oleh customer (FSD 16 & Epic 3)',
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

-- Tabel Booking Services: Relasi Many-to-Many booking dan item layanan
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

-- Tabel Queues: Antrean fisik digital (FSD 17, Epic 2 AC 2.4)
CREATE TABLE `queues` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `booking_id` CHAR(36) NOT NULL,
    `queue_number` VARCHAR(20) NOT NULL COMMENT 'Format nomor antrean e.g. A-023',
    `estimated_wait_time_mins` INT UNSIGNED NOT NULL DEFAULT 0,
    `people_before_count` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Jumlah orang di depan antrean',
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

-- Tabel Payments: Transaksi QRIS via Pakkasir (FSD 19, Epic 2 AC 2.2: 15 menit countdown)
CREATE TABLE `payments` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `booking_id` CHAR(36) NOT NULL,
    `payment_method` VARCHAR(30) NOT NULL DEFAULT 'QRIS',
    `qris_reference_id` VARCHAR(100) NULL COMMENT 'Ref ID dari Pakkasir QRIS Gateway',
    `qris_invoice_url` VARCHAR(255) NULL,
    `amount` DECIMAL(12, 2) NOT NULL,
    `status` ENUM('pending', 'paid', 'failed', 'expired', 'refunded') NOT NULL DEFAULT 'pending',
    `expires_at` TIMESTAMP NOT NULL COMMENT 'Batas waktu bayar QRIS (15 menit sejak terbit)',
    `paid_at` TIMESTAMP NULL DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_payments_booking` (`booking_id`),
    INDEX `idx_payments_qris_ref` (`qris_reference_id`),
    INDEX `idx_payments_status` (`status`),
    INDEX `idx_payments_expires` (`expires_at`),
    CONSTRAINT `fk_payments_booking` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabel Reviews: Ulasan, rating kapster, servis, kepuasan gaya & foto hasil cukur (FSD 21, Epic 3)
CREATE TABLE `reviews` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `booking_id` CHAR(36) NOT NULL,
    `customer_id` CHAR(36) NOT NULL,
    `barber_id` CHAR(36) NOT NULL,
    `rating_barber` TINYINT UNSIGNED NOT NULL,
    `rating_service` TINYINT UNSIGNED NOT NULL,
    `hairstyle_satisfaction` TINYINT UNSIGNED NULL COMMENT 'Skala kepuasan gaya rambut 1-5 (FSD 21)',
    `review_text` TEXT NULL,
    `haircut_result_image_url` VARCHAR(255) NULL COMMENT 'Foto riwayat potongan terakhir customer (FSD Epic 3 AC 3.2)',
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

-- Tabel Customer Haircut History: Riwayat foto & potongan haircut untuk kapster (FSD Epic 3 AC 3.2)
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

-- ==============================================================================
-- 4. PRODUCTS & INVENTORY MANAGEMENT (FSD 25)
-- ==============================================================================

-- Tabel Products: Master produk (Pomade, Wax, Shampoo, Hair tonic, Hair color, Towel, Consumables)
CREATE TABLE `products` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `sku` VARCHAR(50) NULL,
    `name` VARCHAR(100) NOT NULL,
    `category` VARCHAR(50) NOT NULL,
    `unit` VARCHAR(20) NOT NULL DEFAULT 'pcs',
    `stock_quantity` INT NOT NULL DEFAULT 0,
    `minimum_stock_alert` INT UNSIGNED NOT NULL DEFAULT 5,
    `unit_price` DECIMAL(12, 2) NOT NULL COMMENT 'Harga jual',
    `cost_price` DECIMAL(12, 2) NULL COMMENT 'Harga modal untuk laporan laba kotor',
    `is_active` BOOLEAN NOT NULL DEFAULT TRUE,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_products_sku` (`sku`),
    INDEX `idx_products_category` (`category`),
    INDEX `idx_products_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabel Inventory Transactions: Log mutasi stok produk (FSD 25)
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

-- ==============================================================================
-- 5. LOYALTY, PROMOTIONS & NOTIFICATIONS (FSD 22, 24, 26)
-- ==============================================================================

-- Tabel Loyalty Transactions: Transaksi poin loyalitas (FSD 22: Rp10.000 = 10 pts)
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

-- Tabel Promotions: Voucher & kupon diskon (FSD 24: Kategori promo, kuota, target member)
CREATE TABLE `promotions` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `code` VARCHAR(50) NOT NULL,
    `title` VARCHAR(100) NOT NULL,
    `promo_category` ENUM('general', 'voucher', 'event', 'first_visit', 'birthday', 'membership') NOT NULL DEFAULT 'general',
    `discount_type` ENUM('percentage', 'fixed') NOT NULL,
    `discount_value` DECIMAL(12, 2) NOT NULL,
    `min_order_amount` DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `max_discount_amount` DECIMAL(12, 2) NULL,
    `quota` INT UNSIGNED NULL COMMENT 'Batas kuota total pemakaian',
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

-- Tabel Promotion Usages: Catatan penggunaan kupon promo oleh pelanggan
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

-- Tabel Notifications: Notifikasi FCM & In-App (FSD 26: Booking, Reminder, Queue, Promo, Rebooking)
CREATE TABLE `notifications` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `user_id` CHAR(36) NOT NULL,
    `title` VARCHAR(150) NOT NULL,
    `body` TEXT NOT NULL,
    `type` ENUM('booking', 'reminder', 'queue', 'promotion', 'rebooking', 'system') NOT NULL DEFAULT 'system',
    `is_read` BOOLEAN NOT NULL DEFAULT FALSE,
    `data_payload` JSON NULL COMMENT 'Data spesifik FCM (booking_id, queue_number, url)',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_notifications_user` (`user_id`, `is_read`),
    CONSTRAINT `fk_notifications_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 6. STORE SETTINGS, SCHEDULES & HOLIDAYS (FSD 15, FSD 40 EPIC 5)
-- ==============================================================================

-- Tabel Store Settings: Konfigurasi sistem dinamis (FSD Epic 5 AC 5.2)
CREATE TABLE `store_settings` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `setting_key` VARCHAR(100) NOT NULL,
    `setting_value` TEXT NOT NULL,
    `description` VARCHAR(255) NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_store_settings_key` (`setting_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabel Store Schedules: Jam operasional toko
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

-- Tabel Store Holidays: Kalender hari libur operasional (FSD Epic 5 AC 5.2)
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

-- ==============================================================================
-- 7. DATABASE VIEWS UNTUK DASHBOARD & BUSINESS ANALYTICS (PRD 27-29 & FSD 27-29, EPIC 4)
-- ==============================================================================

-- View 1: KPI Dashboard Utama Real-Time (FSD 27: Today's Revenue, Appointments, Customers, Completed)
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

-- View 2: Analisis Konversi AI ke Reservasi (FSD 28 & Epic 4 AC 4.2: AI to Booking Conversion Rate)
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

-- View 3: Leaderboard Performa Kapster (FSD Epic 4 AC 4.3 & FSD 29: Completed Service, Rating, Revenue)
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

-- View 4: Model Rambut Terpopuler & Paling Banyak Direkomendasikan AI (PRD 27 & FSD 28)
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

-- View 5: Peringatan Stok Minimum Inventaris (FSD 25: Stock <= Minimum Stock Alert)
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
-- 8. STORED PROCEDURES & TRIGGERS (FSD 22, EPIC 2 AC 2.2)
-- ==============================================================================

DELIMITER $$

-- Procedure: Membatalkan otomatis transaksi QRIS yang telah kedaluwarsa (> 15 menit)
-- Sesuai FSD Epic 2 AC 2.2
CREATE PROCEDURE `sp_auto_cancel_expired_payments`()
BEGIN
    -- Update status pembayaran yang lewat batas waktu 15 menit
    UPDATE `payments`
    SET `status` = 'expired', `updated_at` = CURRENT_TIMESTAMP
    WHERE `status` = 'pending' AND `expires_at` < CURRENT_TIMESTAMP;

    -- Update booking terkait menjadi cancelled jika pembayarannya expired
    UPDATE `bookings` b
    JOIN `payments` p ON b.`id` = p.`booking_id`
    SET b.`status` = 'cancelled', b.`updated_at` = CURRENT_TIMESTAMP
    WHERE p.`status` = 'expired' AND b.`status` = 'pending';
END$$

-- Trigger: Otomatis tambahkan loyalty points saat pembayaran lunas
-- Sesuai FSD Section 22: Rp10.000 = 10 poin (1 poin per Rp1.000)
CREATE TRIGGER `trg_after_payment_paid`
AFTER UPDATE ON `payments`
FOR EACH ROW
BEGIN
    DECLARE v_customer_id CHAR(36);
    DECLARE v_points INT;

    -- Cek jika status berubah menjadi 'paid'
    IF OLD.`status` <> 'paid' AND NEW.`status` = 'paid' THEN
        -- Ambil customer_id dari booking
        SELECT `customer_id` INTO v_customer_id 
        FROM `bookings` 
        WHERE `id` = NEW.`booking_id`;

        -- Hitung poin: kelipatan 10.000 bernilai 10 poin
        SET v_points = FLOOR(NEW.`amount` / 1000);

        IF v_points > 0 AND v_customer_id IS NOT NULL THEN
            -- Tambahkan poin ke tabel customers
            UPDATE `customers`
            SET `loyalty_points` = `loyalty_points` + v_points
            WHERE `id` = v_customer_id;

            -- Catat ke log loyalty_transactions
            INSERT INTO `loyalty_transactions` (
                `id`, `customer_id`, `points`, `transaction_type`, `reference_id`, `description`
            ) VALUES (
                UUID(), v_customer_id, v_points, 'earn', NEW.`booking_id`, 'Perolehan poin dari transaksi booking QRIS'
            );
        END IF;
    END IF;
END$$

DELIMITER ;
