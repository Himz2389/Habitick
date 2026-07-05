class TodoModel {
  final String id;
  final String title;
  final String description;
  final String date;
  final int isCompleted;
  final String priority;
  final int isFocusMode;   
  final String? startTime; 
  final String? endTime;   

  TodoModel({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.isCompleted,
    required this.priority,
    this.isFocusMode = 0, // Default value
    this.startTime,
    this.endTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date,
      'isCompleted': isCompleted,
      'priority': priority,
      'isFocusMode': isFocusMode,
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  factory TodoModel.fromMap(Map<String, dynamic> map) {
    return TodoModel(
      id: map['id'] ?? '', 
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      date: map['date'] ?? '',
      isCompleted: map['isCompleted'] ?? 0,
      priority: map['priority'] ?? 'Medium',
      isFocusMode: map['isFocusMode'] ?? 0,
      startTime: map['startTime'], 
      endTime: map['endTime'],     
    );
  }
}