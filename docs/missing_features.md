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

| Missing Feature | Business Impact | Required Solution |
| :--- | :--- | :--- |
| **`DELIVERY_FAILED` Status** | When a driver reaches an address but the customer is absent, phone is dead, or address is unreachable, the driver has no way to exit the delivery state without a valid customer OTP. | Add `DELIVERY_FAILED` to `OrderStatus` and `AssignmentStatus`. Allow driver to mark failure with a mandatory reason code (`CUSTOMER_UNAVAILABLE`, `INCORRECT_ADDRESS`, `CUSTOMER_REFUSED`). Automatically release driver availability and trigger admin notification. Stock should NOT be immediately restored until admin reviews the package condition. |
| **Driver Reassignment & Unassignment** | If an assigned driver has a vehicle puncture or fails to accept an order within 15 minutes, the order is currently stuck because `driver_assignments.order_id` is unique and the backend throws a conflict if reassignment is attempted. | Update `DeliveryService.assign()` to support reassigning an existing order from driver A to driver B. Mark old assignment as `CANCELLED` or update the assigned driver. Reset order status to `READY_FOR_PICKUP` or `DRIVER_ASSIGNED` and notify both drivers. |
| **Checkout Idempotency Key** | On flaky 3G/4G connections, a customer may tap "Place Order" multiple times. If network drops before receiving the response, retrying may place duplicate orders. | Add `idempotencyKey` (UUID) to `CheckoutRequest`. Store it in `orders.idempotency_key` (UNIQUE). If a duplicate key arrives within 24 hours, return the existing order without re-executing inventory deductions. |
| **Delivery Slot Cutoff Hours** | Currently, a customer can pick today's MORNING slot at 11:30 AM even if morning delivery is already underway. | Implement cutoff logic: Morning slot (6 AM – 9 AM) cut off at 7:00 AM; Evening slot (5 PM – 8 PM) cut off at 3:30 PM. Disable past slots in Flutter date/slot picker and validate on backend. |
| **Admin Order Cancellation & Editing** | If a customer calls the shop asking to remove an item because they bought it elsewhere, or if an item in the order was damaged during packing, admin currently has no way to adjust or cancel the order after accepting it. | Enable Admin to cancel orders at `ACCEPTED` or `PREPARING` stage with reason ("Damaged stock", "Customer phone request") and auto-restore inventory. |

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
| **Shop Operating Hours** | Store `opening_time` (e.g. 06:30) and `closing_time` (e.g. 21:00). When current local time is outside operating hours, Flutter displays "Shop is closed. Orders placed now will be packed tomorrow morning." |
| **Temporary Shop Closure Toggle** | Single-click toggle in Admin panel (`is_open_today: false`, e.g., rainy day, market holiday). Disables new order placement immediately with custom customer message. |
| **Dynamic Delivery Rules** | Move `minimum_order_value`, `delivery_charge`, and `free_delivery_threshold` (e.g., Free delivery above ₹500) into a database table `shop_settings` with an Admin API (`PUT /api/admin/shop-settings`) and public read API (`GET /api/shop/settings`). |
| **Delivery Radius & Geofencing** | Currently, any 6-digit pincode is accepted. A neighborhood shop cannot deliver 30 km away. Implement a supported pincode list or maximum delivery radius (e.g. 5 km from shop coordinates). |
| **Shop Contact & UPI Metadata** | Display shop phone number, WhatsApp contact button for customer queries, and shop address on the home and checkout screens. |

---

## 5. Customer Experience Improvements

| Feature | Current State | Missing Functionality |
| :--- | :--- | :--- |
| **Saved Addresses** | Customers type recipient name, phone, address, landmark, and pincode every single checkout. | Create `customer_addresses` table. Allow customers to save multiple addresses ("Home", "Work", "Parents") and select a default address with one tap during checkout. |
| **Reorder Button** | Customers re-buy the same staple vegetables weekly (onions, potatoes, tomatoes). | Add a "Reorder" action on past orders in `CustomerOrdersPage`. Clicking it checks current stock, populates the customer's server cart, and navigates directly to checkout. |
| **Order Receipt / Invoice** | No printable or downloadable receipt exists. | Add an in-app receipt summary view with store GST/Tax ID (if applicable), breakdown of line totals, delivery fee, payment mode, and order timestamp. |
| **Customer Cancellation Reasons** | Free-text string; customers often leave it blank. | Provide pre-set cancellation reason chips ("Changed mind", "Ordered by mistake", "Delivery time too late") with optional custom notes. |
| **Product Reviews & Ratings** | Not present. | Lightweight 1-5 star rating and comment per delivered product to help the shop identify suppliers with low vegetable quality. |

---

## 6. Admin Analytics & Financial Operations

| Analytics Area | Current State | Missing Functionality |
| :--- | :--- | :--- |
| **Financial Revenue Aggregates** | Client-side calculations on top 20 recent orders. Inaccurate once orders exceed page size. | Backend analytics repository queries: `daily_revenue`, `weekly_revenue`, `monthly_revenue`, average order value (AOV). |
| **COD Cash Reconciliation** | When drivers complete deliveries, money is in driver's pocket. Admin has no reconciliation dashboard. | Add a COD Settlement workflow: Admin views `unsettled_cash` per driver. Driver hands cash to shop owner; Admin clicks "Settle Cash" (`POST /api/admin/drivers/{id}/settle-cash`), creating an audit trail of cash handed over. |
| **Best-Selling Vegetables** | Not tracked. | Query `order_items` grouped by `product_id` over the last 7 and 30 days to highlight top vegetables and forecast tomorrow's wholesale procurement. |
| **Driver Performance Metrics** | Basic online/available flags. | Metric cards: Total deliveries completed, on-time delivery rate, total COD collected, failed deliveries count. |

---

## 7. Delivery Tracking & Telemetry Gaps

| Area | Deficiency | Required Architectural Fix |
| :--- | :--- | :--- |
| **Foreground Service (Android)** | Driver location stops sending when the driver opens Google Maps or minimizes the app. | Implement an Android Foreground Service with a sticky system notification ("FreshBasket Delivery Active – Sharing Location"). Ensures GPS updates persist while navigating. |
| **Embedded Map View** | Customer app launches an external Google Maps link instead of displaying the driver on a live map. | Integrate an in-app OpenStreetMap widget (using `flutter_map` or Google Maps SDK) showing delivery address pin, shop location, and moving driver marker. |
| **Stale Location Warning** | If a driver loses cellular signal, customer sees the driver's last position without knowing it was sent 20 minutes ago. | Calculate `seconds_since_last_update`. If $> 120$ seconds, display a warning badge: "Location update paused (driver signal weak)". |

---

## 8. Technical & Security Gaps

| Technical Gap | Severity | Required Action |
| :--- | :--- | :--- |
| **Token Refresh Mechanism** | High | Add a `refresh_token` table or dual JWT strategy. When access token expires after 60 min, Dio interceptor transparently calls `/api/auth/refresh` without logging the user out. |
| **Rate Limiting** | High | Integrate a token-bucket rate limiter (e.g. Bucket4j or custom servlet filter) restricting `/api/auth/login` to 5 attempts per minute per IP to prevent brute-force attacks. |
| **Static Upload Protection** | Medium | Direct `/uploads/**` resource mapping does not enforce cache-control or content-disposition headers. Add headers to prevent script execution if malicious files are uploaded. |
| **Driver Location History Retention** | Low | Currently, only the latest active location is stored per driver (`driver_locations`). Historical route breadcrumbs are not retained. For disputes, a lightweight `delivery_location_history` table should store periodic coordinates until delivery is marked complete. |
