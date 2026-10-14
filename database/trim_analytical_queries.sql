-- ==============================================================================
-- BUSINESS & ANALYTICAL SQL QUERIES: TRIM BARBERSHOP
-- Berdasarkan Dokumen: TRIM_PRD.md & TRIM_FSD.md
-- Modul: Dashboard KPI, AI Analytics, Business Reports (Section 27, 28, 29 & Epic 4)
-- ==============================================================================

USE `trim_db`;

-- ------------------------------------------------------------------------------
-- 1. EPIC 4 AC 4.1: LAPORAN PENDAPATAN HARIAN, MINGGUAN & BULANAN
-- ------------------------------------------------------------------------------

-- 1.1 Pendapatan Harian (30 hari terakhir)
SELECT 
    DATE(p.`paid_at`) AS `transaction_date`,
    COUNT(p.`id`) AS `total_transactions`,
    SUM(p.`amount`) AS `daily_revenue`
FROM `payments` p
WHERE p.`status` = 'paid' 
  AND p.`paid_at` >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY DATE(p.`paid_at`)
ORDER BY `transaction_date` DESC;

-- 1.2 Pendapatan Bulanan Tahun Berjalan
SELECT 
    DATE_FORMAT(p.`paid_at`, '%Y-%m') AS `month_period`,
    COUNT(p.`id`) AS `total_transactions`,
    SUM(p.`amount`) AS `monthly_revenue`
FROM `payments` p
WHERE p.`status` = 'paid' 
  AND YEAR(p.`paid_at`) = YEAR(CURDATE())
GROUP BY DATE_FORMAT(p.`paid_at`, '%Y-%m')
ORDER BY `month_period` ASC;

-- ------------------------------------------------------------------------------
-- 2. EPIC 4 AC 4.2 & FSD 28: METRIK KONVERSI FITUR TRIM AI
-- "AI to Booking Conversion Rate" = (Jumlah Booking Sukses / Jumlah Scan Wajah) * 100%
-- ------------------------------------------------------------------------------
SELECT 
    (SELECT COUNT(*) FROM `ai_analyses`) AS `total_face_scans`,
    (SELECT COUNT(DISTINCT `customer_id`) FROM `ai_analyses`) AS `unique_customers_scanned`,
    (SELECT COUNT(DISTINCT b.`id`) 
     FROM `bookings` b 
     JOIN `ai_analyses` a ON b.`customer_id` = a.`customer_id`
     WHERE b.`booking_date` >= DATE(a.`analyzed_at`)
       AND b.`status` IN ('confirmed', 'checked_in', 'in_queue', 'in_service', 'completed')
    ) AS `ai_converted_bookings`,
    ROUND(
        ((SELECT COUNT(DISTINCT b.`id`) 
          FROM `bookings` b 
          JOIN `ai_analyses` a ON b.`customer_id` = a.`customer_id`
          WHERE b.`booking_date` >= DATE(a.`analyzed_at`)
            AND b.`status` IN ('confirmed', 'checked_in', 'in_queue', 'in_service', 'completed')) 
         / NULLIF((SELECT COUNT(*) FROM `ai_analyses`), 0)) * 100, 
        2
    ) AS `ai_to_booking_conversion_rate_percent`;

-- ------------------------------------------------------------------------------
-- 3. EPIC 4 AC 4.3 & FSD 29: LEADERBOARD PERFORMA KAPSTER BULAN INI
-- ------------------------------------------------------------------------------
SELECT 
    b.`full_name` AS `barber_name`,
    b.`specialty`,
    b.`average_rating`,
    COUNT(bk.`id`) AS `completed_services_count`,
    COALESCE(SUM(p.`amount`), 0) AS `revenue_generated`
FROM `barbers` b
LEFT JOIN `bookings` bk ON b.`id` = bk.`barber_id` 
    AND bk.`status` = 'completed'
    AND MONTH(bk.`booking_date`) = MONTH(CURDATE())
    AND YEAR(bk.`booking_date`) = YEAR(CURDATE())
LEFT JOIN `payments` p ON bk.`id` = p.`booking_id` 
    AND p.`status` = 'paid'
WHERE b.`is_active` = TRUE
GROUP BY b.`id`, b.`full_name`, b.`specialty`, b.`average_rating`
ORDER BY `completed_services_count` DESC, b.`average_rating` DESC;

-- ------------------------------------------------------------------------------
-- 4. FSD 27: ANALISIS JAM SIBUK (PEAK HOURS ANALYTICS)
-- ------------------------------------------------------------------------------
SELECT 
    HOUR(b.`start_time`) AS `booking_hour`,
    CONCAT(HOUR(b.`start_time`), ':00 - ', HOUR(b.`start_time`) + 1, ':00') AS `hour_range`,
    COUNT(b.`id`) AS `total_bookings`
FROM `bookings` b
WHERE b.`status` IN ('confirmed', 'checked_in', 'in_queue', 'in_service', 'completed')
GROUP BY HOUR(b.`start_time`)
ORDER BY `total_bookings` DESC;

-- ------------------------------------------------------------------------------
-- 5. FSD 29: LAPORAN LAYANAN TERPOPULER (SERVICE POPULARITY & REVENUE)
-- ------------------------------------------------------------------------------
SELECT 
    s.`name` AS `service_name`,
    s.`category`,
    COUNT(bs.`id`) AS `order_frequency`,
    SUM(bs.`price_at_booking`) AS `total_service_revenue`
FROM `services` s
JOIN `booking_services` bs ON s.`id` = bs.`service_id`
JOIN `bookings` b ON bs.`booking_id` = b.`id`
WHERE b.`status` = 'completed'
GROUP BY s.`id`, s.`name`, s.`category`
ORDER BY `order_frequency` DESC;

-- ------------------------------------------------------------------------------
-- 6. FSD 29: LAPORAN RETENSI PELANGGAN (NEW VS RETURNING CUSTOMERS)
-- ------------------------------------------------------------------------------
SELECT 
    CASE 
        WHEN customer_stats.total_bookings = 1 THEN 'Pelanggan Baru (1x Cut)'
        WHEN customer_stats.total_bookings BETWEEN 2 AND 4 THEN 'Pelanggan Kembali (2-4x Cut)'
        ELSE 'Pelanggan Loyal (>4x Cut)'
    END AS `customer_segment`,
    COUNT(*) AS `customer_count`
FROM (
    SELECT `customer_id`, COUNT(`id`) AS `total_bookings`
    FROM `bookings`
    WHERE `status` = 'completed'
    GROUP BY `customer_id`
) AS customer_stats
GROUP BY `customer_segment`;
