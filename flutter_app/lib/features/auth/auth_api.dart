import '../../core/network/api_client.dart';

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
}
