import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';

void main() {
  runApp(const StickyNoteApp());
}

class StickyNoteApp extends StatelessWidget {
  const StickyNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sticky Notes To-Do',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.amber,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.brown,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.amberAccent,
          foregroundColor: Colors.brown,
        ),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ---------------- Splash Screen ----------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const TodoHomePage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFCC80), Color(0xFFFFAB91)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Text(
            'Sticky Note To-Do',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.brown,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- Task Item Model ----------------
class Task {
  final String id;
  final String title;
  final bool isCompleted; // Changed to final for immutability

  Task({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  // BEST PRACTICE: A more robust copyWith for consistency
  Task copyWith({
    String? id,
    String? title,
    bool? isCompleted,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}


// ---------------- Sort and Filter Options ----------------
enum SortOption { deadline, creationDate, title }
enum FilterOption { all, upcomingDeadlines, completed }

// ---------------- Main Page ----------------
class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key});

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  final List<TodoItem> _stickyNotes = [];
  int _idCounter = 0;
  final Random _random = Random();
  Timer? _notificationTimer;
  SortOption _currentSort = SortOption.creationDate;
  FilterOption _currentFilter = FilterOption.all;

  final List<Color> _noteColors = [
    Colors.yellow.shade100,
    Colors.pink.shade100,
    Colors.green.shade100,
    Colors.blue.shade100,
    Colors.orange.shade100,
    Colors.purple.shade100,
  ];

  List<Color> _gradientColors = [
    const Color(0xFFFFE0B2),
    const Color(0xFFFFCC80),
  ];

  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(seconds: 6), (timer) {
      _updateGradient();
    });
    _startNotificationTimer();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  void _startNotificationTimer() {
    _notificationTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkDeadlines();
    });
  }

  void _checkDeadlines() {
    final now = DateTime.now();
    for (final note in _stickyNotes) {
      if (note.deadline != null) {
        final deadline = note.deadline!;
        final difference = deadline.difference(now);

        // Check if deadline is within 5 minutes and note has incomplete tasks
        if (difference.inMinutes <= 5 && difference.inMinutes >= 0) {
          final incompleteTasks =
              note.tasks.where((task) => !task.isCompleted).length;
          if (incompleteTasks > 0) {
            _showDeadlineNotification(note);
          }
        }
      }
    }
  }

  void _showDeadlineNotification(TodoItem note) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.access_time, color: Colors.orange),
              SizedBox(width: 8),
              Text('Tasks Due!'),
            ],
          ),
          content: Text(
            'Your sticky note "${note.title}" has tasks due soon!\n\nDeadline: ${_formatDateTime(note.deadline!)}',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Dismiss'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StickyNoteDetailPage(
                      stickyNote: note,
                      onUpdate: _updateStickyNote,
                    ),
                  ),
                );
              },
              child: const Text('View Tasks'),
            ),
          ],
        );
      },
    );
  }

  void _updateGradient() {
    setState(() {
      _gradientColors = [
        Color((0xFF000000 + _random.nextInt(0xFFFFFF))).withOpacity(0.3),
        Color((0xFF000000 + _random.nextInt(0xFFFFFF))).withOpacity(0.3),
      ];
    });
  }

  void _addStickyNote(String title, DateTime? deadline) {
    if (title.trim().isEmpty) return;
    setState(() {
      _stickyNotes.add(TodoItem(
        id: 'note_${_idCounter++}',
        title: title,
        angle: (_random.nextDouble() * 6 - 3) * pi / 180,
        color: _noteColors[_random.nextInt(_noteColors.length)],
        deadline: deadline,
        tasks: [],
        createdAt: DateTime.now(),
      ));
    });
  }

  List<TodoItem> _getFilteredAndSortedNotes() {
    List<TodoItem> filteredNotes = List.from(_stickyNotes);

    // Apply filter
    switch (_currentFilter) {
      case FilterOption.upcomingDeadlines:
        final now = DateTime.now();
        filteredNotes = filteredNotes.where((note) {
          if (note.deadline == null) return false;
          return note.deadline!.isAfter(now) &&
              note.deadline!.difference(now).inDays <= 7; // Next 7 days
        }).toList();
        break;
      case FilterOption.completed:
        filteredNotes = filteredNotes.where((note) {
          if (note.tasks.isEmpty) return false;
          return note.tasks.every((task) => task.isCompleted);
        }).toList();
        break;
      case FilterOption.all:
        // No filtering
        break;
    }

    // Apply sorting
    switch (_currentSort) {
      case SortOption.deadline:
        filteredNotes.sort((a, b) {
          if (a.deadline == null && b.deadline == null) return 0;
          if (a.deadline == null) return 1;
          if (b.deadline == null) return -1;
          return a.deadline!.compareTo(b.deadline!);
        });
        break;
      case SortOption.creationDate:
        filteredNotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.title:
        filteredNotes.sort((a, b) => a.title.compareTo(b.title));
        break;
    }

    return filteredNotes;
  }

  void _showSortFilterModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sort & Filter Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Sort Options
            const Text(
              'Sort by:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ...SortOption.values.map((option) {
              String title;
              IconData icon;
              switch (option) {
                case SortOption.deadline:
                  title = 'Deadline (Most Urgent First)';
                  icon = Icons.access_time;
                  break;
                case SortOption.creationDate:
                  title = 'Creation Date (Newest First)';
                  icon = Icons.date_range;
                  break;
                case SortOption.title:
                  title = 'Title (A-Z)';
                  icon = Icons.sort_by_alpha;
                  break;
              }

              return RadioListTile<SortOption>(
                title: Row(
                  children: [
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                    Text(title),
                  ],
                ),
                value: option,
                groupValue: _currentSort,
                onChanged: (value) {
                  setState(() {
                    _currentSort = value!;
                  });
                  Navigator.pop(context);
                },
              );
            }),

            const Divider(),
            const SizedBox(height: 8),

            // Filter Options
            const Text(
              'Filter by:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ...FilterOption.values.map((option) {
              String title;
              IconData icon;
              switch (option) {
                case FilterOption.all:
                  title = 'Show All Notes';
                  icon = Icons.view_list;
                  break;
                case FilterOption.upcomingDeadlines:
                  title = 'Upcoming Deadlines (Next 7 Days)';
                  icon = Icons.notification_important;
                  break;
                case FilterOption.completed:
                  title = 'Completed Notes';
                  icon = Icons.check_circle;
                  break;
              }

              return RadioListTile<FilterOption>(
                title: Row(
                  children: [
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(title)),
                  ],
                ),
                value: option,
                groupValue: _currentFilter,
                onChanged: (value) {
                  setState(() {
                    _currentFilter = value!;
                  });
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _deleteStickyNote(String id) {
    setState(() {
      _stickyNotes.removeWhere((item) => item.id == id);
    });
  }

  void _updateStickyNote(TodoItem updatedNote) {
    setState(() {
      final index =
          _stickyNotes.indexWhere((note) => note.id == updatedNote.id);
      if (index != -1) {
        _stickyNotes[index] = updatedNote;
      }
    });
  }

  void _showAddStickyNoteModal() {
    final titleController = TextEditingController();
    DateTime? selectedDeadline;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add New Sticky Note',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Sticky Note Title',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text(selectedDeadline == null
                      ? 'Set Deadline (Optional)'
                      : 'Deadline: ${_formatDateTime(selectedDeadline!)}'),
                  trailing: selectedDeadline != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setModalState(() {
                              selectedDeadline = null;
                            });
                          },
                        )
                      : const Icon(Icons.arrow_forward_ios),
                  onTap: () async {
                    final DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );

                    if (pickedDate != null) {
                      final TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );

                      if (pickedTime != null) {
                        setModalState(() {
                          selectedDeadline = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  _addStickyNote(titleController.text, selectedDeadline);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.note_add),
                label: const Text('Create Sticky Note'),
              )
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(seconds: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Sticky Notes To-Do'),
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showSortFilterModal,
              tooltip: 'Sort & Filter',
            ),
            // IMPROVEMENT: Removed redundant add button from AppBar
          ],
        ),
        body: _stickyNotes.isEmpty
            ? const Center(
                child: Text(
                  'No sticky notes yet!',
                  style: TextStyle(fontSize: 18, color: Colors.brown),
                ),
              )
            : Builder(builder: (context) {
                final filteredNotes = _getFilteredAndSortedNotes();

                if (filteredNotes.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.brown),
                        SizedBox(height: 16),
                        Text(
                          'No notes match your filter',
                          style: TextStyle(fontSize: 18, color: Colors.brown),
                        ),
                        Text(
                          'Try changing your filter options',
                          style: TextStyle(fontSize: 14, color: Colors.brown),
                        ),
                      ],
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: filteredNotes.length,
                    itemBuilder: (context, index) {
                      final note = filteredNotes[index];
                      final completedTasks =
                          note.tasks.where((task) => task.isCompleted).length;
                      final totalTasks = note.tasks.length;
                      final progress =
                          totalTasks > 0 ? completedTasks / totalTasks : 0.0;

                      return Transform.rotate(
                        angle: note.angle,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => StickyNoteDetailPage(
                                  stickyNote: note,
                                  onUpdate: _updateStickyNote,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  note.color,
                                  note.color.withOpacity(0.95),
                                  note.color.withOpacity(0.9),
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 3,
                                  offset: Offset(1, 1),
                                )
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  note.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.brown.shade800,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (note.deadline != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Due: ${_formatDateTime(note.deadline!)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.brown.shade600,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                if (totalTasks > 0) ...[
                                  LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: Colors.grey.shade300,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                      progress == 1.0
                                          ? Colors.green
                                          : Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$completedTasks/$totalTasks tasks',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.brown.shade600,
                                    ),
                                  ),
                                ] else ...[
                                  Text(
                                    'No tasks yet',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.brown.shade600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          size: 18, color: Colors.redAccent),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () =>
                                          _deleteStickyNote(note.id),
                                    ),
                                    if (totalTasks > 0)
                                      Text(
                                        '${(progress * 100).round()}%',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.brown.shade800,
                                        ),
                                      ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddStickyNoteModal,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}


// ---------------- Sticky Note Detail Page ----------------
class StickyNoteDetailPage extends StatefulWidget {
  final TodoItem stickyNote;
  final Function(TodoItem) onUpdate;

  const StickyNoteDetailPage({
    super.key,
    required this.stickyNote,
    required this.onUpdate,
  });

  @override
  State<StickyNoteDetailPage> createState() => _StickyNoteDetailPageState();
}

class _StickyNoteDetailPageState extends State<StickyNoteDetailPage> {
  late TodoItem _currentNote;
  int _taskIdCounter = 0;

  @override
  void initState() {
    super.initState();
    _currentNote = widget.stickyNote;
    // Initialize counter based on existing tasks to avoid ID collision
    if (_currentNote.tasks.isNotEmpty) {
      final ids = _currentNote.tasks.map((e) => int.tryParse(e.id.split('_').last) ?? 0);
      _taskIdCounter = ids.reduce(max) + 1;
    }
  }

  void _editStickyNote() {
    final titleController = TextEditingController(text: _currentNote.title);
    DateTime? selectedDeadline = _currentNote.deadline;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Edit Sticky Note',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Sticky Note Title',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text(selectedDeadline == null
                      ? 'Set Deadline (Optional)'
                      : 'Deadline: ${_formatDateTime(selectedDeadline!)}'),
                  trailing: selectedDeadline != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setModalState(() {
                              selectedDeadline = null;
                            });
                          },
                        )
                      : const Icon(Icons.arrow_forward_ios),
                  onTap: () async {
                    final DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: selectedDeadline ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 30)), // Allow past dates
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );

                    if (pickedDate != null) {
                      final TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: selectedDeadline != null
                            ? TimeOfDay.fromDateTime(selectedDeadline!)
                            : TimeOfDay.now(),
                      );

                      if (pickedTime != null) {
                        setModalState(() {
                          selectedDeadline = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (titleController.text.trim().isNotEmpty) {
                        setState(() {
                          _currentNote = _currentNote.copyWith(
                            title: titleController.text.trim(),
                            deadline: selectedDeadline,
                          );
                        });
                        widget.onUpdate(_currentNote);
                        Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Save Changes'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _addTask(String taskTitle) {
    if (taskTitle.trim().isEmpty) return;
    setState(() {
      final newTasks = List<Task>.from(_currentNote.tasks);
      newTasks.add(Task(
        id: 'task_${_taskIdCounter++}',
        title: taskTitle,
      ));
      _currentNote = _currentNote.copyWith(tasks: newTasks);
    });
    widget.onUpdate(_currentNote);
  }

  void _toggleTask(String taskId) {
    setState(() {
      final updatedTasks = _currentNote.tasks.map((task) {
        if (task.id == taskId) {
          return task.copyWith(isCompleted: !task.isCompleted);
        }
        return task;
      }).toList();
      _currentNote = _currentNote.copyWith(tasks: updatedTasks);
    });
    widget.onUpdate(_currentNote);
  }

  void _deleteTask(String taskId) {
    setState(() {
      _currentNote = _currentNote.copyWith(
        tasks: _currentNote.tasks.where((task) => task.id != taskId).toList(),
      );
    });
    widget.onUpdate(_currentNote);
  }

  void _showAddTaskModal() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add New Task',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Task description',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              onSubmitted: (value) {
                _addTask(value);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                _addTask(controller.text);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.add_task),
              label: const Text('Add Task'),
            )
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final completedTasks =
        _currentNote.tasks.where((task) => task.isCompleted).length;
    final totalTasks = _currentNote.tasks.length;
    final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _currentNote.color,
            _currentNote.color.withOpacity(0.8),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            _currentNote.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.brown,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _editStickyNote,
              tooltip: 'Edit Note',
            ),
            IconButton(
              icon: const Icon(Icons.add_task),
              onPressed: _showAddTaskModal,
              tooltip: 'Add Task',
            ),
          ],
        ),
        body: Column(
          children: [
            // Header with deadline and progress
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_currentNote.deadline != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: Colors.brown),
                        const SizedBox(width: 8),
                        Text(
                          'Due: ${_formatDateTime(_currentNote.deadline!)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.brown,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress == 1.0
                                ? Colors.green
                                : const Color(0xFF4FC3F7),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${(progress * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.brown,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$completedTasks of $totalTasks tasks completed',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.brown.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // Tasks list
            Expanded(
              child: _currentNote.tasks.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.task_alt,
                            size: 64,
                            color: Colors.brown,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No tasks yet!',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.brown,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Tap the + button to add tasks',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.brown,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _currentNote.tasks.length,
                      itemBuilder: (context, index) {
                        final task = _currentNote.tasks[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: ListTile(
                            leading: Checkbox(
                              value: task.isCompleted,
                              onChanged: (value) => _toggleTask(task.id),
                              activeColor: Colors.green,
                            ),
                            title: Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 16,
                                decoration: task.isCompleted
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                color: task.isCompleted
                                    ? Colors.grey
                                    : Colors.brown.shade800,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteTask(task.id),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddTaskModal,
          backgroundColor: Colors.brown,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}

// ---------------- Sticky Note Model ----------------
class TodoItem {
  final String id;
  final String title;
  final double angle;
  final Color color;
  final DateTime? deadline;
  final List<Task> tasks;
  final DateTime createdAt;

  TodoItem({
    required this.id,
    required this.title,
    required this.angle,
    required this.color,
    this.deadline,
    required this.tasks,
    required this.createdAt,
  });

  // KEY FIX: The copyWith method is corrected to allow setting deadline to null.
  TodoItem copyWith({
    String? id,
    String? title,
    double? angle,
    Color? color,
    DateTime? deadline,
    List<Task>? tasks,
    DateTime? createdAt,
  }) {
    return TodoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      angle: angle ?? this.angle,
      color: color ?? this.color,
      // The '?? this.deadline' is removed.
      // This is the main logical fix.
      deadline: deadline,
      tasks: tasks ?? this.tasks,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}