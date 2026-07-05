import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:file_picker/file_picker.dart';

class BackupService {
  // 1. Data Export (Save Backup)
  Future<String> exportDatabase() async {
    try {
      final dbPath = join(await getDatabasesPath(), 'habit_flow.db');
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        return 'No data found to backup!';
      }

      
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save HabitFlow Backup',
        fileName: 'habit_flow_backup.db',
      );

      if (outputFile != null) {
        await dbFile.copy(outputFile);
        return 'Backup successfully saved! 🎉';
      }
      return 'Backup cancelled.';
    } catch (e) {
      return 'Error exporting backup: $e';
    }
  }

  // 2. Data Import (Restore Backup)
  Future<String> importDatabase() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select HabitFlow Backup File',
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        File backupFile = File(result.files.single.path!);
        
        if (!backupFile.path.endsWith('.db')) {
          return 'Invalid file! Please select a .db backup file.';
        }

        final dbPath = join(await getDatabasesPath(), 'habit_flow.db');
        
        // Purane database ko naye backup se replace karna
        await backupFile.copy(dbPath);
        return 'Restore successful! 🎉 Please restart the app.';
      }
      return 'Restore cancelled.';
    } catch (e) {
      return 'Error restoring backup: $e';
    }
  }
}