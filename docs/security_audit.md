# FreshBasket – Security Architecture & Vulnerability Audit

**Date:** November 2026  
**Auditor:** Principal Security Architect & Lead Penetration Tester  
**Scope:** Backend API, Spring Security, JWT Implementation, Database Constraints, Mobile Client Storage, and File Upload Handling.

---

## 1. Executive Security Summary

FreshBasket adheres to strong defensive programming foundations:
- **Stateless Bearer Authentication**: Passwords hashed with industry-standard BCrypt; no session fixation or CSRF vulnerability due to `SessionCreationPolicy.STATELESS` and CSRF disabled.
- **Strict Role-Based Separation**: The URL namespaces `/api/admin/**`, `/api/driver/**`, `/api/cart/**`, and `/api/orders/**` are fortified by Spring Security method annotations (`@PreAuthorize`) and filter chain rules.
- **Transactional Row Locking**: Pessimistic locking prevents inventory race conditions and double-spending.
- **Safe File Uploads**: Magic-byte inspection, pixel dimension caps, and UUID file renaming shield against remote code execution (RCE).

However, key vulnerabilities exist in **rate limiting, token lifecycle management, driver location privacy boundaries, and customer checkout idempotency**.

---

## 2. Threat Analysis & Vulnerability Matrix

| Security Domain | Vulnerability / Threat | Severity | Code / Component Reference | Current Defense | Recommended Remediation |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Authentication** | Brute-force Password Attacks | **High** | `AuthController.login()` | None. No account lockout or IP rate limiting. | Implement IP and account-based rate limiting (5 attempts / min) using a token-bucket filter (Bucket4j or in-memory LRU). |
| **Authentication** | Expired Token Disruption & Replay | **Medium** | `JwtService.java` | 60-minute hard expiry; no refresh token or blacklist. | Issue a cryptographically secure 30-day refresh token stored as an HttpOnly cookie or secure storage; keep access token to 15 minutes. |
| **Authentication** | Secret Key Predictability | **High** | `application.yml` | Default fallback `local-development-secret...` | In production, startup must fail immediately if `JWT_SECRET` is the default or shorter than 256 bits. |
| **Authorization** | Horizontal Privilege Escalation (IDOR) on Orders | **Passed / Secure** | `OrderService.getMine()`, `cancelMine()` | Query filters by authenticated user ID (`customer.getId()`). | Maintain current explicit ownership checks in JPA repository queries. |
| **Authorization** | Driver Assignment Hijacking | **Passed / Secure** | `DeliveryService.ownedAssignment()` | Checks `assignment.getDriver().getUser().getId().equals(driverId)`. | Enforce that only the assigned driver can accept, pick up, or complete delivery. |
| **Authorization** | Self-Elevation of Privileges | **Passed / Secure** | `AuthService.register()` | Hardcoded `Role.CUSTOMER`; ignores request role. | Never accept role parameter in public registration DTOs. |
| **Delivery Security** | OTP Brute-Force Verification | **Low / Mitigated** | `DeliveryOtp.java` | 5 failed attempt limit; OTP is BCrypt-hashed; locked on 5th error. | Keep failed attempts counter in DB; allow customer to rotate code if compromised. |
| **Privacy** | Driver Location Leakage | **Medium** | `DriverLocation.java`, `OrderService.response()` | Location is only returned when assignment status != `DELIVERED`. | Ensure location sharing is only exposed to the customer whose order is currently `OUT_FOR_DELIVERY`. Automatically deactivate location row upon delivery completion. |
| **Data Protection** | Customer PII in Push Notifications | **Passed / Secure** | `BusinessNotificationPublisher.java` | FCM message payloads only contain generic text ("Order FB-XXXX was placed") and IDs; no recipient address or phone. | Continue omitting personal customer contact data from FCM data payloads. |
| **Data Protection** | Mobile Token Storage | **Passed / Secure** | `ApiClient.dart` | Uses `FlutterSecureStorage` (Android Keystore / iOS Keychain). | Verify Android auto-backup exclusions so keystore encrypted tokens are not backed up. |
| **File Uploads** | Malicious Executable Uploads | **Passed / Secure** | `ProductImageStorage.java` | Inspects magic bytes (PNG/JPEG); limits to 5MB; parses via ImageIO; UUID file naming. | Ensure upload directory `/uploads` does not have executable permissions on the host server. |
| **Database** | SQL Injection | **Passed / Secure** | All Repositories | Spring Data JPA parameterized queries and method derivation. No dynamic string concatenation. | Maintain strictly parameterized JPQL or native queries. |
| **Financial / State** | Double Checkout / Double Order Placement | **Medium** | `OrderService.place()` | Pessimistic locking on stock; no idempotency key on order request. | Add unique `idempotencyKey` per checkout request stored in `orders.idempotency_key` constraint. |

---

## 3. Deep-Dive Security Evaluation

### 3.1 Authentication & Password Security
- **Algorithm**: `BCryptPasswordEncoder` (Spring Security default strength = 10 rounds).
- **Entropy**: Passwords enforce `@Size(min=12)` on bootstrap and driver creation; registration enforces minimum 8 characters.
- **Evaluation**: Password hashing meets modern compliance standards.

### 3.2 Authorization & Role Architecture
The system isolates three principal personas:
1. `ROLE_ADMIN`:
   - Has access to `/api/admin/**`.
   - Controls categories, products, inventory, driver creation, driver assignment, order status overrides, and system reports.
2. `ROLE_DRIVER`:
   - Has access to `/api/driver/**`.
   - Restricts order visibility to assigned orders. Cannot view customer orders belonging to other drivers.
   - Requires explicit active delivery to broadcast GPS coordinates.
3. `ROLE_CUSTOMER`:
   - Has access to `/api/cart/**` and `/api/orders/**`.
   - Access to `/api/orders/{id}` verifies `customer.id == order.customer.id`. Customers cannot inspect peer orders.

### 3.3 File Upload Defensive Implementation
[ProductImageStorage.java](file:///C:/Users/dudim/OneDrive/Desktop/Vegetables/backend/src/main/java/in/freshbasket/catalog/ProductImageStorage.java) implements a defense-in-depth pipeline:
1. **File Size Check**: Rejects any file $> 5 \text{ MB}$.
2. **Magic Bytes Verification**:
   - PNG: `0x89 0x50 0x4E 0x47 0x0D 0x0A 0x1A 0x0A`.
   - JPEG: `0xFF 0xD8 0xFF`.
3. **ImageIO Content Decode**: Validates that bytes form a real renderable image and dimensions do not exceed 25 Megapixels (protecting against decompression bombs / pixel flood DoS).
4. **Path Traversal Shield**: Files are saved with `UUID.randomUUID().toString() + ".png/.jpg"`. File names supplied by HTTP headers are completely discarded.
5. **Parent Verification**: `target.getParent().equals(directory)` asserts the file stays inside the designated upload folder.

### 3.4 Rate Limiting & Denial of Service Deficiencies
- **Vulnerability**: Neither the backend nor mobile client limits the frequency of calls to:
  - `POST /api/auth/login` (enables online dictionary attacks).
  - `POST /api/orders/{id}/delivery-otp` (customer can spam OTP rotations).
  - `POST /api/driver/location` (driver app can spam GPS telemetry).
- **Remediation**:
  - Introduce an in-memory sliding window or token-bucket filter (e.g., Bucket4j).
  - Reject requests exceeding 5/minute on auth and 1/second on telemetry with HTTP 429 `Too Many Requests`.

### 3.5 Delivery OTP Cryptographic Integrity
The delivery OTP architecture is robust:
- OTP is generated via `SecureRandom` (`%06d`, 6 digits: 000000 to 999999).
- Stored as a BCrypt hash in `delivery_otp.code_hash`. Plaintext OTP is never persisted in MySQL.
- Verified using `passwordEncoder.matches(request.otp(), otp.getCodeHash())`.
- `failed_attempts` column tracks incorrect attempts. On the 5th bad attempt, the record is locked (`HttpStatus.LOCKED`).
- Expiration is set to 48 hours.

---

## 4. Production Security Hardening Checklist

- [ ] **Enforce Non-Default Secrets**: Reject startup in `application.yml` if `JWT_SECRET` equals the default template string.
- [ ] **Rate Limiting**: Add HTTP 429 rate limiter on login, registration, and OTP verification.
- [ ] **Idempotency Keys**: Add unique idempotency keys on `/api/orders/checkout`.
- [ ] **Secure Storage Audit**: Verify `flutter_secure_storage` uses encrypted SharedPreferences on Android (`encryptedSharedPreferences: true`).
- [ ] **Static File Security**: Add `Cache-Control: public, max-age=86400, no-transform` and `X-Content-Type-Options: nosniff` headers to `/uploads/**` responses.
- [ ] **HTTPS Enactment**: Ensure reverse proxy (Caddy / Nginx) terminates TLS with Let's Encrypt certificates before forwarding requests to Spring Boot on port 8080.
