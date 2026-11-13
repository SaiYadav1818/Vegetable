import 'package:dio/dio.dart';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// REST client for the local FreshBasket API. On Android emulator use
/// http://10.0.2.2:8080; desktop and iOS simulator can use localhost.
class ApiClient {
  ApiClient({required String baseUrl, FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(),
        dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
            headers: const {'Accept': 'application/json'},
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: _tokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  static const _tokenKey = 'freshbasket.access_token';
  final FlutterSecureStorage _storage;
  final Dio dio;

  Future<void> saveAccessToken(String token) =>
      _storage.write(key: _tokenKey, value: token);
  Future<void> clearAccessToken() => _storage.delete(key: _tokenKey);
  Future<String> getOrCreateDeviceId() async {
    var deviceId = await _storage.read(key: 'freshbasket.device_id');
    if (deviceId == null || deviceId.isEmpty) {
      final random = Random.secure();
      deviceId = List<int>.generate(16, (_) => random.nextInt(256))
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      await _storage.write(key: 'freshbasket.device_id', value: deviceId);
    }
    return deviceId;
  }
}
