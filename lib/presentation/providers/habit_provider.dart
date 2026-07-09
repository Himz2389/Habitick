import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:habit_flow/domain/models/habit_model.dart';
import 'package:habit_flow/data/repositories/habit_repository.dart';
import 'package:habit_flow/core/services/notification_service.dart';

class HabitNotifier extends StateNotifier<List<HabitModel>> {
  final HabitRepository _repository;
  final NotificationService _notificationService = NotificationService();

  HabitNotifier(this._repository) : super([]) {
    loadHabits();
  }

  Future<void> _cancelHabitAlarms(HabitModel habit) async {
    if (habit.reminderTimes.isNotEmpty) {
      for (int i = 0; i < habit.reminderTimes.length; i++) {
        final safeId = (habit.id.hashCode + i).abs();
        await _notificationService.cancelNotification(safeId);
      }
      debugPrint("✅ All alarms successfully cancelled for: ${habit.name}");
    }
  }

  Future<void> loadHabits() async {
    await _autoCleanTrash();
    final habits = await _repository.getHabits();
    state = habits;
  }

  Future<void> addHabit(HabitModel habit) async {
    final nextOrder = await _repository.getNextDisplayOrder(habit.categoryId);

    final newHabit = habit.copyWith(displayOrder: nextOrder);
    await _repository.insertHabit(newHabit);
    await loadHabits();
  }

  //  REFRESHED UPGRADE: UPDATE HABIT WITH PAUSE & AUTO-TRASH TIMESTAMP LOGIC

  Future<void> updateHabit(HabitModel updatedHabit) async {
    // 1. Purani habit ko nikala taaki compare kar sakein ki status change hua hai ya nahi
    final oldHabit = state.firstWhere(
      (h) => h.id == updatedHabit.id,
      orElse: () => updatedHabit,
    );

    HabitModel finalHabitToSave = updatedHabit;
    String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 2. Agar user ne abhi-abhi PAUSE kiya hai (0 se 1)
    if (oldHabit.isPaused == 0 && updatedHabit.isPaused == 1) {
      List<String> newPauseLogs = List.from(oldHabit.pauseLogs);
      // Nayi entry dala: "2026-07-02|" (End date khali hai)
      newPauseLogs.add("$todayStr|");
      finalHabitToSave = updatedHabit.copyWith(pauseLogs: newPauseLogs);
    }
    // 3. Agar user ne abhi-abhi RESUME kiya hai (1 se 0)
    else if (oldHabit.isPaused == 1 && updatedHabit.isPaused == 0) {
      List<String> newPauseLogs = List.from(oldHabit.pauseLogs);
      if (newPauseLogs.isNotEmpty) {
        String lastLog = newPauseLogs.last;

        // Agar aakhiri log mein end date nahi hai, toh aaj ki date laga do
        if (lastLog.endsWith("|")) {
          newPauseLogs[newPauseLogs.length - 1] = "$lastLog$todayStr";
        }
      }
      finalHabitToSave = updatedHabit.copyWith(pauseLogs: newPauseLogs);
    }

    //  NEW AUTO-TRASH TIMESTAMP EXTENSION

    // Case A: Agar habit abhi-abhi TRASH mein bheji gayi hai (0 se 1 hui hai)
    if (oldHabit.isDeleted == 0 && updatedHabit.isDeleted == 1) {
      finalHabitToSave = finalHabitToSave.copyWith(
        deletedAt: DateTime.now().toIso8601String(),
      );
    }
    // Case B: Agar user ne TRASH se habit ko RESTORE kar liya (1 se wapas 0 hui)
    else if (oldHabit.isDeleted == 1 && updatedHabit.isDeleted == 0) {
      finalHabitToSave = finalHabitToSave.copyWith(deletedAt: null);
    }

    // Database aur State update karo
    await _repository.updateHabit(finalHabitToSave);
    state = [
      for (final habit in state)
        if (habit.id == finalHabitToSave.id) finalHabitToSave else habit,
    ];

    if (finalHabitToSave.isCompleted == 1 ||
        finalHabitToSave.isDeleted == 1 ||
        finalHabitToSave.isPaused == 1) {
      await _cancelHabitAlarms(finalHabitToSave);
    }
  }

  Future<void> updateHabitOrder(List<HabitModel> habits) async {
    await _repository.updateHabitOrders(habits);
    await loadHabits();
  }

  //  SMART SYNC: CATEGORY COLOR CHANGE HONE PAR HABITS KA COLOR BHI BADLO

  Future<void> syncCategoryColor(String categoryId, String newColor) async {
    // 1. Un saari habits ko filter kiya jo is category ke andar aati hain
    final habitsToUpdate = state
        .where((h) => h.categoryId == categoryId)
        .toList();

    // 2. Database mein ek-ek karke sabka color update karo
    for (var habit in habitsToUpdate) {
      final updatedHabit = habit.copyWith(color: newColor);
      await _repository.updateHabit(updatedHabit); // Database update
    }

    state = state.map((habit) {
      if (habit.categoryId == categoryId) {
        return habit.copyWith(color: newColor);
      }
      return habit;
    }).toList();

    debugPrint("✅ Category color synced successfully for all related habits!");
  }

  //  AUTO-CLEAN TRASH ENGINE (7 Days Logic)

  Future<void> _autoCleanTrash() async {
    final habits = await _repository.getHabits();
    final now = DateTime.now();

    for (var habit in habits) {
      if (habit.isDeleted == 1 && habit.deletedAt != null) {
        DateTime deletedDate = DateTime.parse(habit.deletedAt!);
        // Agar 7 din ya usse zyada ho gaye hain, toh hamesha ke liye DB se delete
        if (now.difference(deletedDate).inDays >= 7) {
          await _repository.deleteHabit(habit.id);
          debugPrint("🗑️ Auto-deleted from trash: ${habit.name}");
        }
      }
    }
  }
}

final habitProvider = StateNotifierProvider<HabitNotifier, List<HabitModel>>((
  ref,
) {
  return HabitNotifier(HabitRepository());
});
