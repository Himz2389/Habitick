import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';

import 'package:habit_flow/presentation/providers/habit_provider.dart';
import 'package:habit_flow/presentation/providers/habit_completion_provider.dart';
import 'package:habit_flow/presentation/providers/journal_provider.dart'; 
import 'package:habit_flow/domain/models/habit_model.dart'; 

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String _filterType = 'Last 7 Days';
  DateTime _customMonth = DateTime.now();
  String _dropdownValue = 'all';

  DateTime _calendarMonth = DateTime.now();

  bool _isDateOnOrAfterCreation(DateTime date, String createdAtString) {
    try {
      DateTime createDate = DateTime.parse(createdAtString);
      DateTime createDateOnly = DateTime(createDate.year, createDate.month, createDate.day);
      DateTime dateOnly = DateTime(date.year, date.month, date.day);
      return !dateOnly.isBefore(createDateOnly);
    } catch (e) {
      return true; 
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
          endDate = DateTime(today.year + 1, today.month, today.day); // Future date fallback
        }

        // Agar Date Pause aur Resume interval ke beech hai (Resume day EXCLUDED)
        if (!dateOnly.isBefore(startDate) && dateOnly.isBefore(endDate)) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _pickMonth() async {
    DateTime now = DateTime.now();
    List<DateTime> pastMonths = List.generate(12, (index) => DateTime(now.year, now.month - index, 1));
    final selected = await showDialog<DateTime>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Month', style: TextStyle(fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SizedBox(
          width: double.maxFinite, height: 300,
          child: ListView.builder(
            itemCount: pastMonths.length,
            itemBuilder: (context, index) {
              final m = pastMonths[index];
              return ListTile(
                leading: const Icon(Icons.calendar_month, color: Colors.blueAccent),
                title: Text(DateFormat('MMMM yyyy').format(m)),
                onTap: () => Navigator.pop(context, m),
              );
            },
          ),
        ),
      ),
    );
    if (selected != null) {
      setState(() { _filterType = 'Custom Month'; _customMonth = selected; });
    }
  }

  Future<void> _pickCalendarMonth() async {
    DateTime now = DateTime.now();
    List<DateTime> pastMonths = List.generate(24, (index) => DateTime(now.year, now.month - index, 1));
    final selected = await showDialog<DateTime>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Jump to Month', style: TextStyle(fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SizedBox(
          width: double.maxFinite, height: 300,
          child: ListView.builder(
            itemCount: pastMonths.length,
            itemBuilder: (context, index) {
              final m = pastMonths[index];
              return ListTile(
                leading: const Icon(Icons.date_range, color: Colors.deepPurpleAccent),
                title: Text(DateFormat('MMMM yyyy').format(m)),
                onTap: () => Navigator.pop(context, m),
              );
            },
          ),
        ),
      ),
    );
    if (selected != null) setState(() => _calendarMonth = selected);
  }

  Color _getHabitColor(HabitModel habit, BuildContext context) {
    if (habit.color.isNotEmpty) {
      try {
        String colorStr = habit.color.startsWith('0x') || habit.color.startsWith('0X') 
            ? habit.color.substring(2) 
            : habit.color.startsWith('#') ? habit.color.substring(1) : habit.color;
        if (colorStr.length == 6) colorStr = 'FF$colorStr';
        return Color(int.parse(colorStr, radix: 16));
      } catch (e) {
        return Theme.of(context).colorScheme.primary;
      }
    }
    return Theme.of(context).colorScheme.primary;
  }

  Map<String, int> _calculateStreaks(bool isJournal, List<dynamic> journals, List<HabitModel> habits, List<dynamic> completions) {
    DateTime today = DateTime.now();
    List<DateTime> historyDates = List.generate(365, (i) => today.subtract(Duration(days: i))).reversed.toList();

    int bestStreak = 0;
    int runningStreak = 0;

    for (var date in historyDates) {
      String dateStr = DateFormat('yyyy-MM-dd').format(date);
      
      if (isJournal) {
        bool hasJournal = journals.any((j) => j.date == dateStr || j.createdAt.toString().startsWith(dateStr));
        if (hasJournal) {
          runningStreak++;
          if (runningStreak > bestStreak) bestStreak = runningStreak;
        } else if (!date.isAfter(today.subtract(const Duration(days: 1)))) {
          runningStreak = 0;
        }
      } else {
        if (habits.isEmpty) return {'current': 0, 'best': 0};
        bool anyHabitActive = false;
        bool atLeastOneTapOnActiveHabits = false;

        for (var habit in habits) {
          if (habit.activeDays.contains(date.weekday) && _isDateOnOrAfterCreation(date, habit.createdAt)) {
            // 🚨 NAYA: Agar Pause nahi hai, tabhi us din ko calculation mein daalo
            if (!_isDatePaused(date, habit.pauseLogs)) {
              anyHabitActive = true;
              var matchingComps = completions.where((c) => c.habitId == habit.id && c.date == dateStr);
              if (matchingComps.isNotEmpty && matchingComps.first.isCompleted > 0) {
                atLeastOneTapOnActiveHabits = true;
              }
            }
          }
        }
        
        if (!anyHabitActive) continue; 
        
        if (atLeastOneTapOnActiveHabits) {
          runningStreak++;
          if (runningStreak > bestStreak) bestStreak = runningStreak;
        } else if (!date.isAfter(today.subtract(const Duration(days: 1)))) {
          runningStreak = 0;
        }
      }
    }
    return {'current': runningStreak, 'best': bestStreak};
  }

  @override
  Widget build(BuildContext context) {
    final rawHabits = ref.watch(habitProvider);
    final allHabits = rawHabits.where((h) => h.isDeleted == 0 && h.isCompleted == 0).toList();
    final rawCompletions = ref.watch(habitCompletionProvider);
    final journals = ref.watch(journalProvider); 

    bool isJournalSelected = _dropdownValue == 'journal';

    Map<String, List<HabitModel>> groupedHabits = {};
    for (var habit in allHabits) {
      String cat = habit.category.isNotEmpty ? habit.category : 'General'; 
      if (!groupedHabits.containsKey(cat)) groupedHabits[cat] = [];
      groupedHabits[cat]!.add(habit);
    }

    List<HabitModel> activeHabits = [];
    String displaySubtitle = "All Habits";
    
    if (!isJournalSelected) {
      if (_dropdownValue == 'all') {
        activeHabits = allHabits;
        displaySubtitle = "All Habits";
      } else if (_dropdownValue.startsWith('cat_')) {
        String selectedCat = _dropdownValue.replaceFirst('cat_', '');
        activeHabits = allHabits.where((h) => h.category == selectedCat).toList();
        displaySubtitle = "Category: $selectedCat";
      } else if (_dropdownValue.startsWith('hab_')) {
        String selectedId = _dropdownValue.replaceFirst('hab_', '');
        activeHabits = allHabits.where((h) => h.id == selectedId).toList();
        if (activeHabits.isNotEmpty) displaySubtitle = activeHabits.first.name;
      }
    } else {
      displaySubtitle = "Personal Journal";
    }

    final completions = rawCompletions.where((c) => activeHabits.any((h) => h.id == c.habitId)).toList();
    final streakMetrics = _calculateStreaks(isJournalSelected, journals, activeHabits, rawCompletions);

    List<DateTime> dateRange = [];
    final today = DateTime.now();

    if (_filterType == 'Last 7 Days') {
      dateRange = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    } else if (_filterType == 'Last 30 Days') {
      dateRange = List.generate(30, (i) => today.subtract(Duration(days: 29 - i)));
    } else if (_filterType == 'Custom Month') {
      int daysInMonth = DateUtils.getDaysInMonth(_customMonth.year, _customMonth.month);
      for (int i = 1; i <= daysInMonth; i++) {
        dateRange.add(DateTime(_customMonth.year, _customMonth.month, i));
      }
    }

    Color chartColor = isJournalSelected ? Colors.deepPurpleAccent : Theme.of(context).colorScheme.primary;
    if (!isJournalSelected && activeHabits.isNotEmpty && _dropdownValue != 'all') {
      chartColor = _getHabitColor(activeHabits.first, context);
    }

    int totalTargetTaps = 0;
    int totalDoneTaps = 0;

    for (var date in dateRange) {
      String dateStr = DateFormat('yyyy-MM-dd').format(date);
      
      if (isJournalSelected) {
        totalTargetTaps += 1; 
        bool hasJournal = journals.any((j) => j.date == dateStr || j.createdAt.toString().startsWith(dateStr));
        if (hasJournal) totalDoneTaps += 1;
      } else {
        for (var habit in activeHabits) {
          if (habit.activeDays.contains(date.weekday) && _isDateOnOrAfterCreation(date, habit.createdAt)) {
            // 🚨 NAYA: Pause days ko Target mein count hi mat karo (Missed nahi manega!)
            if (!_isDatePaused(date, habit.pauseLogs)) {
              totalTargetTaps += habit.timesPerDay; 
              
              var matchingComps = completions.where((c) => c.habitId == habit.id && c.date == dateStr);
              if (matchingComps.isNotEmpty) {
                totalDoneTaps += matchingComps.first.isCompleted.clamp(0, habit.timesPerDay).toInt();
              }
            }
          }
        }
      }
    }

    double completionRate = totalTargetTaps > 0 ? (totalDoneTaps / totalTargetTaps) * 100 : 0.0;
    int missedTaps = totalTargetTaps - totalDoneTaps;

    String periodTitle = _filterType == 'Custom Month' ? DateFormat('MMMM yyyy').format(_customMonth) : _filterType;

    List<DropdownMenuItem<String>> dropdownItems = [
      const DropdownMenuItem<String>(value: 'all', child: Text('All Habits', style: TextStyle(fontWeight: FontWeight.bold))),
      const DropdownMenuItem<String>(
        value: 'journal',
        child: Row(
          children: [
            Icon(Icons.book, size: 16, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Journal Data', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
          ],
        ),
      )
    ];

    groupedHabits.forEach((categoryName, habitsInCategory) {
      dropdownItems.add(DropdownMenuItem<String>(
        value: 'cat_$categoryName',
        child: Row(
          children: [
            Icon(Icons.folder_open, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Expanded(child: Text(categoryName, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800, fontSize: 14), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ));
      for (var habit in habitsInCategory) {
        dropdownItems.add(DropdownMenuItem<String>(
          value: 'hab_${habit.id}',
          child: Padding(
            padding: const EdgeInsets.only(left: 24.0), 
            child: Row(
              children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: _getHabitColor(habit, context), shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text(habit.name, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ));
      }
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: chartColor.withValues(alpha: 0.05),
        centerTitle: false,

        title: Container(
            width: 150, 
            padding: const EdgeInsets.symmetric(horizontal: 8),
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              color: chartColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: chartColor.withValues(alpha: 0.3)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true, 
                menuMaxHeight: 350, 
                value: _dropdownValue,
                icon: Icon(Icons.arrow_drop_down, color: chartColor),
                style: TextStyle(fontWeight: FontWeight.w600, color: chartColor, fontSize: 13),
                onChanged: (String? newValue) {
                  if (newValue != null) setState(() => _dropdownValue = newValue);
                },
                items: dropdownItems,
              ),
            ),
          ),

        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: PopupMenuButton<String>(
              icon: Icon(Icons.tune, color: Theme.of(context).colorScheme.onSurface),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (value) {
                if (value == 'Custom Month') {
                  _pickMonth();
                } else {
                  setState(() => _filterType = value);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'Last 7 Days', child: Text('Last 7 Days')),
                const PopupMenuItem(value: 'Last 30 Days', child: Text('Last 30 Days')),
                const PopupMenuItem(value: 'Custom Month', child: Text('Specific Month...')),
              ],
            ),
          ),
        ],
      ),
      body: (!isJournalSelected && allHabits.isEmpty)
          ? Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutBack, 
                builder: (context, scale, child) {
                  return Transform.scale(scale: scale, child: Opacity(opacity: scale.clamp(0.0, 1.0), child: child));
                },
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lottie.asset('assets/lottie/empty_chart.json', width: 250, height: 250, fit: BoxFit.contain, 
                          errorBuilder: (context, error, stackTrace) => Icon(Icons.bar_chart_rounded, size: 100, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5))),
                      const SizedBox(height: 20),
                      const Text('No Data Yet', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40.0),
                        child: Text('Hey there! 👋\n Looks like you\'re just getting started.\nCreate a few habits and we\'ll track your progress.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, height: 1.5)),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('$periodTitle • $displaySubtitle', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.secondary)),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      _buildStatCard(context, title: 'Current Streak', value: '${streakMetrics['current']} Days', icon: Icons.local_fire_department_rounded, color: Colors.orange.shade700),
                      const SizedBox(width: 12),
                      _buildStatCard(context, title: 'Best Streak', value: '${streakMetrics['best']} Days', icon: Icons.workspace_premium_rounded, color: Colors.amber.shade800),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      _buildStatCard(context, title: 'Success Rate', value: '${completionRate.toStringAsFixed(1)}%', icon: Icons.trending_up_rounded, color: Colors.green),
                      const SizedBox(width: 12),
                      _buildStatCard(context, title: 'Total Wins', value: '$totalDoneTaps / $totalTargetTaps', icon: Icons.emoji_events_rounded, color: chartColor), 
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  const Text('Habit Trends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    height: 250, 
                    padding: const EdgeInsets.all(16),
                    decoration: _cardDecoration(context),
                    child: _buildDynamicBarChart(isJournalSelected, activeHabits, completions, journals, dateRange, chartColor),
                  ),

                  const SizedBox(height: 24),

                  const Text('Overall Performance Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    height: 180,
                    padding: const EdgeInsets.all(16),
                    decoration: _cardDecoration(context),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              _buildCircularChart(totalDoneTaps, missedTaps, chartColor),
                              Text('${completionRate.toStringAsFixed(0)}%', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: chartColor)),
                            ],
                          )
                        ),
                        Expanded(
                          flex: 1,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLegendItem('Done ($totalDoneTaps)', chartColor),
                              const SizedBox(height: 12),
                              _buildLegendItem('Missed ($missedTaps)', Colors.redAccent.withValues(alpha: 0.6)),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  const Text('Calender Static', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  const SizedBox(height: 12),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('MMMM yyyy').format(_calendarMonth), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Row(
                              children: [
                                IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1, 1))),
                                InkWell(onTap: _pickCalendarMonth, child: const Icon(Icons.edit_calendar_rounded, size: 20, color: Colors.blueAccent)),
                                IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 1))),
                              ],
                            )
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildGridCalendar(isJournalSelected, activeHabits, completions, journals, chartColor),
                      ],
                    ),
                  ),const SizedBox(height: 28),

                  
                  // SPECIFIC HABIT DETAILS SECTION 
                  
                  if (_dropdownValue.startsWith('hab_') && activeHabits.isNotEmpty) ...[
                    const Text('Habit Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        final selectedHabit = activeHabits.first;
                        
                        DateTime startDate;
                        try {
                          startDate = DateTime.parse(selectedHabit.createdAt);
                        } catch (e) {
                          startDate = DateTime.now();
                        }

                        final bool isPaused = selectedHabit.isPaused == 1;

                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: _cardDecoration(context), // Tumhara purana card style helper
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.play_circle_outline, color: Colors.grey),
                                title: const Text("Started From"),
                                trailing: Text(
                                  DateFormat('dd MMM yyyy').format(startDate),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              const Divider(height: 1, indent: 50),
                              
                              ListTile(
                                leading: const Icon(Icons.repeat_rounded, color: Colors.grey),
                                title: const Text("Times Per Day"),
                                trailing: Text(
                                  "${selectedHabit.timesPerDay} times/day",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              const Divider(height: 1, indent: 50),
                              ListTile(
                                leading: const Icon(Icons.low_priority, color: Colors.grey),
                                title: const Text("Priority Level"),
                                trailing: Text(
                                  selectedHabit.priority,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              const Divider(height: 1, indent: 50),
                              ListTile(
                                leading: Icon(
                                  isPaused ? Icons.pause_circle_outline : Icons.check_circle_outline,
                                  color: isPaused ? Colors.orange : Colors.blue,
                                ),
                                title: const Text("Current Status"),
                                trailing: Text(
                                  isPaused ? "Paused" : "Active",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isPaused ? Colors.orange : Colors.blue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    ),
                  ],

                  const SizedBox(height: 40), 
                ],
              ),
            ),
    );
  }

  // SMART BAR CHART (With Real Pause Handling)
  Widget _buildDynamicBarChart(bool isJournal, List<HabitModel> activeHabits, List<dynamic> completions, List<dynamic> journals, List<DateTime> dateRange, Color fallbackColor) {
    List<BarChartGroupData> barGroups = [];
    double maxTargetInRange = 1.0; 
    
    List<double> percentages = []; 

    for (int i = 0; i < dateRange.length; i++) {
      final date = dateRange[i];
      String dateStr = DateFormat('yyyy-MM-dd').format(date);
      
      double targetTimesTotal = 0;
      double userDoneTimesTotal = 0;

      if (isJournal) {
        targetTimesTotal = 1;
        bool hasJournal = journals.any((j) => j.date == dateStr || j.createdAt.toString().startsWith(dateStr));
        if (hasJournal) userDoneTimesTotal = 1;
      } else {
        for (var habit in activeHabits) {
          if (habit.activeDays.contains(date.weekday) && _isDateOnOrAfterCreation(date, habit.createdAt)) {
            if (!_isDatePaused(date, habit.pauseLogs)) {
              targetTimesTotal += habit.timesPerDay;
              
              var matchingComps = completions.where((c) => c.habitId == habit.id && c.date == dateStr);
              if (matchingComps.isNotEmpty) {
                userDoneTimesTotal += matchingComps.first.isCompleted.clamp(0, habit.timesPerDay).toDouble();
              }
            }
          }
        }
      }

      if (targetTimesTotal > maxTargetInRange) {
        maxTargetInRange = targetTimesTotal;
      }

      
      double percentage = targetTimesTotal > 0 ? (userDoneTimesTotal / targetTimesTotal).clamp(0.0, 1.0) * 100 : -1.0;
      percentages.add(percentage);

      barGroups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: userDoneTimesTotal, 
            color: fallbackColor,
            width: dateRange.length > 7 ? 6.0 : 16.0, 
            borderRadius: BorderRadius.circular(4),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              // Agar target 0 hai toh bar completely gayab ho jayega
              toY: targetTimesTotal > 0 ? targetTimesTotal : 0.0, 
              color: targetTimesTotal > 0 
                  ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6) 
                  : Colors.transparent, 
            ),
          )
        ],
      ));
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxTargetInRange > 0 ? maxTargetInRange : 1.0, 
        titlesData: FlTitlesData(
          show: true,
          topTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20, 
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (index < 0 || index >= percentages.length) return const SizedBox.shrink();
                
                
                if (percentages[index] == -1.0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2.0),
                    child: Text('*', style: TextStyle(fontSize: 14, color: Colors.orange.withValues(alpha: 0.8), fontWeight: FontWeight.bold)),
                  );
                }
                
                if (dateRange.length > 7) {
                  if (index == 0 || index == dateRange.length - 1 || dateRange[index].day % 5 == 0) {
                    return Text('${percentages[index].toStringAsFixed(0)}%', style: const TextStyle(fontSize: 8, color: Colors.blueGrey, fontWeight: FontWeight.bold));
                  }
                  return const SizedBox.shrink();
                } else {
                  return Text('${percentages[index].toStringAsFixed(0)}%', style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.bold));
                }
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30, 
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (index < 0 || index >= dateRange.length) return const SizedBox.shrink();
                DateTime date = dateRange[index];

                if (dateRange.length > 7) {
                  if (index == 0 || index == dateRange.length - 1 || date.day % 5 == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(DateFormat('d MMM').format(date), style: const TextStyle(fontSize: 9, color: Colors.grey)),
                    );
                  }
                  return const SizedBox.shrink();
                } else {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(DateFormat('E').format(date), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  );
                }
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
    );
  }

  // 🗓️ 1-TAP FILL CALENDAR (Updated for Perfect Dark/Light Mode Colors)
  Widget _buildGridCalendar(bool isJournal, List<HabitModel> activeHabits, List<dynamic> completions, List<dynamic> journals, Color fallbackColor) {
    final List<String> weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    int daysInMonth = DateUtils.getDaysInMonth(_calendarMonth.year, _calendarMonth.month);
    DateTime firstDayOfMonth = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    
    int emptySpacesBefore = firstDayOfMonth.weekday - 1; 

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          itemCount: 7, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, crossAxisSpacing: 6),
          itemBuilder: (context, index) => Center(child: Text(weekDays[index], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          itemCount: emptySpacesBefore + daysInMonth,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, crossAxisSpacing: 6, mainAxisSpacing: 6),
          itemBuilder: (context, index) {
            if (index < emptySpacesBefore) return const SizedBox.shrink();

            int dayNum = index - emptySpacesBefore + 1;
            DateTime currentGridDate = DateTime(_calendarMonth.year, _calendarMonth.month, dayNum);
            String dateStr = DateFormat('yyyy-MM-dd').format(currentGridDate);

            Color boxColor = Colors.transparent;
            bool isFilled = false; 
            bool isPausedDay = false;

            if (isJournal) {
              bool hasJournal = journals.any((j) => j.date == dateStr || j.createdAt.toString().startsWith(dateStr));
              if (hasJournal) {
                boxColor = fallbackColor;
                isFilled = true;
              }
            } else if (activeHabits.isNotEmpty) {
              for (var habit in activeHabits) {
                if (habit.activeDays.contains(currentGridDate.weekday) && _isDateOnOrAfterCreation(currentGridDate, habit.createdAt)) {
                  if (_isDatePaused(currentGridDate, habit.pauseLogs)) {
                    isPausedDay = true;
                  } else {
                    var matchingComps = completions.where((c) => c.habitId == habit.id && c.date == dateStr);
                    if (matchingComps.isNotEmpty && matchingComps.first.isCompleted > 0) {
                      boxColor = _getHabitColor(habit, context); 
                      isFilled = true; 
                    }
                  }
                }
              }
            }

            
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;

            // Empty box aur Pause box ke colors Theme ke hisaab se adjust honge
            Color emptyBoxBorder = isDark ? theme.colorScheme.outlineVariant.withValues(alpha: 0.3) : Colors.grey.shade300;
            Color pauseBoxBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200;
            Color pauseBoxBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade400;
            
            // Text color logic
            Color normalTextColor = isDark ? Colors.white70 : Colors.black87;
            Color dashTextColor = isDark ? Colors.white54 : Colors.grey.shade600;

            return Container(
              decoration: BoxDecoration(
                color: isFilled ? boxColor.withValues(alpha: 0.8) : (isPausedDay ? pauseBoxBg : Colors.transparent),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isFilled ? boxColor : (isPausedDay ? pauseBoxBorder : emptyBoxBorder), width: 1.5),
              ),
              child: Center(
                child: isPausedDay 
                  ? Text('-', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: dashTextColor)) 
                  : Text('$dayNum', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isFilled ? Colors.white : normalTextColor)),
              ),
            );
          },
        ),
      ],
    );
  }


  BoxDecoration _cardDecoration(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(24),
      boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 6))],
    );
  }

  Widget _buildStatCard(BuildContext context, {required String title, required String value, required IconData icon, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: _cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 2),
            Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularChart(int done, int missed, Color doneColor) {
    int total = done + missed;
    double progress = total > 0 ? done / total : 0.0;
    
    return SizedBox(
      width: 100, height: 100,
      child: CircularProgressIndicator(
        value: progress,
        strokeWidth: 15,
        backgroundColor: Colors.redAccent.withValues(alpha: 0.6),
        valueColor: AlwaysStoppedAnimation<Color>(doneColor),
      ),
    );
  }

  Widget _buildLegendItem(String title, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}