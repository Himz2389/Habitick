import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_flow/domain/models/todo_model.dart';
import 'package:habit_flow/data/repositories/todo_repository.dart'; 
import 'package:habit_flow/core/services/notification_service.dart';

final todoRepositoryProvider = Provider<TodoRepository>((ref) {
  return TodoRepository(); 
});

class TodoNotifier extends StateNotifier<List<TodoModel>> {
  final TodoRepository _repository;
  final NotificationService _notificationService = NotificationService();

  TodoNotifier(this._repository) : super([]);

  // Database se tasks load karna
  Future<void> loadTodosForDate(String date) async {
    // Apni repository method ka exact naam check kar lena
    final todos = await _repository.getTodosByDate(date); 
    state = todos;
  }

  // Naya Task add karna
  Future<void> addTodo(TodoModel todo) async {
    await _repository.insertTodo(todo);
    await loadTodosForDate(todo.date); // UI refresh
    await _manageAlarms(todo); // Alarm set karo
  }

  // Task edit/update karna
  Future<void> updateTodo(TodoModel todo) async {
    await _repository.updateTodo(todo);
    await loadTodosForDate(todo.date);
    await _manageAlarms(todo); 
  }

  // Task delete karna
  Future<void> deleteTodo(String id) async {
    await _repository.deleteTodo(id);
    state = state.where((t) => t.id != id).toList(); 
    
    
    await _notificationService.cancelNotification(id.hashCode);
    await _notificationService.cancelNotification(id.hashCode + 1); 
  }

  // Task par Tick mark (Complete) lagana
  Future<void> toggleTodo(String id, int currentStatus) async {
    final newStatus = currentStatus == 1 ? 0 : 1;
    final todo = state.firstWhere((t) => t.id == id);
    
    final updatedTodo = TodoModel(
      id: todo.id, title: todo.title, description: todo.description,
      date: todo.date, isCompleted: newStatus, priority: todo.priority,
      isFocusMode: todo.isFocusMode, startTime: todo.startTime, endTime: todo.endTime,
    );
    
    await _repository.updateTodo(updatedTodo); 
    
    state = [
      for (final t in state)
        if (t.id == id) updatedTodo else t
    ];
    
    
    if (newStatus == 1) {
      await _notificationService.cancelNotification(id.hashCode);
      await _notificationService.cancelNotification(id.hashCode + 1);
    } else {
      
      await _manageAlarms(updatedTodo);
    }
  }

  
  //  THE BRAIN: ALARM SCHEDULING SYSTEM
  
  Future<void> _manageAlarms(TodoModel todo) async {
    final startAlarmId = todo.id.hashCode;
    final endAlarmId = todo.id.hashCode + 1; // End time ke liye alag ID

    // Rule 1: Pehle purane alarms cancel karo (Duplicate se bachne ke liye)
    await _notificationService.cancelNotification(startAlarmId);
    await _notificationService.cancelNotification(endAlarmId);

    // Rule 2: Alarm tabhi lagega jab Focus mode ON ho aur Task PENDING (0) ho
    if (todo.isFocusMode == 1 && todo.isCompleted == 0 && todo.startTime != null) {
      
      // Date tod kar saal, mahina, din nikalna
      final dateParts = todo.date.split('-');
      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);

      // Start Time Alarm Set 
      final startParts = todo.startTime!.split(':');
      final startDateTime = DateTime(year, month, day, int.parse(startParts[0]), int.parse(startParts[1]));

      
      if (startDateTime.isAfter(DateTime.now())) {
        await _notificationService.scheduleExactNotification(
          id: startAlarmId,
          title: 'Time to Focus! 🎯',
          body: 'Start working on: ${todo.title}',
          scheduledDate: startDateTime,
        );
      }

      // End Time Alarm Set 
      if (todo.endTime != null && todo.endTime!.isNotEmpty) {
        final endParts = todo.endTime!.split(':');
        final endDateTime = DateTime(year, month, day, int.parse(endParts[0]), int.parse(endParts[1]));

        if (endDateTime.isAfter(DateTime.now())) {
          await _notificationService.scheduleExactNotification(
            id: endAlarmId,
            title: 'Time is Up! ⏰',
            body: 'Wrap up your task: ${todo.title}',
            scheduledDate: endDateTime,
          );
        }
      }
    }
  }
}

// Provider Declaration
final todoProvider = StateNotifierProvider<TodoNotifier, List<TodoModel>>((ref) {
  final repository = ref.watch(todoRepositoryProvider);
  return TodoNotifier(repository);
});