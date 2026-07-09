import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:habit_flow/presentation/screens/home_screen.dart';
import 'package:habit_flow/presentation/providers/theme_provider.dart'; 
import 'package:habit_flow/presentation/screens/category_list_screen.dart'; 
import 'package:habit_flow/presentation/screens/habit_archive_screen.dart'; 
import 'package:habit_flow/core/services/notification_service.dart';
import 'package:habit_flow/data/repositories/habit_repository.dart';
import 'package:habit_flow/data/repositories/todo_repository.dart';
import 'package:intl/intl.dart'; 
import 'package:habit_flow/presentation/providers/habit_provider.dart';
import 'package:habit_flow/presentation/providers/category_provider.dart';
import 'package:habit_flow/presentation/providers/habit_completion_provider.dart';
import 'package:google_sign_in/google_sign_in.dart'; 
import 'package:habit_flow/core/services/cloud_sync_service.dart';
import 'package:habit_flow/data/local/database_helper.dart'; 
import 'package:workmanager/workmanager.dart';
import 'package:flutter/services.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isLoading = false;
  String? _customRingtonePath;
  bool _autoBackupEnabled = false;
  String _appVersion = "Loading...";

  Future<void> _loadAutoBackupPref() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoBackupEnabled = prefs.getBool('auto_backup_enabled') ?? false;
    });
  }

  Future<void> _toggleAutoBackup(bool value) async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_backup_enabled', value);
    setState(() {
      _autoBackupEnabled = value;
    });

    if (value) {
      // 🚨 ON kiya: Har 24 ghante ke liye task register karo
      await Workmanager().registerPeriodicTask(
        "habitflow_backup", // Unique ID
        "googleDriveBackupTask", // Task Name (Dispatcher me yahi match kiya hai)
        frequency: const Duration(hours: 24),
        constraints: Constraints(
          networkType: NetworkType.connected, // Backup ke liye net chahiye
        ),
      );

      // Agar ON karte time net hai, to pehla backup instant maar do
      if (_googleSignIn.currentUser != null) {
        try {
          setState(() => _isLoading = true);
          final message = await CloudSyncService().backupToGoogleDrive(_googleSignIn.currentUser!);
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Auto Backup Scheduled! $message"), backgroundColor: Colors.green),
            );
          }
        } catch (e) {
          setState(() => _isLoading = false);
        }
      }
    } else {
      // 🚨 OFF kiya: Background task cancel kar do
      await Workmanager().cancelByUniqueName("habitflow_backup");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Auto Backup Disabled."), backgroundColor: Colors.orange),
        );
      }
    }
  }

  // ==========================================================
  // GOOGLE DRIVE SYNC VARIABLES
  // ==========================================================
  bool _isGoogleLoggedIn = false;
  String _googleUserName = "";
  String _googleUserEmail = "";
  String? _googleUserPhoto; 


  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/drive.appdata',
    ],
  );

  @override
  void initState() {
    super.initState();
    _loadCustomRingtonePath();
    _setupGoogleSignInListener();
    _loadAutoBackupPref();
    _fetchAppVersion();
  } 

  // ==========================================================
  // GOOGLE SYNC & RESTORE LOGIC
  // ==========================================================
  void _setupGoogleSignInListener() async {
    //  1. FAST LOCAL CACHE CHECK
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isGoogleLoggedIn = prefs.getBool('is_google_logged_in') ?? false;
        if (_isGoogleLoggedIn) {
          _googleUserName = prefs.getString('google_name') ?? "Habitick User";
          _googleUserEmail = prefs.getString('google_email') ?? "";
        }
      });
    }

    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) async {
      final localPrefs = await SharedPreferences.getInstance();
      if (account != null) {
        // Login status local memory me save karo
        await localPrefs.setBool('is_google_logged_in', true);
        await localPrefs.setString('google_name', account.displayName ?? "Habitick User");
        await localPrefs.setString('google_email', account.email);
        
        if (mounted) {
          setState(() {
            _isGoogleLoggedIn = true;
            _googleUserName = account.displayName ?? "Habitick User";
            _googleUserEmail = account.email;
            _googleUserPhoto = account.photoUrl;
          });
        }
      } else {
        await localPrefs.setBool('is_google_logged_in', false);
        if (mounted) {
          setState(() {
            _isGoogleLoggedIn = false;
          });
        }
      }
    });
    
    try {
      
      await _googleSignIn.signInSilently();
    } catch (e) {
      debugPrint(" Signin Network Error (Due to Date Change): $e");
    }
  }

  Future<void> _fetchAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = "v${packageInfo.version}"; 
      });
    }
  }

  Future<void> _handleGoogleLogin() async {
    try {
      setState(() => _isLoading = true);
      final account = await _googleSignIn.signIn(); 
      
      if (account != null) {
        bool hasBackup = await CloudSyncService().checkForExistingBackup(account);
        setState(() => _isLoading = false);

        if (hasBackup && mounted) {
          _showRestoreDialog(account);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (error) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login Failed: $error"), backgroundColor: Colors.red),
        );
      }
    }
  }

  
  //  NAYA: SMART LOGOUT WITH WARNING POPUP
  
  Future<void> _handleGoogleLogout() async {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              SizedBox(width: 10),
              Text("Confirm Logout"),
            ],
          ),
          content: const Text(
            "Are you sure you want to log out?\n\nWarning: Backup will be disabled and your new habits won't be saved to Google Drive.",
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext), // Cancel dabane par bas dialog band hoga
              child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext); // Pehle popup band karo
                try {
                  await _googleSignIn.signOut(); // Asli logout yahan hoga
                  
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('is_google_logged_in', false);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Logged out successfully. Auto Backup stopped."), backgroundColor: Colors.orange),
                    );
                  }
                } catch (error) {
                  debugPrint("Logout Error: $error");
                }
              },
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text("Log Out"),
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            ),
          ],
        );
      },
    );
  }

  void _showRestoreDialog(GoogleSignInAccount account) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.cloud_download_rounded, color: Colors.blue),
              SizedBox(width: 10),
              Text("Backup Found!"),
            ],
          ),
          content: const Text(
            "We found an existing habit backup on your Google Drive. Would you like to restore it now, or start fresh?\n\n(Note: Starting fresh and backing up later will overwrite your old data).",
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Starting Fresh. Old backup ignored."), backgroundColor: Colors.orange),
                );
              },
              child: const Text("Start Fresh", style: TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext); 
                setState(() => _isLoading = true);
                
                final message = await CloudSyncService().restoreFromGoogleDrive(account);
                await DatabaseHelper.instance.clearDatabaseConnection();
                await _refreshAllActiveAlarms();
                
                
                //  Data aate hi Riverpod memory clear 
                
                ref.invalidate(habitProvider);
                ref.invalidate(categoryProvider);
                ref.invalidate(habitCompletionProvider);
                

                if (mounted) {
                  setState(() => _isLoading = false);

                  if (message.startsWith("✅")) {
                    showDialog(
                      context: context,
                      barrierDismissible: false, 
                      builder: (BuildContext restartContext) {
                        return AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Row(
                            children: [
                              Icon(Icons.check_circle_rounded, color: Colors.green),
                              SizedBox(width: 10),
                              Text("Restore Successful"),
                            ],
                          ),
                          content: const Text(
                            "Your habits and data have been successfully restored from Google Drive!\n\n Build better habits. Live a better life.",
                            style: TextStyle(fontSize: 14, height: 1.4),
                          ),
                          actions: [
                            FilledButton.icon(
                              onPressed: () {
                                Navigator.pop(restartContext); 
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(builder: (context) => const HomeScreen()), 
                                  (Route<dynamic> route) => false,
                                );
                              },
                              icon: const Icon(Icons.rocket_launch_rounded),
                              label: const Text("Let's Go!", style: TextStyle(fontWeight: FontWeight.bold)),
                              style: FilledButton.styleFrom(backgroundColor: Colors.green),
                            ),
                          ],
                        );
                      },
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              },
              child: const Text("Restore Data", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  
  Future<void> _loadCustomRingtonePath() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _customRingtonePath = prefs.getString('custom_ringtone_path');
    });
  }

  
  Future<void> _pickCustomRingtone() async {
    bool hasPermission = await Permission.audio.request().isGranted || 
                        await Permission.storage.request().isGranted;

    if (hasPermission) {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio, 
      );

      if (result != null && result.files.single.path != null) {
        try {

          File pickedFile = File(result.files.single.path!);
          
          
          final Directory appDir = await getApplicationDocumentsDirectory();
          
          
          final String fileName = result.files.single.name;
          final String newSecurePath = '${appDir.path}/$fileName';
          
          
          final File savedFile = await pickedFile.copy(newSecurePath);
          
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('custom_ringtone_path', savedFile.path);
          
          await _refreshAllActiveAlarms();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("✅ Custom Ringtone Set Securely!"),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error saving ringtone: $e"), backgroundColor: Colors.redAccent),
            );
          }
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⚠️ Storage permission required to set ringtone."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  //  NAYA: Custom Ringtone remove function
  Future<void> _removeCustomRingtone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('custom_ringtone_path');
    await _refreshAllActiveAlarms();
    
    setState(() {
      _customRingtonePath = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ringtone reset to Default Alarm Sound."), backgroundColor: Colors.blueGrey),
      );
    }
  }

  
  //  UPGRADED MASTERPLAN: HABITS + FUTURE PENDING TASKS BOTH REFRESH LOGIC
  
  Future<void> _refreshAllActiveAlarms() async {
    try {
      final notificationService = NotificationService();
      final habitRepo = HabitRepository(); 
      final todoRepo = TodoRepository(); // 🚨 NAYA: Todo repository ka instance

      // 1. Sabse pehle saare scheduled notifications cancel 
      await notificationService.flutterLocalNotificationsPlugin.cancelAll();

      int successCount = 0; 

      
      // PART A: HABITS REFRESH 

      final allHabits = await habitRepo.getHabits(); 
      for (final habit in allHabits) {
        if (habit.isPaused == 0 && habit.isDeleted == 0 && habit.reminderTimes.isNotEmpty) {
          for (int i = 0; i < habit.reminderTimes.length; i++) {
            final timeString = habit.reminderTimes[i];
            if (timeString.contains(':')) {
              final timeParts = timeString.split(':');
              final hour = int.parse(timeParts[0]);
              final minute = int.parse(timeParts[1]);

              final safeId = (habit.id.hashCode + i).abs();
              await notificationService.scheduleDailyNotification(
                id: safeId, 
                title: habit.name,
                body: 'Time for your habit! (${i + 1}/${habit.timesPerDay}) 🚀', 
                time: TimeOfDay(hour: hour, minute: minute),
              );
              successCount++;
            }
          }
        }
      }

      
      // PART B: FUTURE PENDING TASKS REFRESH 
      
      
      DateTime today = DateTime.now();
      for (int dayOffset = 0; dayOffset <= 3; dayOffset++) {
        DateTime targetDate = today.add(Duration(days: dayOffset));
        String dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
        
        
        final dateTodos = await todoRepo.getTodosByDate(dateStr);
        
        for (final todo in dateTodos) {
          
          if (todo.isFocusMode == 1 && todo.isCompleted == 0 && todo.startTime != null) {
            
            final dateParts = todo.date.split('-');
            final year = int.parse(dateParts[0]);
            final month = int.parse(dateParts[1]);
            final day = int.parse(dateParts[2]);

            // 1. Start Time Alarm Setup
            final startParts = todo.startTime!.split(':');
            final startDateTime = DateTime(year, month, day, int.parse(startParts[0]), int.parse(startParts[1]));

            if (startDateTime.isAfter(DateTime.now())) {
              await notificationService.scheduleExactNotification(
                id: todo.id.hashCode.abs(), // .abs() protection
                title: 'Time to Focus! 🎯',
                body: 'Start working on: ${todo.title}',
                scheduledDate: startDateTime,
              );
              successCount++;
            }

            // 2. End Time Alarm Setup 
            if (todo.endTime != null && todo.endTime!.isNotEmpty) {
              final endParts = todo.endTime!.split(':');
              final endDateTime = DateTime(year, month, day, int.parse(endParts[0]), int.parse(endParts[1]));

              if (endDateTime.isAfter(DateTime.now())) {
                await notificationService.scheduleExactNotification(
                  id: (todo.id.hashCode + 1).abs(),
                  title: 'Time is Up! ⏰',
                  body: 'Wrap up your task: ${todo.title}',
                  scheduledDate: endDateTime,
                );
                successCount++;
              }
            }
          }
        }
      }

      // UX Diagnostic SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ Total $successCount active alarms successfully updated!"),
            backgroundColor: successCount > 0 ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("⚠️ System Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> makePhoneCall() async {
  final Uri phoneUri = Uri(
    scheme: 'tel',
    path: '9351076341',
  );

  if (await canLaunchUrl(phoneUri)) {
    await launchUrl(phoneUri);
  }
}


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeProvider); 
    final isDarkMode = themeMode == ThemeMode.dark || (themeMode == ThemeMode.system && theme.brightness == Brightness.dark);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: [
          
          
          // 1. CLOUD ACCOUNT SECTION (Replaced Local Backup)
          
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Text("Cloud Account", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          ),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (!_isGoogleLoggedIn) ...[
                    const Text(
                      "Secure your data permanently. Back up habits and logs to your personal Google Drive for free.",
                      style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _handleGoogleLogin,
                        icon: const Icon(Icons.cloud_queue_rounded),
                        label: const Text("Connect Google Drive", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                          backgroundImage: _googleUserPhoto != null ? NetworkImage(_googleUserPhoto!) : null,
                          child: _googleUserPhoto == null ? Icon(Icons.person, color: theme.colorScheme.primary) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_googleUserName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text(_googleUserEmail, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                          onPressed: _handleGoogleLogout,
                        )
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            onPressed: () async {
                              if (_googleSignIn.currentUser == null) return;
                              setState(() => _isLoading = true);
                              
                              final message = await CloudSyncService().backupToGoogleDrive(_googleSignIn.currentUser!);
                              
                              setState(() => _isLoading = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                              }
                            },
                            icon: const Icon(Icons.upload_rounded, size: 18),
                            label: const Text("Backup to Drive", style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            onPressed: () async {
                              if (_googleSignIn.currentUser == null) return;
                              setState(() => _isLoading = true);
                              
                              final message = await CloudSyncService().restoreFromGoogleDrive(_googleSignIn.currentUser!);
                              await DatabaseHelper.instance.clearDatabaseConnection();
                              setState(() => _isLoading = false);
                              
                              if (mounted) {
                                if (message.startsWith("✅")) {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false, 
                                    builder: (BuildContext restartContext) {
                                      return AlertDialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        title: const Row(
                                          children: [
                                            Icon(Icons.check_circle_rounded, color: Colors.green),
                                            SizedBox(width: 10),
                                            Text("Restore Successful"),
                                          ],
                                        ),
                                        content: const Text(
                                          "Your habits and data have been successfully restored from Google Drive!\n\nPlease restart the app to apply all the changes.",
                                          style: TextStyle(fontSize: 14, height: 1.4),
                                        ),
                                        actions: [
                                          FilledButton.icon(
                                            onPressed: () {
                                              Navigator.pop(restartContext); 
                                              Navigator.pushAndRemoveUntil(
                                                context,
                                                MaterialPageRoute(builder: (context) => const HomeScreen()), 
                                                (Route<dynamic> route) => false,
                                              );
                                            },
                                            icon: const Icon(Icons.rocket_launch_rounded),
                                            label: const Text("Go to Habit Board", style: TextStyle(fontWeight: FontWeight.bold)),
                                            style: FilledButton.styleFrom(backgroundColor: Colors.green),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: const Text("Restore from Drive", style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 24),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.autorenew_rounded, color: Colors.blue),
                      ),
                      title: const Text('Daily Auto Backup', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Silently back up data once a day', style: TextStyle(fontSize: 12)),
                      value: _autoBackupEnabled,
                      onChanged: _toggleAutoBackup,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          
          // 2. DATA MANAGEMENT (Categories & Habits)
          
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Text("Data Management", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          ),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.category_rounded, color: Colors.blue),
                  ),
                  title: const Text('Category List', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('View, edit, or delete categories', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CategoryListScreen()),
                    );
                  },
                ),
                Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3), indent: 60),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.list_alt_rounded, color: Colors.purple),
                  ),
                  title: const Text('Habit Archive', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Active, Paused, Completed & Deleted', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const HabitArchiveScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          
          // 3. PREFERENCES (Theme & Ringtone)
          
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Text("Preferences", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          ),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                // 🚨 NAYA: Working Theme Switcher
                SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: Colors.orange),
                  ),
                  title: const Text('Dark Theme', style: TextStyle(fontWeight: FontWeight.w600)),
                  value: isDarkMode,
                  onChanged: (val) {
                    ref.read(themeProvider.notifier).toggleTheme(val);
                  },
                ),
                Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3), indent: 60),
                //  WORKING: Custom Ringtone logic merged into modern UI
                //  SMART RINGTONE TILE
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.music_note_rounded, color: Colors.teal),
                  ),
                  title: const Text('Custom Ringtone', style: TextStyle(fontWeight: FontWeight.w600)),
                  
                  
                  subtitle: Text(
                    _customRingtonePath == null ? 'Default Alarm Sound' : 'Custom Ringtone Set', 
                    style: TextStyle(
                      fontSize: 12, 
                      color: _customRingtonePath == null ? Colors.grey : Colors.teal,
                      fontWeight: _customRingtonePath == null ? FontWeight.normal : FontWeight.bold,
                    )
                  ),
                  
                  // Icon badlega: Set nahi hai toh Arrow (>), set hai toh Cross (X)
                  trailing: _customRingtonePath == null 
                      ? const Icon(Icons.chevron_right, color: Colors.grey)
                      : IconButton(
                          icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent),
                          tooltip: 'Remove Custom Ringtone',
                          onPressed: _removeCustomRingtone, // Tap karne par remove hoga
                        ),
                        
                  // Tile par tap karne se naya pick hoga (Change karne ke liye)
                  onTap: _pickCustomRingtone,
                ),
                
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          
          Center(
            
            child: Text("Habitick $_appVersion", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
          Center(
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  fontSize: 10,
                  ),
              children: [
                const TextSpan(
                  text: "\n\nDeveloped by GROWLINER\nContact: ",
                ),
                TextSpan(
                  text: "9351076341",
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                recognizer: TapGestureRecognizer()
                ..onTap = () {
                  makePhoneCall();
                },
              ),
            ],
          ),
          ),
        ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}