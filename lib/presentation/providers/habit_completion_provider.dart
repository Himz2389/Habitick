import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_flow/domain/models/habit_completion_model.dart';
import 'package:habit_flow/data/repositories/habit_completion_repository.dart';
import 'package:intl/intl.dart'; 

// 1. Repository Provider
final habitCompletionRepositoryProvider = Provider<HabitCompletionRepository>((ref) {
  return HabitCompletionRepository();
});

// 2. StateNotifier
class HabitCompletionNotifier extends StateNotifier<List<HabitCompletionModel>> {
  final HabitCompletionRepository _repository;

  HabitCompletionNotifier(this._repository) : super([]) {
    loadCompletions();
  }

  // Database se saari completions load karna
  Future<void> loadCompletions() async {
    final completions = await _repository.getAllCompletions();
    state = completions;
  }

  // Tick lagana ya hatana
  Future<void> toggleHabitCompletion(HabitCompletionModel completion) async {
    await _repository.toggleCompletion(completion);
    await loadCompletions(); 
  }
  
  //  BUG FIX: Ab ye hardcoded '1' nahi, balki target (timesPerDay) check karega
  bool isHabitCompletedOnDate(String habitId, String date, int targetTimes) {
    return state.any((completion) => 
      completion.habitId == habitId && 
      completion.date == date && 
      completion.isCompleted >= targetTimes
    );
  }


  int calculateStreak(String habitId, List<int> activeDays, int timesPerDay) {
    if (state.isEmpty) return 0;
    
    DateTime today = DateTime.now();
    // Pichle 365 din check karenge
    List<DateTime> historyDates = List.generate(365, (i) => today.subtract(Duration(days: i))).reversed.toList();
    
    int runningStreak = 0;
    
    for (var date in historyDates) {
      if (!activeDays.contains(date.weekday)) continue; // Not an active day
      
      String dateStr = DateFormat('yyyy-MM-dd').format(date); 
      var matchingComps = state.where((c) => c.habitId == habitId && c.date == dateStr);
      var comp = matchingComps.isNotEmpty ? matchingComps.first : null;
      
      
      if (comp != null && comp.isCompleted > 0) {
        runningStreak++;
      } else {
        
        if (!date.isAfter(today.subtract(const Duration(days: 1)))) {
          runningStreak = 0;
        }
      }
    }
    return runningStreak;
  }
}

// 3. Main Provider
final habitCompletionProvider = StateNotifierProvider<HabitCompletionNotifier, List<HabitCompletionModel>>((ref) {
  final repository = ref.watch(habitCompletionRepositoryProvider);
  return HabitCompletionNotifier(repository);
});