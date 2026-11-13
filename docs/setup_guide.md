# FreshBasket Phase 1: local setup

Phase 1 provides the Java 17 Spring Boot API, MySQL schema migration, customer registration and login, BCrypt password hashing, signed JWT authentication, and role guards for admin and driver routes. Public registration always creates a CUSTOMER; privileged accounts must be provisioned through a controlled administrative process.

## Requirements

- JDK 17 or newer and Maven 3.9+
- Docker Desktop with Compose, or a local MySQL 8 server

## Start MySQL and API

From the repository root:

```powershell
docker compose up -d mysql
cd backend
mvn spring-boot:run
```

The API starts at `http://localhost:8080`. Flyway creates the identity, catalog, and inventory tables on first launch. For an existing MySQL instance, set `DB_URL`, `DB_USERNAME`, and `DB_PASSWORD`. Override the development JWT secret with a private random value using `JWT_SECRET` before deployment.

## Authentication

- `POST /api/auth/register`: `{ "fullName": "Asha Rao", "email": "asha@example.com", "password": "at-least-8-chars", "phoneNumber": "+919876543210" }`
- `POST /api/auth/login`: `{ "email": "asha@example.com", "password": "at-least-8-chars" }`

Both return an access token and basic user details. Send the token as `Authorization: Bearer <token>` to protected endpoints. Swagger UI is available at `/swagger-ui/index.html`.

## First admin account

Before the first API startup, set `ADMIN_BOOTSTRAP_ENABLED=true`, `ADMIN_BOOTSTRAP_EMAIL`, and `ADMIN_BOOTSTRAP_PASSWORD` (at least 12 characters) in the process environment. The startup hook creates one ADMIN with a BCrypt password only when the database has no admin; after it is created, disable the bootstrap flag. Keep the password out of source control. Public registration remains CUSTOMER-only.

## Flutter client

```powershell
cd flutter_app
flutter pub get
flutter run
```

Android emulator defaults to `http://10.0.2.2:8080`; desktop and Web default to `http://localhost:8080`. Override with `flutter run --dart-define=API_BASE_URL=http://your-host:8080`. The Flutter client has customer registration/login, role-based destinations, a live catalog home and category browser, plus admin category/product/inventory management. The Phase 2 customer basket is kept in memory; server-side cart and checkout are Phase 4. The Android debug manifest permits local HTTP during development; release Android builds keep cleartext traffic disabled. Flutter Web uses a development CORS allowlist for localhost origins.

## Current phase boundary

This phase adds catalog maintenance and inventory adjustments on top of the identity foundations. Refresh/logout token revocation, account recovery, image file uploads, customer shopping, order workflows, and delivery features remain for later phases. The local JWT currently expires after 60 minutes and is stateless.
