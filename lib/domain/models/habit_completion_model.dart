class HabitCompletionModel {
  final String id;
  final String habitId;
  final String date; // Format: YYYY-MM-DD
  final int isCompleted; 

  HabitCompletionModel({
    required this.id,
    required this.habitId,
    required this.date,
    required this.isCompleted,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'habitId': habitId,
      'date': date,
      'isCompleted': isCompleted,
    };
  }

  factory HabitCompletionModel.fromMap(Map<String, dynamic> map) {
    return HabitCompletionModel(
      id: map['id'] as String,
      habitId: map['habitId'] as String,
      date: map['date'] as String,
      isCompleted: map['isCompleted'] as int,
    );
  }
}