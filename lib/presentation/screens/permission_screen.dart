import 'package:flutter/material.dart';
import 'package:habit_flow/core/services/notification_service.dart';
import 'package:habit_flow/core/services/alarm_permission_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  final notificationService = NotificationService();
  final permissionService = AlarmPermissionService();
  bool _notificationGranted = false;
  bool _fullscreenGranted = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _watchPermissions();
    });
  }

  Future<void> _watchPermissions() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 1));

      await _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    _notificationGranted = await notificationService
        .isNotificationPermissionGranted();

    _fullscreenGranted = await permissionService
        .isFullScreenPermissionGranted();

    if (_notificationGranted && _fullscreenGranted) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');

      return;
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Permissions"),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 30),

              Icon(
                Icons.security_rounded,
                size: 90,
                color: Theme.of(context).colorScheme.primary,
              ),

              const SizedBox(height: 30),

              const Text(
                "Habitick needs a few permissions to make alarms work reliably.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 40),

              ListTile(
                leading: Icon(
                  _notificationGranted ? Icons.check_circle : Icons.cancel,
                  color: _notificationGranted ? Colors.green : Colors.red,
                ),
                title: const Text("Notifications"),
              ),

              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text("Exact Alarm"),
              ),

              ListTile(
                leading: Icon(
                  _fullscreenGranted ? Icons.check_circle : Icons.cancel,
                  color: _fullscreenGranted ? Colors.green : Colors.red,
                ),
                title: const Text("Full Screen Alarm"),
                subtitle: const Text("Required for lock screen alarms"),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: FilledButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();

                    await prefs.setBool('hasSeenPermissionGuide', true);

                    await notificationService.requestPermissions();
                    await permissionService.openFullScreenSettings();
                    await _checkPermissions();
                  },
                  child: const Text("Continue"),
                ),
              ),
              const SizedBox(height: 12),

              TextButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();

                  await prefs.setBool('hasSeenPermissionGuide', true);

                  if (!mounted) return;
                  
                  Navigator.pushReplacementNamed(context, '/home');
                },
                child: const Text("Skip for now"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
