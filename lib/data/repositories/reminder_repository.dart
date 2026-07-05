import 'package:sqflite/sqflite.dart';
import 'package:habit_flow/data/local/database_helper.dart';
import 'package:habit_flow/domain/models/reminder_model.dart';

class ReminderRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Naya reminder save karna
  Future<int> insertReminder(ReminderModel reminder) async {
    final Database db = await _dbHelper.database;
    return await db.insert(
      'reminders',
      reminder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  //  NAYA: Saare reminders ek sath nikalna
  Future<List<ReminderModel>> getAllReminders() async {
    final Database db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('reminders');
    return List.generate(maps.length, (i) => ReminderModel.fromMap(maps[i]));
  }

  // Kisi ek habit ka reminder nikalna
  Future<List<ReminderModel>> getRemindersByHabit(String habitId) async {
    final Database db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reminders',
      where: 'habitId = ?',
      whereArgs: [habitId],
    );
    return List.generate(maps.length, (i) => ReminderModel.fromMap(maps[i]));
  }

  // Reminder update karna (ON/OFF ya Time change)
  Future<int> updateReminder(ReminderModel reminder) async {
    final Database db = await _dbHelper.database;
    return await db.update(
      'reminders',
      reminder.toMap(),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
  }

  // Reminder delete karna
  Future<int> deleteReminder(String id) async {
    final Database db = await _dbHelper.database;
    return await db.delete(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}