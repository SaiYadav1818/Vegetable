import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/design_components.dart';
import 'order_models.dart';
import 'orders_api.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key, required this.client});
  final ApiClient client;
  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  late final OrdersApi _api = OrdersApi(widget.client);
  late Future<List<OrderRecord>> _future = _api.adminOrders();
  List<Map<String, dynamic>> _drivers = [];

  Future<void> _reload() async {
    setState(() => _future = _api.adminOrders());
    try {
      _drivers = await _api.drivers();
    } catch (_) {}
    await _future;
  }

  void _error(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_api.describeError(error))));
    }
  }

  List<String> _next(String status) => switch (status) {
        'PLACED' => ['ACCEPTED', 'REJECTED'],
        'ACCEPTED' => ['PREPARING'],
        'PREPARING' => ['READY_FOR_PICKUP'],
        _ => [],
      };
  Future<void> _changeStatus(OrderRecord order, String status) async {
    try {
      await _api.updateAdminStatus(order.id, status);
      await _reload();
    } catch (e) {
      _error(e);
    }
  }

  Future<void> _createDriver() async {
    final name = TextEditingController(),
        email = TextEditingController(),
        phone = TextEditingController(),
        password = TextEditingController();
    final saved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Add delivery driver'),
              content: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Full name')),
                TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email')),
                TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration:
                        const InputDecoration(labelText: 'Phone number')),
                TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'Initial password (12+ characters)')),
              ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Create driver'))
              ],
            ));
    if (saved == true) {
      try {
        await _api.createDriver(
            name: name.text.trim(),
            email: email.text.trim(),
            phone: phone.text.trim(),
            password: password.text);
        await _reload();
      } catch (e) {
        _error(e);
      }
    }
    name.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
  }

  Future<void> _assign(OrderRecord order) async {
    try {
      if (_drivers.isEmpty) _drivers = await _api.drivers();
    } catch (e) {
      _error(e);
      return;
    }
    if (!mounted) return;
    final available = _drivers
        .where(
            (driver) => driver['online'] == true && driver['available'] == true)
        .toList();
    final id = await showDialog<int>(
        context: context,
        builder: (ctx) => SimpleDialog(
              title: const Text('Assign available driver'),
              children: [
                if (available.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No drivers are online and available.')),
                ...available.map((driver) => SimpleDialogOption(
                    onPressed: () =>
                        Navigator.pop(ctx, driver['userId'] as int),
                    child: Text(
                        '${driver['fullName']} · ${driver['phoneNumber']}'))),
                SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel')),
              ],
            ));
    if (id == null) return;
    try {
      await _api.assignDriver(order.id, id);
      await _reload();
    } catch (e) {
      _error(e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Orders & deliveries'), actions: [
          IconButton(
              tooltip: 'Add driver',
              onPressed: _createDriver,
              icon: const Icon(Icons.person_add_alt_1)),
          IconButton(
              tooltip: 'Refresh',
              onPressed: _reload,
              icon: const Icon(Icons.refresh))
        ]),
        body: RefreshIndicator(
            onRefresh: _reload,
            child: FutureBuilder<List<OrderRecord>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingState(
                        message: 'Loading customer orders...');
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
                            'Customer orders will appear here when they are placed.');
                  }
                  return ListView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                      children: [
                        Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: AppColors.paleGreen,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md)),
                            child: Row(children: [
                              const Icon(Icons.receipt_long_outlined,
                                  color: AppColors.green),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text('${orders.length} latest orders',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w800)))
                            ])),
                        const SizedBox(height: 8),
                        ...orders.map((order) => DeliveryOrderCard(
                              title: order.orderNumber,
                              subtitle:
                                  '${order.recipientName} · ${order.deliveryDate.day}/${order.deliveryDate.month}/${order.deliveryDate.year}',
                              status: order.status,
                              details: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        '${order.recipientPhone} · ${order.addressLine}, ${order.area}, ${order.pincode}'),
                                    const SizedBox(height: 8),
                                    ...order.items.map((item) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 3),
                                        child: Row(children: [
                                          Expanded(
                                              child: Text(
                                                  '${item.name} · ${item.quantity} ${item.unit.toLowerCase()}')),
                                          Text(
                                              '₹${item.lineTotal.toStringAsFixed(2)}')
                                        ]))),
                                    const Divider(height: 20),
                                    Row(children: [
                                      const Icon(Icons.payments_outlined,
                                          color: AppColors.green, size: 18),
                                      const SizedBox(width: 6),
                                      const Expanded(
                                          child: Text('Cash on delivery')),
                                      Text(
                                          '₹${order.totalAmount.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800))
                                    ]),
                                  ]),
                              actions: [
                                ..._next(order.status).map((status) =>
                                    OutlinedButton(
                                        onPressed: () =>
                                            _changeStatus(order, status),
                                        child:
                                            Text(status.replaceAll('_', ' ')))),
                                if (order.status == 'READY_FOR_PICKUP')
                                  FilledButton.tonal(
                                      onPressed: () => _assign(order),
                                      child: const Text('Assign driver')),
                              ],
                            )),
                      ]);
                })),
      );
}
