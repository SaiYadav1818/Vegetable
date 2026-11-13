import 'package:dio/dio.dart';
import 'dart:typed_data';
import '../../core/network/api_client.dart';
import 'catalog_models.dart';

/// Typed access to the real catalog endpoints. Write methods require an
/// administrator JWT; the backend enforces that role on every request.
class CatalogApi {
  CatalogApi(this._client);
  final ApiClient _client;

  Future<List<Category>> getCategories() async {
    final response = await _client.dio.get<List<dynamic>>('/api/categories');
    return (response.data ?? const [])
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Product>> getProducts({
    int page = 0,
    int size = 20,
    int? categoryId,
    bool admin = false,
  }) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      admin ? '/api/admin/products' : '/api/products',
      queryParameters: {
        'page': page,
        'size': size,
        if (categoryId != null) 'categoryId': categoryId,
      },
    );
    return ((response.data?['content'] as List<dynamic>?) ?? const [])
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Product> getProduct(int id) async => Product.fromJson(
        (await _client.dio.get<Map<String, dynamic>>('/api/products/$id'))
            .data!,
      );

  Future<Category> createCategory({
    required String name,
    String? description,
  }) async =>
      Category.fromJson(
        (await _client.dio.post<Map<String, dynamic>>(
          '/api/admin/categories',
          data: {'name': name, 'description': description},
        ))
            .data!,
      );

  Future<Category> updateCategory(int id,
          {required String name, String? description}) async =>
      Category.fromJson(
        (await _client.dio.put<Map<String, dynamic>>(
                '/api/admin/categories/$id',
                data: {'name': name, 'description': description}))
            .data!,
      );

  Future<Product> createProduct({
    required String name,
    String? description,
    required int categoryId,
    required num price,
    required String unit,
    String? imageUrl,
    required num initialStock,
    required num minimumStock,
    bool active = true,
    bool available = true,
  }) async =>
      Product.fromJson(
        (await _client.dio.post<Map<String, dynamic>>(
          '/api/admin/products',
          data: {
            'name': name,
            'description': description,
            'categoryId': categoryId,
            'price': price,
            'unit': unit,
            'imageUrl': imageUrl,
            'active': active,
            'available': available,
            'initialStock': initialStock,
            'minimumStock': minimumStock,
          },
        ))
            .data!,
      );

  Future<Product> updateProduct(
    int id, {
    required String name,
    String? description,
    required int categoryId,
    required num price,
    required String unit,
    String? imageUrl,
    required num minimumStock,
    bool active = true,
    bool available = true,
  }) async =>
      Product.fromJson(
        (await _client.dio.put<Map<String, dynamic>>(
          '/api/admin/products/$id',
          data: {
            'name': name,
            'description': description,
            'categoryId': categoryId,
            'price': price,
            'unit': unit,
            'imageUrl': imageUrl,
            'active': active,
            'available': available,
            'minimumStock': minimumStock,
          },
        ))
            .data!,
      );

  Future<Product> adjustInventory(
    int productId, {
    required num delta,
    required String reason,
    String? note,
    num? minimumStock,
  }) async =>
      Product.fromJson(
        (await _client.dio.post<Map<String, dynamic>>(
          '/api/admin/products/$productId/inventory-adjustments',
          data: {
            'delta': delta,
            'reason': reason,
            'note': note,
            'minimumStock': minimumStock,
          },
        ))
            .data!,
      );

  Future<Product> uploadProductImage(int productId, String filePath) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    return Product.fromJson(
      (await _client.dio.post<Map<String, dynamic>>(
        '/api/admin/products/$productId/image',
        data: form,
      ))
          .data!,
    );
  }

  Future<Product> uploadProductImageBytes(int productId, Uint8List bytes,
      {required String fileName}) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    return Product.fromJson(
      (await _client.dio.post<Map<String, dynamic>>(
        '/api/admin/products/$productId/image',
        data: form,
      ))
          .data!,
    );
  }

  Future<List<InventoryTransaction>> getInventoryHistory(
    int productId, {
    int page = 0,
    int size = 50,
  }) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      '/api/admin/products/$productId/inventory-history',
      queryParameters: {'page': page, 'size': size},
    );
    return ((response.data?['content'] as List<dynamic>?) ?? const [])
        .map((e) => InventoryTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deactivateProduct(int id) =>
      _client.dio.delete<void>('/api/admin/products/$id');
  Future<void> deactivateCategory(int id) =>
      _client.dio.delete<void>('/api/admin/categories/$id');

  String describeError(Object error) => error is DioException
      ? (error.response?.data is Map<String, dynamic>
          ? ((error.response!.data as Map<String, dynamic>)['detail'] ??
                  (error.response!.data as Map<String, dynamic>)['message'] ??
                  error.message)
              .toString()
          : error.message ?? 'Unable to reach FreshBasket API')
      : error.toString();
}
