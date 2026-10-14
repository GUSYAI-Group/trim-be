-- ==============================================================================
-- DATABASE SEEDER: TRIM - AI-Powered Barbershop Information System
-- Berdasarkan Dokumen: TRIM_TRD.md & Frontend UI Views
-- ==============================================================================

USE `trim_db`;

-- 1. Master Bentuk Wajah (Face Shapes)
INSERT INTO `face_shapes` (`id`, `shape_name`, `description`) VALUES
(1, 'Oval', 'Bentuk wajah proporsional dengan dagu sedikit melengkung. Cocok hampir untuk semua model rambut.'),
(2, 'Round', 'Wajah bulat dengan garis rahang lembut dan pipi penuh. Cocok dengan gaya bertingkat/volume di atas.'),
(3, 'Square', 'Garis rahang tegas dan lebar dahi seimbang. Cocok dengan model fade pendek atau texture crop.'),
(4, 'Heart', 'Dahi lebar dan dagu runcing menyerupai segitiga terbalik. Cocok dengan gaya poni samping.'),
(5, 'Diamond', 'Tulang pipi tinggi dan lebar dengan dahi serta dagu yang sempit. Cocok dengan fringe atau taper cut.'),
(6, 'Oblong', 'Bentuk wajah panjang/lonjong. Cocok dengan model yang memiliki volume samping seimbang.')
ON DUPLICATE KEY UPDATE `shape_name` = VALUES(`shape_name`), `description` = VALUES(`description`);

-- 2. Master Tingkatan Membership (Memberships)
INSERT INTO `memberships` (`id`, `tier_name`, `discount_percentage`, `minimum_points_required`) VALUES
('m0000000-0000-0000-0000-000000000001', 'Silver', 5.00, 100),
('m0000000-0000-0000-0000-000000000002', 'Gold', 10.00, 500),
('m0000000-0000-0000-0000-000000000003', 'Platinum', 15.00, 1500)
ON DUPLICATE KEY UPDATE `tier_name` = VALUES(`tier_name`);

-- 3. Akun Pengguna Dasar (Users) - Catatan: hash password dummy bcrypt untuk 'password123'
INSERT INTO `users` (`id`, `email`, `password_hash`, `role`) VALUES
('u0000000-0000-0000-0000-000000000001', 'aditya@trim.id', '$2a$12$e8yM2dK5WvA8qKqj8/5Gzeu0uXk7n0Xk8vK3/b1q7w6YdC6Vf2d2i', 'owner'),
('u0000000-0000-0000-0000-000000000002', 'dimas@trim.id', '$2a$12$e8yM2dK5WvA8qKqj8/5Gzeu0uXk7n0Xk8vK3/b1q7w6YdC6Vf2d2i', 'admin'),
('u0000000-0000-0000-0000-000000000003', 'raka@trim.id', '$2a$12$e8yM2dK5WvA8qKqj8/5Gzeu0uXk7n0Xk8vK3/b1q7w6YdC6Vf2d2i', 'barber'),
('u0000000-0000-0000-0000-000000000004', 'alya@trim.id', '$2a$12$e8yM2dK5WvA8qKqj8/5Gzeu0uXk7n0Xk8vK3/b1q7w6YdC6Vf2d2i', 'customer')
ON DUPLICATE KEY UPDATE `email` = VALUES(`email`);

-- 4. Profil Kapster (Barbers) - Sinkron dengan mock/data di Frontend
INSERT INTO `barbers` (`id`, `user_id`, `full_name`, `phone_number`, `specialty`, `is_active`, `average_rating`) VALUES
('b0000000-0000-0000-0000-000000000001', 'u0000000-0000-0000-0000-000000000003', 'Raka Putra', '081234567890', 'Fade & taper', TRUE, 4.90)
ON DUPLICATE KEY UPDATE `full_name` = VALUES(`full_name`);

-- 5. Profil Pelanggan (Customers)
INSERT INTO `customers` (`id`, `user_id`, `full_name`, `phone_number`, `loyalty_points`, `membership_id`) VALUES
('c0000000-0000-0000-0000-000000000001', 'u0000000-0000-0000-0000-000000000004', 'Alya Lestari', '081298765432', 150, 'm0000000-0000-0000-0000-000000000001')
ON DUPLICATE KEY UPDATE `full_name` = VALUES(`full_name`);

-- 6. Katalog Layanan (Services)
INSERT INTO `services` (`id`, `name`, `category`, `duration_minutes`, `price`, `is_active`) VALUES
('s0000000-0000-0000-0000-000000000001', 'Gentleman Haircut & Wash', 'Haircut', 45, 60000.00, TRUE),
('s0000000-0000-0000-0000-000000000002', 'Classic Shave & Hot Towel', 'Grooming', 30, 40000.00, TRUE),
('s0000000-0000-0000-0000-000000000003', 'Hair Styling & Pomade', 'Styling', 20, 25000.00, TRUE),
('s0000000-0000-0000-0000-000000000004', 'Full Grooming Combo', 'Package', 75, 100000.00, TRUE)
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);

-- 7. Katalog Model Gaya Rambut (Hairstyles)
INSERT INTO `hairstyles` (`id`, `name`, `image_url`, `description`, `hair_type`, `maintenance_level`, `is_active`) VALUES
('h0000000-0000-0000-0000-000000000001', 'Low Fade with Textured Crop', 'https://images.unsplash.com/photo-1622286342621-4bd786c2447c', 'Gradasi samping rendah dengan tekstur crop modern di bagian atas.', 'Lurus / Bergelombang', 2, TRUE),
('h0000000-0000-0000-0000-000000000002', 'Classic Pompadour', 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1', 'Gaya klasik bervolume tinggi disisir ke belakang rapi.', 'Lurus / Tebal', 4, TRUE),
('h0000000-0000-0000-0000-000000000003', 'Modern Mullet & Taper', 'https://images.unsplash.com/photo-1605497788044-5a32c7078486', 'Rambut samping taper bersih dengan rambut bagian belakang panjang berkarakter.', 'Bergelombang / Keriting', 3, TRUE)
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);

-- 8. Relasi Model Rambut & Bentuk Wajah (HairstyleFaceShapes)
INSERT INTO `hairstyle_face_shapes` (`hairstyle_id`, `face_shape_id`) VALUES
('h0000000-0000-0000-0000-000000000001', 1), -- Low Fade cocok untuk Oval
('h0000000-0000-0000-0000-000000000001', 3), -- Low Fade cocok untuk Square
('h0000000-0000-0000-0000-000000000002', 2), -- Pompadour cocok untuk Round
('h0000000-0000-0000-0000-000000000002', 3), -- Pompadour cocok untuk Square
('h0000000-0000-0000-0000-000000000003', 1), -- Modern Mullet cocok untuk Oval
('h0000000-0000-0000-0000-000000000003', 4)  -- Modern Mullet cocok untuk Heart
ON DUPLICATE KEY UPDATE `hairstyle_id` = VALUES(`hairstyle_id`);

-- 9. Katalog Produk Inventaris (Products)
INSERT INTO `products` (`id`, `name`, `category`, `stock_quantity`, `minimum_stock_alert`, `unit_price`, `is_active`) VALUES
('p0000000-0000-0000-0000-000000000001', 'Suavecito Matte Pomade 4oz', 'Pomade', 25, 5, 140000.00, TRUE),
('p0000000-0000-0000-0000-000000000002', 'Beard Oil Peppermint 30ml', 'Beard Care', 18, 4, 85000.00, TRUE),
('p0000000-0000-0000-0000-000000000003', 'Menthol Cooling Tonic 250ml', 'Hair Tonic', 30, 8, 75000.00, TRUE)
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);

-- 10. Pengaturan Toko (Store Settings)
INSERT INTO `store_settings` (`setting_key`, `setting_value`, `description`) VALUES
('is_store_closed', 'false', 'Status buka/tutup darurat toko (true/false)'),
('holiday_date', '2026-12-25', 'Tanggal libur khusus toko terdekat (YYYY-MM-DD)'),
('store_name', 'TRIM Barbershop', 'Nama resmi barbershop'),
('store_address', 'Jl. Braga No. 45, Bandung, Jawa Barat', 'Alamat toko fisik'),
('store_phone', '081234567890', 'Nomor WhatsApp kontak customer service'),
('qris_merchant_name', 'TRIM Barbershop Bandung', 'Nama merchant yang tertera pada Pakkasir QRIS')
ON DUPLICATE KEY UPDATE `setting_value` = VALUES(`setting_value`);

-- 11. Jadwal Buka Operasional (Store Schedules)
INSERT INTO `store_schedules` (`day_of_week`, `status`, `open_time`, `close_time`, `is_locked`) VALUES
('Senin', 'buka', '08:00:00', '18:00:00', FALSE),
('Selasa', 'buka', '08:00:00', '18:00:00', FALSE),
('Rabu', 'buka', '08:00:00', '18:00:00', FALSE),
('Kamis', 'buka', '08:00:00', '18:00:00', FALSE),
('Jumat', 'buka', '08:00:00', '19:00:00', FALSE),
('Sabtu', 'buka', '09:00:00', '20:00:00', FALSE),
('Minggu', 'tutup', NULL, NULL, TRUE)
ON DUPLICATE KEY UPDATE `status` = VALUES(`status`), `open_time` = VALUES(`open_time`), `close_time` = VALUES(`close_time`);

-- 12. Kalender Libur (Store Holidays)
INSERT INTO `store_holidays` (`id`, `start_date`, `end_date`, `name`, `type`, `description`) VALUES
(1, '2026-12-25', '2026-12-25', 'Hari Raya Natal', 'tanggal-libur', 'Libur Nasional — Hari Raya Natal'),
(2, '2027-01-01', '2027-01-01', 'Tahun Baru 2027', 'tanggal-libur', 'Libur Nasional — Tahun Baru Masehi')
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);
