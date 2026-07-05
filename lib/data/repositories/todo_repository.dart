import 'package:sqflite/sqflite.dart';
import 'package:habit_flow/data/local/database_helper.dart';
import 'package:habit_flow/domain/models/todo_model.dart';

class TodoRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Create: Naya task add karna
  Future<int> insertTodo(TodoModel todo) async {
    final Database db = await _dbHelper.database;
    return await db.insert(
      'todos', 
      todo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Kisi specific date ke tasks nikalna ( To-Do day-by-day hoga)
  Future<List<TodoModel>> getTodosByDate(String date) async {
    final Database db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'todos',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'isCompleted ASC', // Adhoore tasks upar, completed neeche
    );

    return List.generate(maps.length, (i) {
      return TodoModel.fromMap(maps[i]);
    });
  }

  // Update: Task ka text ya detail change karna
  Future<int> updateTodo(TodoModel todo) async {
    final Database db = await _dbHelper.database;
    return await db.update(
      'todos',
      todo.toMap(),
      where: 'id = ?',
      whereArgs: [todo.id],
    );
  }

  // Toggle Completion: Task par tick lagana ya hatana
  Future<int> toggleTodoCompletion(String id, int currentStatus) async {
    final Database db = await _dbHelper.database;
    int newStatus = currentStatus == 1 ? 0 : 1;
    return await db.rawUpdate(
      'UPDATE todos SET isCompleted = ? WHERE id = ?',
      [newStatus, id],
    );
  }

  // Delete: Task delete karna
  Future<int> deleteTodo(String id) async {
    final Database db = await _dbHelper.database;
    return await db.delete(
      'todos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}