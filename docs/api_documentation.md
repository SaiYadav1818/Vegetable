# FreshBasket API Reference

Base URL: `http://localhost:8080`. All JSON requests and responses use UTF-8 encoding.
Authenticated endpoints require: `Authorization: Bearer <accessToken>`.

---

## 1. Authentication & Session (`/api/auth`)

### `POST /api/auth/register`
- **Access**: Public (Subject to IP rate limiting: max 10 attempts / 10 min)
- **Request Body**:
  ```json
  {
    "fullName": "Asha Rao",
    "email": "asha@example.com",
    "password": "Password1234!",
    "phoneNumber": "9876543210"
  }
  ```
- **Response** (`200 OK`):
  ```json
  {
    "accessToken": "eyJhbG...",
    "tokenType": "Bearer",
    "userId": 1,
    "email": "asha@example.com",
    "fullName": "Asha Rao",
    "role": "CUSTOMER",
    "refreshToken": "4a7b9c..."
  }
  ```
- **Error Codes**: `400 Bad Request` (validation errors), `409 Conflict` (generic duplicate rejection without credential enumeration), `429 Too Many Requests`.

### `POST /api/auth/login`
- **Access**: Public (Subject to token-bucket rate limiting: max 5 failed attempts / 1 min)
- **Request Body**:
  ```json
  {
    "email": "asha@example.com",
    "password": "Password1234!"
  }
  ```
- **Response** (`200 OK`): Returns `AuthResponse` with short-lived `accessToken` and secure 30-day `refreshToken`.
- **Error Codes**: `401 Unauthorized` ("Invalid email or password" - uniform error), `429 Too Many Requests`.

### `POST /api/auth/refresh`
- **Access**: Public
- **Request Body**:
  ```json
  {
    "refreshToken": "4a7b9c..."
  }
  ```
- **Behavior**: Implements **Refresh Token Rotation**. The submitted token is revoked and marked with `replacedByHash`. A new access token and new rotated refresh token are issued. If a previously revoked token is presented, all active tokens for that user are immediately revoked (replay attack defense).
- **Response** (`200 OK`): Returns new `AuthResponse`.
- **Error Codes**: `401 Unauthorized` (expired or invalid token).

### `POST /api/auth/logout`
- **Access**: Public / Authenticated
- **Request Body**: `{"refreshToken": "4a7b9c..."}`
- **Behavior**: Explicitly revokes the refresh token.

---

## 2. Catalog & Products (`/api/products`, `/api/categories`)

- `GET /api/categories`: Public list of active product categories.
- `GET /api/products?page=0&size=20&categoryId=1`: Public paginated list of active, available products.
- `GET /api/products/{id}`: Single product details.
- `GET /api/admin/products?page=0&size=20`: Admin view including inactive products and inventory levels (`hasRole('ADMIN')`).
- `POST /api/admin/products`: Create vegetable product.
- `PUT /api/admin/products/{id}`: Update vegetable details.
- `POST /api/admin/products/{id}/image`: Multipart upload (`file`, PNG/JPEG, max 5 MB).
- `POST /api/admin/products/{id}/inventory-adjustments`: Adjust stock with signed `delta`, `reason`, and `note`.
- `GET /api/admin/products/{id}/inventory-history`: Paginated audit log of stock transactions.

---

## 3. Customer Cart & Orders (`/api/cart`, `/api/orders`)

All endpoints require `hasRole('CUSTOMER')`.

### `GET /api/cart`
Returns the server-backed cart lines, product availability, real-time stock snapshot, and subtotal.

### `POST /api/cart/items`
- **Request**: `{"productId": 1, "quantity": 2.5}`
- Validates quantity against current inventory. Throws `409 Conflict` if stock is exceeded.

### `POST /api/orders` (Checkout)
- **Request Body**:
  ```json
  {
    "idempotencyKey": "chk_1710000000_5412",
    "expectedSubtotal": 150.00,
    "recipientName": "Asha Rao",
    "recipientPhone": "9876543210",
    "addressLine": "Flat 302, Green Meadows",
    "houseNumber": "302",
    "area": "Jayanagar 4th Block",
    "landmark": "Opposite Park",
    "pincode": "560041",
    "deliveryInstructions": "Ring the bell",
    "deliveryDate": "2026-11-14",
    "deliverySlot": "MORNING",
    "latitude": 12.9250,
    "longitude": 77.5938
  }
  ```
- **Idempotency Guarantee**: If an order with the same `(customer_user_id, idempotencyKey)` already exists, the backend returns the existing order immediately without re-decrementing stock or creating duplicate entries.
- **Transactional Behavior**: Uses pessimistic locking (`SELECT ... FOR UPDATE`) on product stock, atomically decrements inventory, creates COD payment record (`PENDING`), generates a BCrypt-hashed delivery OTP, and purges the server cart.

### `GET /api/orders/my`
Paginated order history for the authenticated customer.

### `POST /api/orders/{id}/cancel`
Cancels an order if status is `PLACED`. Automatically restores inventory with compensating transaction ledger entry.

### `POST /api/orders/{id}/delivery-otp`
Generates a new 6-digit delivery OTP and rotates the BCrypt hash.

---

## 4. Driver Dispatch & Orders (`/api/driver`)

All endpoints require `hasRole('DRIVER')`.

- `PUT /api/driver/availability`: `{"online": true/false}`. Guards against going offline while deliveries are in progress.
- `GET /api/driver/orders`: Paginated list of assignments belonging to the driver.
- `PUT /api/driver/orders/{id}/accept`: Transitions assignment from `ASSIGNED` to `ACCEPTED`.
- `PUT /api/driver/orders/{id}/pickup`: Transitions order to `OUT_FOR_DELIVERY`.
- `PUT /api/driver/orders/{id}/fail`:
  - **Request**: `{"reason": "Customer unreachable, phone switched off"}`
  - Transitions order to `DELIVERY_FAILED` and assignment to `FAILED`.
  - Releases driver availability. Does NOT restore stock (produce remains with store/driver).
- `PUT /api/driver/orders/{id}/deliver`:
  - **Request**: `{"otp": "123456", "cashCollected": true}`
  - Verifies customer OTP (locks after 5 failed attempts).
  - If `cashCollected: true`: marks payment `PAID` and sets `collected_by_driver_user_id`.
  - If `cashCollected: false`: order status is `DELIVERED`, but payment status remains `PENDING` / `FAILED`.
- `POST /api/driver/location`: Streams GPS coordinates `{"latitude": 12.9250, "longitude": 77.5938}`.

---

## 5. Admin Orders & COD Reconciliation (`/api/admin`)

All endpoints require `hasRole('ADMIN')`.

- `GET /api/admin/orders`: All store orders across all statuses.
- `PUT /api/admin/orders/{id}/status`: Transitions status (`ACCEPTED`, `PREPARING`, `READY_FOR_PICKUP`, `CANCELLED`, `REJECTED`). Allows cancelling failed deliveries.
- `POST /api/admin/orders/{id}/assign-driver`: `{"driverUserId": 3}`. Dispatches order when in `READY_FOR_PICKUP` or reassigns order when in `DELIVERY_FAILED`. Automatically cancels prior failed/stalled assignments.
- `GET /api/admin/reports/cod-reconciliation`:
  - Returns total collected, total settled with counter, total unsettled cash held by drivers, unpaid delivered orders count, and per-driver breakdown.
- `POST /api/admin/payments/{id}/reconcile`: Reconciles a single order payment with optional settlement note.
- `POST /api/admin/drivers/{driverId}/reconcile-all`: Batches and settles all pending collected cash for a specific driver.
