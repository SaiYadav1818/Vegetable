import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
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
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_api.describeError(error))));
  }

  Future<void> _changeStatus(OrderRecord order, String status) async {
    try {
      await _api.updateAdminStatus(order.id, status);
      await _reload();
    } catch (e) {
      _error(e);
    }
  }

  Future<void> _createDriver() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final password = TextEditingController();
    final saved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Add delivery driver'),
              content: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: name,
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
        .where((d) => d['online'] == true && d['available'] == true)
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
                ...available.map((d) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, d['userId'] as int),
                    child: Text('${d['fullName']} · ${d['phoneNumber']}'))),
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

  List<String> _next(String status) => switch (status) {
        'PLACED' => ['ACCEPTED', 'REJECTED'],
        'ACCEPTED' => ['PREPARING'],
        'PREPARING' => ['READY_FOR_PICKUP'],
        _ => [],
      };
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Orders & deliveries'), actions: [
          IconButton(
              tooltip: 'Add driver',
              onPressed: _createDriver,
              icon: const Icon(Icons.person_add_alt_1)),
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh))
        ]),
        body: RefreshIndicator(
            onRefresh: _reload,
            child: FutureBuilder<List<OrderRecord>>(
                future: _future,
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
                    return const Center(child: Text('No orders yet'));
                  return ListView.builder(
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        return Card(
                            margin: const EdgeInsets.all(10),
                            child: ExpansionTile(
                              title: Text(
                                  '${order.orderNumber} · ${order.status.replaceAll('_', ' ')}'),
                              subtitle: Text(
                                  '${order.recipientName} · Rs. ${order.totalAmount.toStringAsFixed(2)} · ${order.deliveryDate.day}/${order.deliveryDate.month}/${order.deliveryDate.year}'),
                              children: [
                                Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              '${order.recipientPhone} · ${order.addressLine}, ${order.area}, ${order.pincode}'),
                                          ...order.items.map((item) => Text(
                                              '${item.name}: ${item.quantity} ${item.unit}')),
                                          Wrap(spacing: 8, children: [
                                            ..._next(order.status).map(
                                                (status) => OutlinedButton(
                                                    onPressed: () =>
                                                        _changeStatus(
                                                            order, status),
                                                    child: Text(
                                                        status.replaceAll(
                                                            '_', ' ')))),
                                            if (order.status ==
                                                'READY_FOR_PICKUP')
                                              FilledButton.tonal(
                                                  onPressed: () =>
                                                      _assign(order),
                                                  child: const Text(
                                                      'Assign driver')),
                                          ]),
                                        ]))
                              ],
                            ));
                      });
                })),
      );
}
