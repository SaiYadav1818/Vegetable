import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/platform/device_services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/design_components.dart';
import 'checkout_page.dart';
import 'order_models.dart';
import 'orders_api.dart';

class CustomerOrdersPage extends StatefulWidget {
  const CustomerOrdersPage(
      {super.key, required this.client, this.embedded = false});
  final ApiClient client;
  final bool embedded;
  @override
  State<CustomerOrdersPage> createState() => _CustomerOrdersPageState();
}

class _CustomerOrdersPageState extends State<CustomerOrdersPage> {
  final _device = const DeviceServices();
  late final OrdersApi _api = OrdersApi(widget.client);
  late Future<List<OrderRecord>> _orders = _api.myOrders();
  Timer? _timer;
  bool _tracking = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_tracking && mounted) _reload().catchError((_) {});
    });
    _reload().catchError((_) {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    final future = _api.myOrders();
    setState(() => _orders = future);
    final orders = await future;
    _tracking = orders.any(
        (o) => o.status == 'DRIVER_ASSIGNED' || o.status == 'OUT_FOR_DELIVERY');
  }

  Future<void> _cancel(OrderRecord order) async {
    String selectedReason = 'Changed mind';
    final customReason = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Cancel Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please tell us why you are cancelling:'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  'Changed mind',
                  'Ordered by mistake',
                  'Delivery time too late',
                  'Other',
                ].map((reason) => ChoiceChip(
                  label: Text(reason),
                  selected: selectedReason == reason,
                  onSelected: (_) => setDialogState(() => selectedReason = reason),
                )).toList(),
              ),
              if (selectedReason == 'Other') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: customReason,
                  decoration: const InputDecoration(
                    labelText: 'Specify reason',
                    hintText: 'Enter cancellation note',
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep Order'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Confirm Cancel'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        final finalReason = selectedReason == 'Other' && customReason.text.trim().isNotEmpty
            ? customReason.text.trim()
            : selectedReason;
        await _api.cancelOrder(order.id, reason: finalReason);
        _toast('Order ${order.orderNumber} cancelled.');
        await _reload();
      } catch (e) {
        _toast(_api.describeError(e));
      }
    }
  }

  Future<void> _reorder(OrderRecord order) async {
    try {
      final res = await _api.reorder(order.id);
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle_outline, color: AppColors.green, size: 40),
          title: const Text('Items Added to Basket'),
          content: Text(
            'Added ${res.itemsAdded} item(s) from Order ${order.orderNumber} to your basket.'
            '${res.itemsUnavailable > 0 ? '\n\nNote: ${res.itemsUnavailable} item(s) were out of stock and skipped.' : ''}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Continue Browsing'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CheckoutPage(client: widget.client)),
                );
              },
              child: const Text('Go to Checkout'),
            ),
          ],
        ),
      );
    } catch (e) {
      _toast(_api.describeError(e));
    }
  }

  Future<void> _rotateOtp(OrderRecord order) async {
    try {
      final code = await _api.rotateDeliveryOtp(order.id);
      _toast('New delivery code: $code');
      await _reload();
    } catch (e) {
      _toast(_api.describeError(e));
    }
  }

  Future<void> _openLocation(OrderRecord order) async {
    final location = order.driverLocation;
    if (location == null) return;
    try {
      await _device.openExternalUrl(
          'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}');
    } catch (_) {
      _toast('Could not open maps on this device.');
    }
  }

  void _toast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<OrderRecord>>(
            future: _orders,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingState(message: 'Loading your orders...');
              }
              if (snapshot.hasError) {
                return ErrorState(
                    message: _api.describeError(snapshot.error!),
                    onRetry: _reload);
              }
              final orders = snapshot.data ?? [];
              if (orders.isEmpty) {
                return const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No orders yet',
                    message:
                        'Your confirmed orders and delivery updates will appear here.');
              }
              return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  children: [
                    Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                            color: AppColors.paleGreen,
                            borderRadius: BorderRadius.circular(AppRadius.md)),
                        child: Row(children: [
                          const Icon(Icons.local_shipping_outlined,
                              color: AppColors.darkGreen, size: 30),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('Neighborhood shop delivery',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w800)),
                                const SizedBox(height: 3),
                                Text(
                                    'Fresh vegetables packed daily. Track assignments, check your delivery OTP, and reorder favorites.',
                                    style:
                                        Theme.of(context).textTheme.bodySmall)
                              ]))
                        ])),
                    const SizedBox(height: 14),
                    ...orders.map(_card)
                  ]);
            }));
    return widget.embedded
        ? content
        : Scaffold(
            appBar: const FreshBasketAppBar(title: Text('My Orders')),
            body: content);
  }

  Widget _card(OrderRecord order) => Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(order.orderNumber,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                      '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year} · ${order.deliverySlot.toLowerCase()}',
                      style: Theme.of(context).textTheme.bodySmall)
                ])),
            StatusBadge.order(order.status)
          ]),
          if (order.cancellationReason != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: AppColors.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Reason: ${order.cancellationReason}',
                        style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          _timeline(order),
          const SizedBox(height: 12),
          ...order.items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(
                    child: Text(
                        '${item.name} · ${item.quantity} ${item.unit.toLowerCase()}',
                        style: Theme.of(context).textTheme.bodyMedium)),
                Text('₹${item.lineTotal.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyMedium)
              ]))),
          const Divider(height: 22),
          Row(children: [
            const Icon(Icons.payments_outlined,
                color: AppColors.green, size: 19),
            const SizedBox(width: 7),
            Expanded(
                child: Text(
                    'Cash on delivery · ${order.paymentStatus.toLowerCase()}',
                    style: Theme.of(context).textTheme.bodySmall)),
            Text('₹${order.totalAmount.toStringAsFixed(2)}',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800))
          ]),
          if (order.deliveryOtp != null)
            Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Text(
                    'Share OTP ${order.deliveryOtp} with your driver when your order arrives.',
                    style: const TextStyle(
                        color: AppColors.ink, fontWeight: FontWeight.w600))),
          if (order.driverLocation != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                        onPressed: () => _openLocation(order),
                        icon: const Icon(Icons.location_on_outlined),
                        label: const Text('Track driver location')))),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            if (order.canReorder)
              FilledButton.tonalIcon(
                  onPressed: () => _reorder(order),
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('Reorder items')),
            if (order.canCancel)
              TextButton.icon(
                  onPressed: () => _cancel(order),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Cancel order')),
            if (!['DELIVERED', 'CANCELLED', 'REJECTED'].contains(order.status))
              TextButton.icon(
                  onPressed: () => _rotateOtp(order),
                  icon: const Icon(Icons.password_rounded, size: 18),
                  label: const Text('Refresh delivery OTP')),
          ]),
        ],
      ));

  Widget _timeline(OrderRecord order) {
    const stages = [
      'PLACED',
      'ACCEPTED',
      'PREPARING',
      'READY_FOR_PICKUP',
      'OUT_FOR_DELIVERY',
      'DELIVERED'
    ];
    final index = stages.indexOf(order.status);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Order progress',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 9),
      Wrap(
          spacing: 6,
          runSpacing: 7,
          children: stages.asMap().entries.map((entry) {
            final current = order.status == entry.value;
            final complete = index >= entry.key && index >= 0;
            return Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                    color: current
                        ? AppColors.green
                        : complete
                            ? AppColors.paleGreen
                            : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Text(entry.value.replaceAll('_', ' '),
                    style: TextStyle(
                        fontSize: 11,
                        color: current
                            ? Colors.white
                            : complete
                                ? AppColors.darkGreen
                                : AppColors.muted,
                        fontWeight: FontWeight.w700)));
          }).toList()),
    ]);
  }
}
