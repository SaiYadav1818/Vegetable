import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/platform/device_services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/design_components.dart';
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

  void _toast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _availability(bool value) async {
    try {
      await _api.setDriverOnline(value);
      if (mounted) setState(() => _online = value);
      await _reload();
    } catch (e) {
      _toast(_api.describeError(e));
    }
  }

  Future<bool> _act(Future<Object?> Function() action) async {
    try {
      setState(() => _busy = true);
      await action();
      await _reload();
      return true;
    } catch (e) {
      _toast(_api.describeError(e));
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
      _toast(_api.describeError(e));
      return;
    }
    _locationTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      try {
        await _sendLocation();
      } catch (e) {
        _stopLocation();
        _toast(_api.describeError(e));
      }
    });
  }

  Future<void> _sendLocation() async {
    if (!_sharing ||
        !mounted ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
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
    bool cashCollected = true;
    final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => StatefulBuilder(
              builder: (ctx, setDialogState) => AlertDialog(
                title: const Text('Verify delivery'),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Order total: ₹${order.totalAmount.toStringAsFixed(2)}'),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Cash collected'),
                        subtitle: Text(cashCollected
                            ? 'Driver collected ₹${order.totalAmount.toStringAsFixed(2)}'
                            : 'Cash was NOT collected'),
                        value: cashCollected,
                        activeColor: AppColors.green,
                        onChanged: (val) =>
                            setDialogState(() => cashCollected = val),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: const InputDecoration(
                              labelText: '6 digit delivery OTP')),
                    ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Back')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, {
                            'otp': controller.text.trim(),
                            'cashCollected': cashCollected,
                          }),
                      child: const Text('Complete delivery'))
                ],
              ),
            ));
    controller.dispose();
    if (result == null) return;
    final otp = result['otp'] as String;
    final collected = result['cashCollected'] as bool;
    if (otp.isEmpty) return;
    if (await _act(
        () => _api.deliver(order.orderId, otp, cashCollected: collected))) {
      _stopLocation();
    }
  }

  Future<void> _reportFailure(DriverOrder order) async {
    final controller = TextEditingController();
    String selectedReason = 'Customer unavailable / not at address';
    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Report delivery failed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Why could this order not be delivered?'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedReason,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                      value: 'Customer unavailable / not at address',
                      child: Text('Customer unavailable')),
                  DropdownMenuItem(
                      value: 'Phone switched off / unreachable',
                      child: Text('Phone unreachable')),
                  DropdownMenuItem(
                      value: 'Customer refused delivery',
                      child: Text('Customer refused')),
                  DropdownMenuItem(
                      value: 'Incorrect delivery address',
                      child: Text('Incorrect address')),
                  DropdownMenuItem(
                      value: 'Other reason', child: Text('Other reason')),
                ],
                onChanged: (val) =>
                    setDialogState(() => selectedReason = val ?? selectedReason),
              ),
              if (selectedReason == 'Other reason') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  decoration:
                      const InputDecoration(labelText: 'Specify reason'),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () {
                final reason = selectedReason == 'Other reason' &&
                        controller.text.trim().isNotEmpty
                    ? controller.text.trim()
                    : selectedReason;
                Navigator.pop(ctx, reason);
              },
              child: const Text('Confirm failure'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (confirmed == null || confirmed.isEmpty) return;
    if (await _act(() => _api.reportDeliveryFailure(order.orderId, confirmed))) {
      _stopLocation();
    }
  }

  Future<void> _navigate(DriverOrder order) async {
    final address = Uri.encodeComponent(
        '${order.addressLine}, ${order.area}, ${order.pincode}');
    try {
      await _device.openExternalUrl(
          'https://www.google.com/maps/search/?api=1&query=$address');
    } catch (_) {
      _toast('Could not open maps on this device.');
    }
  }

  Future<void> _call(String phone) async {
    try {
      await _device.openExternalUrl('tel:$phone');
    } catch (_) {
      _toast('Could not open the phone app.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: FreshBasketAppBar(
            title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Driver dashboard',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text(widget.session.fullName,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: AppColors.muted))
                ]),
            actions: [
              IconButton(
                  tooltip: 'Sign out',
                  onPressed: widget.onSignOut,
                  icon: const Icon(Icons.logout))
            ]),
        body: FutureBuilder<List<DriverOrder>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingState(
                    message: 'Loading assigned deliveries...');
              }
              if (snapshot.hasError) {
                return ErrorState(
                    message: _api.describeError(snapshot.error!),
                    onRetry: _reload);
              }
              final orders = snapshot.data ?? [];
              final active = orders
                  .where((o) =>
                      o.assignmentStatus == 'ACCEPTED' ||
                      o.assignmentStatus == 'PICKED_UP')
                  .length;
              final pending =
                  orders.where((o) => o.assignmentStatus == 'ASSIGNED').length;
              final complete =
                  orders.where((o) => o.assignmentStatus == 'DELIVERED').length;
              return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                      children: [
                        Card(
                            child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 10, 12, 10),
                                child: Row(children: [
                                  Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                          color: _online
                                              ? AppColors.paleGreen
                                              : const Color(0xFFF1F3F0),
                                          shape: BoxShape.circle),
                                      child: Icon(Icons.delivery_dining,
                                          color: _online
                                              ? AppColors.green
                                              : AppColors.muted)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(
                                            _online
                                                ? 'You are online'
                                                : 'You are offline',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w800)),
                                        Text(
                                            _online
                                                ? 'Available for your assigned work'
                                                : 'Go online to receive deliveries',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall)
                                      ])),
                                  Switch(
                                      value: _online,
                                      onChanged: _busy ? null : _availability)
                                ]))),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                              child: DashboardStatCard(
                                  title: 'New',
                                  value: '$pending',
                                  icon: Icons.inbox_outlined)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: DashboardStatCard(
                                  title: 'Active',
                                  value: '$active',
                                  icon: Icons.route_outlined,
                                  accent: AppColors.orange)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: DashboardStatCard(
                                  title: 'Completed',
                                  value: '$complete',
                                  icon: Icons.task_alt_rounded))
                        ]),
                        const SectionTitle('Assigned orders'),
                        if (orders.isEmpty)
                          const EmptyState(
                              icon: Icons.delivery_dining_outlined,
                              title: 'No deliveries assigned',
                              message:
                                  'New delivery assignments will appear here.'),
                        ...orders.map(_orderCard),
                      ]));
            }),
      );

  Widget _orderCard(DriverOrder order) {
    final status = order.assignmentStatus;
    final actions = <Widget>[
      OutlinedButton.icon(
          onPressed: () => _call(order.customerPhone),
          icon: const Icon(Icons.call_outlined),
          label: const Text('Call customer')),
      OutlinedButton.icon(
          onPressed: () => _navigate(order),
          icon: const Icon(Icons.navigation_outlined),
          label: const Text('Navigate')),
      if (status == 'ASSIGNED')
        FilledButton(
            onPressed: _busy
                ? null
                : () => _act(() => _api.acceptDelivery(order.orderId)),
            child: const Text('Accept delivery')),
      if (status == 'ACCEPTED')
        FilledButton(
            onPressed: _busy
                ? null
                : () => _act(() => _api.pickupDelivery(order.orderId)),
            child: const Text('Mark picked up')),
      if (status == 'PICKED_UP')
        FilledButton(
            onPressed: _busy ? null : () => _deliver(order),
            child: const Text('Complete with OTP')),
      if (status == 'ACCEPTED' || status == 'PICKED_UP')
        OutlinedButton.icon(
            onPressed: _busy ? null : () => _reportFailure(order),
            icon: const Icon(Icons.warning_amber_rounded, color: AppColors.error),
            label: const Text('Report failure',
                style: TextStyle(color: AppColors.error))),
    ];
    return DeliveryOrderCard(
        title: order.orderNumber,
        subtitle: '${order.customerName} · ${order.deliverySlot}',
        status: _orderStatus(status),
        actions: actions,
        details:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(order.addressLine,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          Text('${order.area}, ${order.pincode}',
              style: Theme.of(context).textTheme.bodySmall),
          if (order.deliveryInstructions?.isNotEmpty == true)
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Note: ${order.deliveryInstructions}',
                    style: Theme.of(context).textTheme.bodySmall)),
          const Divider(height: 20),
          ...order.items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(
                    child: Text(
                        '${item.name} · ${item.quantity} ${item.unit.toLowerCase()}')),
                Text('₹${item.lineTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w700))
              ]))),
          const Divider(height: 20),
          Row(children: [
            const Icon(Icons.payments_outlined,
                color: AppColors.green, size: 18),
            const SizedBox(width: 6),
            const Expanded(child: Text('Cash to collect')),
            Text('₹${order.totalAmount.toStringAsFixed(2)}',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800))
          ]),
          if (status == 'ACCEPTED' || status == 'PICKED_UP')
            Padding(
                padding: const EdgeInsets.only(top: 10),
                child: OutlinedButton.icon(
                    onPressed: _sharing ? _stopLocation : _startLocation,
                    icon: Icon(_sharing
                        ? Icons.location_on
                        : Icons.location_searching),
                    label: Text(_sharing
                        ? 'Stop live location'
                        : 'Share live location'))),
        ]));
  }

  String _orderStatus(String status) => switch (status) {
        'ASSIGNED' => 'DRIVER_ASSIGNED',
        'ACCEPTED' => 'ACCEPTED',
        'PICKED_UP' => 'OUT_FOR_DELIVERY',
        'DELIVERED' => 'DELIVERED',
        _ => status
      };
}
