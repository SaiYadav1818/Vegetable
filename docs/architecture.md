# FreshBasket Architecture & System Design

**Version:** 1.1 (Phase 1: Critical Security & Order Reliability)  
**Date:** November 2026  
**Status:** Implemented & Verified  

---

## 1. Architectural Overview

FreshBasket is designed as a **modular monolith** optimized for single-shop fresh vegetable retail and hyper-local home delivery. 

```
                                  +------------------------------------+
                                  | Flutter Multi-Persona Mobile App   |
                                  | (Customer, Store Admin, Driver)    |
                                  +-----------------+------------------+
                                                    |
                                    HTTPS / REST API| Bearer JWT + Refresh
                                                    v
                                  +------------------------------------+
                                  | Spring Boot 3.4.4 Modular Service  |
                                  |                                    |
                                  | +--------------------------------+ |
                                  | | AuthRateLimiter & Security     | |
                                  | +--------------------------------+ |
                                  | | Catalog & Inventory Domain     | |
                                  | +--------------------------------+ |
                                  | | Cart & Checkout Domain         | |
                                  | +--------------------------------+ |
                                  | | Order State Machine & History  | |
                                  | +--------------------------------+ |
                                  | | Dispatch, Tracking & Delivery  | |
                                  | +--------------------------------+ |
                                  | | COD Reconciliation & Reports   | |
                                  | +--------------------------------+ |
                                  +-----------------+------------------+
                                                    |
                                       JDBC / Flyway| Connection Pool
                                                    v
                                  +------------------------------------+
                                  | MySQL 8.4 Engine                   |
                                  | (Pessimistic Row Locks, Unique Ks) |
                                  +------------------------------------+
```

The system segregates responsibilities cleanly:
- **Backend**: Single Spring Boot REST service with bounded contexts: `auth`, `catalog`, `cart`, `orders`, `notifications`, and `security`.
- **Database**: MySQL 8.4 managed exclusively through versioned Flyway migrations (`V1` through `V5`).
- **Frontend**: Single cross-platform Flutter application serving three personas (`ROLE_CUSTOMER`, `ROLE_ADMIN`, `ROLE_DRIVER`) isolated by GoRouter redirects and role-gated UI trees.
- **Client Networking**: Dio HTTP client configured with a queuing interceptor for transparent JWT refresh and double-tap prevention.

---

## 2. Authentication & Token Lifecycle Architecture

### 2.1 Dual-Token Architecture with Rotation
To combine stateless fast-path authentication with secure session revocation, FreshBasket implements a rotating dual-token mechanism:
1. **Access Token**:
   - Short-lived HMAC-SHA256 signed JWT (60 minutes).
   - Contains user ID (`sub`), role claims, and issuer metadata.
   - Evaluated statelessly in `JwtAuthFilter` without database queries.
2. **Refresh Token**:
   - Cryptographically random 64-character token issued at login/registration.
   - Stored in MySQL `refresh_tokens` as a SHA-256 hash (`token_hash`) with a 30-day lifetime.
   - Stored on mobile devices using `FlutterSecureStorage` (hardware-backed Android Keystore).

```
Customer App                      Spring Boot Backend                     MySQL
     |                                    |                                 |
     |--- 1. POST /api/auth/login ------->|                                 |
     |                                    |--- Hash & verify password ----->|
     |                                    |<-- User verified ---------------|
     |<-- 2. AccessToken + RefreshToken --|--- Save SHA-256 hash in DB ---->|
     |                                    |                                 |
     |... 60 mins elapse (401 received) ..|                                 |
     |                                    |                                 |
     |--- 3. POST /api/auth/refresh ----->|                                 |
     |    (Queued Dio Interceptor)        |--- Find active hash & rotate -->|
     |                                    |--- Revoke old token ------------|
     |                                    |--- Save new hash in DB -------->|
     |<-- 4. New Access + New Refresh ----|                                 |
```

### 2.2 Replay Attack & Compromise Detection
If an adversary intercepts and attempts to reuse an already-rotated refresh token:
- `RefreshTokenService` detects `token.isRevoked()`.
- The system flags a **token reuse security violation**.
- **All active refresh tokens belonging to that user are immediately revoked**, forcing all sessions to terminate.
- Flutter's `ApiClient` triggers `onAuthenticationExpired`, purging secure storage and routing to the login screen.

### 2.3 Rate Limiting & User Enumeration Protection
- `AuthRateLimiter` enforces in-memory token-bucket rate limits:
  - Max **5 failed login attempts per minute** per client IP and identifier.
  - Max **10 registrations per 10 minutes** per client IP.
  - Requests exceeding quota receive `429 Too Many Requests` with a descriptive message.
- To prevent user enumeration, failed login responses always return a generic `Invalid email/phone or password`, and duplicate registration attempts return `Account registration cannot be processed with the provided details`.

---

## 3. Order Lifecycle & Strict State Machine

### 3.1 Extended Order State Transitions
The order state machine is strictly enforced by `OrderService` and `DeliveryService`:

```
                       +-------------------+
                       |      PLACED       |
                       +---------+---------+
                                 |
                    +------------+------------+
                    |                         |
                    v                         v
            +---------------+         +---------------+
            |   ACCEPTED    |         |   REJECTED    |
            +-------+-------+         +---------------+
                    |
                    v
            +---------------+
            |   PREPARING   |
            +-------+-------+
                    |
                    v
            +-------------------+
            | READY_FOR_PICKUP  |<-----------------------------+
            +---------+---------+                              |
                      |                                        |
                      v                                        | Admin
            +-------------------+                              | Reassign
            |  DRIVER_ASSIGNED  |                              |
            +---------+---------+                              |
                      |                                        |
                      v                                        |
            +-------------------+                              |
            | OUT_FOR_DELIVERY  |                              |
            +----+---------+----+                              |
                 |         |                                   |
    Delivery     |         | Customer Absent /                 |
    OTP Verified |         | Unreachable                       |
                 v         v                                   |
         +-----------+   +-------------------+                 |
         | DELIVERED |   |  DELIVERY_FAILED  |-----------------+
         +-----------+   +---------+---------+
                                   |
                                   | Admin Cancels
                                   v
                         +-------------------+
                         |     CANCELLED     | (Stock Restored)
                         +-------------------+
```

### 3.2 Delivery Failure & History Tracking
- When a driver cannot complete a delivery, they submit a failure request via `PUT /api/driver/orders/{id}/fail` providing a structured reason (`CUSTOMER_UNAVAILABLE`, `INCORRECT_ADDRESS`, `CUSTOMER_REFUSED`, `WEATHER_OR_ROAD_BLOCK`, `OTHER`).
- The order transitions to `DELIVERY_FAILED`, and the active assignment is marked `FAILED` with failure timestamp and reason.
- **Stock is NOT automatically restored upon delivery failure**: fresh produce remains with the driver or returns to the shop until an admin inspects the goods.
- Admin can reassign the order back to `READY_FOR_PICKUP` or another driver, creating a new `DriverAssignment` record while preserving the previous assignment for audit purposes.

---

## 4. Checkout Idempotency & Concurrency Safety

### 4.1 Client-Generated Idempotency Key
- On unstable mobile connections, duplicate order submissions are prevented using an idempotency key generated at the initiation of checkout (`UUID.v4()`).
- The key is sent in the `idempotencyKey` field of `POST /api/orders/checkout`.
- The database enforces `CONSTRAINT uk_orders_customer_idempotency UNIQUE (customer_user_id, idempotency_key)`.

### 4.2 Backend Processing Semantics
1. Before initiating cart locking or stock deduction, `OrderService` queries `orderRepository.findByCustomer_IdAndIdempotencyKey(user.getId(), idempotencyKey)`.
2. If an order with that key already exists for the customer, `OrderService` immediately returns the existing `OrderResponse` without modifying inventory or creating duplicate charges.
3. If concurrent requests arrive simultaneously with the same key, MySQL's unique constraint causes the duplicate transaction to roll back safely.

### 4.3 Pessimistic Row Locking on Inventory
- Stock deduction occurs within a single `@Transactional` method.
- Stock rows are queried with `LockModeType.PESSIMISTIC_WRITE` (`SELECT ... FOR UPDATE`).
- This guarantees sequential execution for concurrent buyers purchasing the final units of a vegetable, preventing negative stock or overselling.

---

## 5. Decoupled Delivery & COD Payment Reconciliation

### 5.1 Decoupling Principle
In traditional e-commerce, order delivery and payment completion are often conflated. For Cash on Delivery (COD) fresh produce, physical package handover and financial cash collection are distinct operational events.

- A delivery can succeed with cash collected (`cashCollected = true`), transitioning payment to `PAID`.
- A package can be accepted where cash collection failed or was deferred, keeping payment in `PENDING` or `FAILED`.
- Physical cash remains in the driver's custody until end-of-day store settlement.

### 5.2 COD Reconciliation Lifecycle
```
[Driver Completes Delivery with Cash]
           |
           v
`payments.status = PAID`
`payments.collected_by_driver_user_id = driver.id`
`payments.reconciled = false`
           |
           v
[End-of-Day Store Reconciliation]
Admin views `GET /api/admin/reports/cod-reconciliation`
Driver hands physical cash to store manager
Store manager executes:
- `POST /api/admin/payments/{id}/reconcile` (Individual order) OR
- `POST /api/admin/drivers/{driverId}/reconcile-all` (Batch driver settlement)
           |
           v
`payments.reconciled = true`
`payments.reconciled_at = NOW()`
`payments.reconciled_by_user_id = admin.id`
`payments.reconciliation_note = "Cash verified & deposited"`
```

---

## 6. Audit & History Immutability
All status shifts and monetary reconciliations produce immutable audit records:
- `order_status_history`: Tracks transitions, actors (`CUSTOMER`, `ADMIN`, `DRIVER`), notes, and timestamps.
- `inventory_transactions`: Tracks stock deltas, reasons (`ORDER_PLACED`, `ORDER_CANCELLED`, `ORDER_REJECTED`), and balances.
- `driver_assignments`: Retains complete history of every assigned, failed, and completed delivery run.
- `payments`: Retains full financial trail of amount, collection status, collecting driver, and reconciling administrator.
