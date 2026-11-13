import '../../core/network/api_client.dart';
import 'package:dio/dio.dart';

class AuthSession {
  const AuthSession({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.role,
  });
  final int userId;
  final String email;
  final String fullName;
  final String role;
}

class AuthApi {
  AuthApi(this._client);
  final ApiClient _client;

  static String describeError(DioException error) {
    if (error.response?.statusCode == 429) {
      final data = error.response?.data;
      if (data is Map<String, dynamic> && data['detail'] != null) {
        return data['detail'].toString();
      }
      return 'Too many attempts. Please wait a minute and try again.';
    }
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['detail'] ?? data['message'] ?? data['error'];
      if (message != null) return message.toString();
    }
    if (error.response?.statusCode == 409) {
      return 'Unable to register with the provided credentials. Please check details or sign in.';
    }
    if (error.response?.statusCode == 401) {
      return 'Invalid email or password.';
    }
    return error.message ?? 'Request failed. Please try again.';
  }

  Future<AuthSession> login(String email, String password) async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      '/api/auth/login',
      data: {'email': email, 'password': password},
    );
    final data = response.data!;
    final accessToken = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String?;
    if (refreshToken != null) {
      await _client.saveTokens(accessToken: accessToken, refreshToken: refreshToken);
    } else {
      await _client.saveAccessToken(accessToken);
    }
    return AuthSession(
      userId: data['userId'] as int,
      email: data['email'] as String,
      fullName: data['fullName'] as String,
      role: data['role'] as String,
    );
  }

  Future<AuthSession> register({
    required String fullName,
    required String email,
    required String password,
    String? phoneNumber,
  }) async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      '/api/auth/register',
      data: {
        'fullName': fullName,
        'email': email,
        'password': password,
        if (phoneNumber != null && phoneNumber.isNotEmpty)
          'phoneNumber': phoneNumber,
      },
    );
    final data = response.data!;
    final accessToken = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String?;
    if (refreshToken != null) {
      await _client.saveTokens(accessToken: accessToken, refreshToken: refreshToken);
    } else {
      await _client.saveAccessToken(accessToken);
    }
    return AuthSession(
      userId: data['userId'] as int,
      email: data['email'] as String,
      fullName: data['fullName'] as String,
      role: data['role'] as String,
    );
  }

  Future<void> logout() async {
    final refreshToken = await _client.getRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _client.dio.post<void>(
          '/api/auth/logout',
          data: {'refreshToken': refreshToken},
        );
      } catch (_) {}
    }
    await _client.clearTokens();
  }
}
