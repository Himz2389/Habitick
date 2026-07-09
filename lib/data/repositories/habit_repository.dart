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
    final List<Map<String, dynamic>> maps = await db.query(
      'habits',
      orderBy: 'categoryId ASC, display_order ASC',
    );
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
      orderBy: 'display_order ASC',
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

  Future<int> getNextDisplayOrder(String categoryId) async {
    final Database db = await _dbHelper.database;

    final result = await db.rawQuery(
      '''
    SELECT MAX(display_order) as maxOrder
    FROM habits
    WHERE categoryId = ?
    ''',
      [categoryId],
    );

    final maxOrder = result.first['maxOrder'] as int?;

    return (maxOrder ?? -1) + 1;
  }

  // 5. Delete Habit
  Future<int> deleteHabit(String id) async {
    final Database db = await _dbHelper.database;
    return await db.delete('habits', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateHabitOrders(List<HabitModel> habits) async {
    final Database db = await _dbHelper.database;

    await db.transaction((txn) async {
      for (final habit in habits) {
        await txn.update(
          'habits',
          {'display_order': habit.displayOrder},
          where: 'id = ?',
          whereArgs: [habit.id],
        );
      }
    });
  }
}
