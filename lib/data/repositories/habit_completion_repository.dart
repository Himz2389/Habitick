import 'package:sqflite/sqflite.dart';
import 'package:habit_flow/data/local/database_helper.dart';
import 'package:habit_flow/domain/models/habit_completion_model.dart';

class HabitCompletionRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Habit ko complete mark karna ya un-mark karna (Toggle)
  Future<int> toggleCompletion(HabitCompletionModel completion) async {
    final Database db = await _dbHelper.database;
    
    // Pehle check karte hain ki is date par is habit ka record pehle se hai ya nahi
    final List<Map<String, dynamic>> existing = await db.query(
      'habit_completions',
      where: 'habitId = ? AND date = ?',
      whereArgs: [completion.habitId, completion.date],
    );

    if (existing.isNotEmpty) {
      // Agar record hai, to usko update kar do (jaise 0 se 1, ya 1 se 0)
      return await db.update(
        'habit_completions',
        completion.toMap(),
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      // Agar us din pehli baar tick kiya hai, to naya record insert 
      return await db.insert(
        'habit_completions',
        completion.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // Saari completions nikalna UI mein dikhane ke liye
  Future<List<HabitCompletionModel>> getAllCompletions() async {
    final Database db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('habit_completions');

    return List.generate(maps.length, (i) {
      return HabitCompletionModel.fromMap(maps[i]);
    });
  }
}