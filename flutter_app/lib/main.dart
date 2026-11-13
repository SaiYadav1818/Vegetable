import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/network/api_client.dart';
import 'features/auth/auth_api.dart';
import 'features/catalog/admin_products_page.dart';

void main() {
  const configuredUrl = String.fromEnvironment('API_BASE_URL');
  final baseUrl = configuredUrl.isNotEmpty
      ? configuredUrl
      : (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
          ? 'http://10.0.2.2:8080'
          : 'http://localhost:8080';
  final client = ApiClient(baseUrl: baseUrl);
  runApp(FreshBasketApp(client: client));
}

class FreshBasketApp extends StatelessWidget {
  const FreshBasketApp({super.key, required this.client});
  final ApiClient client;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FreshBasket',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFFAFCF8),
        ),
        home: SignInPage(client: client),
      );
}

class SignInPage extends StatefulWidget {
  const SignInPage({super.key, required this.client});
  final ApiClient client;
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await AuthApi(
        widget.client,
      ).login(_email.text.trim(), _password.text);
      if (!mounted) return;
      if (session.role != 'ADMIN') {
        await widget.client.clearAccessToken();
        setState(
          () => _error = 'This Phase 3 workspace is for admin accounts.',
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => AdminProductsPage(
              client: widget.client,
              adminName: session.fullName,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Sign in failed. Check your details and API connection.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.eco, size: 52, color: Color(0xFF2E7D32)),
                      const SizedBox(height: 12),
                      Text(
                        'FreshBasket',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 6),
                      const Text('Admin sign in', textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || !v.contains('@')
                            ? 'Enter a valid email'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Enter your password'
                            : null,
                        onFieldSubmitted: (_) => _signIn(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: _busy ? null : _signIn,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Sign in'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
