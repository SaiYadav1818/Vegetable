import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_states.dart';
import '../auth/auth_api.dart';
import '../catalog/catalog_api.dart';
import '../catalog/catalog_models.dart';
import 'customer_cart.dart';

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage(
      {super.key,
      required this.client,
      required this.session,
      required this.onSignOut});
  final ApiClient client;
  final AuthSession session;
  final VoidCallback onSignOut;
  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  late final CatalogApi _api = CatalogApi(widget.client);
  late Future<_StoreCatalog> _catalog = _loadCatalog();
  final _cart = CustomerCart();
  final _search = TextEditingController();
  int _tab = 0;
  int? _selectedCategory;
  String _query = '';
  String _deliveryArea = 'Choose delivery area';

  @override
  void initState() {
    super.initState();
    _loadSavedArea();
  }

  Future<void> _loadSavedArea() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('freshbasket.delivery_area');
    if (mounted && saved != null && saved.isNotEmpty) {
      setState(() => _deliveryArea = saved);
    }
  }

  Future<_StoreCatalog> _loadCatalog() async {
    final values = await Future.wait<Object>([
      _api.getCategories(),
      _api.getProducts(size: 50),
    ]);
    return _StoreCatalog(
        values[0] as List<Category>, values[1] as List<Product>);
  }

  Future<void> _refresh() async {
    setState(() => _catalog = _loadCatalog());
    await _catalog;
  }

  Future<void> _chooseArea() async {
    final controller = TextEditingController(
        text: _deliveryArea == 'Choose delivery area' ? '' : _deliveryArea);
    final area = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 4, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Delivery location',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('Set your area so you can find nearby fresh picks.'),
              const SizedBox(height: 16),
              TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Area, neighborhood or pincode',
                      prefixIcon: Icon(Icons.location_on_outlined))),
              const SizedBox(height: 14),
              FilledButton(
                  onPressed: () {
                    final value = controller.text.trim();
                    if (value.isNotEmpty) Navigator.pop(context, value);
                  },
                  child: const Text('Save location')),
            ]),
      ),
    );
    controller.dispose();
    if (area == null) return;
    setState(() => _deliveryArea = area);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('freshbasket.delivery_area', area);
  }

  List<Product> _visibleProducts(_StoreCatalog catalog) {
    return catalog.products.where((product) {
      final matchesCategory =
          _selectedCategory == null || product.categoryId == _selectedCategory;
      final q = _query.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          product.name.toLowerCase().contains(q) ||
          product.categoryName.toLowerCase().contains(q);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  void _addToCart(Product product) {
    if (product.stock < 1) return;
    _cart.add(product);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${product.name} added to your basket'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 1),
      action: SnackBarAction(
          label: 'VIEW', onPressed: () => setState(() => _tab = 2)),
    ));
  }

  @override
  void dispose() {
    _cart.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: _tab == 0
            ? AppBar(
                title: InkWell(
                    onTap: _chooseArea,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('DELIVERING TO',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                          color: AppColors.muted,
                                          letterSpacing: 1)),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Flexible(
                                    child: Text(_deliveryArea,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.w700))),
                                const Icon(Icons.keyboard_arrow_down, size: 20)
                              ]),
                            ]))),
                actions: [
                  IconButton(
                      tooltip: 'Profile',
                      onPressed: () => setState(() => _tab = 4),
                      icon: const Icon(Icons.account_circle_outlined))
                ],
              )
            : AppBar(
                title: Text([
                'FreshBasket',
                'Categories',
                'Your basket',
                'My orders',
                'Profile'
              ][_tab])),
        body: FutureBuilder<_StoreCatalog>(
          future: _catalog,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingState(message: 'Finding fresh vegetables…');
            }
            if (snapshot.hasError) {
              return ErrorState(
                  message: _api.describeError(snapshot.error!),
                  onRetry: _refresh);
            }
            final catalog = snapshot.data!;
            switch (_tab) {
              case 0:
                return _home(catalog);
              case 1:
                return _categories(catalog);
              case 2:
                return _cartPage();
              case 3:
                return const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Your orders will show here',
                    message:
                        'After you place an order, you can follow its progress from this page.');
              default:
                return _profile();
            }
          },
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (index) => setState(() {
            _tab = index;
            if (index != 1) _selectedCategory = null;
          }),
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
          ],
        ),
      );

  Widget _cartIcon(bool selected) => Badge(
        isLabelVisible: _cart.itemCount > 0,
        label: Text(_cart.itemCount > 99 ? '99+' : '${_cart.itemCount}'),
        child: Icon(
            selected ? Icons.shopping_basket : Icons.shopping_basket_outlined),
      );

  Widget _home(_StoreCatalog catalog) {
    final products = _visibleProducts(catalog);
    return RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: TextField(
                    controller: _search,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                        hintText: 'Search vegetables',
                        prefixIcon: Icon(Icons.search),
                        suffixIcon: Icon(Icons.tune)),
                  ))),
          SliverToBoxAdapter(child: _heroBanner()),
          SliverToBoxAdapter(
              child: _sectionHeading('Shop by category',
                  action: 'See all', onAction: () => setState(() => _tab = 1))),
          SliverToBoxAdapter(
              child: SizedBox(
                  height: 108,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: catalog.categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => _CategoryBubble(
                        category: catalog.categories[index],
                        onTap: () => setState(() {
                              _selectedCategory = catalog.categories[index].id;
                              _tab = 1;
                            })),
                  ))),
          SliverToBoxAdapter(
              child: _sectionHeading(
                  _query.isEmpty ? 'Available now' : 'Search results',
                  action: _selectedCategory == null ? null : 'Clear filter',
                  onAction: () => setState(() => _selectedCategory = null))),
          if (products.isEmpty)
            const SliverToBoxAdapter(
                child: Padding(
                    padding: EdgeInsets.all(30),
                    child: EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No vegetables found',
                        message: 'Try another search or category.')))
          else
            _productGrid(products),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ]));
  }

  Widget _heroBanner() => Container(
        margin: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF1F6B32), Color(0xFF69A94D)]),
            borderRadius: BorderRadius.circular(24)),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(30)),
                    child: const Text('FRESH FROM LOCAL SHOPS',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .8))),
                const SizedBox(height: 12),
                const Text('Good food,\nright around you.',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        height: 1.12,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('Pick your fresh favorites today.',
                    style: TextStyle(color: Colors.white70)),
              ])),
          const SizedBox(width: 8),
          Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                  color: Colors.white24, shape: BoxShape.circle),
              child: const Icon(Icons.local_florist_rounded,
                  color: Colors.white, size: 50)),
        ]),
      );

  Widget _sectionHeading(String title,
          {String? action, VoidCallback? onAction}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 16, 12),
        child: Row(children: [
          Expanded(
              child:
                  Text(title, style: Theme.of(context).textTheme.titleLarge)),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action)),
        ]),
      );

  Widget _productGrid(List<Product> products) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverLayoutBuilder(builder: (context, constraints) {
          final width = constraints.crossAxisExtent;
          final count = width > 1000
              ? 4
              : width > 650
                  ? 3
                  : 2;
          return SliverGrid.builder(
            itemCount: products.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: count,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: width > 650 ? .76 : .66),
            itemBuilder: (context, index) => _ProductCard(
                product: products[index],
                imageBase: widget.client.dio.options.baseUrl,
                quantity: _cart.lines
                        .where((line) => line.product.id == products[index].id)
                        .firstOrNull
                        ?.quantity ??
                    0,
                onAdd: () => _addToCart(products[index]),
                onIncrement: () => _cart.increment(products[index].id),
                onDecrement: () => _cart.decrement(products[index].id)),
          );
        }),
      );

  Widget _categories(_StoreCatalog catalog) {
    final filtered = _visibleProducts(catalog);
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
        child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: TextField(
                controller: _search,
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                    hintText: 'Search vegetables or categories',
                    prefixIcon: Icon(Icons.search)))),
      ),
      SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid.builder(
            itemCount: catalog.categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.65),
            itemBuilder: (context, index) {
              final category = catalog.categories[index];
              final selected = _selectedCategory == category.id;
              return InkWell(
                  onTap: () => setState(
                      () => _selectedCategory = selected ? null : category.id),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: selected ? AppColors.paleGreen : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: selected
                                  ? AppColors.green
                                  : const Color(0xFFE9EEE8))),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(_categoryIcon(category.name),
                                color: AppColors.green, size: 28),
                            Text(category.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall),
                          ])));
            },
          )),
      SliverToBoxAdapter(
          child: _sectionHeading(_selectedCategory == null
              ? 'All vegetables'
              : catalog.categories
                  .firstWhere((c) => c.id == _selectedCategory)
                  .name)),
      if (filtered.isEmpty)
        const SliverToBoxAdapter(
            child: EmptyState(
                icon: Icons.eco_outlined,
                title: 'Nothing in this section yet',
                message: 'Check back soon for fresh stock.'))
      else
        _productGrid(filtered),
      const SliverToBoxAdapter(child: SizedBox(height: 20)),
    ]);
  }

  Widget _cartPage() {
    if (_cart.lines.isEmpty) {
      return const EmptyState(
          icon: Icons.shopping_basket_outlined,
          title: 'Your basket is waiting',
          message: 'Add something fresh from the home or categories tab.');
    }
    return Column(children: [
      Expanded(
          child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _cart.lines.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final line = _cart.lines[index];
                return Card(
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          _ProductImage(
                              url: _resolvedImage(line.product.imageUrl),
                              size: 72),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(line.product.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                Text(
                                    'Rs. ${line.product.price} / ${line.product.unit}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                                const SizedBox(height: 8),
                                _QuantityControl(
                                    quantity: line.quantity,
                                    onIncrement: () =>
                                        _cart.increment(line.product.id),
                                    onDecrement: () =>
                                        _cart.decrement(line.product.id)),
                              ])),
                          Text('Rs. ${line.lineTotal.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.titleSmall),
                        ])));
              })),
      SafeArea(
          top: false,
          child: Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              color: Colors.white,
              child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Subtotal'),
                      Text('Rs. ${_cart.subtotal.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleLarge)
                    ])),
                FilledButton(onPressed: null, child: const Text('Checkout'))
              ]))),
    ]);
  }

  Widget _profile() => ListView(padding: const EdgeInsets.all(18), children: [
        Card(
            child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  const CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.paleGreen,
                      child:
                          Icon(Icons.person, color: AppColors.green, size: 30)),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(widget.session.fullName,
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(widget.session.email,
                            style: Theme.of(context).textTheme.bodySmall),
                      ])),
                ]))),
        const SizedBox(height: 12),
        Card(
            child: ListTile(
                leading: const Icon(Icons.location_on_outlined,
                    color: AppColors.green),
                title: const Text('Delivery area'),
                subtitle: Text(_deliveryArea),
                trailing: const Icon(Icons.chevron_right),
                onTap: _chooseArea)),
        const SizedBox(height: 12),
        Card(
            child: ListTile(
                leading: const Icon(Icons.support_agent_outlined,
                    color: AppColors.green),
                title: const Text('Contact support'),
                subtitle: const Text('Need help with FreshBasket?'))),
        const SizedBox(height: 24),
        OutlinedButton.icon(
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign out')),
      ]);

  String? _resolvedImage(String? value) {
    if (value == null || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    return uri?.hasScheme == true
        ? value
        : '${widget.client.dio.options.baseUrl}$value';
  }
}

class _StoreCatalog {
  const _StoreCatalog(this.categories, this.products);
  final List<Category> categories;
  final List<Product> products;
}

class _CategoryBubble extends StatelessWidget {
  const _CategoryBubble({required this.category, required this.onTap});
  final Category category;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
          width: 82,
          child: Column(children: [
            Container(
                width: 66,
                height: 66,
                decoration: const BoxDecoration(
                    color: AppColors.paleGreen, shape: BoxShape.circle),
                child: Icon(_categoryIcon(category.name),
                    color: AppColors.green, size: 30)),
            const SizedBox(height: 7),
            Text(category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall)
          ])));
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

class _ProductCard extends StatelessWidget {
  const _ProductCard(
      {required this.product,
      required this.imageBase,
      required this.quantity,
      required this.onAdd,
      required this.onIncrement,
      required this.onDecrement});
  final Product product;
  final String imageBase;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  @override
  Widget build(BuildContext context) {
    final imageUrl = product.imageUrl == null
        ? null
        : (Uri.tryParse(product.imageUrl!)?.hasScheme == true
            ? product.imageUrl!
            : '$imageBase${product.imageUrl}');
    final outOfStock = product.stock < 1;
    return Card(
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Stack(fit: StackFit.expand, children: [
            _ProductImage(url: imageUrl, size: double.infinity),
            Positioned(
                left: 8,
                top: 8,
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .92),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(
                        outOfStock
                            ? 'Out of stock'
                            : '${product.stock} ${product.unit} left',
                        style: TextStyle(
                            fontSize: 10,
                            color: outOfStock
                                ? Colors.red.shade700
                                : AppColors.green,
                            fontWeight: FontWeight.w700)))),
          ])),
          Padding(
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall),
                    Text('Rs. ${product.price} / ${product.unit}',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 8),
                    if (quantity == 0)
                      SizedBox(
                          width: double.infinity,
                          height: 36,
                          child: OutlinedButton.icon(
                              onPressed: outOfStock ? null : onAdd,
                              icon: const Icon(Icons.add, size: 17),
                              label: Text(outOfStock ? 'Unavailable' : 'Add')))
                    else
                      Align(
                          alignment: Alignment.centerRight,
                          child: _QuantityControl(
                              quantity: quantity,
                              onIncrement: onIncrement,
                              onDecrement: onDecrement)),
                  ])),
        ]));
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url, required this.size});
  final String? url;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: size,
      height: size,
      child: url == null
          ? const ColoredBox(
              color: AppColors.paleGreen,
              child: Center(
                  child: Icon(Icons.eco_rounded,
                      color: AppColors.green, size: 42)))
          : CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              placeholder: (_, __) => const ColoredBox(
                  color: AppColors.paleGreen,
                  child:
                      Center(child: CircularProgressIndicator(strokeWidth: 2))),
              errorWidget: (_, __, ___) => const ColoredBox(
                  color: AppColors.paleGreen,
                  child: Center(
                      child: Icon(Icons.eco_rounded,
                          color: AppColors.green, size: 42)))));
}

class _QuantityControl extends StatelessWidget {
  const _QuantityControl(
      {required this.quantity,
      required this.onIncrement,
      required this.onDecrement});
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          color: AppColors.paleGreen, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onDecrement,
            icon: const Icon(Icons.remove, size: 18)),
        Text('$quantity', style: const TextStyle(fontWeight: FontWeight.w700)),
        IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onIncrement,
            icon: const Icon(Icons.add, size: 18)),
      ]));
}
