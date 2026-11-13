# FreshBasket Flutter UI audit

## Existing screens

- **Authentication:** email and password sign-in/registration, role-based route selection, and validation.
- **Customer:** home and category catalogs, search filtering, product cards, server-backed cart, COD checkout, order history/tracking, and profile. The orders route exists, but the Home screen's Orders tab currently shows a placeholder instead of opening it.
- **Admin:** product/inventory list, category management, product editor, order processing, and driver creation/assignment.
- **Driver:** online availability, assigned orders, accept/pickup/deliver with OTP, navigation launch, and explicitly started foreground location sharing.

## Existing app architecture and reusable pieces

- `main.dart` uses GoRouter with session-based role routing; `SessionController` is a `ChangeNotifier` provided with Provider.
- `ApiClient` owns Dio, JWT injection, and secure token storage. Feature APIs keep the network calls separated from UI.
- `AppTheme` already enables Material 3 and defines a green palette. `app_states.dart` contains the brand mark plus loading, error, and empty states.
- The customer catalog uses cached network images and has an icon fallback. Product, category, order, and cart JSON models are typed.

## UI problems found

- Customer home has inconsistent text and spacing, an unnecessary gradient banner, a basic search box without clear/suggestion affordances, and no visible notification action.
- Product cards are dense and expose little product detail; there is no product details screen.
- Cart rows lack a direct remove action and the summary has no visual distinction from the list. Delivery pricing is server-configured and is not available as a pre-checkout quote.
- Checkout is one long ungrouped form. It does not show the selected order lines or a clear price summary before placing.
- The customer Orders tab is a placeholder. The separate order list has plain expansions and only offers cancellation where the backend permits it; status presentation needs clearer labels and color.
- Admin opens directly into a dense inventory list. There is no landing dashboard or visual summary, and products lack search/filter controls and strong stock indicators.
- Driver workflow works but is visually plain, with small controls and no summaries for assigned/completed work.
- `ProductEditorDialog` accepts an image URL but does not offer a local picker; the existing API supports image upload, while the form does not use it.
- Some loading/error/empty screens and labels use inconsistent component styles. A few source strings are incorrectly encoded and need cleanup.

## Recommended improvements

- Establish shared palette, typography, spacing, surfaces, rounded corners, status badges, image fallback, search, and quantity components.
- Redesign the customer home around delivery location, search, a restrained promotional panel, API-backed category chips, and a responsive product grid. Add a product detail view and connect every bottom-navigation destination.
- Group checkout into address, delivery, basket, payment, and summary sections without inventing a delivery charge that the API does not quote.
- Turn order cards into readable status summaries with an expandable timeline, receipt details, and active-driver tracking.
- Add an admin dashboard based on the existing orders and catalog endpoints, then improve product search, stock visibility, and order/driver management cards.
- Simplify driver cards, enlarge actions, surface delivery instructions, and summarize assigned work while preserving the current OTP and explicit foreground location flow.
- Keep API classes, role checks, Dio, Provider, and GoRouter intact. Use product image URLs already supplied by the catalog and show attractive fallbacks when absent or unavailable; do not add paid image services or dummy API data.
