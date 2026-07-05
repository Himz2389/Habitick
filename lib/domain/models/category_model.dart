class CategoryModel {
  final String id;
  final String name;
  final String color;

  CategoryModel({
    required this.id,
    required this.name,
    required this.color,
  });

  // App data ko Database map mein convert karne ke liye
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
    };
  }

  // Database map ko wapas App data (Dart Object) mein convert karne ke liye
  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String,
      name: map['name'] as String,
      color: map['color'] as String,
    );
  }
}