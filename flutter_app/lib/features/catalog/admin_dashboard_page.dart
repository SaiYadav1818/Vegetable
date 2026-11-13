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
      CatalogApi(widget.client).getProducts(admin: true, size: 100)
    ]);
    return _AdminData(
        result[0] as List<OrderRecord>, result[1] as List<Product>);
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
              final today = data.orders
                  .where((o) =>
                      o.createdAt.year == now.year &&
                      o.createdAt.month == now.month &&
                      o.createdAt.day == now.day)
                  .length;
              final pending =
                  data.orders.where((o) => o.status == 'PLACED').length;
              final open = data.orders
                  .where((o) => [
                        'PLACED',
                        'ACCEPTED',
                        'PREPARING',
                        'READY_FOR_PICKUP'
                      ].contains(o.status))
                  .length;
              final deliveries = data.orders
                  .where((o) =>
                      o.status == 'DRIVER_ASSIGNED' ||
                      o.status == 'OUT_FOR_DELIVERY')
                  .length;
              final delivered =
                  data.orders.where((o) => o.status == 'DELIVERED').toList();
              final revenue = delivered
                  .where((o) => o.paymentStatus == 'PAID')
                  .fold<num>(0, (sum, o) => sum + o.totalAmount);
              final low =
                  data.products.where((p) => p.stock <= p.minimumStock).length;
              return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                      children: [
                        Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                                color: AppColors.paleGreen,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.lg)),
                            child: Row(children: [
                              Container(
                                  width: 46,
                                  height: 46,
                                  decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.eco_rounded,
                                      color: AppColors.green)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text('Your store, at a glance',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w800)),
                                    Text(
                                        'Latest ${data.orders.length} orders and products in view',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall)
                                  ]))
                            ])),
                        const SectionTitle('Today at FreshBasket'),
                        GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount:
                                MediaQuery.sizeOf(context).width > 800 ? 3 : 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.42,
                            children: [
                              DashboardStatCard(
                                  title: 'Orders today',
                                  value: '$today',
                                  icon: Icons.today_outlined,
                                  onTap: widget.onOrders),
                              DashboardStatCard(
                                  title: 'Pending orders',
                                  value: '$pending',
                                  icon: Icons.pending_actions_outlined,
                                  accent: AppColors.orange,
                                  onTap: widget.onOrders),
                              DashboardStatCard(
                                  title: 'On the way',
                                  value: '$deliveries',
                                  icon: Icons.delivery_dining,
                                  accent: AppColors.orange,
                                  onTap: widget.onOrders),
                              DashboardStatCard(
                                  title: 'Completed',
                                  value: '${delivered.length}',
                                  icon: Icons.task_alt_rounded,
                                  onTap: widget.onOrders),
                              DashboardStatCard(
                                  title: 'Paid revenue',
                                  value: '₹${revenue.toStringAsFixed(0)}',
                                  icon: Icons.currency_rupee_rounded,
                                  onTap: widget.onOrders),
                              DashboardStatCard(
                                  title: 'Products',
                                  value: '${data.products.length}',
                                  icon: Icons.inventory_2_outlined,
                                  onTap: widget.onProducts),
                              DashboardStatCard(
                                  title: 'Low stock',
                                  value: '$low',
                                  icon: Icons.inventory_2_outlined,
                                  accent: low > 0
                                      ? AppColors.orange
                                      : AppColors.green,
                                  onTap: widget.onProducts),
                            ]),
                        Padding(
                            padding: const EdgeInsets.fromLTRB(4, 10, 4, 12),
                            child: Text(
                                'Order and revenue figures use the latest ${data.orders.length} orders returned by the API.',
                                style: const TextStyle(
                                    color: AppColors.muted, fontSize: 12))),
                        const SectionTitle('Quick actions'),
                        _ActionCard(
                            icon: Icons.inventory_2_outlined,
                            title: 'Manage products',
                            subtitle:
                                '${data.products.length} products loaded · $low low stock',
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
  const _AdminData(this.orders, this.products);
  final List<OrderRecord> orders;
  final List<Product> products;
}
