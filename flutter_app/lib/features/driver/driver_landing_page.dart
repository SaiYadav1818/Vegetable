import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_states.dart';
import '../auth/auth_api.dart';

class DriverLandingPage extends StatelessWidget {
  const DriverLandingPage(
      {super.key, required this.session, required this.onSignOut});
  final AuthSession session;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const FreshBasketMark(compact: true), actions: [
          IconButton(
              tooltip: 'Sign out',
              onPressed: onSignOut,
              icon: const Icon(Icons.logout)),
        ]),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                        color: AppColors.paleGreen, shape: BoxShape.circle),
                    child: const Icon(Icons.delivery_dining,
                        size: 56, color: AppColors.green)),
                const SizedBox(height: 20),
                Text('Hello, ${session.fullName}',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: 10),
                const EmptyState(
                    icon: Icons.route_outlined,
                    title: 'You are signed in as a driver',
                    message:
                        'Your delivery dashboard will appear here when driver deliveries are added.'),
                OutlinedButton.icon(
                    onPressed: onSignOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out')),
              ]),
            ),
          ),
        ),
      );
}
