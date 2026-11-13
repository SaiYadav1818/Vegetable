import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_client.dart';

@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } on FirebaseException {
    // Android Firebase options are provided by the installed google-services.json.
  }
}

class PushNotificationsService extends ChangeNotifier {
  PushNotificationsService(this.client);
  final ApiClient client;
  static const _native = MethodChannel('freshbasket/notifications');

  bool _configured = false;
  bool _loggedIn = false;
  bool _listenersAttached = false;
  int unreadCount = 0;
  Map<String, dynamic>? _pendingOpen;
  void Function(int orderId, String eventType)? onOrderOpened;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;

  Future<void> initialize({required bool firebaseConfigured}) async {
    _configured = firebaseConfigured;
    _native.setMethodCallHandler((call) async {
      if (call.method == 'notificationOpened' && call.arguments is Map) {
        _openData(Map<String, dynamic>.from(call.arguments as Map));
      }
    });
    try {
      final pending = await _native.invokeMapMethod<String, String>(
          'consumeInitialNotification');
      if (pending != null) _openData(pending);
    } on PlatformException {
      // The app can still handle notification clicks through Firebase Messaging.
    } on MissingPluginException {
      // This channel is Android-only.
    }
    if (!_configured || _listenersAttached) return;
    _listenersAttached = true;
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(_showForeground);
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _openData(message.data);
    });
    _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      if (_loggedIn) unawaited(_registerCurrentToken());
    });
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _openData(initial.data);
  }

  Future<void> signIn() async {
    _loggedIn = true;
    if (_configured) {
      final permission = await FirebaseMessaging.instance.requestPermission(
          alert: true, badge: true, sound: true);
      if (permission.authorizationStatus == AuthorizationStatus.authorized ||
          permission.authorizationStatus == AuthorizationStatus.provisional) {
        await _registerCurrentToken();
      }
    }
    await refreshUnread();
    final pending = _pendingOpen;
    if (pending != null) {
      _pendingOpen = null;
      _openData(pending);
    }
  }

  Future<void> signOut() async {
    _loggedIn = false;
    try {
      final deviceId = await client.getOrCreateDeviceId();
      await client.dio.delete<void>('/api/notifications/devices/$deviceId');
    } finally {
      if (_configured) {
        try {
          await FirebaseMessaging.instance.deleteToken();
        } catch (error) {
          debugPrint('Could not remove the local FCM token: $error');
        }
      }
      unreadCount = 0;
      notifyListeners();
    }
  }

  Future<void> _registerCurrentToken() async {
    if (!_configured || !_loggedIn) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    final deviceId = await client.getOrCreateDeviceId();
    await client.dio.post<void>('/api/notifications/devices', data: {
      'deviceId': deviceId,
      'token': token,
      'platform': Platform.isAndroid ? 'ANDROID' : 'IOS',
    });
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final title = message.notification?.title ?? 'FreshBasket update';
    final body = message.notification?.body ?? 'There is an update to your order.';
    final data = <String, String>{
      'notificationId': message.data['notificationId']?.toString() ?? '',
      'eventType': message.data['eventType']?.toString() ?? '',
      'orderId': message.data['orderId']?.toString() ?? '',
    };
    try {
      await _native.invokeMethod<void>('showNotification', {
        'title': title,
        'body': body,
        'data': data,
      });
    } on PlatformException catch (error) {
      debugPrint('Could not show foreground notification: ${error.message}');
    } on MissingPluginException {
      // No native notification implementation is available on this platform.
    }
    if (_loggedIn) await refreshUnread();
  }

  void _openData(Map<String, dynamic> data) {
    final id = int.tryParse(data['orderId']?.toString() ?? '');
    if (id == null || id <= 0) return;
    final eventType = data['eventType']?.toString() ?? '';
    final callback = onOrderOpened;
    if (!_loggedIn || callback == null) {
      _pendingOpen = {'orderId': id.toString(), 'eventType': eventType};
      return;
    }
    callback(id, eventType);
  }

  Future<void> refreshUnread() async {
    if (!_loggedIn) return;
    try {
      final response = await client.dio.get<Map<String, dynamic>>(
          '/api/notifications', queryParameters: {'page': 0, 'size': 1});
      unreadCount = response.data?['unreadCount'] as int? ?? 0;
      notifyListeners();
    } catch (error) {
      debugPrint('Could not refresh notification count: $error');
    }
  }

  @override
  void dispose() {
    unawaited(_foregroundSubscription?.cancel());
    unawaited(_openedSubscription?.cancel());
    unawaited(_tokenSubscription?.cancel());
    super.dispose();
  }

}
