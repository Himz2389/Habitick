import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:lottie/lottie.dart';


import 'package:habit_flow/domain/models/habit_completion_model.dart';
import 'package:habit_flow/presentation/providers/habit_provider.dart';
import 'package:habit_flow/presentation/providers/category_provider.dart';
import 'package:habit_flow/presentation/providers/habit_completion_provider.dart';
import 'package:habit_flow/presentation/screens/add_habit_screen.dart';
import 'package:habit_flow/presentation/screens/edit_habit_screen.dart';


class HabitBoardScreen extends ConsumerStatefulWidget {
  const HabitBoardScreen({super.key});

  @override
  ConsumerState<HabitBoardScreen> createState() => _HabitBoardScreenState();
}

class _HabitBoardScreenState extends ConsumerState<HabitBoardScreen> with WidgetsBindingObserver {

  DateTime _lastActiveDate = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 🚨 NAYA: Lifecycle track karne ke liye observer joda 
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // 🚨 NAYA: Screen se bahar jaane par observer saaf kiya
    super.dispose();
  }

  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      DateTime now = DateTime.now();
      
      
      if (now.day != _lastActiveDate.day || now.month != _lastActiveDate.month || now.year != _lastActiveDate.year) {
        debugPrint("🔄 New Day Detected! Refreshing database cache...");
        _lastActiveDate = now; // Nayi date ko save kar liya
        
        if (mounted) {
          ref.invalidate(habitProvider);
          ref.invalidate(categoryProvider);
          ref.invalidate(habitCompletionProvider);
        }
      }

      
      if (mounted) {
        setState(() {}); 
      }
    }
  }

  
  //  SMART COLOR PARSER
  Color _parseColor(String colorStr) {
    try {
      if (colorStr.startsWith('0x') || colorStr.startsWith('0X')) {
        colorStr = colorStr.substring(2);
      } else if (colorStr.startsWith('#')) {
        colorStr = colorStr.substring(1);
      }
      if (colorStr.length == 6) colorStr = 'FF$colorStr'; 
      return Color(int.parse(colorStr, radix: 16));
    } catch (e) {
      return Colors.blue; 
    }
  }

  @override
  Widget build(BuildContext context) { // 🚨 ref yahan se hata diya kyunki Stateful me ye automatically mil jata hai
    final habits = ref.watch(habitProvider).where((habit) => habit.isCompleted == 0 && habit.isDeleted == 0).toList();
    final categories = ref.watch(categoryProvider);
    final completionsList = ref.watch(habitCompletionProvider); 

    final today = DateTime.now();
    final List<DateTime> last7Days = List.generate(7, (index) {
      return today.subtract(Duration(days: 6 - index));
    });

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddHabitScreen()),
          );
        },
        backgroundColor: Theme.of(context).colorScheme.primary, // App ki theme ka primary color lega
        foregroundColor: const Color(0xFFFFFFFF), // Icon ka color white kar dega
        elevation: 6, // Thoda shadow dega jisse ye float karta hua lagega
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // Thoda modern squircle (rounded) shape
        ),
        child: const Icon(Icons.add, size: 28),
      ),
      body: habits.isEmpty
          ? Center(
              // 🚨 Lottie Animation Builder
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutBack, 
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: scale.clamp(0.0, 1.0),
                      child: child,
                    ),
                  );
                },
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lottie.asset(
                        'assets/lottie/empty_board.json', 
                        width: 280,
                        height: 280,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => 
                          Icon(Icons.dashboard_customize_rounded, size: 120, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Ready for a Change?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26, 
                          fontWeight: FontWeight.w800, 
                          color: Theme.of(context).colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40.0),
                        child: Text(
                          '👋 Welcome to Habitick!\nYour future is shaped by what you do today.\nLet\'s make every day count.🌱',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16, 
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), 
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AddHabitScreen()),
                          );
                        },
                        icon: const Icon(Icons.add_task, size: 22),
                        label: const Text('Create First Habit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            )
          : Column(
              children: [
                // === TOP HEADER (Dates Columns) ===
                Builder(
                  builder: (context) {
                    final firstDate = last7Days.first;
                    final lastDate = last7Days.last;
                    final firstMonth = DateFormat('MMM').format(firstDate);
                    final lastMonth = DateFormat('MMM').format(lastDate);
                    
                    String monthYearText = '';
                    if (firstDate.year == lastDate.year) {
                      if (firstDate.month == lastDate.month) {
                        monthYearText = '$firstMonth, ${firstDate.year}';
                      } else {
                        monthYearText = '$firstMonth-$lastMonth, ${firstDate.year}';
                      }
                    } else {
                      final lastYearShort = lastDate.year.toString().substring(2);
                      monthYearText = '$firstMonth-$lastMonth, ${firstDate.year}-$lastYearShort';
                    }

                    return Padding(
                      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 8.0), 
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              monthYearText,
                              style: TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.w900, 
                                color: Theme.of(context).colorScheme.onSurface, 
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 230, 
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: last7Days.map((date) {
                                bool isToday = date.day == today.day && date.month == today.month && date.year == today.year;
                                return Column(
                                  children: [
                                    Text(
                                      DateFormat('EEE').format(date), 
                                      style: TextStyle(
                                        fontSize: 12, 
                                        color: isToday ? Theme.of(context).colorScheme.primary : Colors.grey,
                                        fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('d').format(date),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                        color: isToday ? Theme.of(context).colorScheme.primary : null,
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                ),
                const Divider(),
                
                // === HABIT LIST ===
                Expanded(
                  child: ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (context, categoryIndex) {
                      final category = categories[categoryIndex];
                      final categoryHabits = habits.where((h) => h.categoryId == category.id).toList();
                      
                      if (categoryHabits.isEmpty) return const SizedBox.shrink();
                      
                      final categoryColor = _parseColor(category.color);

                      return Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: true,
                          leading: Icon(Icons.folder, color: categoryColor, size: 24),
                          title: Text(
                            category.name.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: categoryColor,
                              letterSpacing: 1.2,
                            ),
                          ),
                          children: categoryHabits.map((habit) {
                            
                            
                            final habitColor = _parseColor(habit.color);
                            final bool isPaused = habit.isPaused == 1;

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Opacity(
                                opacity: isPaused ? 0.6 : 1.0, 
                                child: Row(
                                  children: [
                                    // Habit Info (Name & Streak)
                                    Expanded(
                                      child: InkWell(
                                        onLongPress: () {
                                          _showHabitOptions(context, ref, habit);
                                        },
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    habit.name,
                                                    style: TextStyle(
                                                      fontSize: 16, 
                                                      fontWeight: FontWeight.w600,
                                                      decoration: isPaused ? TextDecoration.lineThrough : null, 
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (isPaused) 
                                                  const Padding(
                                                    padding: EdgeInsets.only(right: 8.0),
                                                    child: Icon(Icons.pause_circle_filled, size: 14, color: Colors.orange),
                                                  )
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Consumer(builder: (context, ref, child) {
                                              final streak = ref.watch(habitCompletionProvider.notifier)
                                                  .calculateStreak(habit.id, habit.activeDays, habit.timesPerDay);
                                              
                                              return Text(
                                                '🔥 Streak: $streak',
                                                style: TextStyle(
                                                  fontSize: 11, 
                                                  color: Colors.orange.shade800.withValues(alpha: 0.7), 
                                                  fontWeight: FontWeight.w600
                                                ),
                                              );
                                            }),
                                          ],
                                        ),
                                      ),
                                    ),
                                    
                                    // 7 Checkboxes (Dates Columns)
                                    SizedBox(
                                      width: 230,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: last7Days.map((date) {
                                          final dateStr = DateFormat('yyyy-MM-dd').format(date);
                                          bool isActiveDay = habit.activeDays.contains(date.weekday);
                                          bool isToday = date.day == today.day && date.month == today.month && date.year == today.year;

                                          
                                          //  PAUSE LOGIC
                                          
                                          bool isDatePaused = false;
                                          DateTime currentColumnDate = DateTime(date.year, date.month, date.day);
                                          
                                          for (String log in habit.pauseLogs) {
                                            final parts = log.split('|');
                                            if (parts.isNotEmpty && parts[0].isNotEmpty) {
                                              DateTime startDate = DateTime.parse(parts[0]);
                                              DateTime endDate;
                                              if (parts.length > 1 && parts[1].isNotEmpty) {
                                                endDate = DateTime.parse(parts[1]);
                                              } else {
                                                endDate = DateTime(today.year, today.month, today.day).add(const Duration(days: 365));
                                              }

                                              if (!currentColumnDate.isBefore(startDate) && currentColumnDate.isBefore(endDate)) {
                                                isDatePaused = true;
                                                break;
                                              }
                                            }
                                          }

                                          final dateCompletions = completionsList.where((c) => c.habitId == habit.id && c.date == dateStr).toList();
                                          final currentCompletionObj = dateCompletions.isNotEmpty ? dateCompletions.first : null;
                                          
                                          int currentCount = currentCompletionObj?.isCompleted ?? 0;
                                          bool isFullyCompleted = currentCount >= habit.timesPerDay;

                                          
                                          if (isDatePaused || !isActiveDay) {
                                            return Container(
                                              width: 26, height: 26,
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100, 
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: Colors.grey.shade300),
                                              ),
                                              alignment: Alignment.center,
                                              child: Tooltip(
                                                message: isDatePaused ? 'Habit was paused on this day' : 'Not an active day',
                                                child: Text('-', style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold))
                                              ),
                                            );
                                          }

                                          return GestureDetector(
                                            onTap: () {
                                              if (isPaused) {
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This habit is paused. Resume to track!'), duration: Duration(seconds: 1)));
                                                return;
                                              }

                                              if (isToday) {
                                                int nextCount = currentCount + 1;
                                                if (nextCount > habit.timesPerDay) {
                                                  nextCount = 0; 
                                                }
                                                
                                                final newCompletion = HabitCompletionModel(
                                                  id: currentCompletionObj?.id ?? const Uuid().v4(),
                                                  habitId: habit.id,
                                                  date: dateStr,
                                                  isCompleted: nextCount, 
                                                );
                                                
                                                ref.read(habitCompletionProvider.notifier).toggleHabitCompletion(newCompletion);
                                              } else {
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Past dates are read-only!'), duration: Duration(seconds: 1)));
                                              }
                                            },
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 300),
                                              width: 26, height: 26,
                                              decoration: BoxDecoration(
                                                color: isFullyCompleted 
                                                    ? habitColor 
                                                    : (currentCount > 0 ? habitColor.withValues(alpha: 0.2) : Colors.transparent),
                                                border: Border.all(
                                                  color: (isFullyCompleted || currentCount > 0) ? habitColor : Colors.grey.shade400,
                                                  width: 1.5,
                                                ),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Center(
                                                child: isFullyCompleted
                                                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                                                    : (currentCount > 0 
                                                        ? Text('$currentCount', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: habitColor))
                                                        : null),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  void _showHabitOptions(BuildContext context, WidgetRef ref, habit) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.blue),
              title: const Text('Edit Habit'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EditHabitScreen(habit: habit)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Habit'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Habit?'),
                    content: Text('Are you sure you want to delete "${habit.name}"? This cannot be undone.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () {
                          ref.read(habitProvider.notifier).updateHabit(habit.copyWith(isDeleted: 1));
                          Navigator.pop(context);
                        },
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}