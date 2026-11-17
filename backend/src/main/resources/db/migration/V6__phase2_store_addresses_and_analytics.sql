-- V6__phase2_store_addresses_and_analytics.sql
-- 1. Shop Settings & Delivery Configuration
CREATE TABLE shop_settings (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  shop_name VARCHAR(120) NOT NULL,
  contact_phone VARCHAR(20) NOT NULL,
  shop_address VARCHAR(300) NOT NULL,
  opening_time VARCHAR(10) NOT NULL DEFAULT '06:30',
  closing_time VARCHAR(10) NOT NULL DEFAULT '21:30',
  is_open_today BOOLEAN NOT NULL DEFAULT TRUE,
  min_order_value DECIMAL(12,2) NOT NULL DEFAULT 100.00,
  delivery_charge DECIMAL(12,2) NOT NULL DEFAULT 30.00,
  free_delivery_threshold DECIMAL(12,2) NOT NULL DEFAULT 500.00,
  announcement_banner VARCHAR(300) NULL,
  updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)
);

INSERT INTO shop_settings (id, shop_name, contact_phone, shop_address, opening_time, closing_time, is_open_today, min_order_value, delivery_charge, free_delivery_threshold, announcement_banner)
VALUES (1, 'FreshBasket Neighborhood Mart', '+91 98765 43210', '12/4 Green Avenue, Sector 5, Bangalore - 560001', '06:30', '21:30', TRUE, 100.00, 30.00, 500.00, 'Fresh morning farm arrivals available daily from 6:30 AM!');

-- 2. Customer Saved Addresses
CREATE TABLE customer_addresses (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  customer_user_id BIGINT NOT NULL,
  label VARCHAR(50) NOT NULL DEFAULT 'Home',
  recipient_name VARCHAR(120) NOT NULL,
  recipient_phone VARCHAR(20) NOT NULL,
  address_line VARCHAR(300) NOT NULL,
  house_number VARCHAR(100) NULL,
  area VARCHAR(120) NOT NULL,
  landmark VARCHAR(160) NULL,
  pincode VARCHAR(6) NOT NULL,
  is_default BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_customer_addresses_user FOREIGN KEY (customer_user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_customer_addresses_user (customer_user_id, is_default)
);

-- 3. Safety Stock Buffer for Fresh Produce
ALTER TABLE inventory
  ADD COLUMN safety_stock_buffer DECIMAL(12,3) NOT NULL DEFAULT 0;

-- 4. Order Cancellation Reason
ALTER TABLE orders
  ADD COLUMN cancellation_reason VARCHAR(300) NULL;

-- 5. Analytics & Aggregation Indexes
ALTER TABLE order_items ADD INDEX idx_order_items_product_created (product_id);
ALTER TABLE orders ADD INDEX idx_orders_created_status (created_at, status);
