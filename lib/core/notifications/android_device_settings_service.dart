import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AndroidDeviceSettingsService {
  AndroidDeviceSettingsService._();

  static final AndroidDeviceSettingsService instance =
      AndroidDeviceSettingsService._();

  static const MethodChannel _channel = MethodChannel(
    'cvant/android_device_settings',
  );

  bool get _isSupported => !kIsWeb;

  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!_isSupported) return true;
    try {
      return await _channel.invokeMethod<bool>(
            'isIgnoringBatteryOptimizations',
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestIgnoreBatteryOptimizations() async {
    if (!_isSupported) return;
    try {
      await _channel.invokeMethod<void>('requestIgnoreBatteryOptimizations');
    } catch (_) {
      // Best effort only.
    }
  }

  Future<void> openAppNotificationSettings() async {
    if (!_isSupported) return;
    try {
      await _channel.invokeMethod<void>('openAppNotificationSettings');
    } catch (_) {
      // Best effort only.
    }
  }

  Future<void> openAutostartSettingsBestEffort() async {
    if (!_isSupported) return;
    try {
      await _channel.invokeMethod<void>('openAutostartSettings');
    } catch (_) {
      // Best effort only.
    }
  }
}
