import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'package:habit_flow/core/services/cloud_sync_service.dart';

const String dailyBackupUniqueName = 'habitick_daily_backup';
const String dailyBackupTaskName = 'dailyBackupTask';

// Runs in a separate background isolate spawned by WorkManager, so it has no
// access to the running app's state — everything it needs (the toggle, the
// Google session) has to be re-read from disk / re-authenticated here.
@pragma('vm:entry-point')
void backupCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != dailyBackupTaskName) return true;

    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('auto_backup_enabled') ?? false)) return true;

    try {
      final googleSignIn = GoogleSignIn(
        scopes: const ['email', 'https://www.googleapis.com/auth/drive.appdata'],
      );
      final account = await googleSignIn.signInSilently();
      if (account == null) return true;

      await CloudSyncService().backupToGoogleDrive(account);
    } catch (_) {
      // Let WorkManager retry on the next scheduled run rather than crashing
      // the background isolate over a transient network/auth failure.
    }

    return true;
  });
}
