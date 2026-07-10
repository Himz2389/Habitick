package com.example.habit_flow

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Build
import android.view.WindowManager
import android.app.NotificationManager


class MainActivity: FlutterActivity() {
    private val CHANNEL = "habitick/alarm_lock"


    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {

                "isFullScreenPermissionGranted" -> {

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {

                        val manager =
                            getSystemService(NotificationManager::class.java)

                        result.success(manager.canUseFullScreenIntent())

                    } else {

                        result.success(true)

                    }
                }

                "wakeUpScreen" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                        setShowWhenLocked(true)
                        setTurnScreenOn(true)
                        
                    } else {
                        @Suppress("DEPRECATION")
                        window.addFlags(
                            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or 
                            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or 
                            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                        )
                    }
                    result.success(true)
                }
                "sleepScreen" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                        setShowWhenLocked(false)
                        setTurnScreenOn(false)
                    } else {
                        @Suppress("DEPRECATION")
                        window.clearFlags(
                            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or 
                            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                        )
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}