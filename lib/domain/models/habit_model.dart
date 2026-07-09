import 'dart:convert';

class HabitModel {
  final String id;
  final String categoryId;
  final String name;
  final String priority;
  final List<int> activeDays;
  final String createdAt;
  final String category;
  final String color;
  final int isPaused;
  final int isCompleted;
  final int isDeleted; 
  final String? deletedAt; 
  final int timesPerDay;
  final List<String> reminderTimes;
  final List<String> pauseLogs;
  final int displayOrder;


  HabitModel({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.priority,
    required this.activeDays,
    required this.createdAt,
    required this.category,
    required this.color,
    required this.isPaused,
    this.isCompleted = 0,
    this.isDeleted = 0, 
    this.deletedAt, 
    required this.timesPerDay,
    required this.reminderTimes,
    this.pauseLogs = const [], 
    required this.displayOrder,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'categoryId': categoryId,
      'name': name,
      'priority': priority,
      'activeDays': jsonEncode(activeDays), 
      'createdAt': createdAt,
      'category': category,
      'color': color,
      'isPaused': isPaused,
      'isCompleted': isCompleted, 
      'isDeleted': isDeleted, 
      'deletedAt': deletedAt, 
      'timesPerDay': timesPerDay,
      'reminderTimes': jsonEncode(reminderTimes), 
      'pauseLogs': jsonEncode(pauseLogs), 
      'display_order': displayOrder,
    };
  }

  factory HabitModel.fromMap(Map<String, dynamic> map) {
    return HabitModel(
      id: map['id'] ?? '',
      categoryId: map['categoryId'] ?? '',
      name: map['name'] ?? '',
      priority: map['priority'] ?? 'Medium',
      activeDays: List<int>.from(jsonDecode(map['activeDays'] ?? '[]')),
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      category: map['category'] ?? '',
      color: map['color'] ?? '',
      isPaused: map['isPaused'] ?? 0,
      isCompleted: map['isCompleted'] ?? 0, 
      isDeleted: map['isDeleted'] ?? 0, 
      deletedAt: map['deletedAt'], 
      timesPerDay: map['timesPerDay'] ?? 1,
      reminderTimes: List<String>.from(jsonDecode(map['reminderTimes'] ?? '[]')),
      pauseLogs: map['pauseLogs'] != null ? List<String>.from(jsonDecode(map['pauseLogs'])) : [],
      displayOrder: map['display_order'] != null ? map['display_order'] as int : 0,
    );
  }

  HabitModel copyWith({
    String? id,
    String? categoryId,
    String? name,
    String? priority,
    List<int>? activeDays,
    String? createdAt,
    String? category,
    String? color,
    int? isPaused,
    int? isCompleted,
    int? isDeleted, 
    String? deletedAt, 
    int? timesPerDay,
    List<String>? reminderTimes,
    List<String>? pauseLogs,
    int? displayOrder,
  }) {
    return HabitModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      priority: priority ?? this.priority,
      activeDays: activeDays ?? this.activeDays,
      createdAt: createdAt ?? this.createdAt,
      category: category ?? this.category,
      color: color ?? this.color,
      isPaused: isPaused ?? this.isPaused,
      isCompleted: isCompleted ?? this.isCompleted,
      isDeleted: isDeleted ?? this.isDeleted, 
      deletedAt: deletedAt ?? this.deletedAt, 
      timesPerDay: timesPerDay ?? this.timesPerDay,
      reminderTimes: reminderTimes ?? this.reminderTimes,
      pauseLogs: pauseLogs ?? this.pauseLogs, 
      displayOrder: displayOrder ?? this.displayOrder,
    );
  }
}