import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:habit_flow/domain/models/habit_model.dart';
import 'package:habit_flow/domain/models/category_model.dart';

import 'package:habit_flow/presentation/providers/habit_provider.dart';

class ReorderHabitsScreen extends ConsumerStatefulWidget {
  final CategoryModel category;
  final List<HabitModel> habits;

  const ReorderHabitsScreen({
    super.key,
    required this.category,
    required this.habits,
  });

  @override
  ConsumerState<ReorderHabitsScreen> createState() =>
      _ReorderHabitsScreenState();
}

class _ReorderHabitsScreenState extends ConsumerState<ReorderHabitsScreen> {
  late List<HabitModel> _habits;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();

    _habits = List.from(widget.habits);

    _habits.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,

      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (!_hasChanges) {
          Navigator.pop(context);

          return;
        }

        final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Discard changes?"),

            content: const Text("Your habit order has not been saved."),

            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context, false);
                },
                child: const Text("Cancel"),
              ),

              FilledButton(
                onPressed: () {
                  Navigator.pop(context, true);
                },
                child: const Text("Discard"),
              ),
            ],
          ),
        );

        if (discard == true && mounted) {
          Navigator.pop(context);
        }
      },

      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            _hasChanges
              ? "Re-order ${widget.category.name} *"
              : "Re-order ${widget.category.name}",
          ),

          actions: [
            FilledButton.icon(
              onPressed: _hasChanges
              ? () async {
                HapticFeedback.mediumImpact();

                if (!_hasChanges) {
                  Navigator.pop(context);
                  return;
                }

                for (int i = 0; i < _habits.length; i++) {
                  _habits[i] = _habits[i].copyWith(displayOrder: i);
                }

                await ref
                    .read(habitProvider.notifier)
                    .updateHabitOrder(_habits);

                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                    backgroundColor: Colors.green.shade600,
                    duration: const Duration(seconds: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Habit order updated successfully!",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                setState(() {
                  _hasChanges = false;
                });
                Navigator.pop(context);
              }
              : null,

              icon: const Icon(Icons.check),
              label: const Text("Done"),
            ),
          ],
        ),

        body: ReorderableListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),

          buildDefaultDragHandles: false,
          itemCount: _habits.length,

          onReorder: (oldIndex, newIndex) {
            HapticFeedback.lightImpact();

            setState(() {
              if (newIndex > oldIndex) {
                newIndex--;
              }

              final item = _habits.removeAt(oldIndex);

              _habits.insert(newIndex, item);
              _hasChanges = true;
            });
          },

          itemBuilder: (context, index) {
            final habit = _habits[index];

            return Card(
              key: ValueKey(habit.id),

              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),

              child: ListTile(
                title: Text(
                  habit.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),

                trailing: ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle_rounded),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
