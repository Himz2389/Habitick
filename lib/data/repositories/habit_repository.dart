import 'package:sqflite/sqflite.dart';
import 'package:habit_flow/data/local/database_helper.dart';
import 'package:habit_flow/domain/models/habit_model.dart';

class HabitRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // 1. Create Habit
  Future<int> insertHabit(HabitModel habit) async {
    final Database db = await _dbHelper.database;
    return await db.insert(
      'habits',
      habit.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // 2. Read All Habits
  Future<List<HabitModel>> getHabits() async {
    final Database db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('habits');

    return List.generate(maps.length, (i) {
      return HabitModel.fromMap(maps[i]);
    });
  }

  // 3. Read Habits by Category (Kisi ek category ki habits dekhna)
  Future<List<HabitModel>> getHabitsByCategory(String categoryId) async {
    final Database db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'habits',
      where: 'categoryId = ?',
      whereArgs: [categoryId],
    );

    return List.generate(maps.length, (i) {
      return HabitModel.fromMap(maps[i]);
    });
  }

  // 4. Update Habit
  Future<int> updateHabit(HabitModel habit) async {
    final Database db = await _dbHelper.database;
    return await db.update(
      'habits',
      habit.toMap(),
      where: 'id = ?',
      whereArgs: [habit.id],
    );
  }

  // 5. Delete Habit
  Future<int> deleteHabit(String id) async {
    final Database db = await _dbHelper.database;
    return await db.delete(
      'habits',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}