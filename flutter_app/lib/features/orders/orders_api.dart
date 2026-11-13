import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../customer/customer_cart.dart';
import 'order_models.dart';

class OrdersApi implements CartGateway {
  OrdersApi(this.client);
  final ApiClient client;

  @override
  Future<CartSnapshot> getCart() async => CartSnapshot.fromJson(
      (await client.dio.get<Map<String, dynamic>>('/api/cart')).data!);
  @override
  Future<CartSnapshot> addItem(int productId, {num quantity = 1}) async =>
      CartSnapshot.fromJson((await client.dio.post<Map<String, dynamic>>(
              '/api/cart/items',
              data: {'productId': productId, 'quantity': quantity}))
          .data!);
  @override
  Future<CartSnapshot> updateItem(int itemId, num quantity) async =>
      CartSnapshot.fromJson((await client.dio.put<Map<String, dynamic>>(
              '/api/cart/items/$itemId',
              data: {'quantity': quantity}))
          .data!);
  @override
  Future<CartSnapshot> removeItem(int itemId) async {
    await client.dio.delete<void>('/api/cart/items/$itemId');
    return getCart();
  }

  Future<OrderRecord> placeOrder(
          {required CartSnapshot cart,
          required String recipientName,
          required String recipientPhone,
          required String addressLine,
          String? houseNumber,
          required String area,
          String? landmark,
          required String pincode,
          String? deliveryInstructions,
          required DateTime deliveryDate,
          required String deliverySlot,
          num? latitude,
          num? longitude}) async =>
      OrderRecord.fromJson(
          (await client.dio.post<Map<String, dynamic>>('/api/orders', data: {
        'expectedSubtotal': cart.subtotal,
        'recipientName': recipientName,
        'recipientPhone': recipientPhone,
        'addressLine': addressLine,
        'houseNumber': houseNumber,
        'area': area,
        'landmark': landmark,
        'pincode': pincode,
        'deliveryInstructions': deliveryInstructions,
        'deliveryDate': deliveryDate.toIso8601String().substring(0, 10),
        'deliverySlot': deliverySlot,
        'latitude': latitude,
        'longitude': longitude,
      }))
              .data!);
  Future<List<OrderRecord>> myOrders({int page = 0, int size = 20}) async {
    final data = (await client.dio.get<Map<String, dynamic>>('/api/orders/my',
            queryParameters: {'page': page, 'size': size}))
        .data!;
    return ((data['content'] as List<dynamic>?) ?? const [])
        .map((e) => OrderRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<OrderRecord> getOrder(int id) async => OrderRecord.fromJson(
      (await client.dio.get<Map<String, dynamic>>('/api/orders/$id')).data!);
  Future<OrderRecord> cancelOrder(int id, {String? reason}) async =>
      OrderRecord.fromJson((await client.dio.post<Map<String, dynamic>>(
              '/api/orders/$id/cancel',
              data: {'reason': reason}))
          .data!);
  Future<String> rotateDeliveryOtp(int id) async => (await client.dio
          .post<Map<String, dynamic>>('/api/orders/$id/delivery-otp'))
      .data!['deliveryOtp'] as String;

  Future<List<OrderRecord>> adminOrders({int page = 0, int size = 30}) async {
    final data = (await client.dio.get<Map<String, dynamic>>(
            '/api/admin/orders',
            queryParameters: {'page': page, 'size': size}))
        .data!;
    return ((data['content'] as List<dynamic>?) ?? const [])
        .map((e) => OrderRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<OrderRecord> updateAdminStatus(int id, String status,
          {String? reason}) async =>
      OrderRecord.fromJson((await client.dio.put<Map<String, dynamic>>(
              '/api/admin/orders/$id/status',
              data: {'status': status, 'reason': reason}))
          .data!);
  Future<List<Map<String, dynamic>>> drivers(
      {int page = 0, int size = 50}) async {
    final data = (await client.dio.get<Map<String, dynamic>>(
            '/api/admin/drivers',
            queryParameters: {'page': page, 'size': size}))
        .data!;
    return ((data['content'] as List<dynamic>?) ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<OrderRecord> assignDriver(int orderId, int driverUserId) async =>
      OrderRecord.fromJson((await client.dio.post<Map<String, dynamic>>(
              '/api/admin/orders/$orderId/assign-driver',
              data: {'driverUserId': driverUserId}))
          .data!);
  Future<void> createDriver(
      {required String name,
      required String email,
      required String phone,
      required String password}) async {
    await client.dio.post<void>('/api/admin/drivers', data: {
      'fullName': name,
      'email': email,
      'phoneNumber': phone,
      'password': password
    });
  }

  Future<List<DriverOrder>> driverOrders({int page = 0, int size = 30}) async {
    final data = (await client.dio.get<Map<String, dynamic>>(
            '/api/driver/orders',
            queryParameters: {'page': page, 'size': size}))
        .data!;
    return ((data['content'] as List<dynamic>?) ?? const [])
        .map((e) => DriverOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> setDriverOnline(bool online) async {
    await client.dio
        .put<void>('/api/driver/availability', data: {'online': online});
  }

  Future<DriverOrder> acceptDelivery(int id) async =>
      DriverOrder.fromJson((await client.dio
              .put<Map<String, dynamic>>('/api/driver/orders/$id/accept'))
          .data!);
  Future<DriverOrder> pickupDelivery(int id) async =>
      DriverOrder.fromJson((await client.dio
              .put<Map<String, dynamic>>('/api/driver/orders/$id/pickup'))
          .data!);
  Future<OrderRecord> deliver(int id, String otp,
          {required bool cashCollected}) async =>
      OrderRecord.fromJson((await client.dio.put<Map<String, dynamic>>(
              '/api/driver/orders/$id/deliver',
              data: {'otp': otp, 'cashCollected': cashCollected}))
          .data!);
  Future<void> updateDriverLocation(double latitude, double longitude) async {
    await client.dio.post<void>('/api/driver/location',
        data: {'latitude': latitude, 'longitude': longitude});
  }

  String describeError(Object error) => error is DioException
      ? (error.response?.data is Map<String, dynamic>
          ? ((error.response!.data as Map<String, dynamic>)['message'] ??
                  error.message)
              .toString()
          : error.message ?? 'Could not reach FreshBasket API')
      : error.toString();
}
