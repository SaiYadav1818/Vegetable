# API reference (Phase 1)

Base URL: `http://localhost:8080`. JSON requests and responses use UTF-8. Validation errors are handled by Spring's standard HTTP error responses.

## `POST /api/auth/register`

Creates a CUSTOMER account. Required fields: `fullName` (up to 120 chars), valid `email`, and `password` (8–72 chars). Optional `phoneNumber` is unique. Returns `accessToken`, `tokenType`, `userId`, `email`, `fullName`, and `role`.

## `POST /api/auth/login`

Accepts `email` and `password`; returns the same token response. Invalid credentials return 401. Duplicate email/phone on registration returns 409.

## Authorization

Send `Authorization: Bearer <accessToken>` to protected routes. `/api/admin/**` requires ADMIN, `/api/driver/**` requires DRIVER, and all other routes require authentication unless explicitly public. OpenAPI UI: `/swagger-ui/index.html`.

## Catalog and inventory (Phase 3)

Catalog reads are public. Admin write routes require an ADMIN token.

- `GET /api/categories`: category records.
- `GET /api/products?page=0&size=20&categoryId=1`: active, available products in a Spring page response.
- `GET /api/products/{id}`: one active product.
- `GET /api/admin/products?page=0&size=20`: all products for admin management.
- `POST /api/admin/categories`, `PUT /api/admin/categories/{id}`, `DELETE /api/admin/categories/{id}`: category create, edit, and soft-deactivate.
- `POST /api/admin/products`, `PUT /api/admin/products/{id}`, `DELETE /api/admin/products/{id}`: product create, edit, and soft-deactivate. Create includes `initialStock` and `minimumStock`; updates cannot alter current stock.
- `POST /api/admin/products/{id}/inventory-adjustments`: `{ "delta": 5.000, "reason": "ADMIN_ADJUSTMENT", "note": "Morning delivery" }`. The signed delta and resulting balance are recorded transactionally; the inventory row is locked and negative balances are rejected.
- `GET /api/admin/products/{id}/inventory-history?page=0&size=50`: paginated adjustments with balance snapshots.

Product `unit` values: `KG`, `G500`, `G250`, `PIECE`, `BUNCH`. `imageUrl` accepts an absolute HTTP(S) URL. Admins can upload PNG/JPEG files up to 5 MB with `POST /api/admin/products/{id}/image` using multipart field `file`; uploaded images are served from `/uploads/` and stored under `UPLOAD_DIR` (default `./uploads`).
