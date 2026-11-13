import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'catalog_api.dart';
import 'catalog_models.dart';
import '../../core/network/api_client.dart';
import 'admin_categories_page.dart';
import 'product_editor_dialog.dart';

class AdminProductsPage extends StatefulWidget {
  const AdminProductsPage({
    super.key,
    required this.client,
    required this.adminName,
    this.onSignOut,
    this.onOrders,
  });
  final ApiClient client;
  final String adminName;
  final VoidCallback? onSignOut;
  final VoidCallback? onOrders;
  @override
  State<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends State<AdminProductsPage> {
  late final CatalogApi _api = CatalogApi(widget.client);
  late Future<List<Product>> _products = _api.getProducts(admin: true);
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: Text(widget.adminName)),
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
            final items = snapshot.data ?? const <Product>[];
            if (items.isEmpty) {
              return const Center(
                  child: Text('No products yet. Add your first vegetable.'));
            }
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final product = items[index];
                  final low = product.stock <= product.minimumStock;
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFE8F5E9),
                        foregroundImage: product.imageUrl == null
                            ? null
                            : NetworkImage(_imageUri(product.imageUrl!)),
                        child: product.imageUrl == null
                            ? const Icon(Icons.eco, color: Color(0xFF2E7D32))
                            : null,
                      ),
                      title: Text(product.name),
                      subtitle: Text(
                        '${product.categoryName} | Rs. ${product.price}/${product.unit}\n'
                        'Stock ${product.stock} ${product.unit} | minimum ${product.minimumStock} | ${product.active ? 'Active' : 'Inactive'}',
                        style: TextStyle(color: low ? Colors.deepOrange : null),
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'stock') _adjust(product);
                          if (action == 'edit') _edit(product);
                          if (action == 'deactivate') _deactivate(product);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                              value: 'stock', child: Text('Adjust inventory')),
                          PopupMenuItem(
                              value: 'edit', child: Text('Edit product')),
                          PopupMenuItem(
                              value: 'deactivate', child: Text('Deactivate')),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      );

  String _imageUri(String value) {
    final uri = Uri.parse(value);
    return uri.hasScheme ? value : '${widget.client.dio.options.baseUrl}$value';
  }
}
