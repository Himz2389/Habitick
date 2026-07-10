import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

// Tera banaya hua background callback (Safe rakha hai)
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  debugPrint("🔵 Background Notification Callback");
  debugPrint("Payload: ${response.payload}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // 🚨 NAYA: METHOD CHANNEL SETUP (Native Android lock-screen bridge)
  static const platform = MethodChannel('habitick/alarm_lock');

  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    tz.initializeTimeZones();
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();

    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: DarwinInitializationSettings(),
        );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint("🟢 Notification Callback Triggered");
        debugPrint("Payload: ${response.payload}");
        debugPrint("Navigator: ${navigatorKey.currentState}");

        if (response.payload != null) {
          final data = response.payload!.split('|||');
          if (data.length >= 3) {
            final int id = int.parse(data[0]);
            final String title = data[1];
            final String body = data[2];
            final bool isTask = data.length >= 4 && data[3] == 'task';

            // =========================================================
            // 🚨 NAMED ROUTE: Ab mixed navigation nahi hogi (Bug Fixed)
            // =========================================================
            navigatorKey.currentState?.pushNamed(
              '/alarm',
              arguments: {
                'id': id,
                'title': title,
                'description': body,
                'isTask': isTask,
              },
            );
          }
        }
      },
      // Tera background response listener
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  Future<void> requestPermissions() async {
    // 1. Normal Notification Permission
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();

      //  2. EXACT ALARM PERMISSION
      await androidImplementation.requestExactAlarmsPermission();
    }
  }

  Future<bool> isNotificationPermissionGranted() async {
    final android = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android == null) return true;

    return await android.areNotificationsEnabled() ?? false;
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> showInstantNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'instant_test_channel',
          'Test Notifications',
          importance: Importance.max,
          priority: Priority.high,
        );
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await flutterLocalNotificationsPlugin.show(
      999,
      title,
      body,
      platformDetails,
    );
  }

  // 1. HABITS DAILY ALARM ( with Custom Sound)
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final Int32List insistentFlag = Int32List.fromList(<int>[4]);

    final prefs = await SharedPreferences.getInstance();
    final customPath = prefs.getString('custom_ringtone_path');

    AndroidNotificationSound? nativeSound;
    String channelId = 'habit_alarm_channel_v3';
    bool playNativeSound = true;

    if (customPath != null && customPath.isNotEmpty) {
      nativeSound = null;
      playNativeSound = false;
      channelId = 'habit_alarm_channel_custom_v3_${customPath.hashCode}';
    } else {
      nativeSound = const UriAndroidNotificationSound(
        'content://settings/system/alarm_alert',
      );
      channelId = 'habit_alarm_channel_default_v3';
    }

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'Habit Alarms',
          channelDescription: 'Daily continuous alarms for habits',
          importance: Importance.max,
          priority: Priority.high,
          additionalFlags: insistentFlag,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          icon: '@mipmap/ic_launcher',
          sound: nativeSound,
          playSound: playNativeSound,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: '$id|||$title|||$body|||habit',
    );
  }

  // 2. TO-DOs KE LIYE EXACT ALARM
  Future<void> scheduleExactNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    final tz.TZDateTime scheduledTZDate = tz.TZDateTime.from(
      scheduledDate,
      tz.local,
    );

    final Int32List insistentFlag = Int32List.fromList(<int>[4]);
    final prefs = await SharedPreferences.getInstance();
    final customPath = prefs.getString('custom_ringtone_path');

    AndroidNotificationSound? nativeSound;
    String channelId = 'todo_alarm_channel_v3';
    bool playNativeSound = true;

    if (customPath != null && customPath.isNotEmpty) {
      nativeSound = null;
      playNativeSound = false;
      channelId = 'todo_alarm_channel_custom_v3_${customPath.hashCode}';
    } else {
      nativeSound = const UriAndroidNotificationSound(
        'content://settings/system/alarm_alert',
      );
      channelId = 'todo_alarm_channel_default_v3';
    }

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTZDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'To-Do Alarms',
          channelDescription: 'Real continuous alarms for tasks',
          importance: Importance.max,
          priority: Priority.high,
          additionalFlags: insistentFlag,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          icon: '@mipmap/ic_launcher',
          sound: nativeSound,
          playSound: playNativeSound,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: '$id|||$title|||$body|||task',
    );
  }
}
