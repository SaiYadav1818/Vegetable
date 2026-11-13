# FreshBasket

FreshBasket is a local-first vegetable ordering and delivery project for neighborhood shops. The repository currently contains the Phase 1 identity foundation and Phase 3 catalog/inventory work: a Spring Boot REST API, MySQL/Flyway migrations, and a Flutter admin client for product, category, and stock management.

## Run locally

1. Start MySQL 8.4 with Docker Compose: `docker compose up -d mysql`.
2. In `backend`, set `ADMIN_BOOTSTRAP_ENABLED=true`, `ADMIN_BOOTSTRAP_EMAIL`, and a private `ADMIN_BOOTSTRAP_PASSWORD` of at least 12 characters for the first startup. Start the API with `mvn spring-boot:run`. The bootstrap creates an admin only when no admin exists; turn the flag off after that first run.
3. From `flutter_app`, run `flutter pub get` and `flutter run -d chrome` or `flutter run -d windows`. Use `flutter devices` to see available targets. Android emulator requests use `10.0.2.2` for the host API.

The Flutter app reads and writes real API data. Product writes, inventory changes, image uploads, and category changes require an admin JWT. Public registration creates customer accounts only. Configure `API_BASE_URL` at launch when the API host differs from the local defaults.

## Project notes

- [Local setup](docs/setup_guide.md)
- [Architecture](docs/architecture.md)
- [Database design](docs/database_design.md)
- [API reference](docs/api_documentation.md)

Business areas such as checkout, orders, drivers, customer screens, and multi-shop tenant isolation are later phases. MySQL is the development database; keep secrets in environment variables and replace local defaults for deployments.
