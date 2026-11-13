import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FreshBasketMark extends StatelessWidget {
  const FreshBasketMark({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 38 : 48,
            height: compact ? 38 : 48,
            decoration: const BoxDecoration(
                color: AppColors.paleGreen, shape: BoxShape.circle),
            child: const Icon(Icons.eco_rounded, color: AppColors.green),
          ),
          const SizedBox(width: 10),
          Flexible(
              child: Text('FreshBasket',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800))),
        ],
      );
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.message = 'Getting things fresh…'});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 14),
          Text(message, style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded,
                size: 42, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again')),
          ]),
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.message});
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 52, color: AppColors.green),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      );
}
