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
      OrdersApi(widget.client).getAnalyticsOverview().catchError((_) => const AnalyticsOverview(
        revenue: RevenueMetrics(totalRevenue: 0, todayRevenue: 0, thisWeekRevenue: 0, averageOrderValue: 0),
        orders: OrderMetrics(totalOrders: 0, completedOrders: 0, activeOrders: 0, cancelledOrders: 0, failedOrders: 0),
        topSellingVegetables: [],
        driverFleet: DriverFleetMetric(totalDrivers: 0, onlineDrivers: 0, availableDrivers: 0, deliveriesCompleted: 0, codCollected: 0, codPendingReconciliation: 0),
      )),
      OrdersApi(widget.client).getShopSettings().catchError((_) => const ShopSettings(
        id: 1, shopName: 'FreshBasket Neighborhood Mart', contactPhone: '+91 98765 43210',
        shopAddress: '12/4 Green Avenue, Sector 5, Bangalore', openingTime: '06:30', closingTime: '21:30',
        openToday: true, minOrderValue: 100, deliveryCharge: 30, freeDeliveryThreshold: 500,
        announcementBanner: 'Fresh morning farm arrivals available daily from 6:30 AM!',
      )),
    ]);
    return _AdminData(
        result[0] as List<OrderRecord>,
        result[1] as List<Product>,
        result[2] as CodReconciliationReport,
        result[3] as AnalyticsOverview,
        result[4] as ShopSettings);
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

  void _showShopSettingsModal(ShopSettings settings) {
    final nameCtrl = TextEditingController(text: settings.shopName);
    final phoneCtrl = TextEditingController(text: settings.contactPhone);
    final addrCtrl = TextEditingController(text: settings.shopAddress);
    final openTimeCtrl = TextEditingController(text: settings.openingTime);
    final closeTimeCtrl = TextEditingController(text: settings.closingTime);
    final minOrderCtrl = TextEditingController(text: settings.minOrderValue.toString());
    final feeCtrl = TextEditingController(text: settings.deliveryCharge.toString());
    final freeThresholdCtrl = TextEditingController(text: settings.freeDeliveryThreshold.toString());
    final bannerCtrl = TextEditingController(text: settings.announcementBanner ?? '');
    bool isOpen = settings.openToday;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(ctx).bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Shop Settings & Operating Rules',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    Switch(
                      value: isOpen,
                      onChanged: (val) => setModalState(() => isOpen = val),
                    ),
                  ],
                ),
                Text(
                  isOpen ? 'Store is currently OPEN for orders' : 'Store is CLOSED today',
                  style: TextStyle(
                    color: isOpen ? AppColors.green : AppColors.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Shop Name')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Contact Phone'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Shop Address'))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: openTimeCtrl, decoration: const InputDecoration(labelText: 'Opening Time (e.g. 06:30)'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: closeTimeCtrl, decoration: const InputDecoration(labelText: 'Closing Time (e.g. 21:30)'))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: minOrderCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Min Order (₹)'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: feeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Delivery Fee (₹)'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: freeThresholdCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Free Delivery (₹)'))),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(controller: bannerCtrl, decoration: const InputDecoration(labelText: 'Store Notice Banner')),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    try {
                      final updated = ShopSettings(
                        id: settings.id,
                        shopName: nameCtrl.text.trim(),
                        contactPhone: phoneCtrl.text.trim(),
                        shopAddress: addrCtrl.text.trim(),
                        openingTime: openTimeCtrl.text.trim(),
                        closingTime: closeTimeCtrl.text.trim(),
                        openToday: isOpen,
                        minOrderValue: num.tryParse(minOrderCtrl.text.trim()) ?? 100,
                        deliveryCharge: num.tryParse(feeCtrl.text.trim()) ?? 30,
                        freeDeliveryThreshold: num.tryParse(freeThresholdCtrl.text.trim()) ?? 500,
                        announcementBanner: bannerCtrl.text.trim(),
                      );
                      await OrdersApi(widget.client).updateShopSettings(updated);
                      if (!mounted) return;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shop settings updated successfully!')));
                      await _refresh();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(OrdersApi(widget.client).describeError(e))));
                    }
                  },
                  child: const Text('Save Shop Settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              'Track cash collected by delivery drivers and reconcile against register.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.paleGreen,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total collected',
                            style: Theme.of(ctx).textTheme.bodySmall),
                        Text('₹${report.totalCollected.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Unsettled with shop',
                            style: Theme.of(ctx).textTheme.bodySmall),
                        Text('₹${report.totalUnsettled.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Colors.deepOrange)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Drivers holding cash',
                style: Theme.of(ctx)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (report.drivers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: Text('No active driver balances at this time.')),
              )
            else
              ...report.drivers.map((d) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(d.driverName,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          '${d.driverPhone} · ${d.unsettledCount} pending payments'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('₹${d.unsettledAmount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink)),
                          const SizedBox(width: 8),
                          if (d.unsettledAmount > 0)
                            FilledButton.tonal(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _settleDriver(d.driverUserId, d.driverName);
                              },
                              child: const Text('Settle'),
                            ),
                        ],
                      ),
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
          title: Text('Store Manager · ${widget.adminName}'),
          actions: [
            IconButton(
                onPressed: widget.onSignOut,
                icon: const Icon(Icons.logout),
                tooltip: 'Sign out')
          ],
        ),
        body: FutureBuilder<_AdminData>(
            future: _data,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingState(
                    message: 'Loading store overview...');
              }
              if (snapshot.hasError) {
                return ErrorState(
                    message: OrdersApi(widget.client)
                        .describeError(snapshot.error!),
                    onRetry: _refresh);
              }
              final data = snapshot.data!;
              final open = data.orders
                  .where((o) => [
                        'PLACED',
                        'ACCEPTED',
                        'PREPARING',
                        'READY_FOR_PICKUP'
                      ].contains(o.status))
                  .length;
              final low = data.products
                  .where((p) => p.stock <= p.minimumStock)
                  .length;
              final cod = data.codReport;
              final analytics = data.analytics;
              final shop = data.shopSettings;

              return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(shop.shopName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w800)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: shop.openToday
                                              ? AppColors.paleGreen
                                              : const Color(0xFFFFEBEE),
                                          borderRadius:
                                              BorderRadius.circular(AppRadius.sm),
                                        ),
                                        child: Text(
                                          shop.openToday ? 'OPEN' : 'CLOSED',
                                          style: TextStyle(
                                            color: shop.openToday
                                                ? AppColors.darkGreen
                                                : AppColors.error,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                      'Hours: ${shop.openingTime} - ${shop.closingTime} · Min order ₹${shop.minOrderValue.toStringAsFixed(0)} · Free delivery above ₹${shop.freeDeliveryThreshold.toStringAsFixed(0)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                  const SizedBox(height: 12),
                                  Wrap(spacing: 8, runSpacing: 8, children: [
                                    MetricChip(
                                        label: '$open active orders',
                                        accent: open > 0
                                            ? AppColors.orange
                                            : AppColors.green),
                                    MetricChip(
                                        label: '$low low stock alerts',
                                        accent: low > 0
                                            ? AppColors.orange
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
                        const SectionTitle('Business Analytics'),
                        GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.45,
                            children: [
                              DashboardStatCard(
                                  title: "Today's Revenue",
                                  value: '₹${analytics.revenue.todayRevenue.toStringAsFixed(0)}',
                                  icon: Icons.currency_rupee_rounded,
                                  accent: AppColors.darkGreen,
                                  onTap: widget.onOrders),
                              DashboardStatCard(
                                  title: 'Average Order (AOV)',
                                  value: '₹${analytics.revenue.averageOrderValue.toStringAsFixed(0)}',
                                  icon: Icons.analytics_outlined,
                                  onTap: widget.onOrders),
                              DashboardStatCard(
                                  title: 'Delivered Orders',
                                  value: '${analytics.orders.completedOrders}',
                                  icon: Icons.check_circle_outline,
                                  accent: AppColors.green,
                                  onTap: widget.onOrders),
                              DashboardStatCard(
                                  title: 'Active Drivers',
                                  value: '${analytics.driverFleet.onlineDrivers}/${analytics.driverFleet.totalDrivers}',
                                  icon: Icons.delivery_dining_outlined,
                                  onTap: widget.onDrivers),
                            ]),
                        if (analytics.topSellingVegetables.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const SectionTitle('Top Selling Vegetables'),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              child: Column(
                                children: analytics.topSellingVegetables.map((item) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.eco_outlined, color: AppColors.green, size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(item.productName,
                                            style: const TextStyle(fontWeight: FontWeight.w700)),
                                      ),
                                      Text('${item.quantitySold.toStringAsFixed(1)} sold',
                                          style: Theme.of(context).textTheme.bodySmall),
                                      const SizedBox(width: 12),
                                      Text('₹${item.totalRevenue.toStringAsFixed(0)}',
                                          style: const TextStyle(fontWeight: FontWeight.w800)),
                                    ],
                                  ),
                                )).toList(),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        const SectionTitle('Quick Actions'),
                        _ActionCard(
                            icon: Icons.store_mall_directory_outlined,
                            title: 'Shop Settings & Operating Rules',
                            subtitle:
                                'Toggle store open/closed, change timings and delivery rules',
                            onTap: () => _showShopSettingsModal(shop)),
                        const SizedBox(height: 10),
                        _ActionCard(
                            icon: Icons.account_balance_wallet_outlined,
                            title: 'COD Cash Reconciliation',
                            subtitle:
                                '₹${cod.totalUnsettled.toStringAsFixed(2)} held by drivers · Tap to reconcile',
                            onTap: () => _showCodModal(cod)),
                        const SizedBox(height: 10),
                        _ActionCard(
                            icon: Icons.inventory_2_outlined,
                            title: 'Manage Products',
                            subtitle:
                                '${data.products.length} products · $low low stock',
                            onTap: widget.onProducts),
                        const SizedBox(height: 10),
                        _ActionCard(
                            icon: Icons.receipt_long_outlined,
                            title: 'Manage Orders',
                            subtitle: '$open orders need attention',
                            onTap: widget.onOrders),
                        const SizedBox(height: 10),
                        _ActionCard(
                            icon: Icons.people_alt_outlined,
                            title: 'Manage Drivers',
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
  const _AdminData(this.orders, this.products, this.codReport, this.analytics, this.shopSettings);
  final List<OrderRecord> orders;
  final List<Product> products;
  final CodReconciliationReport codReport;
  final AnalyticsOverview analytics;
  final ShopSettings shopSettings;
}
