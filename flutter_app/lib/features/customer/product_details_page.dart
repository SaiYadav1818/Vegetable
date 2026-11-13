import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/design_components.dart';
import '../catalog/catalog_models.dart';

class ProductDetailsPage extends StatefulWidget {
  const ProductDetailsPage(
      {super.key,
      required this.product,
      required this.imageBase,
      required this.quantity,
      required this.onAdd,
      required this.onIncrement,
      required this.onDecrement});
  final Product product;
  final String imageBase;
  final num quantity;
  final Future<num> Function() onAdd, onIncrement, onDecrement;
  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  late num _quantity = widget.quantity;
  bool _busy = false;
  String? get _imageUrl {
    final value = widget.product.imageUrl;
    if (value == null || value.isEmpty) return null;
    return Uri.tryParse(value)?.hasScheme == true
        ? value
        : '${widget.imageBase}$value';
  }

  Future<void> _change(Future<num> Function() action) async {
    setState(() => _busy = true);
    try {
      final value = await action();
      if (mounted) setState(() => _quantity = value);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final available = product.available && product.stock > 0;
    return Scaffold(
      appBar: const FreshBasketAppBar(title: Text('Product details')),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: AspectRatio(
                aspectRatio: 1.08,
                child: Hero(
                    tag: 'product-${product.id}',
                    child: ProductImageView(url: _imageUrl)),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 120),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(product.categoryName,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.green,
                            fontWeight: FontWeight.w700))),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: available
                            ? AppColors.paleGreen
                            : const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(AppRadius.pill)),
                    child: Text(available ? 'In stock' : 'Unavailable',
                        style: TextStyle(
                            color:
                                available ? AppColors.darkGreen : AppColors.red,
                            fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 8),
              Text(product.name,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              PriceText(
                  amount: product.price,
                  unit: product.unit.toLowerCase(),
                  emphasized: true,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.darkGreen, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              Text(
                  available
                      ? '${product.stock} ${product.unit.toLowerCase()} available'
                      : 'Currently unavailable',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: available ? AppColors.green : AppColors.red,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              Text('About this vegetable',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              Text(
                  product.description?.trim().isNotEmpty == true
                      ? product.description!
                      : 'No product description is available yet.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(height: 1.45, color: AppColors.muted)),
              if (available) ...[
                const SizedBox(height: 22),
                Row(children: [
                  Text('Quantity',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (_quantity > 0)
                    QuantitySelector(
                        quantity: _quantity,
                        onDecrement:
                            _busy ? () {} : () => _change(widget.onDecrement),
                        onIncrement:
                            _busy ? () {} : () => _change(widget.onIncrement))
                ]),
                if (_quantity > 0)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(children: [
                        const Text('Total'),
                        const Spacer(),
                        PriceText(
                            amount: product.price * _quantity, emphasized: true)
                      ])),
              ],
            ]),
          ),
        ),
      ]),
      bottomNavigationBar: available
          ? SafeArea(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                  child: SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () async {
                                if (_quantity == 0) {
                                  await _change(widget.onAdd);
                                } else {
                                  Navigator.pop(context);
                                }
                              },
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.shopping_basket_outlined),
                        label: Text(_quantity == 0
                            ? 'Add to basket · ₹${product.price.toStringAsFixed(2)}'
                            : 'Done · ₹${(product.price * _quantity).toStringAsFixed(2)}'),
                      ))))
          : null,
    );
  }
}
