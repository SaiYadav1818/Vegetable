import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/platform/device_services.dart';
import '../auth/auth_api.dart';
import '../orders/order_models.dart';
import '../orders/orders_api.dart';

class DriverLandingPage extends StatefulWidget {
  const DriverLandingPage(
      {super.key,
      required this.session,
      required this.client,
      required this.onSignOut});
  final AuthSession session;
  final ApiClient client;
  final VoidCallback onSignOut;
  @override
  State<DriverLandingPage> createState() => _DriverLandingPageState();
}

class _DriverLandingPageState extends State<DriverLandingPage>
    with WidgetsBindingObserver {
  late final OrdersApi _api = OrdersApi(widget.client);
  final _device = const DeviceServices();
  late Future<List<DriverOrder>> _future = _api.driverOrders();
  Timer? _locationTimer;
  bool _online = false, _sharing = false, _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stopLocation();
  }

  Future<void> _reload() async {
    setState(() => _future = _api.driverOrders());
    await _future;
  }

  void _message(Object e) {
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_api.describeError(e))));
  }

  Future<void> _setOnline(bool value) async {
    try {
      await _api.setDriverOnline(value);
      if (mounted) setState(() => _online = value);
      await _reload();
    } catch (e) {
      _message(e);
    }
  }

  Future<bool> _act(Future<Object?> Function() action) async {
    try {
      setState(() => _busy = true);
      await action();
      await _reload();
      return true;
    } catch (e) {
      _message(e);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startLocation() async {
    setState(() => _sharing = true);
    try {
      await _sendLocation();
    } catch (e) {
      if (mounted) setState(() => _sharing = false);
      _message(e);
      return;
    }
    _locationTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      try {
        await _sendLocation();
      } catch (e) {
        _stopLocation();
        _message(e);
      }
    });
  }

  Future<void> _sendLocation() async {
    if (!_sharing ||
        !mounted ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed)
      return;
    final position = await _device.currentLocation();
    await _api.updateDriverLocation(
        position['latitude']!, position['longitude']!);
  }

  void _stopLocation() {
    _locationTimer?.cancel();
    _locationTimer = null;
    if (mounted && _sharing) setState(() => _sharing = false);
  }

  Future<void> _deliver(DriverOrder order) async {
    final controller = TextEditingController();
    final otp = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Confirm delivery'),
              content: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                      labelText: 'Customer delivery OTP')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Back')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, controller.text),
                    child: const Text('Verify & deliver'))
              ],
            ));
    controller.dispose();
    if (otp == null) return;
    if (await _act(
        () => _api.deliver(order.orderId, otp, cashCollected: true))) {
      _stopLocation();
    }
  }

  Future<void> _navigate(DriverOrder order) async {
    final address = Uri.encodeComponent(
        '${order.addressLine}, ${order.area}, ${order.pincode}');
    try {
      await _device.openExternalUrl(
          'https://www.google.com/maps/search/?api=1&query=$address');
    } catch (e) {
      if (mounted) _message(StateError('Could not open maps'));
    }
  }

  Widget _orderCard(DriverOrder order) {
    final status = order.assignmentStatus;
    return Card(
        margin: const EdgeInsets.fromLTRB(12, 7, 12, 7),
        child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${order.orderNumber} · ${status.replaceAll('_', ' ')}',
                    style: Theme.of(context).textTheme.titleMedium),
                Text('${order.customerName} · ${order.customerPhone}'),
                Text('${order.addressLine}, ${order.area}, ${order.pincode}'),
                Text('${order.deliverySlot} · Rs. ${order.totalAmount}'),
                ...order.items.map((item) =>
                    Text('${item.name} · ${item.quantity} ${item.unit}')),
                Wrap(spacing: 8, children: [
                  TextButton.icon(
                      onPressed: () => _navigate(order),
                      icon: const Icon(Icons.navigation),
                      label: const Text('Navigate')),
                  if (status == 'ASSIGNED')
                    FilledButton(
                        onPressed: _busy
                            ? null
                            : () =>
                                _act(() => _api.acceptDelivery(order.orderId)),
                        child: const Text('Accept')),
                  if (status == 'ACCEPTED')
                    FilledButton(
                        onPressed: _busy
                            ? null
                            : () =>
                                _act(() => _api.pickupDelivery(order.orderId)),
                        child: const Text('Picked up')),
                  if (status == 'PICKED_UP')
                    FilledButton(
                        onPressed: _busy ? null : () => _deliver(order),
                        child: const Text('Complete with OTP')),
                ]),
              ],
            )));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text('Deliveries · ${widget.session.fullName}'),
            actions: [
              IconButton(
                  onPressed: widget.onSignOut, icon: const Icon(Icons.logout))
            ]),
        body: Column(children: [
          SwitchListTile(
              title: const Text('Available for deliveries'),
              value: _online,
              onChanged: _busy ? null : _setOnline),
          Expanded(
              child: FutureBuilder<List<DriverOrder>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const Center(child: CircularProgressIndicator());
                    if (snapshot.hasError)
                      return Center(
                          child: TextButton(
                              onPressed: _reload,
                              child: const Text(
                                  'Could not load deliveries. Retry')));
                    final orders = snapshot.data ?? [];
                    if (orders.isEmpty)
                      return const Center(
                          child: Text('No deliveries assigned yet'));
                    final active = orders.any((o) =>
                        o.assignmentStatus == 'ACCEPTED' ||
                        o.assignmentStatus == 'PICKED_UP');
                    return RefreshIndicator(
                        onRefresh: _reload,
                        child: ListView(children: [
                          if (active)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: OutlinedButton.icon(
                                  onPressed:
                                      _sharing ? _stopLocation : _startLocation,
                                  icon: Icon(_sharing
                                      ? Icons.location_on
                                      : Icons.location_searching),
                                  label: Text(_sharing
                                      ? 'Stop location sharing'
                                      : 'Share live location for active delivery'),
                                )),
                          ...orders.map(_orderCard),
                        ]));
                  })),
        ]),
      );
}
