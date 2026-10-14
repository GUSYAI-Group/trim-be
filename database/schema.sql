-- ==============================================================================
-- DATABASE SCHEMA: TRIM - AI-Powered Barbershop Information System
-- Berdasarkan Dokumen: TRIM_TRD.md (Technical Requirements Document)
-- Target DBMS: MySQL 8.0+ / MariaDB 10.5+
-- Engine: InnoDB | Charset: utf8mb4 | Collation: utf8mb4_unicode_ci
-- ==============================================================================

CREATE DATABASE IF NOT EXISTS `trim_db` 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE `trim_db`;

-- Nonaktifkan pengecekan foreign key selama drop/create tabel
SET FOREIGN_KEY_CHECKS = 0;

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
-- 1. MODUL AUTENTIKASI & PENGGUNA (USERS & MEMBERSHIPS)
-- ==============================================================================

-- Tabel Users: Akun login sentral untuk seluruh role (RBAC)
CREATE TABLE `users` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `email` VARCHAR(191) NOT NULL,
    `password_hash` VARCHAR(255) NOT NULL,
    `role` ENUM('owner', 'admin', 'barber', 'customer') NOT NULL DEFAULT 'customer',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_users_email` (`email`),
    INDEX `idx_users_role` (`role`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabel Memberships: Tingkatan keanggotaan customer (Silver, Gold, Platinum)
CREATE TABLE `memberships` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `tier_name` VARCHAR(50) NOT NULL,
    `discount_percentage` DECIMAL(5, 2) NOT NULL DEFAULT 0.00,
    `minimum_points_required` INT UNSIGNED NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_memberships_tier` (`tier_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabel Customers: Profil data spesifik pelanggan
CREATE TABLE `customers` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `user_id` CHAR(36) NOT NULL,
    `full_name` VARCHAR(100) NOT NULL,
    `phone_number` VARCHAR(20) NOT NULL,
    `profile_picture_url` VARCHAR(255) NULL,
    `loyalty_points` INT UNSIGNED NOT NULL DEFAULT 0,
    `membership_id` CHAR(36) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_customers_user_id` (`user_id`),
    UNIQUE KEY `uk_customers_phone` (`phone_number`),
    INDEX `idx_customers_name` (`full_name`),
    CONSTRAINT `fk_customers_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_customers_membership` FOREIGN KEY (`membership_id`) REFERENCES `memberships` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabel Barbers: Profil kapster / tukang cukur
CREATE TABLE `barbers` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `user_id` CHAR(36) NOT NULL,
    `full_name` VARCHAR(100) NOT NULL,
    `phone_number` VARCHAR(20) NOT NULL,
    `profile_picture_url` VARCHAR(255) NULL,
    `specialty` VARCHAR(100) NOT NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT TRUE,
    `average_rating` DECIMAL(3, 2) NOT NULL DEFAULT 0.00,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_barbers_user_id` (`user_id`),
    UNIQUE KEY `uk_barbers_phone` (`phone_number`),
    INDEX `idx_barbers_active` (`is_active`),
    CONSTRAINT `fk_barbers_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabel Barber Schedules: Jadwal shift harian kapster
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
-- 2. MODUL LAYANAN, GAYA RAMBUT & ANALISIS AI
-- ==============================================================================

-- Tabel Services: Katalog paket / layanan pangkas
CREATE TABLE `services` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `name` VARCHAR(100) NOT NULL,
    `category` VARCHAR(50) NOT NULL DEFAULT 'Haircut',
    `duration_minutes` INT UNSIGNED NOT NULL DEFAULT 30,
    `price` DECIMAL(12, 2) NOT NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT TRUE,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_services_active` (`is_active`),
    INDEX `idx_services_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabel Face Shapes: Master bentuk wajah (Oval, Round, Square, dll)
CREATE TABLE `face_shapes` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `shape_name` VARCHAR(50) NOT NULL,
    `description` TEXT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_face_shapes_name` (`shape_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabel Hairstyles: Katalog model gaya rambut
CREATE TABLE `hairstyles` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `name` VARCHAR(100) NOT NULL,
    `image_url` VARCHAR(255) NULL,
    `description` TEXT NULL,
    `hair_type` VARCHAR(50) NULL,
    `maintenance_level` TINYINT UNSIGNED NOT NULL DEFAULT 1, -- Skala 1 (mudah) s/d 5 (sulit)
    `is_active` BOOLEAN NOT NULL DEFAULT TRUE,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_hairstyles_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabel Pivot: Hubungan Many-to-Many antara Model Rambut dan Kecocokan Bentuk Wajah
CREATE TABLE `hairstyle_face_shapes` (
    `hairstyle_id` CHAR(36) NOT NULL,
    `face_shape_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`hairstyle_id`, `face_shape_id`),
    CONSTRAINT `fk_hfs_hairstyle` FOREIGN KEY (`hairstyle_id`) REFERENCES `hairstyles` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_hfs_face_shape` FOREIGN KEY (`face_shape_id`) REFERENCES `face_shapes` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabel AI Analyses: Riwayat deteksi bentuk wajah oleh AI Computer Vision
CREATE TABLE `ai_analyses` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `customer_id` CHAR(36) NULL, -- Bisa NULL bila pengguna anonim/tamu
    `detected_face_shape_id` INT UNSIGNED NOT NULL,
    `confidence_score` DECIMAL(5, 2) NOT NULL,
    `uploaded_image_url` VARCHAR(255) NULL COMMENT 'Temporary image URL as per AI ethics privacy policy',
    `analyzed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_ai_customer` (`customer_id`),
    CONSTRAINT `fk_ai_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT `fk_ai_face_shape` FOREIGN KEY (`detected_face_shape_id`) REFERENCES `face_shapes` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabel AI Recommendations: Rekomendasi gaya rambut berdasarkan hasil analisis
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
-- 3. MODUL RESERVASI (BOOKING), ANTREAN (QUEUE) & TRANSAKSI PEMBAYARAN
-- ==============================================================================

-- Tabel Bookings: Reservasi pangkas oleh pelanggan
CREATE TABLE `bookings` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `booking_code` VARCHAR(20) NOT NULL, -- e.g. TRM-20261014-001
    `customer_id` CHAR(36) NOT NULL,
    `barber_id` CHAR(36) NOT NULL,
    `booking_date` DATE NOT NULL,
    `start_time` TIME NOT NULL,
    `end_time` TIME NOT NULL,
    `status` ENUM('pending', 'confirmed', 'checked_in', 'in_queue', 'in_service', 'completed', 'cancelled', 'no_show') NOT NULL DEFAULT 'pending',
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
    CONSTRAINT `fk_bookings_barber` FOREIGN KEY (`barber_id`) REFERENCES `barbers` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabel Booking Services: Layanan yang dipilih dalam satu reservasi (Many-to-Many)
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

-- Tabel Queues: Antrean fisik / check-in di barbershop
CREATE TABLE `queues` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `booking_id` CHAR(36) NOT NULL,
    `queue_number` VARCHAR(20) NOT NULL, -- e.g. A-023
    `estimated_wait_time_mins` INT UNSIGNED NOT NULL DEFAULT 0,
    `status` ENUM('waiting', 'in_progress', 'completed', 'skipped') NOT NULL DEFAULT 'waiting',
    `joined_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_queues_booking` (`booking_id`),
    INDEX `idx_queues_status` (`status`),
    INDEX `idx_queues_joined` (`joined_at`),
    CONSTRAINT `fk_queues_booking` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabel Payments: Transaksi pembayaran (Pakkasir QRIS Gateway)
CREATE TABLE `payments` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `booking_id` CHAR(36) NOT NULL,
    `qris_reference_id` VARCHAR(100) NULL COMMENT 'Ref ID dari payment gateway Pakkasir',
    `amount` DECIMAL(12, 2) NOT NULL,
    `status` ENUM('pending', 'paid', 'failed', 'refunded') NOT NULL DEFAULT 'pending',
    `paid_at` TIMESTAMP NULL DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_payments_booking` (`booking_id`),
    INDEX `idx_payments_qris_ref` (`qris_reference_id`),
    INDEX `idx_payments_status` (`status`),
    CONSTRAINT `fk_payments_booking` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabel Reviews: Ulasan dan rating dari pelanggan setelah selesai pangkas
CREATE TABLE `reviews` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `booking_id` CHAR(36) NOT NULL,
    `customer_id` CHAR(36) NOT NULL,
    `barber_id` CHAR(36) NOT NULL,
    `rating_barber` TINYINT UNSIGNED NOT NULL,
    `rating_service` TINYINT UNSIGNED NOT NULL,
    `review_text` TEXT NULL,
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

-- ==============================================================================
-- 4. MODUL INVENTARIS PRODUK & TRANSAKSI STOK
-- ==============================================================================

-- Tabel Products: Produk ritel barbershop (pomade, shampoo, tonic, dll)
CREATE TABLE `products` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `name` VARCHAR(100) NOT NULL,
    `category` VARCHAR(50) NOT NULL, -- Pomade, Shampoo, dll
    `stock_quantity` INT NOT NULL DEFAULT 0,
    `minimum_stock_alert` INT UNSIGNED NOT NULL DEFAULT 5,
    `unit_price` DECIMAL(12, 2) NOT NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT TRUE,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_products_category` (`category`),
    INDEX `idx_products_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabel Inventory Transactions: Log mutasi stok produk (masuk, keluar, penyesuaian)
CREATE TABLE `inventory_transactions` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `product_id` CHAR(36) NOT NULL,
    `transaction_type` ENUM('stock_in', 'stock_out', 'adjustment') NOT NULL,
    `quantity` INT NOT NULL,
    `notes` TEXT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_inv_product` (`product_id`),
    INDEX `idx_inv_type` (`transaction_type`),
    CONSTRAINT `fk_inv_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 5. MODUL LOYALITAS (POINTS), PROMOSI & NOTIFIKASI FCM
-- ==============================================================================

-- Tabel Loyalty Transactions: Riwayat perolehan & penukaran poin loyalitas
CREATE TABLE `loyalty_transactions` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `customer_id` CHAR(36) NOT NULL,
    `points` INT NOT NULL, -- Positif (+) earn, negatif (-) redeem
    `transaction_type` ENUM('earn', 'redeem', 'adjustment') NOT NULL,
    `reference_id` CHAR(36) NULL, -- ID booking / payment jika terkait
    `description` VARCHAR(255) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_loyalty_customer` (`customer_id`),
    CONSTRAINT `fk_loyalty_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabel Promotions: Voucher & kupon diskon
CREATE TABLE `promotions` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `code` VARCHAR(50) NOT NULL,
    `title` VARCHAR(100) NOT NULL,
    `discount_type` ENUM('percentage', 'fixed') NOT NULL,
    `discount_value` DECIMAL(12, 2) NOT NULL,
    `min_order_amount` DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `max_discount_amount` DECIMAL(12, 2) NULL,
    `start_date` DATE NOT NULL,
    `end_date` DATE NOT NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT TRUE,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_promotions_code` (`code`),
    INDEX `idx_promotions_active` (`is_active`, `start_date`, `end_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabel Promotion Usages: Catatan penggunaan voucher oleh customer
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

-- Tabel Notifications: Notifikasi push FCM (Firebase Cloud Messaging) & in-app
CREATE TABLE `notifications` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()),
    `user_id` CHAR(36) NOT NULL,
    `title` VARCHAR(150) NOT NULL,
    `body` TEXT NOT NULL,
    `type` VARCHAR(50) NOT NULL DEFAULT 'system', -- 'booking', 'queue', 'payment', 'promo', 'system'
    `is_read` BOOLEAN NOT NULL DEFAULT FALSE,
    `data_payload` JSON NULL, -- Menyimpan payload JSON untuk FCM (e.g. { "booking_id": "..." })
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_notifications_user` (`user_id`, `is_read`),
    CONSTRAINT `fk_notifications_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 6. MODUL PENGATURAN TOKO (STORE SETTINGS & SCHEDULES)
-- ==============================================================================

-- Tabel Store Settings: Konfigurasi key-value aplikasi (is_store_closed, holiday_date, dll)
CREATE TABLE `store_settings` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `setting_key` VARCHAR(100) NOT NULL,
    `setting_value` TEXT NOT NULL,
    `description` VARCHAR(255) NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_store_settings_key` (`setting_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabel Store Schedules: Jadwal operasional mingguan barbershop
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

-- Tabel Store Holidays: Kalender hari libur khusus toko
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
