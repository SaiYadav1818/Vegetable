import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/network/api_client.dart';
import 'core/session/session_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_page.dart';
import 'features/catalog/admin_products_page.dart';
import 'features/customer/customer_home_page.dart';
import 'features/driver/driver_landing_page.dart';
import 'features/orders/checkout_page.dart';
import 'features/orders/customer_orders_page.dart';
import 'features/orders/admin_orders_page.dart';

void main() {
  const configuredUrl = String.fromEnvironment('API_BASE_URL');
  final baseUrl = configuredUrl.isNotEmpty
      ? configuredUrl
      : (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
          ? 'http://10.0.2.2:8080'
          : 'http://localhost:8080';
  runApp(FreshBasketApp(client: ApiClient(baseUrl: baseUrl)));
}

class FreshBasketApp extends StatefulWidget {
  const FreshBasketApp({super.key, required this.client});
  final ApiClient client;

  @override
  State<FreshBasketApp> createState() => _FreshBasketAppState();
}

class _FreshBasketAppState extends State<FreshBasketApp> {
  late final SessionController _session = SessionController();
  late final GoRouter _router = GoRouter(
    initialLocation: '/auth',
    refreshListenable: _session,
    redirect: (context, state) {
      final destination = _session.destination;
      final path = state.matchedLocation;
      if (path == destination ||
          path.startsWith('$destination/') ||
          (destination == '/customer' &&
              (path == '/checkout' || path == '/orders')) ||
          (destination == '/admin' && path == '/admin/orders')) return null;
      return destination;
    },
    routes: [
      GoRoute(
          path: '/auth',
          builder: (_, __) => AuthPage(
              client: widget.client, onAuthenticated: _session.signIn)),
      GoRoute(
          path: '/customer',
          builder: (context, __) => CustomerHomePage(
              client: widget.client,
              session: _session.session!,
              onSignOut: _signOut,
              onCheckout: () async {
                await context.push('/checkout');
              },
              onOrders: () => context.push('/orders'))),
      GoRoute(
          path: '/checkout',
          builder: (_, __) => CheckoutPage(client: widget.client)),
      GoRoute(
          path: '/orders',
          builder: (_, __) => CustomerOrdersPage(client: widget.client)),
      GoRoute(
          path: '/admin',
          builder: (_, __) => AdminProductsPage(
              client: widget.client,
              adminName: _session.session!.fullName,
              onSignOut: _signOut,
              onOrders: () => _router.push('/admin/orders'))),
      GoRoute(
          path: '/admin/orders',
          builder: (_, __) => AdminOrdersPage(client: widget.client)),
      GoRoute(
          path: '/driver',
          builder: (_, __) => DriverLandingPage(
              client: widget.client,
              session: _session.session!,
              onSignOut: _signOut)),
    ],
  );

  Future<void> _signOut() async {
    await widget.client.clearAccessToken();
    _session.signOut();
  }

  @override
  void dispose() {
    _router.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
        value: _session,
        child: MaterialApp.router(
          title: 'FreshBasket',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          routerConfig: _router,
        ),
      );
}
