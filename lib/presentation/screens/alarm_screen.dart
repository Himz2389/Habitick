import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:habit_flow/core/services/notification_service.dart';

class AlarmScreen extends StatefulWidget {
  final int id;
  final String title;
  final String description;
  final bool isTask;

  const AlarmScreen({
    super.key,
    required this.id,
    required this.title,
    required this.description,
    this.isTask = false,
  });

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  static const platform = MethodChannel('habitick/alarm_lock');
  
  // 🚨 NAYA: Audio player ka instance banaya
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isCustomSoundPlaying = false;

  @override
  void initState() {
    super.initState();
    _wakeUpLockScreen(); 
    _playCustomSoundIfNeeded();
  }

  Future<void> _wakeUpLockScreen() async {
    try {
      await platform.invokeMethod('wakeUpScreen');
    } catch (e) {
      debugPrint("Lock screen bypass failed: $e");
    }
  }

  Future<void> _releaseLockScreen() async {
    try {
      await platform.invokeMethod('sleepScreen');
    } catch (e) {
      debugPrint("Releasing lock screen failed: $e");
    }
  }

  // 🚨 UPDATED: Audioplayers ke through raw file bajayega
  Future<void> _playCustomSoundIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final customPath = prefs.getString('custom_ringtone_path');

    
    if (customPath != null && customPath.isNotEmpty && File(customPath).existsSync()) {
      try {
        await _audioPlayer.setReleaseMode(ReleaseMode.loop); // Continuous bajega
        await _audioPlayer.play(DeviceFileSource(customPath)); // 🚨 Ye raw path perfectly play karega!
        _isCustomSoundPlaying = true;
      } catch (e) {
        debugPrint("Custom Ringtone Play Error: $e");
      }
    }
  }


  void _onNotNow() async {
    if (_isCustomSoundPlaying) {
      await _audioPlayer.stop(); // 🚨 NAYA: Player roko
    }
    
    NotificationService().cancelNotification(widget.id); 
    
    if (widget.isTask) {
      NotificationService().cancelNotification(widget.id + 1);
    }
    await _releaseLockScreen(); 
    SystemNavigator.pop();
  }

  
  void _onStart() async {
    if (_isCustomSoundPlaying) {
      await _audioPlayer.stop(); // 🚨 NAYA: Player roko
    }
    
    NotificationService().cancelNotification(widget.id); 

    await _releaseLockScreen(); 
    SystemNavigator.pop();
  }


  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
  
    return PopScope(
      canPop: false, 
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        
        _onNotNow(); 
      },
      child: Scaffold(
        backgroundColor: Colors.black87,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.alarm_on, size: 100, color: Colors.blueAccent),
                  const SizedBox(height: 30),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, color: Colors.white70),
                  ),
                  const SizedBox(height: 60),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // NOT NOW BUTTON
                      if(widget.isTask)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                        icon: const Icon(Icons.close, color: Colors.white),
                        label: const Text("I can't", style: TextStyle(color: Colors.white, fontSize: 18)),
                        onPressed: _onNotNow,
                      ),

                      
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                        icon: const Icon(Icons.play_arrow, color: Colors.white),
                        label: const Text("Let's Go!", style: TextStyle(color: Colors.white, fontSize: 18)),
                        onPressed: _onStart,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}