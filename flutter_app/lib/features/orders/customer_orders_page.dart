import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/platform/device_services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/design_components.dart';
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
    try {
      await _api.cancelOrder(order.id);
      await _reload();
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
                                Text('Your deliveries',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w800)),
                                Text(
                                    '${orders.length} recent ${orders.length == 1 ? 'order' : 'orders'}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall)
                              ]))
                        ])),
                    const SizedBox(height: 10),
                    ...orders.map((order) => _orderCard(order)),
                  ]);
            }));
    if (widget.embedded) return content;
    return Scaffold(
        appBar: const FreshBasketAppBar(title: Text('My orders')),
        body: content);
  }

  Widget _orderCard(OrderRecord order) => Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(16, 8, 14, 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(children: [
          Expanded(
              child: Text(order.orderNumber,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800))),
          OrderStatusBadge(status: order.status)
        ]),
        subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
                '${_date(order.createdAt)}  ·  ${order.items.length} ${order.items.length == 1 ? 'item' : 'items'}  ·  ₹${order.totalAmount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodySmall)),
        children: [
          Align(alignment: Alignment.centerLeft, child: _timeline(order)),
          const SizedBox(height: 14),
          Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Delivery to ${order.recipientName}',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                        '${order.addressLine}, ${order.area}, ${order.pincode}'),
                    Text(order.recipientPhone,
                        style: Theme.of(context).textTheme.bodySmall),
                  ])),
          const SizedBox(height: 10),
          ...order.items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Expanded(
                    child: Text(
                        '${item.name}  ·  ${item.quantity} ${item.unit.toLowerCase()}')),
                Text('₹${item.lineTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w700))
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
          Wrap(spacing: 8, children: [
            if (order.canCancel)
              TextButton.icon(
                  onPressed: () => _cancel(order),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel order')),
            if (!['DELIVERED', 'CANCELLED', 'REJECTED'].contains(order.status))
              TextButton.icon(
                  onPressed: () => _rotateOtp(order),
                  icon: const Icon(Icons.password_rounded),
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
    final events = order.statusHistory;
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
                            : Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                        color: current ? AppColors.green : AppColors.line)),
                child: Text(entry.value.replaceAll('_', ' ').toLowerCase(),
                    style: TextStyle(
                        fontSize: 11,
                        color: current
                            ? Colors.white
                            : complete
                                ? AppColors.darkGreen
                                : AppColors.muted,
                        fontWeight: FontWeight.w700)));
          }).toList()),
      if (events.isNotEmpty) ...[
        const SizedBox(height: 12),
        ...events.reversed.take(4).map((event) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.check_circle, size: 16, color: AppColors.green),
              const SizedBox(width: 7),
              Expanded(
                  child: Text(
                      '${event.toStatus.replaceAll('_', ' ')} · ${event.createdAt.toLocal().toString().substring(0, 16)}${event.reason == null ? '' : ' — ${event.reason}'}',
                      style: Theme.of(context).textTheme.bodySmall))
            ]))),
      ],
    ]);
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
