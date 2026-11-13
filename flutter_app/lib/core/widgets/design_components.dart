import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../../features/catalog/catalog_models.dart';
import 'app_states.dart';

class FreshBasketAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FreshBasketAppBar(
      {super.key,
      this.title,
      this.actions = const [],
      this.leading,
      this.bottom});
  final Widget? title;
  final List<Widget> actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
  @override
  Widget build(BuildContext context) => AppBar(
        leading: leading,
        title: title ?? const FreshBasketMark(compact: true),
        actions: actions,
        bottom: bottom,
      );
}

class AppSearchField extends StatelessWidget {
  const AppSearchField(
      {super.key,
      required this.controller,
      required this.onChanged,
      this.hint = 'Search vegetables',
      this.autofocus = false});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;
  final bool autofocus;
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        autofocus: autofocus,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.green),
          suffixIcon: controller.text.isEmpty
              ? const Icon(Icons.tune_rounded, color: AppColors.muted)
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      );
}

class ProductImageView extends StatelessWidget {
  const ProductImageView(
      {super.key, this.url, this.fit = BoxFit.cover, this.borderRadius});
  final String? url;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  @override
  Widget build(BuildContext context) {
    final image = url == null || url!.isEmpty
        ? const _ProducePlaceholder()
        : CachedNetworkImage(
            imageUrl: url!,
            fit: fit,
            placeholder: (_, __) => const _ProducePlaceholder(),
            errorWidget: (_, __, ___) => const _ProducePlaceholder(),
          );
    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }
}

class _ProducePlaceholder extends StatelessWidget {
  const _ProducePlaceholder();
  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: AppColors.paleGreen,
        child: Center(
            child: Icon(Icons.eco_rounded, color: AppColors.green, size: 42)),
      );
}

class PriceText extends StatelessWidget {
  const PriceText(
      {super.key,
      required this.amount,
      this.unit,
      this.style,
      this.emphasized = false});
  final num amount;
  final String? unit;
  final TextStyle? style;
  final bool emphasized;
  @override
  Widget build(BuildContext context) => Text(
        '₹${amount.toStringAsFixed(2)}${unit == null ? '' : ' / $unit'}',
        style: style ??
            Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.darkGreen,
                  fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
                ),
      );
}

class QuantitySelector extends StatelessWidget {
  const QuantitySelector(
      {super.key,
      required this.quantity,
      required this.onIncrement,
      required this.onDecrement,
      this.compact = false});
  final num quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final bool compact;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: AppColors.paleGreen,
            borderRadius: BorderRadius.circular(AppRadius.sm)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _QuantityButton(
              icon: Icons.remove_rounded,
              label: 'Decrease quantity',
              onPressed: onDecrement,
              compact: compact),
          Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 6),
              child: Text('$quantity',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkGreen))),
          _QuantityButton(
              icon: Icons.add_rounded,
              label: 'Increase quantity',
              onPressed: onIncrement,
              compact: compact),
        ]),
      );
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton(
      {required this.icon,
      required this.label,
      required this.onPressed,
      required this.compact});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool compact;
  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: label,
        visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
        constraints: BoxConstraints(
            minWidth: compact ? 36 : 44, minHeight: compact ? 36 : 44),
        onPressed: onPressed,
        icon: Icon(icon, size: 19, color: AppColors.darkGreen),
      );
}

class CategoryCard extends StatelessWidget {
  const CategoryCard(
      {super.key,
      required this.title,
      required this.icon,
      required this.onTap,
      this.selected = false,
      this.compact = false});
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected, compact;
  @override
  Widget build(BuildContext context) => Material(
        color: selected ? AppColors.paleGreen : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            width: compact ? 86 : null,
            padding: EdgeInsets.all(compact ? 10 : 14),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                    color: selected
                        ? AppColors.green.withValues(alpha: .3)
                        : AppColors.line)),
            child: compact
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                            color: AppColors.paleGreen, shape: BoxShape.circle),
                        child: Icon(icon, color: AppColors.green)),
                    const SizedBox(height: 7),
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ])
                : Row(children: [
                    Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                            color: AppColors.paleGreen, shape: BoxShape.circle),
                        child: Icon(icon, color: AppColors.green)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall)),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: AppColors.muted),
                  ]),
          ),
        ),
      );
}

class VegetableProductCard extends StatelessWidget {
  const VegetableProductCard(
      {super.key,
      required this.product,
      required this.imageUrl,
      required this.quantity,
      required this.onTap,
      required this.onAdd,
      required this.onIncrement,
      required this.onDecrement});
  final Product product;
  final String? imageUrl;
  final num quantity;
  final VoidCallback onTap, onAdd, onIncrement, onDecrement;
  @override
  Widget build(BuildContext context) {
    final unavailable = product.stock <= 0 || !product.available;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Stack(fit: StackFit.expand, children: [
          InkWell(
              onTap: onTap,
              child: Hero(
                  tag: 'product-${product.id}',
                  child: ProductImageView(url: imageUrl))),
          Positioned(
              left: 9,
              top: 9,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                    color: unavailable
                        ? Colors.white
                        : Colors.white.withValues(alpha: .94),
                    borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Text(unavailable ? 'Sold out' : 'In stock',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color:
                            unavailable ? AppColors.muted : AppColors.darkGreen,
                        fontWeight: FontWeight.w700)),
              )),
          Positioned(
              right: 8,
              top: 8,
              child: Material(
                color: Colors.white.withValues(alpha: .94),
                shape: const CircleBorder(),
                child: IconButton(
                    tooltip: 'View ${product.name}',
                    onPressed: onTap,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.open_in_full_rounded, size: 17)),
              )),
        ])),
        Padding(
            padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              PriceText(
                  amount: product.price, unit: product.unit.toLowerCase()),
              const SizedBox(height: 9),
              if (quantity > 0)
                SizedBox(
                    width: double.infinity,
                    child: QuantitySelector(
                        quantity: quantity,
                        compact: true,
                        onIncrement: onIncrement,
                        onDecrement: onDecrement))
              else
                SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: FilledButton.tonal(
                        onPressed: unavailable ? null : onAdd,
                        child: Text(
                            unavailable ? 'Unavailable' : 'Add to basket'))),
            ])),
      ]),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.actionLabel, this.onAction});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 16, 12),
        child: Row(children: [
          Expanded(
              child: Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800))),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ]),
      );
}

class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (status) {
      'PLACED' => ('Placed', AppColors.orange, const Color(0xFFFFF3E0)),
      'ACCEPTED' => ('Accepted', AppColors.green, AppColors.paleGreen),
      'PREPARING' => ('Preparing', AppColors.green, AppColors.paleGreen),
      'READY_FOR_PICKUP' => (
          'Ready for pickup',
          AppColors.green,
          AppColors.paleGreen
        ),
      'DRIVER_ASSIGNED' => (
          'Driver assigned',
          AppColors.green,
          AppColors.paleGreen
        ),
      'OUT_FOR_DELIVERY' => (
          'Out for delivery',
          AppColors.green,
          AppColors.paleGreen
        ),
      'DELIVERED' => ('Delivered', AppColors.darkGreen, AppColors.paleGreen),
      'REJECTED' || 'CANCELLED' => (
          status == 'REJECTED' ? 'Rejected' : 'Cancelled',
          AppColors.red,
          const Color(0xFFFFEBEE)
        ),
      _ => (
          status.replaceAll('_', ' '),
          AppColors.muted,
          const Color(0xFFF1F3F0)
        ),
    };
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w800)));
  }
}

class DashboardStatCard extends StatelessWidget {
  const DashboardStatCard(
      {super.key,
      required this.title,
      required this.value,
      required this.icon,
      this.accent = AppColors.green,
      this.onTap});
  final String title, value;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(height: 14),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(title, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      );
}

class DeliveryOrderCard extends StatelessWidget {
  const DeliveryOrderCard(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.status,
      required this.details,
      this.actions = const []});
  final String title, subtitle, status;
  final Widget details;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(subtitle,
                            style: Theme.of(context).textTheme.bodySmall),
                      ])),
                  const SizedBox(width: 8),
                  OrderStatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 12),
              details,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            ],
          ),
        ),
      );
}
