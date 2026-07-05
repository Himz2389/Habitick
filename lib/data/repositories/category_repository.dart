import 'package:sqflite/sqflite.dart';
import 'package:habit_flow/data/local/database_helper.dart';
import 'package:habit_flow/domain/models/category_model.dart';

class CategoryRepository {
  // DatabaseHelper ka instance mangwana
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // 1. Create: Nayi category database mein daalna
  Future<int> insertCategory(CategoryModel category) async {
    final Database db = await _dbHelper.database;
    return await db.insert(
      'categories',
      category.toMap(), // Model ko Map mein convert karke save kar raha hai
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // 2. Read: Saari categories database se nikalna
  Future<List<CategoryModel>> getCategories() async {
    final Database db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('categories');

    // Database ke Map ko wapas CategoryModel mein convert kar raha hai
    return List.generate(maps.length, (i) {
      return CategoryModel.fromMap(maps[i]);
    });
  }

  // 3. Update: Kisi existing category ko edit karna
  Future<int> updateCategory(CategoryModel category) async {
    final Database db = await _dbHelper.database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?', 
      whereArgs: [category.id],
    );
  }

  // 4. Delete: Category ko delete karna
  Future<int> deleteCategory(String id) async {
    final Database db = await _dbHelper.database;
    return await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}