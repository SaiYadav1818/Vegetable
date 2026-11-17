# FreshBasket – Comprehensive Missing Features & Gap Analysis

**Date:** November 2026  
**Auditor:** Principal Software Architect & Product Lead  
**Scope:** Functional and technical requirements necessary for running a real single-shop neighborhood vegetable delivery business.

---

## 1. Overview

While FreshBasket provides a working prototype spanning customer ordering, catalog management, and driver dispatch, a production deployment in a real physical store faces real-world operational friction: drivers encounter locked gates, customers request order changes after shop confirmation, shopkeepers close early on festivals, and cash collected by drivers needs end-of-day reconciliation.

This document identifies every missing feature and architectural gap across seven operational domains.

---

## 2. Order Management Gaps

| Feature | Status | Details / Implemented Solution |
| :--- | :--- | :--- |
| **`DELIVERY_FAILED` Status** | **Implemented (Phase 1)** | Added `DELIVERY_FAILED` to `OrderStatus` and `AssignmentStatus`. Driver reports failure via `PUT /api/driver/orders/{id}/fail` with structured reason codes. Driver released; order transitions to `DELIVERY_FAILED`; stock preserved until admin audit. |
| **Driver Reassignment & Unassignment** | **Implemented (Phase 1)** | Relaxed 1:1 `order_id` in `driver_assignments` via Flyway migration `V5`. `DeliveryService.assign()` cancels prior active assignments and reassigns driver while retaining full assignment audit history. |
| **Checkout Idempotency Key** | **Implemented (Phase 1)** | Flutter sends client UUID `idempotencyKey`. Flyway `V5` adds `(customer_user_id, idempotency_key)` unique constraint. Repeated submissions return existing order without duplicate stock deductions. |
| **Delivery Slot Cutoff Hours** | Open / Phase 2 | Implement cutoff logic: Morning slot (6 AM – 9 AM) cut off at 7:00 AM; Evening slot (5 PM – 8 PM) cut off at 3:30 PM. Disable past slots in Flutter date/slot picker and validate on backend. |
| **Admin Order Cancellation & Editing** | Open / Phase 2 | Enable Admin to cancel orders at `ACCEPTED` or `PREPARING` stage with reason ("Damaged stock", "Customer phone request") and auto-restore inventory. |

---

## 3. Inventory & Perishable Goods Gaps

| Missing Feature | Business Impact | Required Solution |
| :--- | :--- | :--- |
| **Safety Stock Buffer** | Fresh vegetables lose weight or have bad pieces sorted out during packing (e.g., leafy greens). Selling 100% of recorded inventory frequently causes stockouts at the packing table. | Add `safety_stock_buffer` percentage or quantity threshold. Only expose `sellable_quantity = max(0, quantity - safety_stock_buffer)` to the customer catalog. |
| **Stock Spoilage / Shrinkage Write-off** | Perishable produce spoils daily. Shop owners need to discard unsellable vegetables without tying them to an order. | Add an Admin inventory adjustment reason: `SPOILAGE_WRITE_OFF` or `WEIGHT_LOSS` in `CatalogService.adjustInventory()`, logging dedicated loss records in `inventory_transactions`. |
| **Immediate Deduction vs. Reservation** | FreshBasket currently deducts stock immediately at checkout. If a shop rejects an order (`REJECTED`), stock is restored. | Documented Decision: **Immediate deduction at checkout is optimal for single-shop fresh produce.** Reserving stock in temporary carts leads to "inventory hoarding" where bots or abandoned carts lock perishable stock. Immediate checkout deduction with atomic rollback upon rejection/cancellation is the most reliable model. |

---

## 4. Shop Settings & Delivery Configuration

Currently, shop parameters are hardcoded in `application.yml` or assumed in code. A real store owner must be able to manage their shop from the admin panel.

| Missing Feature | Description & Requirement |
| :--- | :--- |
| **Shop Operating Hours** | **Implemented (Phase 2)**: Stored in `shop_settings` via Flyway `V6`. Customer Home and Checkout screens display store opening hours, while Admin Dashboard provides interactive sheet to configure daily hours. |
| **Temporary Shop Closure Toggle** | **Implemented (Phase 2)**: Single-click toggle in Admin Dashboard (`open_today`). Blocks checkout when closed with store notice and informs customers on Home Page. |
| **Dynamic Delivery Rules** | **Implemented (Phase 2)**: `min_order_value`, `delivery_charge`, and `free_delivery_threshold` in `shop_settings`. APIs `GET /api/shop/settings` and `PUT /api/admin/shop-settings`. Dynamically calculated at checkout. |
| **Delivery Radius & Geofencing** | Currently, any 6-digit pincode is accepted. A neighborhood shop cannot deliver 30 km away. Implement a supported pincode list or maximum delivery radius (e.g. 5 km from shop coordinates). |
| **Shop Contact & Metadata** | **Implemented (Phase 2)**: Shop contact phone and store address exposed via `GET /api/shop/settings` and displayed in Customer Home Support and Store Manager headers. |

---

## 5. Customer Experience Improvements

| Feature | Current State | Missing Functionality |
| :--- | :--- | :--- |
| **Saved Addresses** | **Implemented (Phase 2)** | `customer_addresses` table via Flyway `V6`. `CustomerAddressService` provides address saving, listing, update, delete, and default selection. Flutter Checkout page provides one-tap address chips. |
| **Reorder Button** | **Implemented (Phase 2)** | `POST /api/orders/{id}/reorder` validates stock availability, adds available items into cart, and returns itemized report. Flutter My Orders page provides "Reorder items" action. |
| **Order Receipt / Invoice** | Open / Future Phase | Add an in-app receipt summary view with store GST/Tax ID (if applicable), breakdown of line totals, delivery fee, payment mode, and order timestamp. |
| **Customer Cancellation Reasons** | **Implemented (Phase 2)** | Modal dialog with reason chips ("Changed mind", "Ordered by mistake", etc.) sending structured cancellation reason saved in `orders.cancellation_reason` and restoring stock. |
| **Product Reviews & Ratings** | Not present. | Lightweight 1-5 star rating and comment per delivered product to help the shop identify suppliers with low vegetable quality. |

---

## 6. Admin Analytics & Financial Operations

| Analytics Area | Current State | Missing Functionality |
| :--- | :--- | :--- |
| **Financial Revenue Aggregates** | **Implemented (Phase 2)** | Backend `AnalyticsService` queries: `total_revenue`, `today_revenue`, `weekly_revenue`, `average_order_value (AOV)`. Exposed via `GET /api/admin/analytics/overview`. |
| **COD Cash Reconciliation** | **Implemented (Phase 1)** | `GET /api/admin/reports/cod-reconciliation` exposes per-driver unsettled and collected cash. Admin can reconcile per-payment (`POST /api/admin/payments/{id}/reconcile`) or batch driver settlement (`POST /api/admin/drivers/{driverId}/reconcile-all`). Flutter Admin Dashboard features live COD reconciliation bottom sheet. |
| **Best-Selling Vegetables** | **Implemented (Phase 2)** | Database aggregate query grouping `order_items` from delivered orders to highlight top vegetables with quantity sold and revenue. Displayed in Flutter Admin Dashboard. |
| **Driver Performance Metrics** | **Implemented (Phase 2)** | Fleet metric cards in Admin Dashboard: Total drivers, online drivers, available drivers, completed deliveries, COD collected, and unsettled balances. |

---

## 7. Delivery Tracking & Telemetry Gaps

| Area | Deficiency | Required Architectural Fix |
| :--- | :--- | :--- |
| **Foreground Service (Android)** | Driver location stops sending when the driver opens Google Maps or minimizes the app. | Implement an Android Foreground Service with a sticky system notification ("FreshBasket Delivery Active – Sharing Location"). Ensures GPS updates persist while navigating. |
| **Embedded Map View** | Customer app launches an external Google Maps link instead of displaying the driver on a live map. | Integrate an in-app OpenStreetMap widget (using `flutter_map` or Google Maps SDK) showing delivery address pin, shop location, and moving driver marker. |
| **Stale Location Warning** | If a driver loses cellular signal, customer sees the driver's last position without knowing it was sent 20 minutes ago. | Calculate `seconds_since_last_update`. If $> 120$ seconds, display a warning badge: "Location update paused (driver signal weak)". |

---

## 8. Technical & Security Gaps

| Technical Gap | Severity | Status & Implemented Solution |
| :--- | :--- | :--- |
| **Token Refresh Mechanism** | High | **Implemented (Phase 1)**: `refresh_tokens` table created via Flyway `V5`. `RefreshTokenService` provides token issuance, rotation, and replay attack revocation. Flutter `ApiClient` queues 401 retries seamlessly with `FlutterSecureStorage`. |
| **Rate Limiting** | High | **Implemented (Phase 1)**: `AuthRateLimiter` enforces in-memory token-bucket limits on login (5/min) and registration (10/10min), issuing HTTP 429 and generic error messages. |
| **Static Upload Protection** | Medium | Direct `/uploads/**` resource mapping does not enforce cache-control or content-disposition headers. Add headers to prevent script execution if malicious files are uploaded. |
| **Driver Location History Retention** | Low | Currently, only the latest active location is stored per driver (`driver_locations`). Historical route breadcrumbs are not retained. For disputes, a lightweight `delivery_location_history` table should store periodic coordinates until delivery is marked complete. |
