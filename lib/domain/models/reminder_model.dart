class ReminderModel {
  final String id;
  final String habitId;
  final String time; // Format: "HH:mm" (Jaise 18:30)
  final int isOn; // 1 for ON, 0 for OFF

  ReminderModel({
    required this.id,
    required this.habitId,
    required this.time,
    this.isOn = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'habitId': habitId,
      'time': time,
      'isOn': isOn,
    };
  }

  factory ReminderModel.fromMap(Map<String, dynamic> map) {
    return ReminderModel(
      id: map['id'] as String,
      habitId: map['habitId'] as String,
      time: map['time'] as String,
      isOn: map['isOn'] as int,
    );
  }
}