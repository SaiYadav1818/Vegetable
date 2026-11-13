import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'catalog_api.dart';
import 'catalog_models.dart';

class AdminCategoriesPage extends StatefulWidget {
  const AdminCategoriesPage({super.key, required this.api});
  final CatalogApi api;
  @override
  State<AdminCategoriesPage> createState() => _AdminCategoriesPageState();
}

class _AdminCategoriesPageState extends State<AdminCategoriesPage> {
  late Future<List<Category>> _future = widget.api.getCategories();
  void _reload() => setState(() => _future = widget.api.getCategories());

  Future<void> _add() async {
    final name = TextEditingController();
    final description = TextEditingController();
    final saved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('New category'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Name')),
                TextField(
                    controller: description,
                    decoration: const InputDecoration(labelText: 'Description'))
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () async {
                      if (name.text.trim().isEmpty) return;
                      try {
                        await widget.api.createCategory(
                            name: name.text.trim(),
                            description: description.text.trim());
                        if (context.mounted) Navigator.pop(context, true);
                      } on DioException catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(widget.api.describeError(e))));
                        }
                      }
                    },
                    child: const Text('Save'))
              ],
            ));
    name.dispose();
    description.dispose();
    if (saved == true) _reload();
  }

  Future<void> _deactivate(Category category) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text('Deactivate ${category.name}?'),
                content: const Text(
                    'Products in this category will be hidden from the customer catalog.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Deactivate'))
                ]));
    if (ok != true) return;
    try {
      await widget.api.deactivateCategory(category.id);
      _reload();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(widget.api.describeError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: const Text('Add category')),
      body: FutureBuilder<List<Category>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                  child: Text(widget.api.describeError(snapshot.error!)));
            }
            final items = snapshot.data ?? const <Category>[];
            if (items.isEmpty) {
              return const Center(
                  child: Text(
                      'No active categories. Add one to start managing vegetables.'));
            }
            return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final category = items[index];
                  return Card(
                      child: ListTile(
                          leading: const Icon(Icons.category_outlined),
                          title: Text(category.name),
                          subtitle: category.description == null
                              ? null
                              : Text(category.description!),
                          trailing: IconButton(
                              tooltip: 'Deactivate',
                              onPressed: () => _deactivate(category),
                              icon: const Icon(Icons.archive_outlined))));
                });
          }));
}
