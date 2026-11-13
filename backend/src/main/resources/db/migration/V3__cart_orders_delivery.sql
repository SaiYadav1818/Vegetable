CREATE TABLE carts (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  customer_user_id BIGINT NOT NULL UNIQUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_carts_customer FOREIGN KEY (customer_user_id) REFERENCES users(id)
);

CREATE TABLE cart_items (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  cart_id BIGINT NOT NULL,
  product_id BIGINT NOT NULL,
  quantity DECIMAL(12,3) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_cart_items_cart FOREIGN KEY (cart_id) REFERENCES carts(id) ON DELETE CASCADE,
  CONSTRAINT fk_cart_items_product FOREIGN KEY (product_id) REFERENCES products(id),
  CONSTRAINT uq_cart_product UNIQUE (cart_id, product_id),
  CONSTRAINT chk_cart_items_quantity CHECK (quantity > 0),
  INDEX idx_cart_items_cart (cart_id)
);

CREATE TABLE orders (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_number VARCHAR(32) NOT NULL UNIQUE,
  customer_user_id BIGINT NOT NULL,
  status VARCHAR(24) NOT NULL,
  payment_method VARCHAR(16) NOT NULL DEFAULT 'COD',
  payment_status VARCHAR(16) NOT NULL DEFAULT 'PENDING',
  subtotal DECIMAL(12,2) NOT NULL,
  delivery_charge DECIMAL(12,2) NOT NULL DEFAULT 0,
  total_amount DECIMAL(12,2) NOT NULL,
  recipient_name VARCHAR(120) NOT NULL,
  recipient_phone VARCHAR(20) NOT NULL,
  address_line VARCHAR(300) NOT NULL,
  house_number VARCHAR(100),
  area VARCHAR(120) NOT NULL,
  landmark VARCHAR(160),
  pincode VARCHAR(6) NOT NULL,
  delivery_instructions VARCHAR(500),
  delivery_date DATE NOT NULL,
  delivery_slot VARCHAR(20) NOT NULL,
  latitude DECIMAL(10,7),
  longitude DECIMAL(10,7),
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_orders_customer FOREIGN KEY (customer_user_id) REFERENCES users(id),
  INDEX idx_orders_customer_created (customer_user_id, created_at),
  INDEX idx_orders_status_created (status, created_at)
);

CREATE TABLE order_items (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_id BIGINT NOT NULL,
  product_id BIGINT NOT NULL,
  product_name VARCHAR(120) NOT NULL,
  unit VARCHAR(12) NOT NULL,
  quantity DECIMAL(12,3) NOT NULL,
  unit_price DECIMAL(10,2) NOT NULL,
  line_total DECIMAL(12,2) NOT NULL,
  CONSTRAINT fk_order_items_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  CONSTRAINT fk_order_items_product FOREIGN KEY (product_id) REFERENCES products(id),
  CONSTRAINT chk_order_items_quantity CHECK (quantity > 0),
  INDEX idx_order_items_order (order_id)
);

CREATE TABLE order_status_history (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_id BIGINT NOT NULL,
  from_status VARCHAR(24),
  to_status VARCHAR(24) NOT NULL,
  changed_by_user_id BIGINT,
  reason VARCHAR(300),
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_order_history_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  CONSTRAINT fk_order_history_actor FOREIGN KEY (changed_by_user_id) REFERENCES users(id),
  INDEX idx_order_history_order_created (order_id, created_at)
);

CREATE TABLE payments (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_id BIGINT NOT NULL UNIQUE,
  method VARCHAR(16) NOT NULL,
  status VARCHAR(16) NOT NULL,
  amount DECIMAL(12,2) NOT NULL,
  paid_at TIMESTAMP(6),
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_payments_order FOREIGN KEY (order_id) REFERENCES orders(id),
  INDEX idx_payments_status (status)
);

CREATE TABLE drivers (
  user_id BIGINT PRIMARY KEY,
  online BOOLEAN NOT NULL DEFAULT FALSE,
  available BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_drivers_user FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE driver_assignments (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_id BIGINT NOT NULL UNIQUE,
  driver_user_id BIGINT NOT NULL,
  status VARCHAR(20) NOT NULL,
  assigned_by_user_id BIGINT NOT NULL,
  assigned_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  accepted_at TIMESTAMP(6),
  picked_up_at TIMESTAMP(6),
  delivered_at TIMESTAMP(6),
  CONSTRAINT fk_assignment_order FOREIGN KEY (order_id) REFERENCES orders(id),
  CONSTRAINT fk_assignment_driver FOREIGN KEY (driver_user_id) REFERENCES drivers(user_id),
  CONSTRAINT fk_assignment_admin FOREIGN KEY (assigned_by_user_id) REFERENCES users(id),
  INDEX idx_driver_assignments_driver_status (driver_user_id, status)
);

CREATE TABLE driver_locations (
  driver_user_id BIGINT PRIMARY KEY,
  assignment_id BIGINT NOT NULL,
  latitude DECIMAL(10,7) NOT NULL,
  longitude DECIMAL(10,7) NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_driver_location_driver FOREIGN KEY (driver_user_id) REFERENCES drivers(user_id),
  CONSTRAINT fk_driver_location_assignment FOREIGN KEY (assignment_id) REFERENCES driver_assignments(id)
);

CREATE TABLE delivery_otp (
  order_id BIGINT PRIMARY KEY,
  code_hash VARCHAR(100) NOT NULL,
  expires_at TIMESTAMP(6) NOT NULL,
  verified_at TIMESTAMP(6),
  failed_attempts SMALLINT NOT NULL DEFAULT 0,
  CONSTRAINT fk_delivery_otp_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
);
