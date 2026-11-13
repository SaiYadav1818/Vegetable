import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/design_components.dart';
import '../catalog/catalog_api.dart';
import '../catalog/catalog_models.dart';
import '../orders/order_models.dart';
import '../orders/orders_api.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage(
      {super.key,
      required this.client,
      required this.adminName,
      required this.onProducts,
      required this.onOrders,
      required this.onDrivers,
      required this.onSignOut});
  final ApiClient client;
  final String adminName;
  final VoidCallback onProducts, onOrders, onDrivers, onSignOut;
  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late Future<_AdminData> _data = _load();
  Future<void> _refresh() async {
    setState(() => _data = _load());
    await _data;
  }

  Future<_AdminData> _load() async {
    final result = await Future.wait<Object>([
      OrdersApi(widget.client).adminOrders(size: 100),
      CatalogApi(widget.client).getProducts(admin: true, size: 100),
      OrdersApi(widget.client).getCodReconciliationReport(),
    ]);
    return _AdminData(
        result[0] as List<OrderRecord>,
        result[1] as List<Product>,
        result[2] as CodReconciliationReport);
  }

  Future<void> _settleDriver(int driverId, String driverName) async {
    try {
      final count = await OrdersApi(widget.client)
          .reconcileDriverPayments(driverId, note: 'Settled with counter');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Settled $count payments for $driverName'),
        behavior: SnackBarBehavior.floating,
      ));
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(OrdersApi(widget.client).describeError(e)),
      ));
    }
  }

  void _showCodModal(CodReconciliationReport report) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('COD cash reconciliation',
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Total collected: ₹${report.totalCollected.toStringAsFixed(2)} · Unsettled: ₹${report.totalUnsettled.toStringAsFixed(2)}',
              style: const TextStyle(color: AppColors.muted),
            ),
            const Divider(height: 24),
            if (report.drivers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No drivers have collected cash yet.')),
              )
            else
              ...report.drivers.map((d) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(d.driverName,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          'Unsettled: ₹${d.unsettledAmount.toStringAsFixed(2)} (${d.unsettledCount} orders)\nSettled: ₹${d.settledAmount.toStringAsFixed(2)}'),
                      isThreeLine: true,
                      trailing: d.unsettledAmount > 0
                          ? FilledButton.tonal(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _settleDriver(d.driverUserId, d.driverName);
                              },
                              child: const Text('Settle'),
                            )
                          : const Icon(Icons.check_circle_rounded,
                              color: AppColors.green),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: FreshBasketAppBar(
            title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Good day, ${widget.adminName.split(' ').first}',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text('FreshBasket store overview',
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
        body: FutureBuilder<_AdminData>(
            future: _data,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingState(message: 'Loading store overview...');
              }
              if (snapshot.hasError) {
                return ErrorState(
                    message:
                        'Could not load store information. ${snapshot.error}',
                    onRetry: _refresh);
              }
              final data = snapshot.data!;
              final now = DateTime.now();
              final todayOrders = data.orders
                  .where((o) =>
                      o.createdAt.year == now.year &&
                      o.createdAt.month == now.month &&
                      o.createdAt.day == now.day)
                  .toList();
              final open = data.orders
                  .where((o) =>
                      o.status == 'PLACED' ||
                      o.status == 'ACCEPTED' ||
                      o.status == 'PREPARING' ||
                      o.status == 'READY_FOR_PICKUP' ||
                      o.status == 'DELIVERY_FAILED')
                  .length;
              final low = data.products
                  .where((p) => p.stock <= p.minimumStock)
                  .length;
              final cod = data.codReport;

              return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                      children: [
                        Card(
                            color: AppColors.paleGreen,
                            child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Container(
                                            width: 40,
                                            height: 40,
                                            decoration: const BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle),
                                            child: const Icon(
                                                Icons.storefront_rounded,
                                                color: AppColors.green)),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                              Text('Daily operational summary',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w800)),
                                              Text(
                                                  '${todayOrders.length} orders received today',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                          color:
                                                              AppColors.muted))
                                            ]))
                                      ]),
                                      const SizedBox(height: 14),
                                      Wrap(spacing: 8, runSpacing: 8, children: [
                                        MetricChip(
                                            label: '$open open orders',
                                            accent: open > 0
                                                ? AppColors.orange
                                                : AppColors.green),
                                        MetricChip(
                                            label: '$low low stock',
                                            accent: low > 0
                                                ? AppColors.error
                                                : AppColors.green),
                                        MetricChip(
                                            label:
                                                '₹${cod.totalUnsettled.toStringAsFixed(0)} COD unsettled',
                                            accent: cod.totalUnsettled > 0
                                                ? AppColors.orange
                                                : AppColors.green),
                                      ])
                                    ]))),
                        const SizedBox(height: 16),
                        const SectionTitle('Store metrics'),
                        GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.45,
                            children: [
                              DashboardStatCard(
                                  title: 'Open orders',
                                  value: '$open',
                                  icon: Icons.receipt_long_outlined,
                                  accent: open > 0
                                      ? AppColors.orange
                                      : AppColors.green,
                                  onTap: widget.onOrders),
                              DashboardStatCard(
                                  title: 'COD Collected',
                                  value: '₹${cod.totalCollected.toStringAsFixed(0)}',
                                  icon: Icons.currency_rupee_rounded,
                                  onTap: () => _showCodModal(cod)),
                              DashboardStatCard(
                                  title: 'Products',
                                  value: '${data.products.length}',
                                  icon: Icons.inventory_2_outlined,
                                  onTap: widget.onProducts),
                              DashboardStatCard(
                                  title: 'COD Unsettled',
                                  value: '₹${cod.totalUnsettled.toStringAsFixed(0)}',
                                  icon: Icons.account_balance_wallet_outlined,
                                  accent: cod.totalUnsettled > 0
                                      ? AppColors.orange
                                      : AppColors.green,
                                  onTap: () => _showCodModal(cod)),
                            ]),
                        const SizedBox(height: 16),
                        const SectionTitle('Quick actions'),
                        _ActionCard(
                            icon: Icons.account_balance_wallet_outlined,
                            title: 'COD Cash Reconciliation',
                            subtitle:
                                '₹${cod.totalUnsettled.toStringAsFixed(2)} held by drivers · Tap to reconcile',
                            onTap: () => _showCodModal(cod)),
                        const SizedBox(height: 10),
                        _ActionCard(
                            icon: Icons.inventory_2_outlined,
                            title: 'Manage products',
                            subtitle:
                                '${data.products.length} products · $low low stock',
                            onTap: widget.onProducts),
                        const SizedBox(height: 10),
                        _ActionCard(
                            icon: Icons.receipt_long_outlined,
                            title: 'Manage orders',
                            subtitle: '$open orders need attention',
                            onTap: widget.onOrders),
                        const SizedBox(height: 10),
                        _ActionCard(
                            icon: Icons.people_alt_outlined,
                            title: 'Manage drivers',
                            subtitle:
                                'Create driver accounts and check availability',
                            onTap: widget.onDrivers),
                      ]));
            }),
      );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
      child: ListTile(
          leading: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                  color: AppColors.paleGreen, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.green)),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          onTap: onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6)));
}

class _AdminData {
  const _AdminData(this.orders, this.products, this.codReport);
  final List<OrderRecord> orders;
  final List<Product> products;
  final CodReconciliationReport codReport;
}
