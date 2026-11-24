-- ==============================================================================
-- NEON POSTGRESQL PRODUCTION DATABASE SCRIPT: TRIM
-- AI-POWERED INTEGRATED BARBERSHOP SYSTEM
-- Dokumen Acuan: TRIM_TRD.md, TRIM_PRD.md & TRIM_FSD.md
-- Target Engine: PostgreSQL 15+ / Neon Serverless Postgres
-- ==============================================================================

-- 0. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Drop existing views
DROP VIEW IF EXISTS v_dashboard_kpis CASCADE;
DROP VIEW IF EXISTS v_ai_conversion_analytics CASCADE;
DROP VIEW IF EXISTS v_barber_leaderboard CASCADE;
DROP VIEW IF EXISTS v_popular_hairstyles CASCADE;
DROP VIEW IF EXISTS v_inventory_stock_alerts CASCADE;

-- Drop existing tables (with cascade)
DROP TABLE IF EXISTS store_holidays CASCADE;
DROP TABLE IF EXISTS store_schedules CASCADE;
DROP TABLE IF EXISTS store_settings CASCADE;
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS promotion_usages CASCADE;
DROP TABLE IF EXISTS promotions CASCADE;
DROP TABLE IF EXISTS loyalty_transactions CASCADE;
DROP TABLE IF EXISTS inventory_transactions CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS customer_haircut_history CASCADE;
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS queues CASCADE;
DROP TABLE IF EXISTS booking_services CASCADE;
DROP TABLE IF EXISTS bookings CASCADE;
DROP TABLE IF EXISTS ai_recommendations CASCADE;
DROP TABLE IF EXISTS ai_analyses CASCADE;
DROP TABLE IF EXISTS barber_schedules CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS hairstyle_face_shapes CASCADE;
DROP TABLE IF EXISTS hairstyles CASCADE;
DROP TABLE IF EXISTS services CASCADE;
DROP TABLE IF EXISTS barbers CASCADE;
DROP TABLE IF EXISTS face_shapes CASCADE;
DROP TABLE IF EXISTS memberships CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Function for automatic updated_at timestamp
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ==============================================================================
-- 1. USERS & MEMBERSHIPS (RBAC: Owner, Manager, Admin, Barber, Customer)
-- ==============================================================================

CREATE TABLE users (
    id VARCHAR(36) NOT NULL,
    email VARCHAR(191) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'customer' CHECK (role IN ('owner', 'manager', 'admin', 'barber', 'customer')),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT uk_users_email UNIQUE (email)
);
CREATE INDEX idx_users_role ON users(role);

CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE memberships (
    id VARCHAR(36) NOT NULL,
    tier_name VARCHAR(50) NOT NULL,
    discount_percentage DECIMAL(5, 2) NOT NULL DEFAULT 0.00,
    minimum_points_required INTEGER NOT NULL DEFAULT 0,
    point_multiplier DECIMAL(3, 2) NOT NULL DEFAULT 1.00,
    priority_booking BOOLEAN NOT NULL DEFAULT FALSE,
    free_service_quota INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT uk_memberships_tier UNIQUE (tier_name)
);

CREATE TRIGGER trg_memberships_updated_at
BEFORE UPDATE ON memberships
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE face_shapes (
    id SERIAL PRIMARY KEY,
    shape_name VARCHAR(50) NOT NULL,
    description TEXT NULL,
    CONSTRAINT uk_face_shapes_name UNIQUE (shape_name)
);

CREATE TABLE barbers (
    id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    profile_picture_url VARCHAR(255) NULL,
    specialty VARCHAR(100) NOT NULL,
    experience_years INTEGER NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    average_rating DECIMAL(3, 2) NOT NULL DEFAULT 0.00,
    total_reviews INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT uk_barbers_user_id UNIQUE (user_id),
    CONSTRAINT uk_barbers_phone UNIQUE (phone_number),
    CONSTRAINT fk_barbers_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX idx_barbers_active ON barbers(is_active);

CREATE TRIGGER trg_barbers_updated_at
BEFORE UPDATE ON barbers
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE services (
    id VARCHAR(36) NOT NULL,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL DEFAULT 'Haircut',
    duration_minutes INTEGER NOT NULL DEFAULT 30,
    price DECIMAL(12, 2) NOT NULL,
    description TEXT NULL,
    image_url VARCHAR(255) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
);
CREATE INDEX idx_services_active ON services(is_active);
CREATE INDEX idx_services_category ON services(category);

CREATE TRIGGER trg_services_updated_at
BEFORE UPDATE ON services
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE hairstyles (
    id VARCHAR(36) NOT NULL,
    name VARCHAR(100) NOT NULL,
    image_url VARCHAR(255) NULL,
    description TEXT NULL,
    hair_type VARCHAR(50) NULL,
    maintenance_level SMALLINT NOT NULL DEFAULT 1,
    related_service_id VARCHAR(36) NULL,
    estimated_duration_minutes INTEGER NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_hairstyles_service FOREIGN KEY (related_service_id) REFERENCES services (id) ON DELETE SET NULL ON UPDATE CASCADE
);
CREATE INDEX idx_hairstyles_active ON hairstyles(is_active);

CREATE TRIGGER trg_hairstyles_updated_at
BEFORE UPDATE ON hairstyles
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE hairstyle_face_shapes (
    hairstyle_id VARCHAR(36) NOT NULL,
    face_shape_id INTEGER NOT NULL,
    PRIMARY KEY (hairstyle_id, face_shape_id),
    CONSTRAINT fk_hfs_hairstyle FOREIGN KEY (hairstyle_id) REFERENCES hairstyles (id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_hfs_face_shape FOREIGN KEY (face_shape_id) REFERENCES face_shapes (id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE customers (
    id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    profile_picture_url VARCHAR(255) NULL,
    loyalty_points INTEGER NOT NULL DEFAULT 0,
    membership_id VARCHAR(36) NULL,
    favorite_barber_id VARCHAR(36) NULL,
    favorite_hairstyle_id VARCHAR(36) NULL,
    detected_face_shape_id INTEGER NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT uk_customers_user_id UNIQUE (user_id),
    CONSTRAINT uk_customers_phone UNIQUE (phone_number),
    CONSTRAINT fk_customers_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_customers_membership FOREIGN KEY (membership_id) REFERENCES memberships (id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_customers_fav_barber FOREIGN KEY (favorite_barber_id) REFERENCES barbers (id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_customers_fav_hairstyle FOREIGN KEY (favorite_hairstyle_id) REFERENCES hairstyles (id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_customers_face_shape FOREIGN KEY (detected_face_shape_id) REFERENCES face_shapes (id) ON DELETE SET NULL ON UPDATE CASCADE
);
CREATE INDEX idx_customers_name ON customers(full_name);

CREATE TRIGGER trg_customers_updated_at
BEFORE UPDATE ON customers
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE barber_schedules (
    id VARCHAR(36) NOT NULL,
    barber_id VARCHAR(36) NOT NULL,
    day_of_week VARCHAR(20) NOT NULL CHECK (day_of_week IN ('Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu')),
    start_time TIME NULL,
    end_time TIME NULL,
    is_off BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT uk_barber_schedule_day UNIQUE (barber_id, day_of_week),
    CONSTRAINT fk_schedules_barber FOREIGN KEY (barber_id) REFERENCES barbers (id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TRIGGER trg_barber_schedules_updated_at
BEFORE UPDATE ON barber_schedules
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ==============================================================================
-- 2. AI ANALYSES & RECOMMENDATIONS
-- ==============================================================================

CREATE TABLE ai_analyses (
    id VARCHAR(36) NOT NULL,
    customer_id VARCHAR(36) NULL,
    detected_face_shape_id INTEGER NOT NULL,
    confidence_score DECIMAL(5, 2) NOT NULL,
    uploaded_image_url VARCHAR(255) NULL,
    analyzed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_ai_customer FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_ai_face_shape FOREIGN KEY (detected_face_shape_id) REFERENCES face_shapes (id) ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX idx_ai_customer ON ai_analyses(customer_id);

CREATE TABLE ai_recommendations (
    id VARCHAR(36) NOT NULL,
    analysis_id VARCHAR(36) NOT NULL,
    hairstyle_id VARCHAR(36) NOT NULL,
    match_percentage DECIMAL(5, 2) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_air_analysis FOREIGN KEY (analysis_id) REFERENCES ai_analyses (id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_air_hairstyle FOREIGN KEY (hairstyle_id) REFERENCES hairstyles (id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX idx_air_analysis ON ai_recommendations(analysis_id);

-- ==============================================================================
-- 3. BOOKINGS, QUEUES, PAYMENTS, REVIEWS & HISTORY
-- ==============================================================================

CREATE TABLE bookings (
    id VARCHAR(36) NOT NULL,
    booking_code VARCHAR(20) NOT NULL,
    customer_id VARCHAR(36) NOT NULL,
    barber_id VARCHAR(36) NOT NULL,
    requested_hairstyle_id VARCHAR(36) NULL,
    booking_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'checked_in', 'in_queue', 'in_service', 'completed', 'cancelled', 'no_show')),
    check_in_method VARCHAR(30) NOT NULL DEFAULT 'none' CHECK (check_in_method IN ('none', 'gps_geofence', 'qr_scan_cashier', 'manual_cashier')),
    checked_in_at TIMESTAMPTZ NULL,
    service_started_at TIMESTAMPTZ NULL,
    service_completed_at TIMESTAMPTZ NULL,
    total_price DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    notes TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT uk_bookings_code UNIQUE (booking_code),
    CONSTRAINT fk_bookings_customer FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_bookings_barber FOREIGN KEY (barber_id) REFERENCES barbers (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_bookings_requested_style FOREIGN KEY (requested_hairstyle_id) REFERENCES hairstyles (id) ON DELETE SET NULL ON UPDATE CASCADE
);
CREATE INDEX idx_bookings_customer ON bookings(customer_id);
CREATE INDEX idx_bookings_barber_date ON bookings(barber_id, booking_date);
CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_bookings_date ON bookings(booking_date);

CREATE TRIGGER trg_bookings_updated_at
BEFORE UPDATE ON bookings
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE booking_services (
    id VARCHAR(36) NOT NULL,
    booking_id VARCHAR(36) NOT NULL,
    service_id VARCHAR(36) NOT NULL,
    price_at_booking DECIMAL(12, 2) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_bs_booking FOREIGN KEY (booking_id) REFERENCES bookings (id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_bs_service FOREIGN KEY (service_id) REFERENCES services (id) ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX idx_bs_booking ON booking_services(booking_id);

CREATE TABLE queues (
    id VARCHAR(36) NOT NULL,
    booking_id VARCHAR(36) NOT NULL,
    queue_number VARCHAR(20) NOT NULL,
    estimated_wait_time_mins INTEGER NOT NULL DEFAULT 0,
    people_before_count INTEGER NOT NULL DEFAULT 0,
    status VARCHAR(30) NOT NULL DEFAULT 'waiting' CHECK (status IN ('waiting', 'in_progress', 'completed', 'skipped')),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    called_at TIMESTAMPTZ NULL,
    completed_at TIMESTAMPTZ NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT uk_queues_booking UNIQUE (booking_id),
    CONSTRAINT fk_queues_booking FOREIGN KEY (booking_id) REFERENCES bookings (id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX idx_queues_status ON queues(status);
CREATE INDEX idx_queues_joined ON queues(joined_at);

CREATE TRIGGER trg_queues_updated_at
BEFORE UPDATE ON queues
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE payments (
    id VARCHAR(36) NOT NULL,
    booking_id VARCHAR(36) NOT NULL,
    payment_method VARCHAR(30) NOT NULL DEFAULT 'QRIS',
    qris_reference_id VARCHAR(100) NULL,
    qris_invoice_url VARCHAR(255) NULL,
    amount DECIMAL(12, 2) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'failed', 'expired', 'refunded')),
    expires_at TIMESTAMPTZ NOT NULL,
    paid_at TIMESTAMPTZ NULL DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT uk_payments_booking UNIQUE (booking_id),
    CONSTRAINT fk_payments_booking FOREIGN KEY (booking_id) REFERENCES bookings (id) ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX idx_payments_qris_ref ON payments(qris_reference_id);
CREATE INDEX idx_payments_status ON payments(status);

CREATE TRIGGER trg_payments_updated_at
BEFORE UPDATE ON payments
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE reviews (
    id VARCHAR(36) NOT NULL,
    booking_id VARCHAR(36) NOT NULL,
    customer_id VARCHAR(36) NOT NULL,
    barber_id VARCHAR(36) NOT NULL,
    rating_barber SMALLINT NOT NULL CHECK (rating_barber BETWEEN 1 AND 5),
    rating_service SMALLINT NOT NULL CHECK (rating_service BETWEEN 1 AND 5),
    hairstyle_satisfaction SMALLINT NULL CHECK (hairstyle_satisfaction BETWEEN 1 AND 5),
    review_text TEXT NULL,
    haircut_result_image_url VARCHAR(255) NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT uk_reviews_booking UNIQUE (booking_id),
    CONSTRAINT fk_reviews_booking FOREIGN KEY (booking_id) REFERENCES bookings (id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_reviews_customer FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_reviews_barber FOREIGN KEY (barber_id) REFERENCES barbers (id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX idx_reviews_barber ON reviews(barber_id);
CREATE INDEX idx_reviews_customer ON reviews(customer_id);

CREATE TABLE customer_haircut_history (
    id VARCHAR(36) NOT NULL,
    customer_id VARCHAR(36) NOT NULL,
    booking_id VARCHAR(36) NOT NULL,
    barber_id VARCHAR(36) NOT NULL,
    hairstyle_id VARCHAR(36) NULL,
    cut_date DATE NOT NULL,
    photo_url VARCHAR(255) NULL,
    notes TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_chh_customer FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_chh_booking FOREIGN KEY (booking_id) REFERENCES bookings (id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_chh_barber FOREIGN KEY (barber_id) REFERENCES barbers (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_chh_hairstyle FOREIGN KEY (hairstyle_id) REFERENCES hairstyles (id) ON DELETE SET NULL ON UPDATE CASCADE
);
CREATE INDEX idx_history_customer ON customer_haircut_history(customer_id, cut_date);

-- ==============================================================================
-- 4. PRODUCTS & INVENTORY
-- ==============================================================================

CREATE TABLE products (
    id VARCHAR(36) NOT NULL,
    sku VARCHAR(50) NULL,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    unit VARCHAR(20) NOT NULL DEFAULT 'pcs',
    stock_quantity INTEGER NOT NULL DEFAULT 0,
    minimum_stock_alert INTEGER NOT NULL DEFAULT 5,
    unit_price DECIMAL(12, 2) NOT NULL,
    cost_price DECIMAL(12, 2) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT uk_products_sku UNIQUE (sku)
);
CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_products_active ON products(is_active);

CREATE TRIGGER trg_products_updated_at
BEFORE UPDATE ON products
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE inventory_transactions (
    id VARCHAR(36) NOT NULL,
    product_id VARCHAR(36) NOT NULL,
    transaction_type VARCHAR(30) NOT NULL CHECK (transaction_type IN ('stock_in', 'stock_out', 'adjustment')),
    quantity INTEGER NOT NULL,
    unit_price_at_transaction DECIMAL(12, 2) NULL,
    notes TEXT NULL,
    created_by_user_id VARCHAR(36) NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_inv_product FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_inv_creator FOREIGN KEY (created_by_user_id) REFERENCES users (id) ON DELETE SET NULL ON UPDATE CASCADE
);
CREATE INDEX idx_inv_product ON inventory_transactions(product_id);
CREATE INDEX idx_inv_type ON inventory_transactions(transaction_type);

-- ==============================================================================
-- 5. LOYALTY, PROMOTIONS & NOTIFICATIONS
-- ==============================================================================

CREATE TABLE loyalty_transactions (
    id VARCHAR(36) NOT NULL,
    customer_id VARCHAR(36) NOT NULL,
    points INTEGER NOT NULL,
    transaction_type VARCHAR(30) NOT NULL CHECK (transaction_type IN ('earn', 'redeem', 'adjustment')),
    reference_id VARCHAR(36) NULL,
    description VARCHAR(255) NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_loyalty_customer FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX idx_loyalty_customer ON loyalty_transactions(customer_id);

CREATE TABLE promotions (
    id VARCHAR(36) NOT NULL,
    code VARCHAR(50) NOT NULL,
    title VARCHAR(100) NOT NULL,
    promo_category VARCHAR(30) NOT NULL DEFAULT 'general' CHECK (promo_category IN ('general', 'voucher', 'event', 'first_visit', 'birthday', 'membership')),
    discount_type VARCHAR(20) NOT NULL CHECK (discount_type IN ('percentage', 'fixed')),
    discount_value DECIMAL(12, 2) NOT NULL,
    min_order_amount DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    max_discount_amount DECIMAL(12, 2) NULL,
    quota INTEGER NULL,
    used_count INTEGER NOT NULL DEFAULT 0,
    target_membership_tier_id VARCHAR(36) NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT uk_promotions_code UNIQUE (code),
    CONSTRAINT fk_promotions_tier FOREIGN KEY (target_membership_tier_id) REFERENCES memberships (id) ON DELETE SET NULL ON UPDATE CASCADE
);
CREATE INDEX idx_promotions_active ON promotions(is_active, start_date, end_date);

CREATE TRIGGER trg_promotions_updated_at
BEFORE UPDATE ON promotions
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE promotion_usages (
    id VARCHAR(36) NOT NULL,
    promotion_id VARCHAR(36) NOT NULL,
    customer_id VARCHAR(36) NOT NULL,
    booking_id VARCHAR(36) NOT NULL,
    discount_applied DECIMAL(12, 2) NOT NULL,
    used_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_pu_promotion FOREIGN KEY (promotion_id) REFERENCES promotions (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_pu_customer FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_pu_booking FOREIGN KEY (booking_id) REFERENCES bookings (id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX idx_pu_customer ON promotion_usages(customer_id);
CREATE INDEX idx_pu_booking ON promotion_usages(booking_id);

CREATE TABLE notifications (
    id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    title VARCHAR(150) NOT NULL,
    body TEXT NOT NULL,
    type VARCHAR(30) NOT NULL DEFAULT 'system' CHECK (type IN ('booking', 'reminder', 'queue', 'promotion', 'rebooking', 'system')),
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    data_payload JSONB NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX idx_notifications_user ON notifications(user_id, is_read);

-- ==============================================================================
-- 6. STORE SETTINGS & SCHEDULES
-- ==============================================================================

CREATE TABLE store_settings (
    id SERIAL PRIMARY KEY,
    setting_key VARCHAR(100) NOT NULL,
    setting_value TEXT NOT NULL,
    description VARCHAR(255) NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_store_settings_key UNIQUE (setting_key)
);

CREATE TRIGGER trg_store_settings_updated_at
BEFORE UPDATE ON store_settings
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE store_schedules (
    id SERIAL PRIMARY KEY,
    day_of_week VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'buka' CHECK (status IN ('buka', 'tutup')),
    open_time TIME NULL,
    close_time TIME NULL,
    is_locked BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT uk_store_schedules_day UNIQUE (day_of_week)
);

CREATE TABLE store_holidays (
    id SERIAL PRIMARY KEY,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(30) NOT NULL DEFAULT 'tanggal-libur' CHECK (type IN ('tanggal-libur', 'rentang-libur')),
    description TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_holidays_dates ON store_holidays(start_date, end_date);

-- ==============================================================================
-- 7. ANALYTICAL VIEWS
-- ==============================================================================

CREATE OR REPLACE VIEW v_dashboard_kpis AS
SELECT 
    CURRENT_DATE AS date,
    COALESCE(SUM(CASE WHEN p.status = 'paid' AND p.paid_at::date = CURRENT_DATE THEN p.amount ELSE 0 END), 0) AS today_revenue,
    COUNT(DISTINCT CASE WHEN b.booking_date = CURRENT_DATE THEN b.id END) AS today_appointments,
    COUNT(DISTINCT CASE WHEN b.booking_date = CURRENT_DATE THEN b.customer_id END) AS today_customers,
    COUNT(DISTINCT CASE WHEN b.booking_date = CURRENT_DATE AND b.status = 'completed' THEN b.id END) AS completed_services,
    COUNT(DISTINCT CASE WHEN q.status = 'waiting' THEN q.id END) AS currently_in_queue
FROM bookings b
LEFT JOIN payments p ON b.id = p.booking_id
LEFT JOIN queues q ON b.id = q.booking_id;

CREATE OR REPLACE VIEW v_ai_conversion_analytics AS
SELECT 
    COUNT(a.id) AS total_ai_scans,
    COUNT(DISTINCT b.id) AS converted_bookings,
    ROUND(
        (COUNT(DISTINCT b.id)::numeric / NULLIF(COUNT(a.id), 0)) * 100, 
        2
    ) AS ai_to_booking_conversion_rate_pct
FROM ai_analyses a
LEFT JOIN bookings b ON a.customer_id = b.customer_id 
    AND b.booking_date >= a.analyzed_at::date
    AND b.status IN ('confirmed', 'checked_in', 'in_queue', 'in_service', 'completed');

CREATE OR REPLACE VIEW v_barber_leaderboard AS
SELECT 
    b.id AS barber_id,
    b.full_name AS barber_name,
    b.specialty,
    b.average_rating,
    COUNT(DISTINCT CASE WHEN bk.status = 'completed' THEN bk.id END) AS total_completed_services,
    COALESCE(SUM(CASE WHEN bk.status = 'completed' AND p.status = 'paid' THEN p.amount ELSE 0 END), 0) AS total_revenue_generated
FROM barbers b
LEFT JOIN bookings bk ON b.id = bk.barber_id
LEFT JOIN payments p ON bk.id = p.booking_id
WHERE b.is_active = TRUE
GROUP BY b.id, b.full_name, b.specialty, b.average_rating
ORDER BY total_completed_services DESC, b.average_rating DESC;

CREATE OR REPLACE VIEW v_popular_hairstyles AS
SELECT 
    h.id AS hairstyle_id,
    h.name AS hairstyle_name,
    COUNT(DISTINCT ar.id) AS times_recommended_by_ai,
    COUNT(DISTINCT bk.id) AS times_booked_by_customers
FROM hairstyles h
LEFT JOIN ai_recommendations ar ON h.id = ar.hairstyle_id
LEFT JOIN bookings bk ON h.id = bk.requested_hairstyle_id
GROUP BY h.id, h.name
ORDER BY times_booked_by_customers DESC, times_recommended_by_ai DESC;

CREATE OR REPLACE VIEW v_inventory_stock_alerts AS
SELECT 
    id AS product_id,
    sku,
    name AS product_name,
    category,
    stock_quantity,
    minimum_stock_alert,
    (minimum_stock_alert - stock_quantity) AS deficit_quantity
FROM products
WHERE stock_quantity <= minimum_stock_alert AND is_active = TRUE
ORDER BY stock_quantity ASC;

-- ==============================================================================
-- 8. INITIAL SEED DATA
-- ==============================================================================

INSERT INTO face_shapes (id, shape_name, description) VALUES
(1, 'Oval', 'Bentuk wajah proporsional dengan dagu sedikit melengkung. Cocok hampir untuk semua model rambut.'),
(2, 'Round', 'Wajah bulat dengan garis rahang lembut dan pipi penuh. Cocok dengan gaya bertingkat/volume di atas.'),
(3, 'Square', 'Garis rahang tegas dan lebar dahi seimbang. Cocok dengan model fade pendek atau texture crop.'),
(4, 'Heart', 'Dahi lebar dan dagu runcing menyerupai segitiga terbalik. Cocok dengan gaya poni samping.'),
(5, 'Diamond', 'Tulang pipi tinggi dan lebar dengan dahi serta dagu yang sempit. Cocok dengan fringe atau taper cut.'),
(6, 'Oblong', 'Bentuk wajah panjang/lonjong. Cocok dengan model yang memiliki volume samping seimbang.')
ON CONFLICT (id) DO UPDATE SET shape_name = EXCLUDED.shape_name, description = EXCLUDED.description;
SELECT setval('face_shapes_id_seq', (SELECT MAX(id) FROM face_shapes));

INSERT INTO memberships (id, tier_name, discount_percentage, minimum_points_required, point_multiplier, priority_booking, free_service_quota) VALUES
('m0000000-0000-0000-0000-000000000001', 'Silver', 5.00, 100, 1.00, FALSE, 0),
('m0000000-0000-0000-0000-000000000002', 'Gold', 10.00, 500, 1.25, TRUE, 1),
('m0000000-0000-0000-0000-000000000003', 'Platinum', 15.00, 1500, 1.50, TRUE, 3)
ON CONFLICT (id) DO UPDATE SET tier_name = EXCLUDED.tier_name;

INSERT INTO users (id, email, password_hash, role) VALUES
('u0000000-0000-0000-0000-000000000001', 'owner@trim.id', '$2b$10$2htLOxZmo9KRzb7tynkvv.JgZQ8WkFGPrx5fLhGWpmNx3Zkb4SqlS', 'owner'),
('u0000000-0000-0000-0000-000000000002', 'dimas@trim.id', '$2b$10$2htLOxZmo9KRzb7tynkvv.JgZQ8WkFGPrx5fLhGWpmNx3Zkb4SqlS', 'admin'),
('u0000000-0000-0000-0000-000000000003', 'raka@trim.id', '$2b$10$2htLOxZmo9KRzb7tynkvv.JgZQ8WkFGPrx5fLhGWpmNx3Zkb4SqlS', 'barber'),
('u0000000-0000-0000-0000-000000000004', 'alya@trim.id', '$2b$10$2htLOxZmo9KRzb7tynkvv.JgZQ8WkFGPrx5fLhGWpmNx3Zkb4SqlS', 'customer')
ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email, password_hash = EXCLUDED.password_hash;

INSERT INTO barbers (id, user_id, full_name, phone_number, specialty, experience_years, is_active, average_rating, total_reviews) VALUES
('b0000000-0000-0000-0000-000000000001', 'u0000000-0000-0000-0000-000000000003', 'Raka Putra', '081234567890', 'Fade & taper', 4, TRUE, 4.90, 48)
ON CONFLICT (id) DO UPDATE SET full_name = EXCLUDED.full_name;

INSERT INTO services (id, name, category, duration_minutes, price, description, is_active) VALUES
('s0000000-0000-0000-0000-000000000001', 'Gentleman Haircut & Wash', 'Haircut', 45, 60000.00, 'Potongan rambut presisi, cuci rambut, dan pijat kepala rileks.', TRUE),
('s0000000-0000-0000-0000-000000000002', 'Classic Shave & Hot Towel', 'Grooming', 30, 40000.00, 'Cukur jenggot/kumis tradisional menggunakan pisau cukur dan handuk hangat.', TRUE),
('s0000000-0000-0000-0000-000000000003', 'Hair Styling & Pomade', 'Styling', 20, 25000.00, 'Penataan rambut profesional menggunakan pomade premium.', TRUE),
('s0000000-0000-0000-0000-000000000004', 'Full Grooming Combo', 'Package', 75, 100000.00, 'Paket komplit pangkas, cuci, cukur jenggot, dan styling.', TRUE)
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO hairstyles (id, name, image_url, description, hair_type, maintenance_level, related_service_id, estimated_duration_minutes, is_active) VALUES
('h0000000-0000-0000-0000-000000000001', 'Low Fade with Textured Crop', 'https://images.unsplash.com/photo-1622286342621-4bd786c2447c', 'Gradasi samping rendah dengan tekstur crop modern di bagian atas.', 'Lurus / Bergelombang', 2, 's0000000-0000-0000-0000-000000000001', 45, TRUE),
('h0000000-0000-0000-0000-000000000002', 'Classic Pompadour', 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1', 'Gaya klasik bervolume tinggi disisir ke belakang rapi.', 'Lurus / Tebal', 4, 's0000000-0000-0000-0000-000000000001', 45, TRUE),
('h0000000-0000-0000-0000-000000000003', 'Modern Mullet & Taper', 'https://images.unsplash.com/photo-1605497788044-5a32c7078486', 'Rambut samping taper bersih dengan rambut bagian belakang panjang berkarakter.', 'Bergelombang / Keriting', 3, 's0000000-0000-0000-0000-000000000001', 45, TRUE)
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO hairstyle_face_shapes (hairstyle_id, face_shape_id) VALUES
('h0000000-0000-0000-0000-000000000001', 1),
('h0000000-0000-0000-0000-000000000001', 3),
('h0000000-0000-0000-0000-000000000002', 2),
('h0000000-0000-0000-0000-000000000002', 3),
('h0000000-0000-0000-0000-000000000003', 1),
('h0000000-0000-0000-0000-000000000003', 4)
ON CONFLICT (hairstyle_id, face_shape_id) DO NOTHING;

INSERT INTO customers (id, user_id, full_name, phone_number, loyalty_points, membership_id, favorite_barber_id, favorite_hairstyle_id, detected_face_shape_id) VALUES
('c0000000-0000-0000-0000-000000000001', 'u0000000-0000-0000-0000-000000000004', 'Alya Lestari', '081298765432', 150, 'm0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'h0000000-0000-0000-0000-000000000001', 1)
ON CONFLICT (id) DO UPDATE SET full_name = EXCLUDED.full_name;

INSERT INTO products (id, sku, name, category, unit, stock_quantity, minimum_stock_alert, unit_price, cost_price, is_active) VALUES
('p0000000-0000-0000-0000-000000000001', 'POM-MATTE-01', 'Suavecito Matte Pomade 4oz', 'Pomade', 'jar', 25, 5, 140000.00, 95000.00, TRUE),
('p0000000-0000-0000-0000-000000000002', 'BRD-OIL-02', 'Beard Oil Peppermint 30ml', 'Beard Care', 'bottle', 18, 4, 85000.00, 50000.00, TRUE),
('p0000000-0000-0000-0000-000000000003', 'TNC-COOL-03', 'Menthol Cooling Tonic 250ml', 'Hair Tonic', 'bottle', 30, 8, 75000.00, 45000.00, TRUE)
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO store_settings (setting_key, setting_value, description) VALUES
('is_store_closed', 'false', 'Status buka/tutup darurat toko (true/false)'),
('holiday_date', '2026-12-25', 'Tanggal libur khusus toko terdekat (YYYY-MM-DD)'),
('store_name', 'TRIM Barbershop', 'Nama resmi barbershop'),
('store_address', 'Jl. Braga No. 45, Bandung, Jawa Barat', 'Alamat toko fisik'),
('store_phone', '081234567890', 'Nomor WhatsApp kontak customer service'),
('qris_merchant_name', 'TRIM Barbershop Bandung', 'Nama merchant yang tertera pada Pakkasir QRIS')
ON CONFLICT (setting_key) DO UPDATE SET setting_value = EXCLUDED.setting_value;
SELECT setval('store_settings_id_seq', (SELECT MAX(id) FROM store_settings));

INSERT INTO store_schedules (day_of_week, status, open_time, close_time, is_locked) VALUES
('Senin', 'buka', '08:00:00', '18:00:00', FALSE),
('Selasa', 'buka', '08:00:00', '18:00:00', FALSE),
('Rabu', 'buka', '08:00:00', '18:00:00', FALSE),
('Kamis', 'buka', '08:00:00', '18:00:00', FALSE),
('Jumat', 'buka', '08:00:00', '19:00:00', FALSE),
('Sabtu', 'buka', '09:00:00', '20:00:00', FALSE),
('Minggu', 'tutup', NULL, NULL, TRUE)
ON CONFLICT (day_of_week) DO UPDATE SET status = EXCLUDED.status, open_time = EXCLUDED.open_time, close_time = EXCLUDED.close_time;
SELECT setval('store_schedules_id_seq', (SELECT MAX(id) FROM store_schedules));

INSERT INTO store_holidays (id, start_date, end_date, name, type, description) VALUES
(1, '2026-12-25', '2026-12-25', 'Hari Raya Natal', 'tanggal-libur', 'Libur Nasional — Hari Raya Natal'),
(2, '2027-01-01', '2027-01-01', 'Tahun Baru 2027', 'tanggal-libur', 'Libur Nasional — Tahun Baru Masehi')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;
SELECT setval('store_holidays_id_seq', (SELECT MAX(id) FROM store_holidays));

