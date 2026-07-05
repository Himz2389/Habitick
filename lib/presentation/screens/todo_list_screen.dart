import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:habit_flow/domain/models/todo_model.dart';
import 'package:habit_flow/presentation/providers/todo_provider.dart';

class TodoListScreen extends ConsumerStatefulWidget {
  const TodoListScreen({super.key});

  @override
  ConsumerState<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends ConsumerState<TodoListScreen> {
  late PageController _pageController;
  DateTime _today = DateTime.now();
  late DateTime _selectedDate;
  
  final int _todayIndex = 10000; 

  @override
  void initState() {
    super.initState();
    _today = DateTime(_today.year, _today.month, _today.day);
    _selectedDate = _today;
    _pageController = PageController(initialPage: _todayIndex);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTodosForSelectedDate();
    });
  }

  void _loadTodosForSelectedDate() {
    String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    ref.read(todoProvider.notifier).loadTodosForDate(dateStr);
  }

  Future<void> _pickDate() async {
    
    final currentTodosState = ref.read(todoProvider); 
    
    DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => CustomTodoDatePicker(
        initialDate: _selectedDate,
        maxAllowedDate: _today.add(const Duration(days: 3)),
        allLoadedTodos: currentTodosState, 
      ),
    );

    if (picked != null) {
      int difference = picked.difference(_today).inDays;
      _pageController.animateToPage(
        _todayIndex + difference,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  int _getPriorityWeight(String priority) {
    if (priority == 'High') return 3;
    if (priority == 'Medium') return 2;
    return 1;
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High': return Colors.red;
      case 'Medium': return Colors.orange;
      case 'Low': return Colors.green;
      default: return Colors.blue;
    }
  }

  void _showAddEditTodoModal({TodoModel? existingTodo}) {
    final titleController = TextEditingController(text: existingTodo?.title ?? '');
    final descController = TextEditingController(text: existingTodo?.description ?? '');
    String selectedPriority = existingTodo?.priority ?? 'Medium';
    bool isFocusMode = existingTodo?.isFocusMode == 1;
    
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    
    if (existingTodo?.startTime != null) {
      final parts = existingTodo!.startTime!.split(':');
      startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    if (existingTodo?.endTime != null) {
      final parts = existingTodo!.endTime!.split(':');
      endTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20, right: 20, top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(existingTodo == null ? 'Add New Task' : 'Edit Task', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Task Title', border: OutlineInputBorder()),
                      autofocus: existingTodo == null,
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Description (Optional)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: selectedPriority,
                      decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
                      items: ['Low', 'Medium', 'High'].map((p) {
                        return DropdownMenuItem(
                          value: p,
                          child: Row(
                            children: [
                              Container(
                                width: 12, height: 12,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: _getPriorityColor(p)),
                              ),
                              const SizedBox(width: 10),
                              Text(p),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) { if (val != null) selectedPriority = val; },
                    ),
                    const SizedBox(height: 20),

                    // FOCUS MODE
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.center_focus_strong, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('Focus Mode', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                ],
                              ),
                              Switch(
                                value: isFocusMode,
                                onChanged: (val) => setModalState(() => isFocusMode = val),
                              ),
                            ],
                          ),
                          if (isFocusMode) ...[
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.play_arrow),
                                  label: Text(startTime != null ? startTime!.format(context) : 'Start Time *'),
                                  onPressed: () async {
                                    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                                    if (time != null) setModalState(() => startTime = time);
                                  },
                                ),
                                const Text('-'),
                                TextButton.icon(
                                  icon: const Icon(Icons.stop),
                                  label: Text(endTime != null ? endTime!.format(context) : 'End Time (Opt)'),
                                  onPressed: () async {
                                    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                                    if (time != null) setModalState(() => endTime = time);
                                  },
                                ),
                              ],
                            ),
                          ]
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                      onPressed: () {
                        if (titleController.text.trim().isNotEmpty) {
                          if (isFocusMode && startTime == null) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Start Time is required for Focus Mode')));
                            return;
                          }

                          String formatTime(TimeOfDay? t) => t != null ? '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}' : '';

                          final updatedTodo = TodoModel(
                            id: existingTodo?.id ?? const Uuid().v4(),
                            title: titleController.text.trim(),
                            description: descController.text.trim(),
                            date: DateFormat('yyyy-MM-dd').format(_selectedDate),
                            isCompleted: existingTodo?.isCompleted ?? 0,
                            priority: selectedPriority,
                            isFocusMode: isFocusMode ? 1 : 0,
                            startTime: isFocusMode ? formatTime(startTime) : null,
                            endTime: isFocusMode && endTime != null ? formatTime(endTime) : null,
                          );
                          
                          if (existingTodo == null) {
                            ref.read(todoProvider.notifier).addTodo(updatedTodo);
                          } else {
                            ref.read(todoProvider.notifier).updateTodo(updatedTodo);
                          }
                          Navigator.pop(context); 
                        }
                      },
                      child: Text(existingTodo == null ? 'Save Task' : 'Update Task', style: const TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final todos = ref.watch(todoProvider);
    bool isPast = _selectedDate.isBefore(_today);

    final pendingTodos = todos.where((t) => t.isCompleted == 0).toList();
    final completedTodos = todos.where((t) => t.isCompleted == 1).toList();

    pendingTodos.sort((a, b) {
      int priorityCompare = _getPriorityWeight(b.priority).compareTo(_getPriorityWeight(a.priority));
      if (priorityCompare != 0) return priorityCompare;

      String timeA = a.startTime ?? "24:00"; 
      String timeB = b.startTime ?? "24:00";
      return timeA.compareTo(timeB); 
    });

    String displayDate = _selectedDate.day == _today.day && _selectedDate.month == _today.month 
          ? "Today's Tasks" 
          : DateFormat('EEEE, MMMM d').format(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: Text(displayDate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      ),
      body: Column(
        children: [
          // === DATE SLIDER HEADER ===
          Container(
            height: 50,
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 18),
                  onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _todayIndex + 4, 
                    onPageChanged: (index) {
                      setState(() {
                        _selectedDate = _today.add(Duration(days: index - _todayIndex));
                      });
                      _loadTodosForSelectedDate();
                    },
                    itemBuilder: (context, index) {
                      DateTime date = _today.add(Duration(days: index - _todayIndex));
                      return Center(
                        child: InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Text(
                              DateFormat('dd MMM yyyy').format(date),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blue),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.arrow_forward_ios, size: 18, color: _selectedDate.difference(_today).inDays >= 3 ? Colors.grey.withValues(alpha: 0.3) : null),
                  onPressed: () {
                    if (_selectedDate.difference(_today).inDays < 3) {
                      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                    }
                  },
                ),
              ],
            ),
          ),
          
          // === TASKS LIST (WITH SCREEN SWIPE DETECTOR) ===
          Expanded(
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity! < -300) {
                  if (_selectedDate.difference(_today).inDays < 3) {
                    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  }
                } else if (details.primaryVelocity! > 300) {
                  _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                }
              },
              child: Container(
                color: Colors.transparent, 
                child: todos.isEmpty
                    ? Center(
                        child: Text(
                          isPast ? 'No tasks were added on this day.' : 'Your To-Do List is empty.\nLet\'s add something\n    Awesome! ✨',
                          textAlign: TextAlign.center, 
                          style: const TextStyle(fontSize: 20, color: Colors.grey)
                        ),
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(), 
                        padding: const EdgeInsets.all(8.0),
                        children: [
                          ...pendingTodos.map((todo) => _buildTodoCard(todo, isDone: false, isPast: isPast)),
                          if (completedTodos.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.only(top: 16, bottom: 8, left: 8),
                              child: Text('Completed Tasks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                            ),
                            ...completedTodos.map((todo) => _buildTodoCard(todo, isDone: true, isPast: isPast)),
                          ]
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: isPast 
          ? null 
          : FloatingActionButton(
              backgroundColor: Theme.of(context).colorScheme.primary, 
              foregroundColor: Colors.white, 
              onPressed: () => _showAddEditTodoModal(),
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildTodoCard(TodoModel todo, {required bool isDone, required bool isPast}) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: isDone ? 0.3 : 0.5),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        onTap: isPast ? null : () => _showAddEditTodoModal(existingTodo: todo), 
        leading: Checkbox(
          value: isDone,
          onChanged: isPast ? null : (bool? value) {
            ref.read(todoProvider.notifier).toggleTodo(todo.id, todo.isCompleted);
          },
        ),
        title: Text(
          todo.title,
          style: TextStyle(
            decoration: isDone ? TextDecoration.lineThrough : null, 
            fontWeight: FontWeight.w600, 
            color: isDone ? Colors.grey : null
          ),
        ),
        subtitle: todo.description.isNotEmpty 
            ? Text(
                todo.description, 
                style: TextStyle(color: isDone ? Colors.grey : null)
              ) 
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12, height: 12, 
              decoration: BoxDecoration(shape: BoxShape.circle, color: _getPriorityColor(todo.priority))
            ),
            const SizedBox(width: 8),
            if (!isPast)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => ref.read(todoProvider.notifier).deleteTodo(todo.id),
              ),
          ],
        ),
      ),
    );
  }
}


//  NAYA WIDGET: MATERIAL 3 COMPATIBLE TO-DO DIALOG WITH PRODUCTIVITY MATRIX!

class CustomTodoDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime maxAllowedDate;
  final List<TodoModel> allLoadedTodos; 

  const CustomTodoDatePicker({
    super.key, 
    required this.initialDate, 
    required this.maxAllowedDate,
    required this.allLoadedTodos,
  });

  @override
  State<CustomTodoDatePicker> createState() => _CustomTodoDatePickerState();
}

class _CustomTodoDatePickerState extends State<CustomTodoDatePicker> {
  late DateTime _selectedDate;
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _displayedMonth = DateTime(widget.initialDate.year, widget.initialDate.month, 1);
  }

  void _showYearPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        content: SizedBox(
          width: 300, height: 400,
          child: YearPicker(
            firstDate: DateTime(2000),
            lastDate: widget.maxAllowedDate,
            initialDate: _displayedMonth,
            selectedDate: _displayedMonth,
            onChanged: (DateTime dateTime) {
              Navigator.pop(context);
              setState(() {
                _displayedMonth = DateTime(dateTime.year, _displayedMonth.month, 1);
              });
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final List<String> weekDays = ['S', 'M', 'T', 'W', 'T', 'F', 'S']; 
    
    int daysInMonth = DateUtils.getDaysInMonth(_displayedMonth.year, _displayedMonth.month);
    int emptySpacesBefore = _displayedMonth.weekday == 7 ? 0 : _displayedMonth.weekday;
    DateTime todayOnly = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    return Dialog(
      backgroundColor: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Select date", style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd MMM, EEE').format(_selectedDate),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5), height: 1),
            const SizedBox(height: 8),
            
            // --- MONTH SWITCHER ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _showYearPicker,
                  style: TextButton.styleFrom(foregroundColor: theme.colorScheme.onSurface),
                  child: Row(
                    children: [
                      Text(DateFormat('MMMM yyyy').format(_displayedMonth), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left, color: theme.colorScheme.onSurface),
                      onPressed: () => setState(() => _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1, 1)),
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right, color: theme.colorScheme.onSurface),
                      onPressed: (_displayedMonth.year == widget.maxAllowedDate.year && _displayedMonth.month == widget.maxAllowedDate.month) 
                          ? null 
                          : () => setState(() => _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1)),
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 8),
            
            // --- WEEKDAYS MATRIX ---
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 7,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
              itemBuilder: (context, index) => Center(
                child: Text(weekDays[index], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant)),
              ),
            ),
            
            // --- DAYS MATRIX + TARGET PERFORMANCE LOGIC ---
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: emptySpacesBefore + daysInMonth,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
              itemBuilder: (context, index) {
                if (index < emptySpacesBefore) return const SizedBox.shrink();

                int dayNum = index - emptySpacesBefore + 1;
                DateTime currentGridDate = DateTime(_displayedMonth.year, _displayedMonth.month, dayNum);
                
                bool isFutureBlocked = currentGridDate.isAfter(widget.maxAllowedDate);
                bool isSelected = currentGridDate.year == _selectedDate.year && currentGridDate.month == _selectedDate.month && currentGridDate.day == _selectedDate.day;
                bool isToday = currentGridDate.year == todayOnly.year && currentGridDate.month == todayOnly.month && currentGridDate.day == todayOnly.day;

                //  AAPKA DYNAMIC CIRCLE LOGIC ENGINE
                String dateStrCheck = DateFormat('yyyy-MM-dd').format(currentGridDate);
                
                // Watch entries list filtered by matching iteration date sequence
                var targetedDayTasks = widget.allLoadedTodos.where((t) => t.date == dateStrCheck).toList();
                
                bool hasTasks = targetedDayTasks.isNotEmpty;
                bool allTasksCompleted = hasTasks && targetedDayTasks.every((t) => t.isCompleted == 1);

                // Styling Configuration Matrix
                BoxDecoration dayBoxDecoration = const BoxDecoration();
                Color textColor = theme.colorScheme.onSurface;

                if (isSelected) {
                  dayBoxDecoration = BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  );
                  textColor = theme.colorScheme.onPrimary;
                } else if (isFutureBlocked) {
                  textColor = theme.colorScheme.onSurface.withValues(alpha: 0.3);
                } else {
                  if (allTasksCompleted) {
                    // Rule 2: Sub tasks completed -> light filled transparent background circle
                    dayBoxDecoration = BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4), width: 1.5),
                    );
                  } else if (hasTasks) {
                    // Rule 1: Tasks exist but incomplete -> transparent circle outline border
                    dayBoxDecoration = BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4), width: 1.5),
                    );
                  } else if (isToday) {
                    // Normal today highlighting ring if no actions registered yet
                    dayBoxDecoration = BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.colorScheme.primary, width: 1.5),
                    );
                  }
                }

                return GestureDetector(
                  onTap: isFutureBlocked ? null : () => setState(() => _selectedDate = currentGridDate),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: dayBoxDecoration,
                    child: Center(
                      child: Text(
                        '$dayNum',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            
            // --- ACTION CONTROLS ---
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context, _selectedDate),
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}