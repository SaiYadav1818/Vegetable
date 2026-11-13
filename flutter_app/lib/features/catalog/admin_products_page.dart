import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'catalog_api.dart';
import 'catalog_models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/design_components.dart';
import 'admin_categories_page.dart';
import 'product_editor_dialog.dart';

class AdminProductsPage extends StatefulWidget {
  const AdminProductsPage({
    super.key,
    required this.client,
    required this.adminName,
    this.onSignOut,
    this.onOrders,
    this.onDashboard,
  });
  final ApiClient client;
  final String adminName;
  final VoidCallback? onSignOut;
  final VoidCallback? onOrders;
  final VoidCallback? onDashboard;
  @override
  State<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends State<AdminProductsPage> {
  late final CatalogApi _api = CatalogApi(widget.client);
  late Future<List<Product>> _products = _api.getProducts(admin: true);
  late final Future<List<Category>> _categories = _api.getCategories();
  String _query = '';
  int? _categoryId;
  Future<void> _reload() async {
    setState(() => _products = _api.getProducts(admin: true));
    await _products;
  }

  Future<void> _adjust(Product product) async {
    final delta = TextEditingController();
    final note = TextEditingController();
    final result = await showDialog<(num, String)?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Adjust ${product.name} stock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current stock: ${product.stock} ${product.unit}'),
            TextField(
              controller: delta,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Change (+ receive, - remove)',
              ),
            ),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
        actions: [
          if (widget.onSignOut != null)
            IconButton(
                tooltip: 'Sign out',
                onPressed: widget.onSignOut,
                icon: const Icon(Icons.logout)),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = num.tryParse(delta.text);
              if (value != null && value != 0) {
                Navigator.pop(context, (value, note.text));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    delta.dispose();
    note.dispose();
    if (result == null) return;
    try {
      await _api.adjustInventory(
        product.id,
        delta: result.$1,
        reason: 'ADMIN_ADJUSTMENT',
        note: result.$2,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Inventory updated')));
        await _reload();
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_api.describeError(e))));
      }
    }
  }

  Future<void> _edit(Product? product) async {
    final saved = await showDialog<bool>(
        context: context,
        builder: (_) => ProductEditorDialog(api: _api, product: product));
    if (saved == true) await _reload();
  }

  Future<void> _deactivate(Product product) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text('Deactivate ${product.name}?'),
                content: const Text(
                    'The product will be hidden from the customer catalog.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Deactivate'))
                ]));
    if (confirmed != true) return;
    try {
      await _api.deactivateProduct(product.id);
      await _reload();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_api.describeError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Products & inventory'),
          actions: [
            IconButton(
                tooltip: 'Dashboard',
                icon: const Icon(Icons.dashboard_outlined),
                onPressed: widget.onDashboard),
            IconButton(
                tooltip: 'Orders',
                icon: const Icon(Icons.receipt_long),
                onPressed: widget.onOrders),
            IconButton(
                tooltip: 'Categories',
                icon: const Icon(Icons.category_outlined),
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => AdminCategoriesPage(api: _api)))),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(null),
            icon: const Icon(Icons.add),
            label: const Text('Add vegetable')),
        body: FutureBuilder<List<Product>>(
          future: _products,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not load products from the API.'),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: _reload,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              );
            }
            final allItems = snapshot.data ?? const <Product>[];
            final items = allItems
                .where((product) =>
                    (_categoryId == null ||
                        product.categoryId == _categoryId) &&
                    (_query.trim().isEmpty ||
                        product.name
                            .toLowerCase()
                            .contains(_query.trim().toLowerCase())))
                .toList();
            if (allItems.isEmpty) {
              return EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No products yet',
                  message:
                      'Add your first vegetable to start building the FreshBasket catalog.',
                  actionLabel: 'Add vegetable',
                  onAction: () => _edit(null));
            }
            return RefreshIndicator(
              onRefresh: _reload,
              child: Column(children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: AppSearchField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value),
                        hint: 'Search products')),
                FutureBuilder<List<Category>>(
                    future: _categories,
                    builder: (context, categoriesSnapshot) {
                      final categories =
                          categoriesSnapshot.data ?? const <Category>[];
                      return SizedBox(
                          height: 48,
                          child: ListView(
                              scrollDirection: Axis.horizontal,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              children: [
                                Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                        label: const Text('All'),
                                        selected: _categoryId == null,
                                        onSelected: (_) => setState(
                                            () => _categoryId = null))),
                                ...categories.map((category) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                        label: Text(category.name),
                                        selected: _categoryId == category.id,
                                        onSelected: (_) => setState(() =>
                                            _categoryId =
                                                _categoryId == category.id
                                                    ? null
                                                    : category.id)))),
                              ]));
                    }),
                Expanded(
                    child: items.isEmpty
                        ? const EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No matching vegetables',
                            message:
                                'Clear the search or choose another category.')
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 9),
                            itemBuilder: (context, index) {
                              final product = items[index];
                              final low = product.stock <= product.minimumStock;
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(children: [
                                    SizedBox(
                                        width: 68,
                                        height: 68,
                                        child: ProductImageView(
                                            url: _imageUri(product.imageUrl),
                                            borderRadius: BorderRadius.circular(
                                                AppRadius.sm))),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Text(product.name,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall
                                                  ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w800)),
                                          const SizedBox(height: 3),
                                          Text(
                                              '${product.categoryName} · ₹${product.price}/${product.unit.toLowerCase()}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall),
                                          const SizedBox(height: 6),
                                          Row(children: [
                                            Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                    color: low
                                                        ? const Color(
                                                            0xFFFFF3E0)
                                                        : AppColors.paleGreen,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            AppRadius.pill)),
                                                child: Text(
                                                    '${product.stock} ${product.unit.toLowerCase()}${low ? ' · Low' : ''}',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: low
                                                            ? AppColors.orange
                                                            : AppColors
                                                                .darkGreen,
                                                        fontWeight:
                                                            FontWeight.w700))),
                                            const SizedBox(width: 6),
                                            Text(
                                                product.active &&
                                                        product.available
                                                    ? 'Active'
                                                    : 'Hidden',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                        color:
                                                            AppColors.muted)),
                                          ]),
                                        ])),
                                    PopupMenuButton<String>(
                                      onSelected: (action) {
                                        if (action == 'stock') _adjust(product);
                                        if (action == 'edit') _edit(product);
                                        if (action == 'deactivate') {
                                          _deactivate(product);
                                        }
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                            value: 'stock',
                                            child: Text('Adjust inventory')),
                                        PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Edit product')),
                                        PopupMenuItem(
                                            value: 'deactivate',
                                            child: Text('Deactivate')),
                                      ],
                                    ),
                                  ]),
                                ),
                              );
                            },
                          )),
              ]),
            );
          },
        ),
      );

  final _searchController = TextEditingController();
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? _imageUri(String? value) {
    if (value == null || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    return uri?.hasScheme == true
        ? value
        : '${widget.client.dio.options.baseUrl}$value';
  }
}
