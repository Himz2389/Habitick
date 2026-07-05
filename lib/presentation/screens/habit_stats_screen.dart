import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:habit_flow/domain/models/habit_model.dart';
import 'package:habit_flow/presentation/providers/habit_provider.dart';
import 'package:habit_flow/presentation/providers/habit_completion_provider.dart';

class HabitStatsScreen extends ConsumerWidget {
  final HabitModel habit;

  const HabitStatsScreen({super.key, required this.habit});

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString));
    } catch (e) {
      return Colors.blue; 
    }
  }

  bool _isDatePaused(DateTime date, List<String> pauseLogs) {
    if (pauseLogs.isEmpty) return false;
    DateTime dateOnly = DateTime(date.year, date.month, date.day);
    DateTime today = DateTime.now();

    for (String log in pauseLogs) {
      final parts = log.split('|');
      if (parts.isNotEmpty && parts[0].isNotEmpty) {
        DateTime startDate = DateTime.parse(parts[0]);
        DateTime endDate;
        if (parts.length > 1 && parts[1].isNotEmpty) {
          endDate = DateTime.parse(parts[1]);
        } else {
          endDate = DateTime(today.year + 1, today.month, today.day);
        }

        if (!dateOnly.isBefore(startDate) && dateOnly.isBefore(endDate)) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    // FETCH LATEST DATA FROM PROVIDER
    final allHabits = ref.watch(habitProvider);
    final currentHabit = allHabits.firstWhere((h) => h.id == habit.id, orElse: () => habit);
    
    final habitColor = _parseColor(currentHabit.color);

    final allCompletions = ref.watch(habitCompletionProvider);
    final myCompletions = allCompletions.where((c) => c.habitId == currentHabit.id).toList();

    Map<String, int> completionMap = {};
    for (var c in myCompletions) {
      completionMap[c.date] = (completionMap[c.date] ?? 0) + c.isCompleted;
    }

    // TIME FREEZE LOGIC
    DateTime rawStartDate;
    try {
      rawStartDate = DateTime.parse(currentHabit.createdAt);
    } catch (e) {
      rawStartDate = DateTime.now();
    }
    DateTime startDate = DateTime(rawStartDate.year, rawStartDate.month, rawStartDate.day);
    
    DateTime endDate;
    if (currentHabit.isCompleted == 1) {
      if (myCompletions.isNotEmpty) {
        myCompletions.sort((a, b) => a.date.compareTo(b.date)); 
        DateTime lastLogDate = DateTime.parse(myCompletions.last.date);
        endDate = DateTime(lastLogDate.year, lastLogDate.month, lastLogDate.day);
      } else {
        endDate = startDate; 
      }
    } else {
      DateTime now = DateTime.now();
      endDate = DateTime(now.year, now.month, now.day);
    }

    if (endDate.isBefore(startDate)) endDate = startDate;
    int totalDaysDuration = endDate.difference(startDate).inDays + 1;

    // ENGINE CALCULATIONS
    int totalCompletedTaps = 0;
    int totalScheduledTaps = 0;
    
    int bestStreak = 0;
    int runningStreak = 0;
    DateTime todayOnly = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    for (int i = 0; i < totalDaysDuration; i++) {
      DateTime currentDay = startDate.add(Duration(days: i));
      String dateStr = DateFormat('yyyy-MM-dd').format(currentDay);
      
      int doneOnDay = completionMap[dateStr] ?? 0;
      totalCompletedTaps += doneOnDay;

      if (currentHabit.activeDays.contains(currentDay.weekday)) {
        if (!_isDatePaused(currentDay, currentHabit.pauseLogs)) {
          totalScheduledTaps += currentHabit.timesPerDay;
          
          if (doneOnDay >= currentHabit.timesPerDay) {
            runningStreak++;
            if (runningStreak > bestStreak) bestStreak = runningStreak;
          } else {
            if (currentDay.isBefore(todayOnly) || currentHabit.isCompleted == 1) {
              runningStreak = 0;
            }
          }
        }
      }
    }

    int totalMissedTaps = totalScheduledTaps - totalCompletedTaps;
    if (totalMissedTaps < 0) totalMissedTaps = 0;

    double successRate = totalScheduledTaps > 0 ? (totalCompletedTaps / totalScheduledTaps) * 100 : 0.0;
    if (successRate > 100) successRate = 100.0;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Habit Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: habitColor.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: Icon(currentHabit.isCompleted == 1 ? Icons.emoji_events_rounded : Icons.track_changes_rounded, color: habitColor, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(currentHabit.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: habitColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: habitColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(currentHabit.category, style: TextStyle(color: habitColor, fontWeight: FontWeight.bold, fontSize: 12)),
                      )
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 30),

            
            //  UPGRADED SYMMETRIC OVERVIEW SECTION (5 CARDS)
            
            const Text("Overview", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            
            // Row 1: Total Days & Success Rate
            Row(
              children: [
                Expanded(child: _buildStatCard('Total Days', '$totalDaysDuration Days', Icons.timelapse, Colors.purple, theme)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Success Rate', '${successRate.toStringAsFixed(1)}%', Icons.pie_chart, successRate > 50 ? Colors.green : Colors.orange, theme)),
              ],
            ),
            const SizedBox(height: 12),
            
            // Row 2: Total Completed & Total Missed
            Row(
              children: [
                Expanded(child: _buildStatCard('Total Completed', '$totalCompletedTaps', Icons.fact_check_outlined, Colors.blue, theme)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Total Missed', '$totalMissedTaps', Icons.cancel_outlined, Colors.redAccent, theme)),
              ],
            ),
            const SizedBox(height: 12),
            
            // Row 3: Full Width Streak Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.star_rounded, color: Colors.amber, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Best Streak', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text('$bestStreak Days', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Timeline Graph
            const Text("Lifetime Timeline", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(totalDaysDuration, (index) {
                        DateTime dayDate = startDate.add(Duration(days: index));
                        String dateStr = DateFormat('yyyy-MM-dd').format(dayDate);
                        
                        bool isActiveDay = currentHabit.activeDays.contains(dayDate.weekday);
                        bool isPausedOnDay = _isDatePaused(dayDate, currentHabit.pauseLogs);

                        int completedCountOnDay = completionMap[dateStr] ?? 0;
                        int targetPerDay = currentHabit.timesPerDay > 0 ? currentHabit.timesPerDay : 1;
                        
                        double dayPercentage = (completedCountOnDay / targetPerDay);
                        if (dayPercentage > 1.0) dayPercentage = 1.0;

                        return Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: _buildBarChart(
                            DateFormat('dd MMM').format(dayDate), 
                            dayPercentage, 
                            habitColor,
                            isActiveDay,
                            isPausedOnDay,
                            theme,
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.swipe, size: 14, color: Colors.grey),
                      SizedBox(width: 6),
                      Text("Bars display exact completion ratio per active day", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Details Section
            const Text("Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.date_range_outlined, color: Colors.grey),
                    title: const Text("Duration"),
                    trailing: Text(
                      "${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const Divider(height: 1, indent: 50),
                  ListTile(
                    leading: const Icon(Icons.repeat_rounded, color: Colors.grey),
                    title: const Text("Times Per Day"),
                    trailing: Text(
                      "${currentHabit.timesPerDay} times/day",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Divider(height: 1, indent: 50),
                  ListTile(
                    leading: const Icon(Icons.low_priority, color: Colors.grey),
                    title: const Text("Priority Level"),
                    trailing: Text(currentHabit.priority, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const Divider(height: 1, indent: 50),
                  ListTile(
                    leading: Icon(
                      currentHabit.isCompleted == 1 
                          ? Icons.emoji_events_outlined 
                          : (currentHabit.isPaused == 1 ? Icons.pause_circle_outline : Icons.check_circle_outline), 
                      color: currentHabit.isCompleted == 1 ? Colors.green : (currentHabit.isPaused == 1 ? Colors.orange : Colors.blue)
                    ),
                    title: const Text("Current Status"),
                    trailing: Text(
                      currentHabit.isCompleted == 1 ? "Completed" : (currentHabit.isPaused == 1 ? "Paused" : "Active"), 
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        color: currentHabit.isCompleted == 1 ? Colors.green : (currentHabit.isPaused == 1 ? Colors.orange : Colors.blue)
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBarChart(String dayStr, double percentage, Color color, bool isActiveDay, bool isPausedOnDay, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    bool shouldShowBar = isActiveDay && !isPausedOnDay;
    Color labelColor = (isActiveDay && !isPausedOnDay) ? (isDark ? Colors.white70 : Colors.black87) : Colors.grey.withValues(alpha: 0.4);

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 100, width: 24,
              decoration: BoxDecoration(
                color: isPausedOnDay ? Colors.orange.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: isPausedOnDay ? Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 1) : null,
              ),
              alignment: Alignment.center,
              child: isPausedOnDay ? const Text('-', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14)) : null,
            ),
            if (shouldShowBar)
              AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                height: 100 * percentage, width: 24,
                decoration: BoxDecoration(
                  color: percentage > 0 ? color : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(dayStr.split(' ')[0], style: TextStyle(fontSize: 10, color: labelColor, fontWeight: FontWeight.bold)),
        Text(dayStr.split(' ')[1], style: TextStyle(fontSize: 10, color: labelColor)),
      ],
    );
  }
}