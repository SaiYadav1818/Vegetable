# FreshBasket real-time workflow and FCM audit

## Existing implementation inspected

- Flutter Android app uses Dio with JWT in `ApiClient`, GoRouter, and role-specific customer, admin, and driver routes.
- Spring Boot 3.4 / Java 17 uses JWT authentication, JPA, Flyway, and MySQL.
- Order creation, status transitions, driver assignment, delivery OTP, inventory adjustments, and role checks are already implemented in the backend.
- There was no Firebase configuration, FCM dependency, device-token API, notification history, or notification UI.
- The order state change points are centralized in `OrderService.changeStatus`; order placement and driver assignment have dedicated service methods. These are the notification event integration points.

## FCM work in this change

- Add Firebase Admin SDK and secure optional service-account loading from an external path.
- Add Flyway tables for per-user device tokens, notification history, and delivery attempts.
- Add authenticated token register/remove and notification list/count/read APIs. Account identity always comes from the JWT.
- Persist notifications after business transactions commit, then send asynchronously with bounded retries and invalid-token deactivation.
- Emit order placed, relevant order status, driver assignment, delivery, cancellation, and low-stock events without including customer private data in FCM payloads.
- Add Flutter Firebase initialization, permission/token lifecycle, foreground/background/open handling, notification list and unread count, logout token removal, and order navigation.

## Firebase setup required for live delivery

No `google-services.json` or service-account key was present during inspection. They are intentionally not generated or checked in. Install the Android app config from the Firebase console at `flutter_app/android/app/google-services.json`. Configure the backend with `FIREBASE_CREDENTIALS` pointing to a service-account JSON outside the repository (and restrict file access). FCM stays inactive until those real project credentials are provided; notification records and APIs remain usable.

## Scope and limitations

This change implements the requested FCM workflow against the existing order and inventory transitions. It does not replace the rest of the business system, guarantee push delivery, or add a mock transport. FCM delivery must be verified on a real Firebase project and Android device for foreground, background, terminated, token-refresh, and multi-device scenarios. Android 13+ requires the user to grant notification permission. Notification history is persisted in MySQL; database retention policy is not currently configured.

## Cost note

Firebase lists Cloud Messaging as a no-cost product. Sending still depends on an internet-connected app/server and valid Firebase project credentials. Other Firebase products or Google Cloud resources are separate and may be billable; this implementation does not add them.
