import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_flow/presentation/providers/theme_provider.dart';
import 'package:habit_flow/core/services/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:habit_flow/presentation/screens/alarm_screen.dart';
import 'package:habit_flow/presentation/screens/splash_screen.dart';
import 'package:habit_flow/presentation/screens/onboarding_screen.dart';
import 'package:habit_flow/presentation/screens/home_screen.dart';
// import 'package:workmanager/workmanager.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:habit_flow/presentation/screens/permission_screen.dart';





final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
String? coldBootPayload;
bool? globalHasSeenOnboarding;

//  NAYA FUNCTION: LIVE USERS KA RINGTONE DATA SECURE FOLDER ME MIGRATION KAREGA
Future<void> _migrateOldRingtone() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final currentPath = prefs.getString('custom_ringtone_path');

    if (currentPath != null && currentPath.isNotEmpty) {
      final appDir = await getApplicationDocumentsDirectory();

      if (!currentPath.contains(appDir.path)) {
        File oldFile = File(currentPath);

        if (oldFile.existsSync()) {
          final fileName = currentPath.split('/').last;
          final newSecurePath = '${appDir.path}/$fileName';

          await oldFile.copy(newSecurePath);
          await prefs.setString('custom_ringtone_path', newSecurePath);
          debugPrint("✅ Old user's ringtone securely migrated!");
        } else {
          await prefs.remove('custom_ringtone_path');
          debugPrint(
            "⚠️ Old temporary ringtone was deleted by OS. Reset to default.",
          );
        }
      }
    }
  } catch (e) {
    debugPrint("Migration error: $e");
  }
}

@pragma('vm:entry-point')

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //  0. MIGRATION CHALANA
  await _migrateOldRingtone();

  //  1. TIMEZONE INITIALIZATION
  try {
    tz.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    String tzName;
    try {
      tzName = (localTimezone as dynamic).name;
    } catch (_) {
      tzName = localTimezone.toString();
    }
    tz.setLocalLocation(tz.getLocation(tzName));
  } catch (e) {
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
  }

  //  2. NOTIFICATIONS INITIALIZATION
  try {
    final notificationService = NotificationService();
    await notificationService.init(navigatorKey);
    await notificationService.requestPermissions();

    final launchDetails = await notificationService
        .flutterLocalNotificationsPlugin
        .getNotificationAppLaunchDetails();
    if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
      coldBootPayload = launchDetails.notificationResponse?.payload;
    }
  } catch (e) {
    print("⚠️ Notification Error: $e");
  }

  //  3. ONBOARDING STATUS CHECK
  try {
    final prefs = await SharedPreferences.getInstance();
    globalHasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
  } catch (e) {
    globalHasSeenOnboarding = false;
  }


  //  4. APP START
  runApp(Phoenix(child: const ProviderScope(child: HabitFlowApp())));

  //  5. SECURITY FIX
  if (coldBootPayload == null) {
    try {
      const platform = MethodChannel('habitick/alarm_lock');
      platform.invokeMethod('sleepScreen');
    } catch (e) {
      debugPrint("Security pass revoke error: $e");
    }
  }
}

class HabitFlowApp extends ConsumerWidget {
  const HabitFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentThemeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Habitick',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', 'US')],

      //  LIGHT THEME
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.light,
          seedColor: const Color(0xFF8C52FF),
          primary: const Color(0xFF8C52FF),
          onSurface: Colors.black,
          secondary: const Color(0xFF00E676),
          surface: const Color(0xFFF8F9FA),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Color.fromARGB(255, 0, 0, 0),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8C52FF),
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: const Color(0xFF8C52FF).withValues(alpha: 0.4),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),

      //  DARK THEME
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color(0xFF8C52FF),
          primary: const Color(0xFF8C52FF),
          onPrimary: Colors.white,
          secondary: const Color(0xFF00E676),
          surface: const Color.fromARGB(255, 20, 20, 20),
          onSurface: const Color.fromARGB(255, 255, 255, 255),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8C52FF),
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: const Color(0xFF8C52FF).withValues(alpha: 0.4),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      themeMode: currentThemeMode,

      // =========================================================
      // 🚨 NAYA ROUTING SYSTEM (home: hata diya gaya hai)
      // =========================================================
      initialRoute: coldBootPayload != null ? '/alarm' : '/splash',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          // 1. SPLASH ROUTE
          case '/splash':
            return MaterialPageRoute(
              builder: (_) => SplashScreen(
                hasSeenOnboarding: globalHasSeenOnboarding ?? false,
              ),
            );

          // 2. HOME ROUTE
          case '/home':
            return MaterialPageRoute(builder: (_) => const HomeScreen());

          case '/onboarding':
            return MaterialPageRoute(builder: (_) => const OnboardingScreen());

          case '/permissions':
            return MaterialPageRoute(
              builder: (_) => const PermissionScreen(),
            );

          // 3. ALARM ROUTE (Payload ya Arguments ke sath)
          case '/alarm':
            // Agar app already open hai aur notification click hui
            if (settings.arguments != null) {
              final args = settings.arguments as Map<String, dynamic>;
              return MaterialPageRoute(
                builder: (_) => AlarmScreen(
                  id: args['id'],
                  title: args['title'],
                  description: args['description'],
                  isTask: args['isTask'],
                ),
              );
            }

            // Agar app poori tarah band thi aur Cold Boot se start hui (Native bypass)
            if (coldBootPayload != null) {
              final data = coldBootPayload!.split('|||');
              final bool isTask = data.length >= 4 && data[3] == 'task';

              // 🚨 PRIVACY BREACH PERMANENT FIX: Payload ko extract karne ke baad hamesha ke liye destroy kar do
              coldBootPayload = null;

              return MaterialPageRoute(
                builder: (_) => AlarmScreen(
                  id: int.parse(data[0]),
                  title: data[1],
                  description: data[2],
                  isTask: isTask,
                ),
              );
            }

            // Fallback (Agar galti se '/alarm' call hua bina kisi data ke)
            return MaterialPageRoute(
              builder: (_) => SplashScreen(
                hasSeenOnboarding: globalHasSeenOnboarding ?? false,
              ),
            );

          // DEFAULT FALLBACK ROUTE
          default:
            return MaterialPageRoute(builder: (_) => HomeScreen());
        }
      },
    );
  }
}
