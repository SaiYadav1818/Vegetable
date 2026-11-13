# FreshBasket – Security Architecture & Vulnerability Audit

**Version:** 1.1 (Phase 1: Critical Security & Order Reliability)  
**Date:** November 2026  
**Scope:** Backend API, Spring Security, JWT & Refresh Implementation, Database Constraints, Mobile Client Storage, and File Upload Handling.

---

## 1. Executive Security Summary

FreshBasket adheres to strong defensive programming foundations:
- **Stateless Bearer Authentication & Refresh Tokens**: Short-lived JWTs (60 min) paired with cryptographically secure, rotating 30-day refresh tokens stored as SHA-256 hashes in MySQL. Mobile client stores tokens in hardware-backed `FlutterSecureStorage`.
- **Brute-Force & Flood Protection**: In-memory sliding token-bucket rate limiter (`AuthRateLimiter`) blocks credential stuffing, dictionary attacks, and registration flooding with HTTP 429.
- **Strict Role-Based Separation**: URL namespaces `/api/admin/**`, `/api/driver/**`, `/api/cart/**`, and `/api/orders/**` are fortified by Spring Security filter chains and `@PreAuthorize` guards.
- **Order Concurrency & Idempotency**: Pessimistic row locking (`LockModeType.PESSIMISTIC_WRITE`) prevents inventory double-allocation; unique client-generated UUID idempotency keys prevent duplicate order placement during network retries.
- **Decoupled Financial Auditing**: Separation of physical order delivery from payment collection ensures COD cash handling is auditable and reconciled by administrators.
- **Safe File Uploads**: Magic-byte inspection, pixel dimension caps, and UUID file renaming shield against remote code execution (RCE).

---

## 2. Threat Analysis & Vulnerability Matrix

| Security Domain | Vulnerability / Threat | Severity | Component Reference | Status & Implemented Defense | Verification |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Authentication** | Brute-force Password Attacks | **High** | `AuthController.login()`, `AuthRateLimiter` | **Mitigated**: Enforces max 5 failed attempts/minute per IP/identifier; returns HTTP 429 with generic error responses to prevent user enumeration. | Verified in `AuthServiceTest` |
| **Authentication** | Expired Token Disruption & Replay | **Medium** | `RefreshTokenService`, `ApiClient` | **Mitigated**: Rotating refresh tokens with SHA-256 hashing; reuse detection automatically revokes all user sessions if a compromised token is reused. | Verified in `RefreshTokenServiceTest` |
| **Authentication** | Secret Key Predictability | **High** | `application.yml` | **Defense**: Standard HMAC-SHA256 secret key configuration via environment variable `JWT_SECRET`. | Configurable |
| **Authorization** | Horizontal Privilege Escalation (IDOR) on Orders | **Passed / Secure** | `OrderService.getMine()`, `cancelMine()` | **Enforced**: JPA queries filter explicitly by authenticated customer user ID (`customer.getId()`). | Unit tested |
| **Authorization** | Driver Assignment Hijacking | **Passed / Secure** | `DeliveryService.ownedAssignment()` | **Enforced**: Validates `assignment.getDriver().getUser().getId().equals(driverId)`. Only assigned driver can update delivery states. | Unit tested |
| **Authorization** | Self-Elevation of Privileges | **Passed / Secure** | `AuthService.register()` | **Enforced**: Registration strictly hardcodes `Role.CUSTOMER`. Admin and Driver provisioning require explicit administrative APIs. | Verified |
| **Delivery Security** | OTP Brute-Force Verification | **Low / Mitigated** | `DeliveryOtp.java` | **Enforced**: 5 failed attempt limit; OTP is BCrypt-hashed; locked on 5th error. Plaintext OTP is never stored in DB. | Verified |
| **Financial / State** | Double Checkout / Order Duplication | **High** | `OrderService.place()`, `orders.idempotency_key` | **Mitigated**: Mandatory client UUID idempotency key enforced via MySQL unique constraint `(customer_user_id, idempotency_key)` and backend query. Repeated requests return existing order. | Verified in `OrderReliabilityTest` |
| **Financial / COD** | Unverified Driver Cash Collection | **Medium** | `DeliveryService.deliver()`, `PaymentRepository` | **Mitigated**: Decoupled order delivery from payment status. Requires explicit driver cash confirmation; tracks collecting driver and administrative reconciliation. | Verified in `OrderReliabilityTest` |
| **Privacy** | Driver Location Leakage | **Medium** | `DriverLocation.java`, `OrderService.response()` | **Enforced**: Driver location is only exposed to the customer whose order is currently active (`OUT_FOR_DELIVERY`). | Code inspected |
| **Data Protection** | Customer PII in Push Notifications | **Passed / Secure** | `BusinessNotificationPublisher.java` | **Enforced**: Push notification payloads contain only order numbers and generic messages, omitting phone numbers or addresses. | Code inspected |
| **Data Protection** | Mobile Token Storage | **Passed / Secure** | `ApiClient.dart` | **Enforced**: Uses `FlutterSecureStorage` utilizing Android Keystore / iOS Keychain. | Code inspected |
| **File Uploads** | Malicious Executable Uploads | **Passed / Secure** | `ProductImageStorage.java` | **Enforced**: Magic byte verification, max 5MB, max 25MP dimensions, UUID file renaming. Uploads directory cannot execute scripts. | Code inspected |
| **Database** | SQL Injection | **Passed / Secure** | All Repositories | **Enforced**: All queries use Spring Data JPA parameterized derived queries or JPQL. No dynamic string concatenation. | Code inspected |

---

## 3. Deep-Dive Security Evaluation

### 3.1 Authentication & Token Rotation Security
FreshBasket implements refresh token rotation with theft detection:
- Each refresh token is generated via `SecureRandom` (64 alphanumeric characters).
- Stored exclusively as SHA-256 hex hashes in MySQL `refresh_tokens`.
- On refresh:
  1. The presented token is hashed and checked against active records.
  2. If the token was previously revoked (a rotated token is submitted again), the system detects a token replay attack and revokes **all** active tokens for that user ID.
  3. If valid, the existing token is marked `revoked = true` and `replaced_by_hash = newHash`, and a newly minted token is returned.
- Flutter's `ApiClient` queues concurrent requests during a refresh cycle using Dio's `QueuedInterceptor`, preventing race conditions where multiple requests attempt simultaneous rotation.

### 3.2 Anti-Brute-Force & Enumeration Protections
- `AuthRateLimiter`:
  - Token-bucket algorithm with automatic cleanup of expired tracking entries.
  - Prevents credential stuffing against `/api/auth/login`.
  - Prevents mass account creation on `/api/auth/register`.
- Error Message Normalization:
  - Registration rejects duplicate emails/phones with: `"Account registration cannot be processed with the provided details."`
  - Login rejects invalid credentials with: `"Invalid email/phone or password."`
  - Neither response leaks whether the email or phone number is registered.

### 3.3 Checkout Idempotency & Concurrency Defenses
- A customer double-tapping "Checkout" or retrying on a dropped network connection sends the same `idempotencyKey`.
- Backend checks for an existing order by `(customer_id, idempotency_key)`.
- If found, it returns the existing order details without touching inventory or creating extra charges.
- The database constraint `uk_orders_customer_idempotency` ensures that even two parallel requests running simultaneously cannot insert two order records.

### 3.4 Delivery Failure & Stock Protection
- Drivers report delivery failures via `/api/driver/orders/{id}/fail` with an authenticated session and verified assignment ownership.
- The order transitions to `DELIVERY_FAILED`, preventing duplicate delivery completion.
- To prevent inventory discrepancy or theft, stock is **not** restored automatically upon delivery failure; inventory remains allocated until the physical package is inspected and marked cancelled or restocked by an administrator.

---

## 4. Production Security Hardening Checklist

- [x] **Rate Limiting**: In-memory token-bucket rate limiter active on login and registration (HTTP 429).
- [x] **Token Refresh & Rotation**: Dual-token mechanism with SHA-256 token hash storage, rotation, and reuse revocation.
- [x] **Idempotency Keys**: Unique client UUID idempotency keys enforced on `/api/orders/checkout` with DB unique constraint.
- [x] **User Enumeration Defense**: Opaque authentication and registration error messages.
- [x] **COD Audit & Reconciliation**: Separation of delivery status and payment status with administrative cash reconciliation.
- [ ] **Enforce Non-Default Secrets**: Reject startup in `application.yml` if `JWT_SECRET` equals the default template string in production profile.
- [ ] **Android Auto-Backup Exclusions**: Ensure `AndroidManifest.xml` excludes `FlutterSecureStorage` files from cloud auto-backup.
- [ ] **HTTPS Enactment**: Deploy reverse proxy (Nginx or Caddy) with TLS termination and security headers (`X-Content-Type-Options: nosniff`, `Strict-Transport-Security`).
