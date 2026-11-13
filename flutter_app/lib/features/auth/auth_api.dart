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
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['detail'] ?? data['message'] ?? data['error'];
      if (message != null) return message.toString();
    }
    if (error.response?.statusCode == 409) {
      return 'This email or mobile number is already registered.';
    }
    return error.message ?? 'Request failed. Please try again.';
  }

  Future<AuthSession> login(String email, String password) async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      '/api/auth/login',
      data: {'email': email, 'password': password},
    );
    final data = response.data!;
    await _client.saveAccessToken(data['accessToken'] as String);
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
    await _client.saveAccessToken(data['accessToken'] as String);
    return AuthSession(
      userId: data['userId'] as int,
      email: data['email'] as String,
      fullName: data['fullName'] as String,
      role: data['role'] as String,
    );
  }
}
