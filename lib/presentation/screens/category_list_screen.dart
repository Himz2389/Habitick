import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'package:habit_flow/domain/models/category_model.dart';
import 'package:habit_flow/presentation/providers/category_provider.dart';
import 'package:habit_flow/presentation/providers/habit_provider.dart';

class CategoryListScreen extends ConsumerWidget {
  const CategoryListScreen({super.key});

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString));
    } catch (e) {
      return Colors.blue; 
    }
  }

  void _showEditCategoryDialog(BuildContext context, WidgetRef ref, CategoryModel category) {
    final nameController = TextEditingController(text: category.name);
    Color pickerColor = _parseColor(category.color);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Edit Category', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Category Name', border: OutlineInputBorder()),
                      autofocus: true,
                    ),
                    const SizedBox(height: 20),
                    const Text('Update Panel Color:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ColorPicker(
                      pickerColor: pickerColor,
                      onColorChanged: (color) { setDialogState(() { pickerColor = color; }); },
                      pickerAreaHeightPercent: 0.4,
                      enableAlpha: false,
                      displayThumbColor: true,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.trim().isNotEmpty) {
                      String hexColor = '0xFF${pickerColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                      final updatedCategory = CategoryModel(id: category.id, name: nameController.text.trim(), color: hexColor);
                      
                      // 1. Category ka color update 
                      ref.read(categoryProvider.notifier).updateCategory(updatedCategory);
                      
                      
                      //  Habits color sync 
                      
                      ref.read(habitProvider.notifier).syncCategoryColor(updatedCategory.id, hexColor);
                      
                      Navigator.pop(context);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Category and Habits updated successfully!'), backgroundColor: Colors.green),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  
  void _confirmDelete(BuildContext context, WidgetRef ref, CategoryModel category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Category?'),
        content: Text('Are you sure you want to delete "${category.name}"?\n\nActive and Paused habits inside this category will move to Trash. Completed habits will remain safe in your history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final allHabits = ref.read(habitProvider);
              final affectedHabits = allHabits.where((h) => h.categoryId == category.id).toList();
              
              for (var habit in affectedHabits) {
                // 🚨 SMART CHECK: Agar habit complete NAHI hai, tabhi Trash me bhejo
                if (habit.isCompleted == 0) {
                  ref.read(habitProvider.notifier).updateHabit(habit.copyWith(isDeleted: 1));
                }
                
              }

              
              ref.read(categoryProvider.notifier).deleteCategory(category.id);
              
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${category.name} deleted! Active habits moved to Trash.'), backgroundColor: Colors.redAccent),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
  

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Manage Categories', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: categories.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category_outlined, size: 80, color: Colors.grey.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text('No categories found.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text('Add categories while creating a habit!', style: TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final categoryColor = _parseColor(category.color);

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: categoryColor.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: categoryColor, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          category.name.isNotEmpty ? category.name[0].toUpperCase() : '?',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: categoryColor),
                        ),
                      ),
                    ),
                    title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                          tooltip: 'Edit Category',
                          onPressed: () => _showEditCategoryDialog(context, ref, category),
                        ),
                        
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          tooltip: 'Delete Category',
                          onPressed: () => _confirmDelete(context, ref, category), 
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}