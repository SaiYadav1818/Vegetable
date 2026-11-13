import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_states.dart';
import 'auth_api.dart';

class AuthPage extends StatefulWidget {
  const AuthPage(
      {super.key, required this.client, required this.onAuthenticated});
  final ApiClient client;
  final ValueChanged<AuthSession> onAuthenticated;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _registering = false;
  bool _showPassword = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _toggleMode() => setState(() {
        _registering = !_registering;
        _error = null;
        _formKey.currentState?.reset();
      });

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = AuthApi(widget.client);
      final session = _registering
          ? await api.register(
              fullName: _name.text.trim(),
              email: _email.text.trim(),
              password: _password.text,
              phoneNumber: _phone.text.trim())
          : await api.login(_email.text.trim(), _password.text);
      if (mounted) widget.onAuthenticated(session);
    } on DioException catch (e) {
      if (mounted) setState(() => _error = AuthApi.describeError(e));
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not connect. Check that the FreshBasket API is running.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _validEmail(String? value) {
    final email = value?.trim() ?? '';
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
        ? null
        : 'Enter a valid email address';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: LayoutBuilder(builder: (context, constraints) {
                final wide = constraints.maxWidth > 700;
                final form = _formCard(theme);
                if (!wide) return form;
                return Row(children: [
                  Expanded(
                      child: Container(
                    height: 610,
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    padding: const EdgeInsets.all(40),
                    child: const _WelcomePanel(),
                  )),
                  const SizedBox(width: 28),
                  Expanded(child: form),
                ]);
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formCard(ThemeData theme) => Card(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Form(
            key: _formKey,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FreshBasketMark(),
                  const SizedBox(height: 28),
                  Text(_registering ? 'Create your account' : 'Welcome back',
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text(
                      _registering
                          ? 'Get fresh picks delivered from your local shop.'
                          : 'Sign in to continue to FreshBasket.',
                      style: theme.textTheme.bodySmall),
                  const SizedBox(height: 22),
                  if (_registering) ...[
                    TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                            labelText: 'Full name',
                            prefixIcon: Icon(Icons.person_outline)),
                        validator: (v) => (v?.trim().length ?? 0) < 2
                            ? 'Enter your name'
                            : null),
                    const SizedBox(height: 13),
                  ],
                  TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline)),
                      validator: _validEmail),
                  if (_registering) ...[
                    const SizedBox(height: 13),
                    TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                            labelText: 'Mobile number (optional)',
                            prefixIcon: Icon(Icons.phone_outlined)),
                        validator: (v) => v != null &&
                                v.isNotEmpty &&
                                !RegExp(r'^[0-9+() -]{7,20}$').hasMatch(v)
                            ? 'Enter a valid phone number'
                            : null),
                  ],
                  const SizedBox(height: 13),
                  TextFormField(
                      controller: _password,
                      obscureText: !_showPassword,
                      autofillHints: _registering
                          ? const [AutofillHints.newPassword]
                          : const [AutofillHints.password],
                      decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                              tooltip: _showPassword
                                  ? 'Hide password'
                                  : 'Show password',
                              onPressed: () => setState(
                                  () => _showPassword = !_showPassword),
                              icon: Icon(_showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined))),
                      validator: (v) => _registering
                          ? ((v?.length ?? 0) < 8 || (v?.length ?? 0) > 72
                              ? 'Use 8 to 72 characters'
                              : null)
                          : ((v?.isEmpty ?? true)
                              ? 'Enter your password'
                              : null),
                      onFieldSubmitted: (_) => _submit()),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(_error!,
                            style: TextStyle(
                                color: theme.colorScheme.onErrorContainer))),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_registering ? 'Create account' : 'Sign in')),
                  const SizedBox(height: 14),
                  TextButton(
                      onPressed: _busy ? null : _toggleMode,
                      child: Text(_registering
                          ? 'Already have an account? Sign in'
                          : 'New to FreshBasket? Create an account')),
                ]),
          ),
        ),
      );
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel();
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Spacer(),
        Container(
            width: 92,
            height: 92,
            decoration: const BoxDecoration(
                color: Colors.white24, shape: BoxShape.circle),
            child:
                const Icon(Icons.eco_rounded, color: Colors.white, size: 54)),
        const SizedBox(height: 28),
        Text('Good food starts close to home.',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: Colors.white, fontSize: 34)),
        const SizedBox(height: 12),
        const Text(
            'Shop seasonal vegetables from your neighborhood shop, picked fresh and brought to your door.',
            style: TextStyle(color: Colors.white, height: 1.5, fontSize: 16)),
        const Spacer(),
        const Row(children: [
          Icon(Icons.spa_outlined, color: Colors.white),
          SizedBox(width: 8),
          Flexible(
              child: Text('Fresh from local shops',
                  style: TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis))
        ]),
      ]);
}
