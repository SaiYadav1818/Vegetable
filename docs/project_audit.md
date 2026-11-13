# FreshBasket – Project Audit & Architecture Review

**Date:** November 2026  
**Auditor:** Principal Software Architect & QA Lead  
**Scope:** Full-stack inspection of Backend (Spring Boot 3.4.4, Java 17, MySQL 8.4, Flyway), Frontend (Flutter 3.x, Android), and Infrastructure/Integrations (FCM, Docker, Android Platform Channels).

---

## 1. Executive Summary

FreshBasket is an end-to-end vegetable ordering and delivery platform designed for local neighborhood shops. The system is architected as a **modular monolith** on the backend and a **role-gated multi-persona client** on Flutter (Customer, Admin, Driver). 

The application has completed four foundational phases of development:
1. **Phase 1**: Identity, BCrypt hashing, JWT issuance/validation, RBAC guards.
2. **Phase 2**: Flutter customer browsing, category navigation, Material 3 design system.
3. **Phase 3**: Catalog, category hierarchies, inventory ledger, image upload with dimension validation.
4. **Phase 4**: Server-persisted cart, atomic order placement with pessimistic locking, driver dispatch, OTP delivery verification, and an asynchronous FCM push notification engine.

While core business pathways are functional, several critical gaps must be bridged before the application can safely handle real commercial operations (e.g., lack of token refresh, absence of a background location foreground service for drivers, missing failure/reassignment states in the order lifecycle, and absence of database-driven shop operating hours).

---

## 2. Feature Classification Matrix

As per audit standards, every feature is classified into one of five rigorous tiers:
- **Fully implemented and verified**: Implemented in code, backed by database constraints, covered by tests, and verified functional.
- **Implemented but not tested**: Implemented in backend and frontend code, but lacking automated test coverage or verified end-to-end under real devices/simulations.
- **Partially implemented**: Core logic exists, but edge cases, lifecycle transitions, UI affordances, or API fields are missing.
- **Requires improvement**: Feature functions but suffers from architectural, UX, or operational shortcomings.
- **Missing**: Critical for a real vegetable store, but not yet implemented.

| Feature Area | Component / Flow | Classification | Details & Code References |
| :--- | :--- | :--- | :--- |
| **Authentication** | Customer Registration | **Fully implemented and verified** | Restricted to `CUSTOMER` role; email normalization; duplicate checks; covered in `AuthServiceTest`. |
| | Login & JWT Issuance | **Fully implemented and verified** | BCrypt match; issues HMAC-SHA signed JWT containing email and role. |
| | Admin Bootstrap | **Implemented but not tested** | `AdminBootstrap.java` runs only once if no admin exists; requires manual env setup. |
| | Driver Provisioning | **Implemented but not tested** | Restricted to Admin (`/api/admin/drivers`); generates driver user + `DriverProfile`. |
| | JWT Refresh & Revocation | **Missing** | JWT expires after 60 min; no refresh token or blacklist exists in backend or client. |
| **Catalog** | Category Hierarchy & CRUD | **Implemented but not tested** | Categories table with unique names; public read API; admin edit/deactivate API. |
| | Product CRUD & Pricing | **Implemented but not tested** | Positive price constraint; active/available flags; `ProductUnit` enum (`KG`, `PACK`, etc.). |
| | Product Image Upload | **Fully implemented and verified** | `ProductImageStorage.java`: Magic byte checks (PNG/JPEG), max 5MB, max 25MP ImageIO check, UUID file paths. |
| | Product Details Screen | **Implemented but not tested** | `product_details_page.dart` provides clean layout, unit pricing, description, stock status. |
| **Inventory** | Real-time Stock Tracking | **Fully implemented and verified** | Database constraint `quantity >= 0`; atomic decrements in order placement. |
| | Pessimistic Locking on Checkout | **Fully implemented and verified** | `inventory.findLockedByProductId` locks stock row during checkout to prevent overselling. |
| | Inventory Transaction Ledger | **Fully implemented and verified** | Immutable audit trail in `inventory_transactions` recording delta, post-quantity, actor, and reason. |
| | Low-Stock Alerts | **Implemented but not tested** | Compares against `minimum_stock` during order placement; triggers `BusinessNotificationPublisher.lowStock`. |
| | Batch / Spoilage Management | **Missing** | Perishable vegetables have shelf lives and waste; no lot/batch tracking or write-off module exists. |
| **Cart** | Server-Backed Persistent Cart | **Fully implemented and verified** | `carts` and `cart_items` tables; stock-enforced additions; covered in `customer_cart_test.dart`. |
| | Client-Side Optimistic Controls | **Fully implemented and verified** | Increment, decrement, delete line, clear; reactive state updates with Dio error rollback. |
| **Orders** | Atomic Checkout Transaction | **Fully implemented and verified** | Cart locked, price rechecked against `expectedSubtotal`, stock reduced, COD payment created, OTP saved. |
| | Order Number Generation | **Fully implemented and verified** | `FB-XXXXXXXXXXXX` unique random string. |
| | Order Status Audit Trail | **Fully implemented and verified** | `order_status_history` records `from_status`, `to_status`, actor, reason, and timestamp. |
| | Customer Cancellation | **Partially implemented** | Only permitted when status is `PLACED`; automatically restores stock and creates ledger entry. |
| | Order State Machine | **Partially implemented** | Supports `PLACED`, `ACCEPTED`, `PREPARING`, `READY_FOR_PICKUP`, `DRIVER_ASSIGNED`, `OUT_FOR_DELIVERY`, `DELIVERED`, `CANCELLED`, `REJECTED`. Missing `DELIVERY_FAILED`. |
| | Checkout Idempotency | **Requires improvement** | No unique idempotency key sent by Flutter; double-tap protection relies purely on UI state flag. |
| **Delivery & Driver** | Driver Availability Toggle | **Fully implemented and verified** | Guard prevents going offline if active assignments are pending (`ASSIGNED`, `ACCEPTED`, `PICKED_UP`). |
| | Driver Assignment | **Partially implemented** | Admin assigns online, available driver; order must be `READY_FOR_PICKUP`. Reassignment is not supported. |
| | Delivery OTP Verification | **Fully implemented and verified** | BCrypt-hashed 6-digit code; locked after 5 failed attempts; customer can rotate code on demand. |
| | Cash Collection Confirmation | **Partially implemented** | `DeliverRequest` requires `cashCollected=true`, marking `PaymentStatus.PAID` simultaneously. Needs independent admin reconciliation. |
| | Live GPS Streaming (Driver) | **Requires improvement** | Android `MethodChannel` requests `ACCESS_FINE_LOCATION`; periodically posted every 15s. Halts when app is minimized. |
| | Live GPS Tracking (Customer) | **Requires improvement** | 15s polling; opens external Google Maps link; no embedded map widget; no stale location handling. |
| **Notifications** | FCM Push Notification Engine | **Implemented but not tested** | Multi-device registration, background/foreground listeners, deduplication keys, retry worker. |
| | Notification History & Unread Count | **Implemented but not tested** | Database persistence in `notifications`; unread counter badge; mark-read API. |
| | Production Firebase Credentials | **Missing** | Requires genuine `google-services.json` and backend `FIREBASE_CREDENTIALS` service account. |
| **Shop Operations** | Shop Metadata & Working Hours | **Missing** | Opening/closing hours, temporary shop closure, store notice banner are not configurable via DB. |
| | Dynamic Delivery Configuration | **Missing** | Minimum order and delivery fee are hardcoded in backend `application.yml`; cannot be changed in Admin UI. |
| | Admin Analytics Dashboard | **Partially implemented** | `admin_dashboard_page.dart` calculates stats on client-side from recent lists; lacks server aggregate queries. |
| | Customer Saved Addresses | **Missing** | Customers re-enter full address, area, and pincode manually on every checkout. |

---

## 3. Deep-Dive Inspection of Existing Subsystems

### 3.1 Order Lifecycle and State Transitions
Existing flow in [OrderService.java](file:///C:/Users/dudim/OneDrive/Desktop/Vegetables/backend/src/main/java/in/freshbasket/orders/OrderService.java) and [DeliveryService.java](file:///C:/Users/dudim/OneDrive/Desktop/Vegetables/backend/src/main/java/in/freshbasket/orders/DeliveryService.java):
```
[Customer] Checkout -> PLACED
[Admin]    PLACED -> ACCEPTED or REJECTED or CANCELLED (restores stock)
[Admin]    ACCEPTED -> PREPARING or CANCELLED (restores stock)
[Admin]    PREPARING -> READY_FOR_PICKUP or CANCELLED (restores stock)
[Admin]    READY_FOR_PICKUP -> DRIVER_ASSIGNED (requires online, unassigned driver)
[Driver]   DRIVER_ASSIGNED -> ACCEPTED (driver accepts assignment)
[Driver]   ACCEPTED -> OUT_FOR_DELIVERY (driver picks up packages)
[Driver]   OUT_FOR_DELIVERY -> DELIVERED (validates customer OTP, sets Payment -> PAID)
```
**Key Architectural Deficiencies Identified:**
1. **Missing `DELIVERY_FAILED`**: If the customer is unreachable, the address is wrong, or customer rejects perishable produce, the driver cannot mark the delivery as failed.
2. **No Driver Reassignment**: In `driver_assignments`, `order_id` is unique. If an assigned driver breaks down or goes unresponsive, there is no endpoint to unassign or reassign the order to another driver.
3. **No Cancellation Once Accepted**: Customers cannot cancel after `PLACED`. While reasonable for perishable packing, there is no provision for customer service/admin cancellation during `PREPARING` without manual status updates.

### 3.2 Inventory Concurrency & Double-Spend Prevention
- **Deduction Timing**: Immediate at checkout time.
  - *Rationale*: For fresh vegetables with limited inventory, immediate deduction avoids overselling.
- **Pessimistic Locking**: `Inventory stock = inventory.findLockedByProductId(p.getId())` uses `LockModeType.PESSIMISTIC_WRITE` (SQL `SELECT ... FOR UPDATE`). Concurrent checkouts on the same product queue sequentially at the database row level.
- **Restoration**: Stock restoration is encapsulated in `OrderService.restoreStock()` and invoked only on terminal failure transitions (`CANCELLED`, `REJECTED`). Every restoration logs a compensating record in `inventory_transactions`.

### 3.3 Security & Role-Based Access Control
- **Filter Chain**: `SecurityConfig` enforces stateless JWT validation via `JwtAuthFilter`.
- **Role Isolation**:
  - `/api/admin/**` $\rightarrow$ guarded with `@PreAuthorize("hasRole('ADMIN')")` and filter rule.
  - `/api/driver/**` $\rightarrow$ guarded with `@PreAuthorize("hasRole('DRIVER')")`.
  - `/api/orders/**` & `/api/cart/**` $\rightarrow$ guarded with `@PreAuthorize("hasRole('CUSTOMER')")`.
- **Data Ownership**:
  - `OrderService.getMine(id, email)` and `cancelMine` explicitly filter by `order.getCustomer().getId() == authUser.getId()`.
  - `DeliveryService.ownedAssignment(orderId, driverId)` prevents drivers from viewing or updating orders assigned to others.
- **Vulnerabilities / Gaps**:
  - No rate limiting on `/api/auth/login` (brute force vulnerability).
  - Short-lived JWT (60 min) with no refresh mechanism degrades UX.
  - Upload directory `/uploads/**` is served statically without MIME validation on GET.

### 3.4 Real-Time Notifications
- [BusinessNotificationPublisher.java](file:///C:/Users/dudim/OneDrive/Desktop/Vegetables/backend/src/main/java/in/freshbasket/notifications/BusinessNotificationPublisher.java) publishes domain events.
- An `@Async("notificationExecutor")` event listener intercepts events `AFTER_COMMIT`, writes `NotificationRecord` rows with deduplication keys, and delegates to `NotificationDeliveryWorker`.
- If FCM is unconfigured (`FIREBASE_ENABLED=false`), records are persisted in MySQL and available via REST polling without throwing errors.
- Device tokens that return `UNREGISTERED` from FCM are automatically deactivated.

### 3.5 Location Tracking & Hardware Telemetry
- [MainActivity.kt](file:///C:/Users/dudim/OneDrive/Desktop/Vegetables/flutter_app/android/app/src/main/kotlin/com/example/freshbasket/MainActivity.kt) implements `freshbasket/device` MethodChannel.
- Uses Android `LocationManager` to query coarse or fine GPS location.
- **Major Operational Flaw**: In [driver_landing_page.dart](file:///C:/Users/dudim/OneDrive/Desktop/Vegetables/flutter_app/lib/features/driver/driver_landing_page.dart), `didChangeAppLifecycleState` immediately cancels location sharing when the app loses focus. Since drivers must switch to Google Maps or phone calls to find houses, location telemetry stops during navigation.

---

## 4. Test Coverage Assessment

- **Backend**:
  - [AuthServiceTest.java](file:///C:/Users/dudim/OneDrive/Desktop/Vegetables/backend/src/test/java/in/freshbasket/auth/AuthServiceTest.java): Unit tests for registration and duplicate email rejection.
  - **Missing**: OrderService integration tests, concurrent checkout tests, delivery OTP verification edge cases, stock restoration idempotency tests.
- **Frontend**:
  - [auth_page_test.dart](file:///C:/Users/dudim/OneDrive/Desktop/Vegetables/flutter_app/test/auth_page_test.dart): Form validation tests.
  - [customer_cart_test.dart](file:///C:/Users/dudim/OneDrive/Desktop/Vegetables/flutter_app/test/customer_cart_test.dart): Verifies quantity updates and stock limit guards.
  - [catalog_models_test.dart](file:///C:/Users/dudim/OneDrive/Desktop/Vegetables/flutter_app/test/catalog_models_test.dart): JSON serialization tests.
  - **Missing**: Checkout submission tests, driver state transition widget tests, order tracking polling tests.

---

## 5. Audit Conclusions & Strategic Directives

The existing codebase demonstrates solid architectural foundations (clean separation of concerns, transactional safety on orders, Flyway migrations, and typed Flutter models). To transform FreshBasket into a reliable production-grade vegetable delivery app, development must execute in strict order of priority:
1. Complete order state machine (support `DELIVERY_FAILED` and driver reassignment).
2. Harden checkout with client/server idempotency keys.
3. Introduce an Android Foreground Service for persistent driver GPS telemetry during delivery.
4. Add database-backed shop configuration (operating hours, temporary closure, dynamic delivery radius).
5. Build admin reconciliation reports for COD cash collections.
6. Provide refresh token support to prevent user session dropouts.
