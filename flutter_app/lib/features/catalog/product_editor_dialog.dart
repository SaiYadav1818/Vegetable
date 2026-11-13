import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/platform/device_services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/design_components.dart';
import 'catalog_api.dart';
import 'catalog_models.dart';

class ProductEditorDialog extends StatefulWidget {
  const ProductEditorDialog({super.key, required this.api, this.product});
  final CatalogApi api;
  final Product? product;
  @override
  State<ProductEditorDialog> createState() => _ProductEditorDialogState();
}

class _ProductEditorDialogState extends State<ProductEditorDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _description =
      TextEditingController(text: widget.product?.description ?? '');
  late final _price =
      TextEditingController(text: widget.product?.price.toString() ?? '');
  late final _stock =
      TextEditingController(text: widget.product?.stock.toString() ?? '0');
  late final _minimum = TextEditingController(
      text: widget.product?.minimumStock.toString() ?? '0');
  late final _imageUrl =
      TextEditingController(text: widget.product?.imageUrl ?? '');
  late final Future<List<Category>> _categories = widget.api.getCategories();
  String _unit = 'KG';
  int? _categoryId;
  bool _active = true;
  bool _available = true;
  bool _saving = false;
  String? _error;
  PickedImage? _pickedImage;
  final _device = const DeviceServices();

  @override
  void initState() {
    super.initState();
    _unit = widget.product?.unit ?? 'KG';
    _categoryId = widget.product?.categoryId;
    _active = widget.product?.active ?? true;
    _available = widget.product?.available ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _stock.dispose();
    _minimum.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _categoryId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final oldProduct = widget.product;
      late Product savedProduct;
      if (oldProduct == null) {
        savedProduct = await widget.api.createProduct(
            name: _name.text.trim(),
            description: _description.text,
            categoryId: _categoryId!,
            price: num.parse(_price.text),
            unit: _unit,
            imageUrl: _blankToNull(_imageUrl.text),
            initialStock: num.parse(_stock.text),
            minimumStock: num.parse(_minimum.text),
            active: _active,
            available: _available);
      } else {
        savedProduct = await widget.api.updateProduct(oldProduct.id,
            name: _name.text.trim(),
            description: _description.text,
            categoryId: _categoryId!,
            price: num.parse(_price.text),
            unit: _unit,
            imageUrl: _blankToNull(_imageUrl.text),
            minimumStock: num.parse(_minimum.text),
            active: _active,
            available: _available);
      }
      if (_pickedImage != null) {
        try {
          savedProduct = await widget.api.uploadProductImageBytes(
              savedProduct.id, _pickedImage!.bytes,
              fileName: _pickedImage!.fileName);
        } on DioException catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    'Product saved, but the image could not be uploaded: ${widget.api.describeError(e)}')));
          }
        }
      }
      if (mounted) Navigator.pop(context, true);
    } on DioException catch (e) {
      if (mounted) setState(() => _error = widget.api.describeError(e));
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Could not save product. Check the values and try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chooseImage() async {
    try {
      final image = await _device.pickProductImage();
      if (image != null && mounted) setState(() => _pickedImage = image);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not open the image picker: $e');
      }
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
  String? _positive(String? value) {
    final parsed = num.tryParse(value ?? '');
    return parsed == null || parsed <= 0 ? 'Enter a value above zero' : null;
  }

  String? _nonNegative(String? value) {
    final parsed = num.tryParse(value ?? '');
    return parsed == null || parsed < 0 ? 'Enter zero or more' : null;
  }

  String? _blankToNull(String value) =>
      value.trim().isEmpty ? null : value.trim();

  @override
  Widget build(BuildContext context) => AlertDialog(
        title:
            Text(widget.product == null ? 'Add vegetable' : 'Edit vegetable'),
        content: SizedBox(
            width: 440,
            child: FutureBuilder<List<Category>>(
                future: _categories,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                        height: 120,
                        child: Center(child: CircularProgressIndicator()));
                  }
                  if (snapshot.hasError) {
                    return const Text('Could not load categories.');
                  }
                  final categories = snapshot.data ?? const <Category>[];
                  if (categories.isEmpty) {
                    return const Text(
                        'Create a category before adding a product.');
                  }
                  if (_categoryId != null &&
                      !categories.any((c) => c.id == _categoryId)) {
                    _categoryId = null;
                  }
                  return SingleChildScrollView(
                      child: Form(
                          key: _form,
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md)),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                              AppRadius.sm),
                                          child: SizedBox(
                                              height: 130,
                                              width: double.infinity,
                                              child: _pickedImage != null
                                                  ? Image.memory(
                                                      _pickedImage!.bytes,
                                                      fit: BoxFit.cover)
                                                  : widget.product?.imageUrl !=
                                                          null
                                                      ? ProductImageView(
                                                          url: widget.product!
                                                              .imageUrl)
                                                      : const ProductImageView())),
                                      const SizedBox(height: 9),
                                      OutlinedButton.icon(
                                          onPressed: _chooseImage,
                                          icon: const Icon(Icons
                                              .add_photo_alternate_outlined),
                                          label: Text(_pickedImage == null
                                              ? 'Choose product image'
                                              : 'Change image')),
                                      Text(
                                          _pickedImage?.fileName ??
                                              'Use a clear, well-lit vegetable photo.',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                    ])),
                            TextFormField(
                                controller: _name,
                                decoration:
                                    const InputDecoration(labelText: 'Name'),
                                validator: _required),
                            TextFormField(
                                controller: _description,
                                decoration: const InputDecoration(
                                    labelText: 'Description')),
                            DropdownButtonFormField<int>(
                                initialValue: _categoryId,
                                decoration: const InputDecoration(
                                    labelText: 'Category'),
                                items: categories
                                    .map((c) => DropdownMenuItem(
                                        value: c.id, child: Text(c.name)))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _categoryId = v),
                                validator: (v) =>
                                    v == null ? 'Choose a category' : null),
                            Row(children: [
                              Expanded(
                                  child: TextFormField(
                                      controller: _price,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      decoration: const InputDecoration(
                                          labelText: 'Price (₹)'),
                                      validator: _positive)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: DropdownButtonFormField<String>(
                                      initialValue: _unit,
                                      decoration: const InputDecoration(
                                          labelText: 'Unit'),
                                      items: const [
                                        DropdownMenuItem(
                                            value: 'KG', child: Text('kg')),
                                        DropdownMenuItem(
                                            value: 'G500',
                                            child: Text('500 g')),
                                        DropdownMenuItem(
                                            value: 'G250',
                                            child: Text('250 g')),
                                        DropdownMenuItem(
                                            value: 'PIECE',
                                            child: Text('piece')),
                                        DropdownMenuItem(
                                            value: 'BUNCH',
                                            child: Text('bunch'))
                                      ],
                                      onChanged: (v) {
                                        if (v != null) {
                                          setState(() => _unit = v);
                                        }
                                      }))
                            ]),
                            if (widget.product == null)
                              TextFormField(
                                  controller: _stock,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: const InputDecoration(
                                      labelText: 'Starting stock'),
                                  validator: _nonNegative),
                            TextFormField(
                                controller: _minimum,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                    labelText: 'Low-stock alert at'),
                                validator: _nonNegative),
                            SwitchListTile(
                                title: const Text('Active'),
                                value: _active,
                                onChanged: (v) => setState(() => _active = v)),
                            SwitchListTile(
                                title: const Text('Available to order'),
                                value: _available,
                                onChanged: (v) =>
                                    setState(() => _available = v)),
                            if (_error != null)
                              Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(_error!,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error))),
                          ])));
                })),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'))
        ],
      );
}
