import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshbasket/core/network/api_client.dart';
import 'package:freshbasket/features/auth/auth_page.dart';

void main() {
  testWidgets('auth page switches between sign-in and customer registration',
      (tester) async {
    final client = ApiClient(baseUrl: 'http://localhost:8080');
    await tester.pumpWidget(MaterialApp(
      home: AuthPage(client: client, onAuthenticated: (_) {}),
    ));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Full name'), findsNothing);
    await tester.tap(find.text('New to FreshBasket? Create an account'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Mobile number (optional)'), findsOneWidget);
  });
}
