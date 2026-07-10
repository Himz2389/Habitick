import 'dart:io';
import 'package:flutter/services.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:device_info_plus/device_info_plus.dart';

class AlarmPermissionService {
  Future<void> openFullScreenSettings() async {
    if (!Platform.isAndroid) return;

    final info = await DeviceInfoPlugin().androidInfo;

    if (info.version.sdkInt >= 34) {
      final intent = AndroidIntent(
        action: 'android.settings.MANAGE_APP_USE_FULL_SCREEN_INTENT',
        data: 'package:com.example.habit_flow',
      );

      await intent.launch();
    }
  }

  Future<void> openNotificationSettings() async {
    final intent = AndroidIntent(
      action: 'android.settings.APP_NOTIFICATION_SETTINGS',
      arguments: <String, dynamic>{
        'android.provider.extra.APP_PACKAGE': 'com.example.habit_flow',
      },
    );

    await intent.launch();
  }

  static const MethodChannel _channel = MethodChannel('habitick/alarm_lock');

  Future<bool> isFullScreenPermissionGranted() async {
    try {
      final result = await _channel.invokeMethod(
        'isFullScreenPermissionGranted',
      );

      return result == true;
    } catch (_) {
      return false;
    }
  }
}
