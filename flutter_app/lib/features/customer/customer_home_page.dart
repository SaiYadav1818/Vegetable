import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/design_components.dart';
import '../auth/auth_api.dart';
import '../catalog/catalog_api.dart';
import '../catalog/catalog_models.dart';
import '../orders/customer_orders_page.dart';
import '../orders/orders_api.dart';
import 'customer_cart.dart';
import 'product_details_page.dart';

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage(
      {super.key,
      required this.client,
      required this.session,
      required this.onSignOut,
      required this.onCheckout});
  final ApiClient client;
  final AuthSession session;
  final VoidCallback onSignOut;
  final Future<void> Function() onCheckout;
  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  late final CatalogApi _catalogApi = CatalogApi(widget.client);
  late final OrdersApi _ordersApi = OrdersApi(widget.client);
  late Future<_CatalogData> _catalog = _loadCatalog();
  late final CustomerCart _cart = CustomerCart(_ordersApi);
  final _search = TextEditingController();
  int _tab = 0;
  int? _selectedCategory;
  String _query = '';
  String _deliveryArea = 'Choose delivery area';

  @override
  void initState() {
    super.initState();
    _loadSavedArea();
    _cart.load().then((_) {
      if (mounted) setState(() {});
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _cart.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<_CatalogData> _loadCatalog() async {
    final result = await Future.wait<Object>(
        [_catalogApi.getCategories(), _catalogApi.getProducts(size: 50)]);
    return _CatalogData(
        result[0] as List<Category>, result[1] as List<Product>);
  }

  Future<void> _refresh() async {
    setState(() => _catalog = _loadCatalog());
    await Future.wait([_catalog, _cart.refresh()]);
  }

  Future<void> _loadSavedArea() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('freshbasket.delivery_area');
    if (mounted && value != null && value.isNotEmpty) {
      setState(() => _deliveryArea = value);
    }
  }

  Future<void> _chooseArea() async {
    final controller = TextEditingController(
        text: _deliveryArea == 'Choose delivery area' ? '' : _deliveryArea);
    final value = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Delivery location',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text('Choose the area for your fresh delivery.',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 14),
                    TextField(
                        controller: controller,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                            labelText: 'Area, neighbourhood or pincode',
                            prefixIcon: Icon(Icons.location_on_outlined))),
                    const SizedBox(height: 14),
                    FilledButton(
                        onPressed: () {
                          final input = controller.text.trim();
                          if (input.isNotEmpty) Navigator.pop(context, input);
                        },
                        child: const Text('Save location')),
                  ]),
            ));
    controller.dispose();
    if (value == null) return;
    setState(() => _deliveryArea = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('freshbasket.delivery_area', value);
  }

  List<Product> _visibleProducts(_CatalogData data) =>
      data.products.where((product) {
        final matchesCategory = _selectedCategory == null ||
            product.categoryId == _selectedCategory;
        final query = _query.trim().toLowerCase();
        return matchesCategory &&
            (query.isEmpty ||
                product.name.toLowerCase().contains(query) ||
                product.categoryName.toLowerCase().contains(query));
      }).toList();

  Future<void> _addToCart(Product product) async {
    try {
      await _cart.add(product);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${product.name} added to your basket'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
              label: 'VIEW CART', onPressed: () => setState(() => _tab = 2))));
    } catch (error) {
      _showError(_ordersApi.describeError(error));
    }
  }

  Future<num> _addForDetails(Product product) async {
    try {
      await _cart.add(product);
      if (mounted) setState(() {});
    } catch (error) {
      _showError(_ordersApi.describeError(error));
    }
    return _cart.quantityFor(product.id);
  }

  Future<num> _changeQuantity(Product product, {required bool increase}) async {
    try {
      final line =
          _cart.lines.where((item) => item.productId == product.id).firstOrNull;
      if (line == null && increase) {
        await _cart.add(product);
      } else if (line != null && increase) {
        await _cart.increment(line);
      } else if (line != null) {
        await _cart.decrement(line);
      }
      if (mounted) setState(() {});
    } catch (error) {
      _showError(_ordersApi.describeError(error));
    }
    return _cart.quantityFor(product.id);
  }

  Future<void> _cartAction(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) setState(() {});
    } catch (error) {
      _showError(_ordersApi.describeError(error));
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _openProduct(Product product) =>
      Navigator.of(context).push<void>(MaterialPageRoute(
          builder: (_) => ProductDetailsPage(
                product: product,
                imageBase: widget.client.dio.options.baseUrl,
                quantity: _cart.quantityFor(product.id),
                onAdd: () => _addForDetails(product),
                onIncrement: () => _changeQuantity(product, increase: true),
                onDecrement: () => _changeQuantity(product, increase: false),
              )));
  Future<void> _checkout() async {
    await widget.onCheckout();
    if (!mounted) return;
    await _cart.refresh();
    setState(() => _tab = 0);
  }

  void _changeTab(int index) => setState(() {
        _tab = index;
        if (index != 1) _selectedCategory = null;
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: _tab == 0
            ? FreshBasketAppBar(
                title: Row(children: [
                  Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                          color: AppColors.paleGreen, shape: BoxShape.circle),
                      child: const Icon(Icons.eco_rounded,
                          color: AppColors.green)),
                  const SizedBox(width: 9),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                        Text('FreshBasket',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        InkWell(
                            onTap: _chooseArea,
                            child: Row(children: [
                              const Icon(Icons.location_on_rounded,
                                  color: AppColors.green, size: 14),
                              const SizedBox(width: 3),
                              Flexible(
                                  child: Text(_deliveryArea,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(color: AppColors.muted))),
                              const Icon(Icons.keyboard_arrow_down,
                                  size: 17, color: AppColors.muted)
                            ])),
                      ])),
                ]),
                actions: [
                  IconButton(
                      tooltip: 'Notifications',
                      onPressed: () => ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(
                              content: Text("You're all caught up"))),
                      icon: const Icon(Icons.notifications_none_rounded)),
                  IconButton(
                      tooltip: 'Profile',
                      onPressed: () => _changeTab(4),
                      icon: const Icon(Icons.account_circle_outlined))
                ],
              )
            : FreshBasketAppBar(
                title: Text([
                'FreshBasket',
                'Categories',
                'Your basket',
                'My orders',
                'Profile'
              ][_tab])),
        body: switch (_tab) {
          2 => _cartPage(),
          3 => CustomerOrdersPage(client: widget.client, embedded: true),
          4 => _profile(),
          _ => _catalogBody(),
        },
        bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: _changeTab,
            destinations: [
              const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home'),
              const NavigationDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view_rounded),
                  label: 'Categories'),
              NavigationDestination(
                  icon: _cartIcon(false),
                  selectedIcon: _cartIcon(true),
                  label: 'Cart'),
              const NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'Orders'),
              const NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile'),
            ]),
      );

  Widget _catalogBody() => FutureBuilder<_CatalogData>(
      future: _catalog,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingState(message: 'Finding fresh vegetables...');
        }
        if (snapshot.hasError) {
          return ErrorState(
              message: _catalogApi.describeError(snapshot.error!),
              onRetry: _refresh);
        }
        final data = snapshot.data!;
        return _tab == 1 ? _categories(data) : _home(data);
      });

  Widget _cartIcon(bool selected) => Badge(
      isLabelVisible: _cart.itemCount > 0,
      label: Text(_cart.itemCount > 99 ? '99+' : '${_cart.itemCount}'),
      child: Icon(
          selected ? Icons.shopping_basket : Icons.shopping_basket_outlined));

  Widget _home(_CatalogData data) {
    final products = _visibleProducts(data);
    final suggestions =
        _query.trim().isEmpty ? <Product>[] : products.take(4).toList();
    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                child: AppSearchField(
                    controller: _search,
                    onChanged: (value) => setState(() => _query = value)))),
        if (suggestions.isNotEmpty)
          SliverToBoxAdapter(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 18, 0),
                  child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: suggestions
                          .map((product) => ActionChip(
                              avatar: const Icon(Icons.search, size: 16),
                              label: Text(product.name),
                              onPressed: () => _openProduct(product)))
                          .toList()))),
        SliverToBoxAdapter(child: _promoBanner()),
        SliverToBoxAdapter(
            child: SectionTitle('Shop by category',
                actionLabel: 'See all', onAction: () => _changeTab(1))),
        SliverToBoxAdapter(
            child: SizedBox(
                height: 104,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  scrollDirection: Axis.horizontal,
                  itemCount: data.categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final category = data.categories[index];
                    return CategoryCard(
                        title: category.name,
                        icon: _categoryIcon(category.name),
                        compact: true,
                        onTap: () => setState(() {
                              _selectedCategory = category.id;
                              _tab = 1;
                            }));
                  },
                ))),
        SliverToBoxAdapter(
            child: SectionTitle(
                _query.isEmpty ? 'Fresh picks' : 'Search results',
                actionLabel: _selectedCategory == null ? null : 'Clear filter',
                onAction: () => setState(() => _selectedCategory = null))),
        if (products.isEmpty)
          const SliverToBoxAdapter(
              child: Padding(
                  padding: EdgeInsets.all(26),
                  child: EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No vegetables found',
                      message: 'Try another name or browse the categories.')))
        else
          _productGrid(products),
        const SliverToBoxAdapter(child: SizedBox(height: 26)),
      ]),
    );
  }

  Widget _promoBanner() => Container(
        margin: const EdgeInsets.fromLTRB(18, 18, 18, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: AppColors.paleGreen,
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.pill)),
                    child: Text('FRESH FROM LOCAL SHOPS',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.darkGreen,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .4))),
                const SizedBox(height: 12),
                Text('Good food starts\nwith fresh picks.',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 22,
                        height: 1.15,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Browse vegetables for today.',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                TextButton.icon(
                    onPressed: () => _changeTab(1),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('Shop vegetables')),
              ])),
          const SizedBox(width: 8),
          Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.local_florist_rounded,
                  color: AppColors.green, size: 48)),
        ]),
      );

  Widget _productGrid(List<Product> products) => SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverLayoutBuilder(builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final columns = width > 1000
            ? 4
            : width > 650
                ? 3
                : 2;
        return SliverGrid.builder(
            itemCount: products.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: width > 650 ? .78 : .68),
            itemBuilder: (context, index) {
              final product = products[index];
              final image = _imageUrl(product.imageUrl);
              return VegetableProductCard(
                  product: product,
                  imageUrl: image,
                  quantity: _cart.quantityFor(product.id),
                  onTap: () => _openProduct(product),
                  onAdd: () => _addToCart(product),
                  onIncrement: () => _cartAction(() =>
                      _changeQuantity(product, increase: true).then((_) {})),
                  onDecrement: () => _cartAction(() =>
                      _changeQuantity(product, increase: false).then((_) {})));
            });
      }));

  Widget _categories(_CatalogData data) {
    final products = _visibleProducts(data);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
                child: AppSearchField(
                    controller: _search,
                    hint: 'Search vegetables or categories',
                    onChanged: (value) => setState(() => _query = value)))),
        SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid.builder(
              itemCount: data.categories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.75),
              itemBuilder: (context, index) {
                final category = data.categories[index];
                return CategoryCard(
                    title: category.name,
                    icon: _categoryIcon(category.name),
                    selected: _selectedCategory == category.id,
                    onTap: () => setState(() => _selectedCategory =
                        _selectedCategory == category.id ? null : category.id));
              },
            )),
        SliverToBoxAdapter(
            child: SectionTitle(_selectedCategory == null
                ? 'All vegetables'
                : data.categories
                    .firstWhere((item) => item.id == _selectedCategory)
                    .name)),
        if (products.isEmpty)
          const SliverToBoxAdapter(
              child: EmptyState(
                  icon: Icons.eco_outlined,
                  title: 'Nothing here yet',
                  message: 'Try a different category or search term.'))
        else
          _productGrid(products),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ]),
    );
  }

  Widget _cartPage() {
    if (_cart.loading) {
      return const LoadingState(message: 'Loading your basket...');
    }
    if (_cart.error != null && _cart.lines.isEmpty) {
      return ErrorState(
          message:
              'Could not load your basket. Check your connection and retry.',
          onRetry: () => _cartAction(_cart.refresh));
    }
    if (_cart.lines.isEmpty) {
      return EmptyState(
          icon: Icons.shopping_basket_outlined,
          title: 'Your basket is waiting',
          message: 'Add something fresh from Home or Categories.',
          actionLabel: 'Browse vegetables',
          onAction: () => _changeTab(0));
    }
    return Column(children: [
      Expanded(
          child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              itemCount: _cart.lines.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final line = _cart.lines[index];
                return Card(
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          SizedBox(
                              width: 76,
                              height: 76,
                              child: ProductImageView(
                                  url: _imageUrl(line.imageUrl),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(line.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                PriceText(
                                    amount: line.price,
                                    unit: line.unit.toLowerCase()),
                                const SizedBox(height: 8),
                                QuantitySelector(
                                    quantity: line.quantity,
                                    compact: true,
                                    onIncrement: () => _cartAction(
                                        () => _cart.increment(line)),
                                    onDecrement: () => _cartAction(
                                        () => _cart.decrement(line)))
                              ])),
                          const SizedBox(width: 6),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                PriceText(
                                    amount: line.lineTotal, emphasized: true),
                                IconButton(
                                    tooltip: 'Remove ${line.name}',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () =>
                                        _cartAction(() => _cart.remove(line)),
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: AppColors.muted,
                                        size: 20))
                              ]),
                        ])));
              })),
      SafeArea(
          top: false,
          child: Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.line))),
              child: Column(children: [
                Row(children: [
                  Text('Subtotal',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  PriceText(
                      amount: _cart.subtotal,
                      emphasized: true,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.darkGreen,
                          fontWeight: FontWeight.w800))
                ]),
                const SizedBox(height: 4),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Delivery charge is confirmed at checkout.',
                        style: Theme.of(context).textTheme.bodySmall)),
                const SizedBox(height: 12),
                SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                        onPressed: _checkout,
                        child: const Text('Continue to checkout'))),
              ]))),
    ]);
  }

  String? _imageUrl(String? value) {
    if (value == null || value.isEmpty) return null;
    return Uri.tryParse(value)?.hasScheme == true
        ? value
        : '${widget.client.dio.options.baseUrl}$value';
  }

  Widget _profile() => ListView(padding: const EdgeInsets.all(18), children: [
        Card(
            child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  const CircleAvatar(
                      radius: 27,
                      backgroundColor: AppColors.paleGreen,
                      child:
                          Icon(Icons.person, color: AppColors.green, size: 28)),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(widget.session.fullName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        Text(widget.session.email,
                            style: Theme.of(context).textTheme.bodySmall)
                      ]))
                ]))),
        const SizedBox(height: 12),
        Card(
            child: ListTile(
                leading: const Icon(Icons.receipt_long_outlined,
                    color: AppColors.green),
                title: const Text('My orders'),
                subtitle: const Text('Track deliveries and view receipts'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _changeTab(3))),
        const SizedBox(height: 10),
        Card(
            child: ListTile(
                leading: const Icon(Icons.location_on_outlined,
                    color: AppColors.green),
                title: const Text('Delivery area'),
                subtitle: Text(_deliveryArea),
                trailing: const Icon(Icons.chevron_right),
                onTap: _chooseArea)),
        const SizedBox(height: 10),
        Card(
            child: const ListTile(
                leading:
                    Icon(Icons.support_agent_outlined, color: AppColors.green),
                title: Text('Contact support'),
                subtitle: Text('Need help with FreshBasket?'))),
        const SizedBox(height: 24),
        OutlinedButton.icon(
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign out')),
      ]);
}

class _CatalogData {
  const _CatalogData(this.categories, this.products);
  final List<Category> categories;
  final List<Product> products;
}

IconData _categoryIcon(String name) {
  final value = name.toLowerCase();
  if (value.contains('leaf')) return Icons.eco_outlined;
  if (value.contains('root')) return Icons.grass_outlined;
  if (value.contains('fruit')) return Icons.apple;
  if (value.contains('season')) return Icons.wb_sunny_outlined;
  if (value.contains('fresh')) return Icons.local_florist_outlined;
  return Icons.spa_outlined;
}
