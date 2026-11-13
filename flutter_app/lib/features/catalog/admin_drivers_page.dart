import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/design_components.dart';
import '../orders/orders_api.dart';

class AdminDriversPage extends StatefulWidget {
  const AdminDriversPage({super.key, required this.client});
  final ApiClient client;
  @override
  State<AdminDriversPage> createState() => _AdminDriversPageState();
}

class _AdminDriversPageState extends State<AdminDriversPage> {
  late final OrdersApi _api = OrdersApi(widget.client);
  late Future<List<Map<String, dynamic>>> _future = _api.drivers(size: 100);
  Future<void> _reload() async {
    setState(() => _future = _api.drivers(size: 100));
    await _future;
  }

  Future<void> _createDriver() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final password = TextEditingController();
    final accepted = await showDialog<bool>(
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
    if (accepted == true) {
      try {
        await _api.createDriver(
            name: name.text.trim(),
            email: email.text.trim(),
            phone: phone.text.trim(),
            password: password.text);
        await _reload();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(_api.describeError(e))));
        }
      }
    }
    name.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const FreshBasketAppBar(title: Text('Delivery drivers')),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: _createDriver,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Add driver')),
        body: RefreshIndicator(
            onRefresh: _reload,
            child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingState(
                        message: 'Loading driver availability...');
                  }
                  if (snapshot.hasError) {
                    return ErrorState(
                        message: _api.describeError(snapshot.error!),
                        onRetry: _reload);
                  }
                  final drivers = snapshot.data ?? [];
                  if (drivers.isEmpty) {
                    return const EmptyState(
                        icon: Icons.delivery_dining_outlined,
                        title: 'No drivers yet',
                        message:
                            'Add drivers from the Orders screen when your team is ready.');
                  }
                  final online =
                      drivers.where((d) => d['online'] == true).length;
                  return ListView(padding: const EdgeInsets.all(16), children: [
                    Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                            color: AppColors.paleGreen,
                            borderRadius: BorderRadius.circular(AppRadius.md)),
                        child: Row(children: [
                          Expanded(
                              child: Text(
                                  '$online of ${drivers.length} drivers online',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800))),
                          const Icon(Icons.circle,
                              size: 11, color: AppColors.green)
                        ])),
                    const SizedBox(height: 10),
                    ...drivers.map((driver) {
                      final isOnline = driver['online'] == true;
                      final available = driver['available'] == true;
                      final statusColor = !isOnline
                          ? AppColors.muted
                          : available
                              ? AppColors.green
                              : AppColors.orange;
                      final status = !isOnline
                          ? 'Offline'
                          : available
                              ? 'Available'
                              : 'Assigned';
                      return Card(
                          margin: const EdgeInsets.only(bottom: 9),
                          child: ListTile(
                              leading: CircleAvatar(
                                  backgroundColor: isOnline
                                      ? AppColors.paleGreen
                                      : const Color(0xFFF1F3F0),
                                  child: Icon(Icons.person_outline,
                                      color: isOnline
                                          ? AppColors.green
                                          : AppColors.muted)),
                              title: Text(driver['fullName']?.toString() ?? 'Driver',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                  '${driver['phoneNumber'] ?? ''}\n${driver['email'] ?? ''}',
                                  maxLines: 2),
                              isThreeLine: true,
                              trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: .1),
                                      borderRadius: BorderRadius.circular(
                                          AppRadius.pill)),
                                  child: Text(status,
                                      style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 11)))));
                    }),
                  ]);
                })),
      );
}
