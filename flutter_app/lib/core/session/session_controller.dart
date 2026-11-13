import 'package:flutter/foundation.dart';
import '../../features/auth/auth_api.dart';

class SessionController extends ChangeNotifier {
  AuthSession? _session;
  AuthSession? get session => _session;
  bool get isSignedIn => _session != null;

  String get destination => switch (_session?.role) {
        'ADMIN' => '/admin',
        'DRIVER' => '/driver',
        'CUSTOMER' => '/customer',
        _ => '/auth',
      };

  void signIn(AuthSession session) {
    _session = session;
    notifyListeners();
  }

  void signOut() {
    _session = null;
    notifyListeners();
  }
}
