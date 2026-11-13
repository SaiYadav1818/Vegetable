# Database design (Phase 1)

Flyway migration `V1` creates:

- `roles`: canonical role names (`ADMIN`, `CUSTOMER`, `DRIVER`), referenced by user role.
- `users`: normalized unique email, optional unique phone, BCrypt hash, role foreign key, active flag, and creation/update timestamps. An index supports role and account status filters.

The account role is stored as a string enum and constrained by a foreign key to `roles`. New roles must be seeded through a migration before they are assigned. No credentials or personal data beyond account contact fields are stored in application configuration.

The remaining entities in the product brief (addresses, categories, products, inventory transactions, carts, orders, assignments, locations, OTPs, payments, notifications, coupons, reviews, and settings) are intentionally deferred to their implementation phases so migrations stay incremental and reviewable.
