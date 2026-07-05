class JournalModel {
  final String id;
  final String title;
  final String content;
  final String date;
  final String? mood;
  final String createdAt;

  JournalModel({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    this.mood,
    required this.createdAt,
  });

  // 1. Map se Model banaya (Database se padhne ke liye)
  factory JournalModel.fromMap(Map<String, dynamic> map) {
    return JournalModel(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      date: map['date'],
      mood: map['mood'],
      createdAt: map['createdAt'],
    );
  }

  // 2. Model se Map banaya (Database mein save karne ke liye)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'date': date,
      'mood': mood,
      'createdAt': createdAt,
    };
  }
}