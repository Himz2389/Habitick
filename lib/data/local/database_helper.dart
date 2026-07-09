import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  // Singleton Pattern
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  DatabaseHelper._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'habit_flow.db');

    return await openDatabase(
      path,
      version: 6, 
      onCreate: _onCreate,
      onUpgrade:
          _onUpgrade, 
    );
  }

  //  NAYA UPGRADE FUNCTION (Data Safe Rakhega)
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Agar user ke paas version 1 hai, toh usme bina data udaye sirf journal table jod do
      await db.execute('''
        CREATE TABLE journals (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          content TEXT NOT NULL, -- Isme tumhara Rich Text, Image, Colors sab JSON format mein save hoga
          date TEXT NOT NULL,
          mood TEXT,
          createdAt TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 3) {
      // 1. isCompleted column 
      try {
        await db.execute(
          "ALTER TABLE habits ADD COLUMN isCompleted INTEGER DEFAULT 0",
        );
      } catch (e) {
        print("isCompleted column error: $e");
      }

      // 2. isDeleted column 
      try {
        await db.execute(
          "ALTER TABLE habits ADD COLUMN isDeleted INTEGER DEFAULT 0",
        );
      } catch (e) {
        print("isDeleted column error: $e");
      }
    }
    if (oldVersion < 4) {
      // 3. timesPerDay column 
      try {
        await db.execute(
          "ALTER TABLE habits ADD COLUMN timesPerDay INTEGER DEFAULT 1",
        );
      } catch (e) {
        print("timesPerDay column error: $e");
      }

      // 4. reminderTimes column 
      try {
        await db.execute(
          "ALTER TABLE habits ADD COLUMN reminderTimes TEXT",
        );
      } catch (e) {
        print("reminderTimes column error: $e");
      }

      // 5. pauseLogs column 
      try {
        await db.execute(
          "ALTER TABLE habits ADD COLUMN pauseLogs TEXT DEFAULT '[]'",
        );
      } catch (e) {
        print("pauseLogs column error: $e");
      }
    }

    if (oldVersion < 5) {
      try {
        await db.execute("ALTER TABLE habits ADD COLUMN deletedAt TEXT");
        print("✅ deletedAt column added successfully!");
      } catch (e) {
        print("⚠️ deletedAt column error: $e");
      }
    }

    if (oldVersion < 6) {
      try {
        await db.execute(
          "ALTER TABLE habits ADD COLUMN display_order INTEGER DEFAULT 0",
        );

        print("✅ display_order column added!");
      } catch (e) {
        print("⚠️ display_order migration: $e");
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Users Table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fullName TEXT,
        username TEXT,
        mobileNumber TEXT,
        email TEXT,
        password TEXT,
        profilePhoto TEXT
      )
    ''');

    // 2. Categories Table
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color TEXT NOT NULL
      )
    ''');

    // 3. Habits Table
    await db.execute('''
      CREATE TABLE habits (
        id TEXT PRIMARY KEY,
        categoryId TEXT,
        name TEXT NOT NULL,
        priority TEXT NOT NULL,
        activeDays TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        category TEXT,         
        color TEXT,
        deletedAt TEXT,            
        isPaused INTEGER DEFAULT 0,
        isCompleted INTEGER DEFAULT 0,
        isDeleted INTEGER DEFAULT 0,    
        timesPerDay INTEGER DEFAULT 1, 
        reminderTimes TEXT,
        pauseLogs TEXT DEFAULT '[]',
        display_order INTEGER DEFAULT 0,    
        
        FOREIGN KEY (categoryId) REFERENCES categories (id) ON DELETE CASCADE
      )
    ''');

    // 4. HabitDays Table
    await db.execute('''
      CREATE TABLE habit_days (
        id TEXT PRIMARY KEY,
        habitId TEXT,
        dayOfWeek INTEGER NOT NULL,
        FOREIGN KEY (habitId) REFERENCES habits (id) ON DELETE CASCADE
      )
    ''');

    // 5. HabitCompletions Table
    await db.execute('''
      CREATE TABLE habit_completions (
        id TEXT PRIMARY KEY,
        habitId TEXT,
        date TEXT NOT NULL,
        isCompleted INTEGER NOT NULL,
        FOREIGN KEY (habitId) REFERENCES habits (id) ON DELETE CASCADE
      )
    ''');

    // 6. Streaks Table
    await db.execute('''
      CREATE TABLE streaks (
        habitId TEXT PRIMARY KEY,
        currentStreak INTEGER DEFAULT 0,
        bestStreak INTEGER DEFAULT 0,
        totalCompletions INTEGER DEFAULT 0,
        FOREIGN KEY (habitId) REFERENCES habits (id) ON DELETE CASCADE
      )
    ''');

    // 7. Reminders Table
    await db.execute('''
      CREATE TABLE reminders (
        id TEXT PRIMARY KEY,
        habitId TEXT,
        time TEXT NOT NULL,
        isOn INTEGER DEFAULT 1,
        FOREIGN KEY (habitId) REFERENCES habits (id) ON DELETE CASCADE
      )
    ''');

    // 8. Todos Table
    await db.execute('''
      CREATE TABLE todos (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        isCompleted INTEGER NOT NULL,
        priority TEXT NOT NULL,
        isFocusMode INTEGER DEFAULT 0,
        startTime TEXT,
        endTime TEXT
      )
    ''');

    // 9. AnalyticsCache Table
    await db.execute('''
      CREATE TABLE analytics_cache (
        id TEXT PRIMARY KEY,
        monthYear TEXT NOT NULL,
        completionRate REAL DEFAULT 0.0,
        totalCompleted INTEGER DEFAULT 0
      )
    ''');

    // 10. Journals Table ( NAYI TABLE FRESH INSTALL KE LIYE)
    await db.execute('''
      CREATE TABLE journals (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        date TEXT NOT NULL,
        mood TEXT,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  
  //  CATEGORY CRUD OPERATIONS
  
  Future<int> insertCategory(Map<String, dynamic> category) async {
    final db = await database;
    return await db.insert(
      'categories',
      category,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    return await db.query('categories');
  }

  Future<int> deleteCategory(String id) async {
    final db = await database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateCategory(Map<String, dynamic> category) async {
    final db = await database;
    return await db.update(
      'categories',
      category,
      where: 'id = ?',
      whereArgs: [category['id']],
    );
  }

  //  HABIT CRUD OPERATIONS

  Future<int> insertHabit(Map<String, dynamic> habit) async {
    final db = await database;
    return await db.insert(
      'habits',
      habit,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getHabits() async {
    final db = await database;
    return await db.query('habits');
  }

  Future<int> updateHabit(Map<String, dynamic> habit) async {
    final db = await database;
    return await db.update(
      'habits',
      habit,
      where: 'id = ?',
      whereArgs: [habit['id']],
    );
  }

  Future<int> deleteHabit(String id) async {
    final db = await database;
    return await db.delete('habits', where: 'id = ?', whereArgs: [id]);
  }


    //  REMINDER CRUD OPERATIONS

  Future<int> insertReminder(Map<String, dynamic> reminder) async {
    final db = await database;
    return await db.insert(
      'reminders',
      reminder,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getReminders() async {
    final db = await database;
    return await db.query('reminders');
  }

  Future<int> updateReminder(Map<String, dynamic> reminder) async {
    final db = await database;
    return await db.update(
      'reminders',
      reminder,
      where: 'id = ?',
      whereArgs: [reminder['id']],
    );
  }

  Future<int> deleteReminder(String id) async {
    final db = await database;
    return await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }


  //  JOURNAL CRUD OPERATIONS 
  
  Future<int> insertJournal(Map<String, dynamic> journal) async {
    final db = await database;
    return await db.insert(
      'journals',
      journal,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getJournals() async {
    final db = await database;
    // Date ke hisaab se sabse naya journal sabse upar aayega
    return await db.query('journals', orderBy: 'date DESC');
  }

  Future<int> updateJournal(Map<String, dynamic> journal) async {
    final db = await database;
    return await db.update(
      'journals',
      journal,
      where: 'id = ?',
      whereArgs: [journal['id']],
    );
  }

  Future<int> deleteJournal(String id) async {
    final db = await database;
    return await db.delete('journals', where: 'id = ?', whereArgs: [id]);
  }

  //  Purane connection ko memory se saaf karne ke liye
  Future<void> clearDatabaseConnection() async {
    if (_database != null) {
      await _database!.close();
      _database = null; // Flutter Phoenix ekdum naya data padhega
    }
  }
  
}
