# FreshBasket architecture (Phase 1)

The system is a modular monolith: one Spring Boot REST service backed by MySQL. Keeping identity, catalog, inventory, orders, delivery, and reporting as separate backend packages gives a small shop one simple local deployment while leaving clear boundaries for later growth. Flutter will remain a separate client and will never contain database credentials or signing keys.

Requests enter REST controllers, pass bean validation and Spring Security authorization, and reach services that own business rules and transactions. Spring Data repositories persist entities; Flyway owns schema changes, while Hibernate validates the mapped schema at startup. Public self-registration is limited to CUSTOMER. Admin and DRIVER identities require trusted provisioning so a client cannot elevate its role.

## Phase 1 security flow

Passwords are stored as BCrypt hashes. Successful login issues a short-lived signed JWT containing the subject and role. A stateless filter verifies its signature and expiry, loads the active account, and builds the Spring Security authority. Admin and driver URL namespaces have server-side role guards. All database connections and secrets are configurable through environment variables; defaults are for local development only.

## Growth decisions

Business tables will use numeric primary keys and explicit foreign keys. Money will use fixed precision decimals. Order placement and inventory reservation will be one database transaction with row-level locking or conditional stock updates to prevent overselling. Tenant/shop ownership must be added to business records and authorization checks before enabling multiple shops; the initial identity foundation is not yet tenant isolation.
