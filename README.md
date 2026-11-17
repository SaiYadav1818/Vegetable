# FreshBasket

FreshBasket is a full-stack, local-first vegetable ordering and delivery platform built for neighborhood shops. The repository contains a complete Spring Boot REST API (Java 17, Spring Boot 3.4.4, MySQL 8.4, Flyway migrations) and a multi-persona Flutter application (Customer, Admin, and Delivery Driver).

---

## Key Features & End-to-End Capabilities

### 1. Customer Experience
- **Catalog & Safety Stock Buffer**: Browse real-time fresh vegetable categories with sellable stock calculations that prevent ordering into store safety buffers.
- **Server Cart & Idempotent Checkout**: Multi-item persistent cart with pessimistic locking at checkout and unique client idempotency keys (`idempotency_key`) to prevent duplicate transactions.
- **Saved Addresses**: Manage multiple delivery addresses (Home, Work, etc.) with default address auto-selection and 1-tap checkout.
- **One-Tap Reorder**: Re-buy past orders instantly with automatic inventory availability checking and cart population.
- **Order Lifecycle & OTP Tracking**: Live order tracking, OTP generation and rotation, and structured cancellation with immediate inventory restoration.

### 2. Store Manager / Admin Operations
- **Shop Operating Hours & Rules**: Database-driven store timings (`opening_time`, `closing_time`), temporary store closure toggle, minimum order value, and free delivery thresholds (`/api/shop/settings`, `/api/admin/shop-settings`).
- **Live Business Analytics**: Real-time revenue aggregates (total, today, past 7 days, AOV), best-selling vegetables ranking, and active driver telemetry (`/api/admin/analytics/overview`).
- **Order Dispatch & Driver Reassignment**: Order status advancement (`ACCEPTED`, `PREPARING`, `READY_FOR_PICKUP`), driver assignment and reassignment from failed states, and admin order cancellations with automatic stock rollback.
- **COD Cash Reconciliation**: Complete audit trail of cash collected by drivers, uncollected balances, and single-click driver cash settlement (`/api/admin/reports/cod-reconciliation`).

### 3. Delivery Driver Flow
- **Duty & Availability Management**: Online/offline toggle guarded against active deliveries.
- **Order Execution & GPS Tracking**: Accept assigned orders, mark pickup, stream live GPS location breadcrumbs, and report delivery failures with structured reason codes.
- **OTP Verification & Cash Collection**: Secure BCrypt-hashed OTP customer verification and atomic COD cash collection tracking.

---

## Run Locally

1. **Start MySQL 8.4**:
   ```bash
   docker compose up -d mysql
   ```
2. **Start Backend**:
   ```bash
   cd backend
   mvn spring-boot:run
   ```
   *For initial setup, set `ADMIN_BOOTSTRAP_ENABLED=true`, `ADMIN_BOOTSTRAP_EMAIL`, and `ADMIN_BOOTSTRAP_PASSWORD` in environment variables or `.env`.*
3. **Start Flutter Client**:
   ```bash
   cd flutter_app
   flutter pub get
   flutter run -d chrome # or -d windows
   ```

---

## End-to-End Performance & Concurrency Verification

To run the automated end-to-end performance test suite and benchmark:

```bash
# Using Python
python scripts/performance_e2e_runner.py http://localhost:8080

# Using PowerShell
./scripts/run_e2e_performance.ps1
```

The runner exercises:
- Public store configuration and catalog latency
- End-to-end customer checkout and idempotency
- 25-50 concurrent client checkout stress simulation with zero inventory overselling
- Response latency percentiles (P50, P95, P99)

---

## Documentation

- [Setup Guide](docs/setup_guide.md)
- [Architecture & State Machine](docs/architecture.md)
- [Database Schema & Migrations](docs/database_design.md)
- [REST API Reference](docs/api_documentation.md)
- [Missing Features & Audit Status](docs/missing_features.md)
