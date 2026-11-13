-- V5__security_and_order_reliability.sql
-- 1. Checkout Idempotency: store unique idempotency key per customer
ALTER TABLE orders
  ADD COLUMN idempotency_key VARCHAR(64) NULL,
  ADD CONSTRAINT uq_orders_customer_idempotency UNIQUE (customer_user_id, idempotency_key);

-- 2. JWT Refresh Tokens
CREATE TABLE refresh_tokens (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  token_hash VARCHAR(64) NOT NULL UNIQUE,
  expires_at TIMESTAMP(6) NOT NULL,
  revoked BOOLEAN NOT NULL DEFAULT FALSE,
  replaced_by_hash VARCHAR(64) NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_refresh_tokens_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_refresh_tokens_user (user_id, revoked)
);

-- 3. Driver Assignments: Allow reassignment by replacing single unique order constraint with index and tracking failure
ALTER TABLE driver_assignments ADD INDEX idx_driver_assignments_order (order_id);
ALTER TABLE driver_assignments DROP INDEX order_id;
ALTER TABLE driver_assignments
  ADD COLUMN failed_at TIMESTAMP(6) NULL,
  ADD COLUMN failure_reason VARCHAR(300) NULL;

-- 4. COD Payment Reconciliation: Explicit collection & settlement audit
ALTER TABLE payments
  ADD COLUMN collected_by_driver_user_id BIGINT NULL,
  ADD COLUMN collected_at TIMESTAMP(6) NULL,
  ADD COLUMN reconciled BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN reconciled_at TIMESTAMP(6) NULL,
  ADD COLUMN reconciled_by_user_id BIGINT NULL,
  ADD COLUMN reconciliation_note VARCHAR(300) NULL,
  ADD CONSTRAINT fk_payments_collected_by FOREIGN KEY (collected_by_driver_user_id) REFERENCES users(id),
  ADD CONSTRAINT fk_payments_reconciled_by FOREIGN KEY (reconciled_by_user_id) REFERENCES users(id),
  ADD INDEX idx_payments_reconciliation (status, reconciled, collected_by_driver_user_id);
