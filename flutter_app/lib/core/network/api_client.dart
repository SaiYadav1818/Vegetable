import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// REST client for the local FreshBasket API with automatic JWT token refresh.
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
        onError: (error, handler) async {
          final statusCode = error.response?.statusCode;
          final path = error.requestOptions.path;

          // Only attempt refresh on 401 and not for auth endpoints
          if (statusCode == 401 &&
              !path.contains('/api/auth/login') &&
              !path.contains('/api/auth/register') &&
              !path.contains('/api/auth/refresh')) {
            try {
              final refreshed = await _refreshTokens();
              if (refreshed) {
                final newToken = await _storage.read(key: _tokenKey);
                final opts = Options(
                  method: error.requestOptions.method,
                  headers: Map<String, dynamic>.from(error.requestOptions.headers)
                    ..['Authorization'] = 'Bearer $newToken',
                );
                final response = await dio.request<dynamic>(
                  error.requestOptions.path,
                  data: error.requestOptions.data,
                  queryParameters: error.requestOptions.queryParameters,
                  options: opts,
                );
                return handler.resolve(response);
              }
            } catch (_) {
              await clearTokens();
              onAuthenticationExpired?.call();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  static const _tokenKey = 'freshbasket.access_token';
  static const _refreshKey = 'freshbasket.refresh_token';
  final FlutterSecureStorage _storage;
  final Dio dio;
  void Function()? onAuthenticationExpired;

  Future<bool>? _inFlightRefresh;

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _tokenKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  Future<void> saveAccessToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<String?> getAccessToken() => _storage.read(key: _tokenKey);
  Future<String?> getRefreshToken() => _storage.read(key: _refreshKey);

  Future<void> clearAccessToken() => _storage.delete(key: _tokenKey);
  Future<void> clearTokens() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshKey);
  }

  Future<bool> _refreshTokens() async {
    // Queuing pattern: if a refresh is already underway, await it
    if (_inFlightRefresh != null) {
      return await _inFlightRefresh!;
    }
    final completer = Completer<bool>();
    _inFlightRefresh = completer.future;

    try {
      final currentRefresh = await _storage.read(key: _refreshKey);
      if (currentRefresh == null || currentRefresh.isEmpty) {
        completer.complete(false);
        return false;
      }

      // Use a clean Dio instance to avoid interceptor recursion
      final refreshDio = Dio(dio.options);
      final response = await refreshDio.post<Map<String, dynamic>>(
        '/api/auth/refresh',
        data: {'refreshToken': currentRefresh},
      );

      final data = response.data;
      if (data != null && data['accessToken'] is String) {
        final newAccess = data['accessToken'] as String;
        final newRefresh = (data['refreshToken'] as String?) ?? currentRefresh;
        await saveTokens(accessToken: newAccess, refreshToken: newRefresh);
        completer.complete(true);
        return true;
      }
      completer.complete(false);
      return false;
    } catch (e) {
      completer.complete(false);
      return false;
    } finally {
      _inFlightRefresh = null;
    }
  }

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
