import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; 
import 'package:uuid/uuid.dart';

import 'package:habit_flow/domain/models/habit_model.dart';
import 'package:habit_flow/domain/models/category_model.dart';
import 'package:habit_flow/presentation/providers/habit_provider.dart';
import 'package:habit_flow/presentation/providers/category_provider.dart';
import 'package:habit_flow/core/services/notification_service.dart'; 

class EditHabitScreen extends ConsumerStatefulWidget {
  final HabitModel habit; 
  
  const EditHabitScreen({super.key, required this.habit});

  @override
  ConsumerState<EditHabitScreen> createState() => _EditHabitScreenState();
}

class _EditHabitScreenState extends ConsumerState<EditHabitScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  
  late String? _selectedCategoryId;
  late String _selectedPriority;
  final List<String> _priorities = ['Low', 'Medium', 'High'];
  late List<int> _selectedDays; 
  final List<String> _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  late bool _isReminderEnabled;
  late int _timesPerDay; 
  late List<TimeOfDay?> _selectedTimes; 

  // 🚨 NAYE STATUS VARIABLES
  late bool _isPaused;
  late bool _isCompleted;

  @override
  void initState() {
    super.initState();
    
    _nameController = TextEditingController(text: widget.habit.name);
    _selectedCategoryId = widget.habit.categoryId;
    _selectedPriority = widget.habit.priority;
    _selectedDays = List.from(widget.habit.activeDays);
    _timesPerDay = widget.habit.timesPerDay;
    
    _isReminderEnabled = widget.habit.reminderTimes.isNotEmpty;
    
    //  STATUS INIT
    _isPaused = widget.habit.isPaused == 1;
    _isCompleted = widget.habit.isCompleted == 1; // Ye HabitModel me add karna zaroori hai
    
    _selectedTimes = List.generate(_timesPerDay, (index) {
      if (index < widget.habit.reminderTimes.length) {
        final timeStr = widget.habit.reminderTimes[index];
        final parts = timeStr.split(':');
        if (parts.length == 2) {
          return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }
      }
      return null;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context, int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTimes[index] ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTimes[index] = picked;
      });
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final categoryNameController = TextEditingController();
    Color pickerColor = Colors.blueAccent; 
    
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder( 
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create New Category', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: categoryNameController,
                      decoration: const InputDecoration(labelText: 'Category Name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 20),
                    const Text('Choose Panel Color:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    if (categoryNameController.text.isNotEmpty) {
                      String hexColor = '0xFF${pickerColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                      final newCategory = CategoryModel(id: const Uuid().v4(), name: categoryNameController.text, color: hexColor);
                      
                      ref.read(categoryProvider.notifier).addCategory(newCategory);
                      Navigator.pop(context); 

                      Future.delayed(const Duration(milliseconds: 150), () {
                        if (mounted) setState(() => _selectedCategoryId = newCategory.id);
                      });
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _saveHabit() {
    if (_formKey.currentState!.validate()) {
      final categories = ref.read(categoryProvider);
      if (_selectedCategoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a category!')));
        return;
      }
      if (_selectedDays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one day!')));
        return;
      }
      if (_isReminderEnabled && _selectedTimes.any((time) => time == null)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please set all reminder times!')));
        return;
      }

      final selectedCategoryObj = categories.firstWhere((c) => c.id == _selectedCategoryId);

      List<String> formattedTimes = [];
      if (_isReminderEnabled) {
        formattedTimes = _selectedTimes.map((t) => "${t!.hour}:${t.minute}").toList();
      }

      //  UPDATE HABIT MODEL
      final updatedHabit = HabitModel(
        id: widget.habit.id, 
        categoryId: _selectedCategoryId!,
        name: _nameController.text,
        priority: _selectedPriority,
        activeDays: _selectedDays, 
        createdAt: widget.habit.createdAt, 
        category: selectedCategoryObj.name, 
        color: selectedCategoryObj.color,   
        isPaused: _isPaused ? 1 : 0, // 🚨 PAUSE UPDATE             
        isCompleted: _isCompleted ? 1 : 0, // 🚨 COMPLETE UPDATE             
        isDeleted: 0,
        timesPerDay: _timesPerDay, 
        reminderTimes: formattedTimes, 
      );

      ref.read(habitProvider.notifier).updateHabit(updatedHabit);

      final notificationService = NotificationService();
      
      for (int i = 0; i < widget.habit.timesPerDay; i++) {
        notificationService.cancelNotification(widget.habit.id.hashCode + i);
      }

      
      if (_isReminderEnabled && !_isPaused && !_isCompleted) {
        for (int i = 0; i < _selectedTimes.length; i++) {
          if (_selectedTimes[i] != null) {
            notificationService.scheduleDailyNotification(
              id: widget.habit.id.hashCode + i, 
              title: updatedHabit.name,
              body: 'Time for your habit! (${i + 1}/$_timesPerDay) 🚀',
              time: _selectedTimes[i]!,
            );
          }
        }
      }
      
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryProvider);

    bool categoryExists = categories.any((c) => c.id == _selectedCategoryId);
    if (!categoryExists) {
      _selectedCategoryId = null; 
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Habit', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView( 
            children: [
              
              
              //  HABIT STATUS CARD (Pause / Complete)
              
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: _isCompleted 
                      ? Colors.green.withValues(alpha: 0.05) 
                      : (_isPaused ? Colors.orange.withValues(alpha: 0.05) : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)),
                  border: Border.all(
                    color: _isCompleted 
                        ? Colors.green.withValues(alpha: 0.5) 
                        : (_isPaused ? Colors.orange.withValues(alpha: 0.5) : Colors.grey.shade300)
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Pause Habit', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Temporarily stop tracking this habit', style: TextStyle(fontSize: 12)),
                      value: _isPaused,
                      activeThumbColor: Colors.orange,
                      // Agar complete ho gayi, toh pause nahi kar sakte
                      onChanged: _isCompleted ? null : (val) {
                        setState(() => _isPaused = val);
                      },
                    ),
                    Divider(height: 1, color: Colors.grey.shade300),
                    SwitchListTile(
                      title: const Text('Mark as Completed', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Move this habit to your completed list', style: TextStyle(fontSize: 12)),
                      value: _isCompleted,
                      activeThumbColor: Colors.green,
                      onChanged: (val) {
                        setState(() {
                          _isCompleted = val;
                          if (val) _isPaused = false; 
                        });
                      },
                    ),
                  ],
                ),
              ),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Category', 
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 14), 
                      ),
                      initialValue: _selectedCategoryId, 
                      items: categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                      onChanged: (val) => setState(() => _selectedCategoryId = val),
                      hint: const Text('Select Category'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 56, 
                    child: IconButton.filled(onPressed: _showAddCategoryDialog, icon: const Icon(Icons.add)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Habit Name', hintText: 'e.g. Drink Water', border: OutlineInputBorder()),
                validator: (value) => value == null || value.isEmpty ? 'Please enter a habit name' : null,
              ),
              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 14)),
                initialValue: _selectedPriority, 
                items: _priorities.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (val) { if (val != null) setState(() => _selectedPriority = val); },
              ),
              const SizedBox(height: 30),

              const Text('Active Days', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (index) {
                  int dayValue = index + 1; 
                  bool isSelected = _selectedDays.contains(dayValue);
                  return GestureDetector(
                    onTap: () {
                      setState(() { isSelected ? _selectedDays.remove(dayValue) : _selectedDays.add(dayValue); });
                    },
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                        border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade400, width: 1.5),
                      ),
                      child: Center(
                        child: Text(_dayNames[index], style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 30),

              const Text('Daily Goal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Times per day:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          color: Theme.of(context).colorScheme.primary,
                          onPressed: _timesPerDay > 1 ? () {
                            setState(() {
                              _timesPerDay--;
                              _selectedTimes.removeLast(); 
                            });
                          } : null,
                        ),
                        Text('$_timesPerDay', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          color: Theme.of(context).colorScheme.primary,
                          onPressed: () {
                            setState(() {
                              _timesPerDay++;
                              _selectedTimes.add(null); 
                            });
                          },
                        ),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.notifications_active_outlined, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Daily Reminders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        Switch(
                          value: _isReminderEnabled,
                          onChanged: (val) {
                            setState(() {
                              _isReminderEnabled = val;
                              if (val && _selectedTimes[0] == null) {
                                _selectTime(context, 0); 
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    if (_isReminderEnabled) ...[
                      const Divider(),
                      const SizedBox(height: 5),
                      ...List.generate(_timesPerDay, (index) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Reminder ${index + 1}'),
                          trailing: TextButton.icon(
                            onPressed: () => _selectTime(context, index),
                            icon: const Icon(Icons.access_time),
                            label: Text(
                              _selectedTimes[index] != null ? _selectedTimes[index]!.format(context) : 'Choose Time',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        );
                      }),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 30),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saveHabit,
                child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}