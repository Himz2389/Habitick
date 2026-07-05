import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart'; 


class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}


class CloudSyncService {
  final String dbName = 'habit_flow.db'; 

  
  // UPLOAD: Phone se Google Drive (Backup)
  
  Future<String> backupToGoogleDrive(GoogleSignInAccount account) async {
    try {
      final authHeaders = await account.authHeaders;
      final authenticateClient = GoogleAuthClient(authHeaders);
      final driveApi = drive.DriveApi(authenticateClient);

      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      final dbPath = join(documentsDirectory.path, dbName);
      final file = File(dbPath);

      if (!await file.exists()) {
        return "⚠️ No local database found to backup!";
      }

      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder', 
        q: "name = '$dbName'",
      );

      
      // CONDITION 1: Purana backup UPDATE karna hai
      
      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final fileId = fileList.files!.first.id!;
        var updateFile = drive.File(); 
        
        await driveApi.files.update(
          updateFile, 
          fileId, 
          uploadMedia: drive.Media(file.openRead(), file.lengthSync())
        );
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_backup_date', DateTime.now().toIso8601String());

        return "✅ Backup Updated on Google Drive Successfully!";
      } 
      
      // CONDITION 2: Pehli baar NAYA backup CREATE karna 
      
      else {
        var createFile = drive.File();
        createFile.name = dbName;
        createFile.parents = ['appDataFolder']; 

        await driveApi.files.create(
          createFile, 
          uploadMedia: drive.Media(file.openRead(), file.lengthSync())
        );
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_backup_date', DateTime.now().toIso8601String());
        
        return "✅ Backup Created on Google Drive Successfully!";
      }
    } catch (e) {
      return "❌ Backup Failed: $e";
    }
  }

  
  // DOWNLOAD: Google Drive se Phone (Restore)
  
  Future<String> restoreFromGoogleDrive(GoogleSignInAccount account) async {
    try {
      
      final authHeaders = await account.authHeaders;
      final authenticateClient = GoogleAuthClient(authHeaders);
      final driveApi = drive.DriveApi(authenticateClient);

      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder', 
        q: "name = '$dbName'",
      );

      if (fileList.files == null || fileList.files!.isEmpty) {
        return "⚠️ No backup found on Google Drive!";
      }

      final fileId = fileList.files!.first.id!;
      final drive.Media media = await driveApi.files.get(
        fileId, 
        downloadOptions: drive.DownloadOptions.fullMedia
      ) as drive.Media;
      
      
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      final dbPath = join(documentsDirectory.path, dbName);
      final file = File(dbPath);
      
      final sink = file.openWrite();
      await media.stream.forEach((chunk) {
        sink.add(chunk);
      });
      await sink.close();

      return "✅ Data Restored! Please restart the app to see changes.";
    } catch (e) {
      return "❌ Restore Failed: $e";
    }
  }
  
  
  
  Future<bool> checkForExistingBackup(GoogleSignInAccount account) async {
    try {
      final authHeaders = await account.authHeaders;
      final authenticateClient = GoogleAuthClient(authHeaders);
      final driveApi = drive.DriveApi(authenticateClient);

      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder', 
        q: "name = '$dbName'",
      );


      return fileList.files != null && fileList.files!.isNotEmpty;
    } catch (e) {
      return false; 
    }
  }
}