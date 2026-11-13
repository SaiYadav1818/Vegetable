# API reference (Phase 1)

Base URL: `http://localhost:8080`. JSON requests and responses use UTF-8. Validation errors are handled by Spring's standard HTTP error responses.

## `POST /api/auth/register`

Creates a CUSTOMER account. Required fields: `fullName` (up to 120 chars), valid `email`, and `password` (8–72 chars). Optional `phoneNumber` is unique. Returns `accessToken`, `tokenType`, `userId`, `email`, `fullName`, and `role`.

## `POST /api/auth/login`

Accepts `email` and `password`; returns the same token response. Invalid credentials return 401. Duplicate email/phone on registration returns 409.

## Authorization

Send `Authorization: Bearer <accessToken>` to protected routes. `/api/admin/**` requires ADMIN, `/api/driver/**` requires DRIVER, and all other routes require authentication unless explicitly public. OpenAPI UI: `/swagger-ui/index.html`.
