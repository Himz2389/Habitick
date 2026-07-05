import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_flow/domain/models/category_model.dart';
import 'package:habit_flow/data/repositories/category_repository.dart';

// 1. Repository ko Riverpod mein inject karna 
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository();
});

// 2. StateNotifier 
class CategoryNotifier extends StateNotifier<List<CategoryModel>> {
  final CategoryRepository _repository;

  
  CategoryNotifier(this._repository) : super([]) {
    loadCategories();
  }

  // Read: Database se saari categories lana
  Future<void> loadCategories() async {
    final categories = await _repository.getCategories();
    state = categories; 
  }

  // Create: Nayi category add karna aur list update karna
  Future<void> addCategory(CategoryModel category) async {
    await _repository.insertCategory(category);
    await loadCategories();
  }

  // Update: Kisi category ko edit karna
  Future<void> updateCategory(CategoryModel category) async {
    await _repository.updateCategory(category);
    await loadCategories();
  }

  // Delete: Category ko delete karna
  Future<void> deleteCategory(String id) async {
    await _repository.deleteCategory(id);
    await loadCategories();
  }
}

// 3. Main Provider
final categoryProvider = StateNotifierProvider<CategoryNotifier, List<CategoryModel>>((ref) {
  final repository = ref.watch(categoryRepositoryProvider);
  return CategoryNotifier(repository);
});