import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/platform/device_services.dart';
import 'order_models.dart';
import 'orders_api.dart';

class CustomerOrdersPage extends StatefulWidget {
  const CustomerOrdersPage({super.key, required this.client});
  final ApiClient client;
  @override
  State<CustomerOrdersPage> createState() => _CustomerOrdersPageState();
}

class _CustomerOrdersPageState extends State<CustomerOrdersPage> {
  final _device = const DeviceServices();
  late final OrdersApi _api = OrdersApi(widget.client);
  late Future<List<OrderRecord>> _orders = _api.myOrders();
  Timer? _trackingTimer;
  bool _hasActiveTracking = false;

  @override
  void initState() {
    super.initState();
    _trackingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_hasActiveTracking && mounted) _reload().catchError((_) {});
    });
    _reload().catchError((_) {});
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    final request = _api.myOrders();
    setState(() => _orders = request);
    final result = await request;
    _hasActiveTracking = result.any(
        (o) => o.status == 'DRIVER_ASSIGNED' || o.status == 'OUT_FOR_DELIVERY');
  }

  Future<void> _cancel(OrderRecord order) async {
    try {
      await _api.cancelOrder(order.id);
      await _reload();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_api.describeError(e))));
    }
  }

  Future<void> _rotateOtp(OrderRecord order) async {
    try {
      final otp = await _api.rotateDeliveryOtp(order.id);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('New delivery OTP: $otp')));
      await _reload();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_api.describeError(e))));
    }
  }

  Future<void> _openDriverLocation(OrderRecord order) async {
    final location = order.driverLocation;
    if (location == null) return;
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}');
    await _device.openExternalUrl(uri.toString());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('My orders'), actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh))
        ]),
        body: RefreshIndicator(
            onRefresh: _reload,
            child: FutureBuilder<List<OrderRecord>>(
                future: _orders,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError)
                    return Center(
                        child: TextButton(
                            onPressed: _reload,
                            child: const Text('Could not load orders. Retry')));
                  final orders = snapshot.data ?? [];
                  if (orders.isEmpty)
                    return const Center(child: Text('No orders yet.'));
                  return ListView.builder(
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        return Card(
                            margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                            child: ExpansionTile(
                              title: Text(
                                  '${order.orderNumber} · ${order.status.replaceAll('_', ' ')}'),
                              subtitle: Text(
                                  '${order.deliverySlot} · Rs. ${order.totalAmount.toStringAsFixed(2)} · ${order.paymentStatus.replaceAll('_', ' ')}'),
                              children: [
                                Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 14),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              '${order.recipientName} · ${order.recipientPhone}'),
                                          Text(
                                              '${order.addressLine}, ${order.area}, ${order.pincode}'),
                                          const SizedBox(height: 8),
                                          ...order.items.map((item) => Text(
                                              '${item.name}  ${item.quantity} ${item.unit} · Rs. ${item.lineTotal}')),
                                          if (order.deliveryOtp != null)
                                            Text(
                                                'Delivery OTP: ${order.deliveryOtp}',
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          if (order.driverLocation != null)
                                            TextButton.icon(
                                              onPressed: () =>
                                                  _openDriverLocation(order),
                                              icon: const Icon(
                                                  Icons.location_on_outlined),
                                              label: const Text(
                                                  'Open driver location'),
                                            ),
                                          if (order
                                              .statusHistory.isNotEmpty) ...[
                                            const Divider(),
                                            const Text('Order status history',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            ...order.statusHistory
                                                .map((event) => Text(
                                                      '${event.toStatus.replaceAll('_', ' ')} · ${event.createdAt.toLocal()}${event.reason == null ? '' : ' · ${event.reason}'}',
                                                    )),
                                          ],
                                          Wrap(spacing: 8, children: [
                                            if (![
                                              'DELIVERED',
                                              'CANCELLED',
                                              'REJECTED'
                                            ].contains(order.status))
                                              TextButton(
                                                  onPressed: () =>
                                                      _cancel(order),
                                                  child: const Text(
                                                      'Cancel order')),
                                            if (order.status ==
                                                    'DRIVER_ASSIGNED' ||
                                                order.status ==
                                                    'OUT_FOR_DELIVERY')
                                              TextButton(
                                                  onPressed: _reload,
                                                  child: const Text(
                                                      'Refresh tracking')),
                                            if (order.canCancel)
                                              TextButton(
                                                  onPressed: () =>
                                                      _rotateOtp(order),
                                                  child: const Text(
                                                      'Refresh OTP')),
                                          ]),
                                        ]))
                              ],
                            ));
                      });
                })),
      );
}
