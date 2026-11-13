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

The API starts at `http://localhost:8080`. Flyway creates the identity tables on first launch. For an existing MySQL instance, set `DB_URL`, `DB_USERNAME`, and `DB_PASSWORD`. Override the development JWT secret with a private random value using `JWT_SECRET` before deployment.

## Authentication

- `POST /api/auth/register`: `{ "fullName": "Asha Rao", "email": "asha@example.com", "password": "at-least-8-chars", "phoneNumber": "+919876543210" }`
- `POST /api/auth/login`: `{ "email": "asha@example.com", "password": "at-least-8-chars" }`

Both return an access token and basic user details. Send the token as `Authorization: Bearer <token>` to protected endpoints. Swagger UI is available at `/swagger-ui/index.html`.

## Current phase boundary

This first phase establishes identity and authorization foundations. Refresh/logout token revocation, account recovery, business-domain tables, Flutter screens, products, orders, and delivery workflows are scheduled for later phases. The local JWT currently expires after 60 minutes and is stateless.
