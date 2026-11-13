CREATE TABLE device_tokens (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  device_id VARCHAR(128) NOT NULL,
  token VARCHAR(512) NOT NULL UNIQUE,
  device_platform VARCHAR(16) NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_device_tokens_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT uq_device_tokens_user_device UNIQUE (user_id, device_id),
  INDEX idx_device_tokens_user_active (user_id, active)
);

CREATE TABLE notifications (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  order_id BIGINT NULL,
  event_type VARCHAR(40) NOT NULL,
  deduplication_key VARCHAR(160) NOT NULL,
  title VARCHAR(120) NOT NULL,
  body VARCHAR(240) NOT NULL,
  read_at TIMESTAMP(6) NULL,
  delivery_status VARCHAR(16) NOT NULL DEFAULT 'PENDING',
  attempts SMALLINT NOT NULL DEFAULT 0,
  next_attempt_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  last_error VARCHAR(240) NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_notifications_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL,
  CONSTRAINT uq_notifications_dedupe UNIQUE (user_id, deduplication_key),
  INDEX idx_notifications_user_created (user_id, created_at),
  INDEX idx_notifications_delivery (delivery_status, next_attempt_at)
);
