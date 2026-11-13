import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeviceServices {
  const DeviceServices();
  static const _channel = MethodChannel('freshbasket/device');

  Future<Map<String, double>> currentLocation() async {
    if (kIsWeb)
      throw UnsupportedError(
          'Location sharing is available in the Android app.');
    final value =
        await _channel.invokeMapMethod<String, dynamic>('currentLocation');
    if (value == null ||
        value['latitude'] is! num ||
        value['longitude'] is! num) {
      throw StateError('Device did not return a location.');
    }
    return {
      'latitude': (value['latitude'] as num).toDouble(),
      'longitude': (value['longitude'] as num).toDouble()
    };
  }

  Future<void> openExternalUrl(String url) async {
    if (kIsWeb) return;
    await _channel.invokeMethod<void>('openExternalUrl', {'url': url});
  }
}
