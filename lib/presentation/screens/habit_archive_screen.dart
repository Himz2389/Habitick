import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:habit_flow/domain/models/habit_model.dart';
import 'package:habit_flow/presentation/providers/habit_provider.dart';
import 'package:habit_flow/presentation/screens/edit_habit_screen.dart'; 
import 'package:habit_flow/presentation/screens/habit_stats_screen.dart';


class HabitArchiveScreen extends ConsumerWidget {
  const HabitArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final allHabits = ref.watch(habitProvider);

    
    final activeHabits = allHabits.where((h) => h.isPaused == 0 && h.isCompleted == 0 && h.isDeleted == 0).toList();
    final pausedHabits = allHabits.where((h) => h.isPaused == 1 && h.isCompleted == 0 && h.isDeleted == 0).toList();
    final completedHabits = allHabits.where((h) => h.isCompleted == 1 && h.isDeleted == 0).toList();
    final deletedHabits = allHabits.where((h) => h.isDeleted == 1).toList(); // Trash!

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: const Text('Habit Archive', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: theme.colorScheme.primary,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: '🟢 Active'),
              Tab(text: '⏸️ Paused'),
              Tab(text: '✅ Completed'),
              Tab(text: '🗑️ Deleted'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildHabitList(context, activeHabits, 'No active habits found.', theme, isCompletedTab: false, isDeletedTab: false),
            _buildHabitList(context, pausedHabits, 'No paused habits.', theme, isCompletedTab: false, isDeletedTab: false),
            _buildHabitList(context, completedHabits, 'No completed habits yet.', theme, isCompletedTab: true, isDeletedTab: false),
            _buildHabitList(context, deletedHabits, 'Trash is empty.', theme, isCompletedTab: false, isDeletedTab: true),
          ],
        ),
      ),
    );
  }
Widget _buildHabitList(BuildContext context, List<HabitModel> habits, String emptyMessage, ThemeData theme, {required bool isCompletedTab, required bool isDeletedTab}) {
    if (habits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isDeletedTab ? Icons.delete_outline : Icons.inbox_outlined, size: 80, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(emptyMessage, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: habits.length,
      itemBuilder: (context, index) {
        final habit = habits[index];
        DateTime createdDate;
        try {
          createdDate = DateTime.parse(habit.createdAt);
        } catch (e) {
          createdDate = DateTime.now();
        }
        
        String formattedDate = DateFormat('dd MMM yyyy').format(createdDate);

        Color categoryColor = Colors.blue;
        try {
          categoryColor = Color(int.parse(habit.color));
        } catch (e) {}

        if (isDeletedTab) categoryColor = Colors.grey;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDeletedTab ? 0.1 : 0.3),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: categoryColor.withValues(alpha: 0.3), width: 1.5),
          ),
          child: InkWell(
            onTap: () {
              if (isCompletedTab) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => HabitStatsScreen(habit: habit)),
                );
                return;
              }
              
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EditHabitScreen(habit: habit)),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          habit.name,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, decoration: isDeletedTab ? TextDecoration.lineThrough : null),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: categoryColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          isDeletedTab ? "Deleted Category" : habit.category,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: categoryColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text('Started on: $formattedDate', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.track_changes_rounded, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text('Target: ${habit.timesPerDay} times/day', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      const Spacer(),
                      if (isCompletedTab)
                        const Row(children: [Icon(Icons.check_circle, size: 16, color: Colors.green), SizedBox(width: 4), Text('Completed', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))])
                      else if (isDeletedTab)
                        const Row(children: [Icon(Icons.settings_backup_restore, size: 16, color: Colors.red), SizedBox(width: 4), Text('Tap to Restore', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12))])
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}