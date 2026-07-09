import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';
import 'package:habit_flow/domain/models/journal_model.dart';
import 'package:habit_flow/presentation/providers/journal_provider.dart';
import 'dart:io';


// 1. SMART NOTEPAD SCREEN (Main Journal Tab)

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

//  WidgetsBindingObserver AUTO-SAVE ke liye
class _JournalScreenState extends ConsumerState<JournalScreen> with WidgetsBindingObserver {
  late DateTime _selectedDate;
  final TextEditingController _titleController = TextEditingController();
  late QuillController _quillController;
  final FocusNode _editorFocus = FocusNode();
  final ScrollController _editorScroll = ScrollController();
  
  //  Sirf 4 Required Moods
  String _selectedMood = '😊';
  final List<String> _moods = ['🥰', '😊', '😔', '😡'];
  
  bool _isToolbarExpanded = false; 
  JournalModel? _currentJournal;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Auto-save chalu
    _selectedDate = DateTime.now();
    _quillController = QuillController.basic();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadJournalForDate(_selectedDate);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Auto-save band
    _titleController.dispose();
    _quillController.dispose();
    _editorFocus.dispose();
    _editorScroll.dispose();
    super.dispose();
  }

  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _saveCurrentJournal(showSnackbar: false);
    }
  }

  void _loadJournalForDate(DateTime date) {
    final allJournals = ref.read(journalProvider);
    final dateString = DateFormat('dd MMM yyyy').format(date);
    
    try {
      final existingJournal = allJournals.firstWhere((j) => j.date.startsWith(dateString));
      setState(() {
        _currentJournal = existingJournal;
        _titleController.text = existingJournal.title;
        _selectedMood = existingJournal.mood ?? '😊';
        
        final myJSON = jsonDecode(existingJournal.content);
        _quillController = QuillController(
          document: Document.fromJson(myJSON),
          selection: const TextSelection.collapsed(offset: 0),
        );
      });
    } catch (e) {
      setState(() {
        _currentJournal = null;
        _titleController.clear();
        _selectedMood = '😊';
        _quillController = QuillController.basic();
      });
    }
  }

  void _saveCurrentJournal({bool showSnackbar = true}) {
    if (_titleController.text.trim().isEmpty && _quillController.document.isEmpty()) {
      return; 
    }

    final contentJson = jsonEncode(_quillController.document.toDelta().toJson());
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(_selectedDate);

    final newJournal = JournalModel(
      id: _currentJournal?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text, // Ab title optional hai
      content: contentJson,
      date: _currentJournal?.date ?? dateStr,
      mood: _selectedMood,
      
      createdAt: _currentJournal?.createdAt ?? DateTime.now().toIso8601String(),
    );

    if (_currentJournal != null) {
      ref.read(journalProvider.notifier).updateJournal(newJournal);
    } else {
      ref.read(journalProvider.notifier).addJournal(newJournal);
      _currentJournal = newJournal;
    }
    
    if (showSnackbar && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved!'), duration: Duration(milliseconds: 800)),
      );
    }
  }

  //  SWIPE LOGIC
  void _changeDate(int days) {
    final newDate = _selectedDate.add(Duration(days: days));
    final today = DateTime.now();
    
    // Future date block
    if (newDate.isAfter(today) && newDate.day != today.day) {
      return; 
    }
    
    _saveCurrentJournal(showSnackbar: false);
    setState(() => _selectedDate = newDate);
    _loadJournalForDate(_selectedDate);
  }

  //  Image Upload Function
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final index = _quillController.selection.baseOffset;
      final length = _quillController.selection.extentOffset - index;
      _quillController.replaceText(index, length, BlockEmbed.image(pickedFile.path), null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom; // Keyboard height detection

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // ==========================================
                // 🛠️ CUSTOM HEADER
                // ==========================================
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.history, size: 30),
                        color: theme.colorScheme.primary,
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const JournalHistoryScreen()));
                          },
                      ),
                      const SizedBox(width: 8),
                      
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final allJournals = ref.read(journalProvider);
                            // 🚨 NAYA: Ekdum Native Material 3 jaisa Custom Date Picker!
                            final pickedDate = await showDialog<DateTime>(
                              context: context,
                              builder: (context) => CustomEmojiDatePicker(
                                initialDate: _selectedDate,
                                journals: allJournals,
                              ),
                            );
                            
                            if (pickedDate != null) {
                              _saveCurrentJournal(showSnackbar: false);
                              setState(() => _selectedDate = pickedDate);
                              _loadJournalForDate(pickedDate);
                            }
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedDate.day == DateTime.now().day ? "Today" : "Past Entry",
                                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                DateFormat('dd MMM, EEE').format(_selectedDate),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      PopupMenuButton<String>(
                        initialValue: _selectedMood,
                        child: Text(_selectedMood, style: const TextStyle(fontSize: 24)),
                        onSelected: (String mood) => setState(() => _selectedMood = mood),
                        itemBuilder: (BuildContext context) {
                          return _moods.map((String choice) {
                            return PopupMenuItem<String>(
                              value: choice,
                              child: Text(choice, style: const TextStyle(fontSize: 24)),
                            );
                          }).toList();
                        },
                      ),
                      
                      const SizedBox(width: 12),
                      
                      TextButton(
                        onPressed: _saveCurrentJournal,
                        child: Text("Save", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                      ),
                    ],
                  ),
                ),

                
                // THE NOTEPAD AREA (Swipeable)
                
                Expanded(
                  child: GestureDetector(
                    onHorizontalDragEnd: (details) {
                      if (details.primaryVelocity! > 0) {
                        _changeDate(-1);
                      } else if (details.primaryVelocity! < 0) _changeDate(1);
                    },
                    child: Container(
                      color: Colors.transparent, 
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          TextField(
                            controller: _titleController,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(
                              hintText: 'Title',
                              border: InputBorder.none,
                            ),
                          ),
                          Expanded(
                            child: QuillEditor.basic(
                              controller: _quillController,
                                focusNode: _editorFocus,          // 👈 Yahan change kiya
                                scrollController: _editorScroll,
                                config: QuillEditorConfig( // 👈 Naya V11 code (config)
                                embedBuilders: [CustomImageEmbedBuilder()],
                              ),
                            ),
                          ),                          
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            
            //  EXPANDABLE TOOLBAR (Floating over keyboard)
            
            Positioned(
              bottom: bottomInset > 0 ? bottomInset + 10 : 20, 
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: _isToolbarExpanded ? MediaQuery.of(context).size.width - 90 : 0,
                    height: 50,
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)
                      ],
                    ),
                    child: _isToolbarExpanded 
                      ? SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              // 🚨 Image Upload Icon Added Here!
                              IconButton(
                                icon: const Icon(Icons.image, color: Colors.blue),
                                onPressed: _pickImage,
                              ),
                              Container(width: 1, height: 30, color: Colors.grey.shade300),
                              QuillSimpleToolbar(
                                controller: _quillController,
                              ),
                            ],
                          )
                        )
                      : const SizedBox.shrink(),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  FloatingActionButton(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    child: Icon(_isToolbarExpanded ? Icons.close : Icons.text_format),
                    onPressed: () {
                      setState(() {
                        _isToolbarExpanded = !_isToolbarExpanded;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// 2. JOURNAL HISTORY SCREEN (List View)

class JournalHistoryScreen extends ConsumerWidget {
  const JournalHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journals = ref.watch(journalProvider);
    final theme = Theme.of(context);

    final sortedJournals = List<JournalModel>.from(journals);
    sortedJournals.sort((a, b) {
      final dateA = DateTime.tryParse(a.createdAt) ?? DateTime.now();
      final dateB = DateTime.tryParse(b.createdAt) ?? DateTime.now();
      return dateB.compareTo(dateA); // Descending (Newest First)
    });

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text("Journal History", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 6,
      ),
      body: sortedJournals.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off, size: 80, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text("No history found.", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedJournals.length,
              itemBuilder: (context, index) {
                final journal = sortedJournals[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    title: Text(
                      journal.title.isEmpty ? "Untitled Note" : journal.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        journal.date,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                    
                    trailing: Text(journal.mood ?? '😊', style: const TextStyle(fontSize: 28)),
                    onTap: () {
                      // Tap karne par Read-Only screen par bhejenge
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => JournalReadScreen(journal: journal),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}


// 3. READ-ONLY & EDIT SCREEN

class JournalReadScreen extends ConsumerStatefulWidget {
  final JournalModel journal;
  const JournalReadScreen({super.key, required this.journal});

  @override
  ConsumerState<JournalReadScreen> createState() => _JournalReadScreenState();
}

class _JournalReadScreenState extends ConsumerState<JournalReadScreen> {
  late QuillController _quillController;
  late TextEditingController _titleController;
  bool _isEditing = false;
  final FocusNode _editorFocus = FocusNode();
  final ScrollController _editorScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.journal.title);
    final myJSON = jsonDecode(widget.journal.content);
    
    // 🚨 V11.5.1 MAGIC: readOnly ab controller ke andar hota hai!
    _quillController = QuillController(
      document: Document.fromJson(myJSON),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true, // Pehle se Read-Only
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quillController.dispose();
    _editorFocus.dispose();
    _editorScroll.dispose();
    super.dispose();
  }

  void _saveEdits() {
    final contentJson = jsonEncode(_quillController.document.toDelta().toJson());
    final updatedJournal = JournalModel(
      id: widget.journal.id,
      title: _titleController.text,
      content: contentJson,
      date: widget.journal.date,
      mood: widget.journal.mood,
      createdAt: widget.journal.createdAt,
    );

    ref.read(journalProvider.notifier).updateJournal(updatedJournal);
    setState(() {
      _isEditing = false;
      _quillController.readOnly = true; // 🚨 Wapas Read-Only mode mein daalo
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Changes Saved!')),
    );
  }

  void _deleteJournal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Journal?"),
        content: const Text("Are you sure you want to delete this entry? This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              ref.read(journalProvider.notifier).deleteJournal(widget.journal.id);
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Journal Deleted')),
              );
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(widget.journal.date, style: const TextStyle(fontSize: 16)),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 6,
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: "Save",
              onPressed: _saveEdits,
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: "Edit",
              onPressed: () {
                setState(() {
                  _isEditing = true;
                  _quillController.readOnly = false; // 🚨 Keyboard kholne ki permission de di
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: "Delete",
              onPressed: _deleteJournal,
            ),
          ]
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
              child: Row(
                children: [
                  Text(widget.journal.mood ?? '😊', style: const TextStyle(fontSize: 25)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _titleController,
                      readOnly: !_isEditing,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: "Untitled Note",
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_isEditing)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8.0),
                child: QuillSimpleToolbar(
                  controller: _quillController,
                ),
              ),
            if (_isEditing) Divider(height: 1, color: Colors.grey.shade300),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                
                child: QuillEditor.basic(
                  controller: _quillController,
                  focusNode: _editorFocus,          
                  scrollController: _editorScroll,
                  config: QuillEditorConfig(
                    embedBuilders: [CustomImageEmbedBuilder()],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
//  MAGIC: Updated Image Builder (For v11.5.1)
// ==========================================
class CustomImageEmbedBuilder extends EmbedBuilder {
  @override
  String get key => 'image';

  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    // V11.5.1 ke hisaab se data nikalne ka naya tareeqa
    final imageUrl = embedContext.node.value.data as String;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(File(imageUrl), fit: BoxFit.contain),
      ),
    );
  }
}


// ==========================================
//  EXACT MATERIAL 3 CLONE: WITH EMOJIS AND DARK MODE SUPPORT!
// ==========================================
class CustomEmojiDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final List<JournalModel> journals;

  const CustomEmojiDatePicker({super.key, required this.initialDate, required this.journals});

  @override
  State<CustomEmojiDatePicker> createState() => _CustomEmojiDatePickerState();
}

class _CustomEmojiDatePickerState extends State<CustomEmojiDatePicker> {
  late DateTime _selectedDate;
  late DateTime _displayedMonth;
  final DateTime _today = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _displayedMonth = DateTime(widget.initialDate.year, widget.initialDate.month, 1);
  }

  //  Native Year Picker Popup!
  void _showYearPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        content: SizedBox(
          width: 300,
          height: 400,
          child: YearPicker(
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
            // ignore: deprecated_member_use
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
    // Screenshot ke hisaab se Sunday first
    final List<String> weekDays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    
    int daysInMonth = DateUtils.getDaysInMonth(_displayedMonth.year, _displayedMonth.month);
    
    
    int emptySpacesBefore = _displayedMonth.weekday == 7 ? 0 : _displayedMonth.weekday;
    
    DateTime todayOnly = DateTime(_today.year, _today.month, _today.day);

    return Dialog(
      backgroundColor: theme.colorScheme.surfaceContainerHigh, // M3 Dialog Color
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)), // M3 Curve
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. TOP HEADER (Select date) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Select date", style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('EEE, MMM d').format(_selectedDate),
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5), height: 1),
            const SizedBox(height: 8),
            
            // --- 2. MONTH / YEAR CHANGER ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _showYearPicker, // 👈 Clickable Dropdown!
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
                      // Future me switch block
                      onPressed: (_displayedMonth.year == _today.year && _displayedMonth.month == _today.month) 
                          ? null 
                          : () => setState(() => _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1)),
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 8),
            
            // --- 3. WEEKDAYS ---
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 7,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
              itemBuilder: (context, index) => Center(
                child: Text(weekDays[index], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant)),
              ),
            ),
            
            // --- 4. CALENDAR DAYS WITH EMOJIS ---
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: emptySpacesBefore + daysInMonth,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
              itemBuilder: (context, index) {
                if (index < emptySpacesBefore) return const SizedBox.shrink();

                int dayNum = index - emptySpacesBefore + 1;
                DateTime currentGridDate = DateTime(_displayedMonth.year, _displayedMonth.month, dayNum);
                
                bool isFuture = currentGridDate.isAfter(todayOnly);
                bool isSelected = currentGridDate.year == _selectedDate.year && currentGridDate.month == _selectedDate.month && currentGridDate.day == _selectedDate.day;
                bool isToday = currentGridDate.year == todayOnly.year && currentGridDate.month == todayOnly.month && currentGridDate.day == todayOnly.day;

                //  MOOD EMOJI LOGIC
                String? moodEmoji;
                String dateStringCheck = DateFormat('dd MMM yyyy').format(currentGridDate);
                var matchedJournals = widget.journals.where((j) => j.date.startsWith(dateStringCheck));
                if (matchedJournals.isNotEmpty) {
                  moodEmoji = matchedJournals.first.mood;
                }

                
                Color textColor = isSelected 
                    ? theme.colorScheme.onPrimary 
                    : (isFuture ? theme.colorScheme.onSurface.withValues(alpha: 0.3) : theme.colorScheme.onSurface);

                return GestureDetector(
                  onTap: isFuture ? null : () => setState(() => _selectedDate = currentGridDate),
                  child: Container(
                    margin: const EdgeInsets.all(4), // Circle size
                    decoration: BoxDecoration(
                      color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                      shape: BoxShape.circle,
                      border: (isToday && !isSelected) ? Border.all(color: theme.colorScheme.primary, width: 1.5) : null,
                    ),
                    child: Stack(
                      children: [
                        // DAY NUMBER
                        Center(
                          child: Text(
                            '$dayNum',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor),
                          ),
                        ),
                        // EMOJI BADGE (Top Right Side)
                        if (moodEmoji != null && moodEmoji.isNotEmpty)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Text(moodEmoji, style: const TextStyle(fontSize: 11)),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            
            // --- 5. BOTTOM ACTIONS (Cancel / OK) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context), // Cancel
                  style: TextButton.styleFrom(foregroundColor: theme.colorScheme.primary),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context, _selectedDate), // OK
                  style: TextButton.styleFrom(foregroundColor: theme.colorScheme.primary),
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