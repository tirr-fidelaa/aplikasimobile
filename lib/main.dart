import 'package:flutter/material.dart';
import 'models/task_model.dart';
import 'services/task_services.dart';
import 'pages/add_task_page.dart';

void main() {
  runApp(const TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF4CAF8D),
          secondary: Color(0xFFF5F0E8),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  List<TaskModel> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final tasks = await TaskServices.loadTasks();
    setState(() {
      _tasks = tasks;
      _isLoading = false;
    });
  }

  Future<void> _saveTask(TaskModel task) async {
    final exists = _tasks.any((t) => t.id == task.id);
    List<TaskModel> updated;
    if (exists) {
      updated = await TaskServices.updateTask(_tasks, task);
    } else {
      updated = await TaskServices.addTask(_tasks, task);
    }
    setState(() => _tasks = updated);
  }

  Future<void> _deleteTask(String id) async {
    final updated = await TaskServices.deleteTask(_tasks, id);
    setState(() => _tasks = updated);
  }

  void _openAddTask({TaskModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.95,
        minChildSize: 0.5,
        maxChildSize: 0.97,
        expand: false,
        builder: (_, controller) => AddTaskPage(
          existingTask: existing,
          onSave: _saveTask,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          BoardsScreen(
            tasks: _tasks,
            onAddTask: _openAddTask,
            onDeleteTask: _deleteTask,
            onUpdateTask: _saveTask,
          ),
          ScheduleScreen(
            tasks: _tasks,
            onAddTask: _openAddTask,
          ),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  BOARDS SCREEN
// ─────────────────────────────────────────
class BoardsScreen extends StatefulWidget {
  final List<TaskModel> tasks;
  final Function({TaskModel? existing}) onAddTask;
  final Function(String) onDeleteTask;
  final Function(TaskModel) onUpdateTask;

  const BoardsScreen({
    Key? key,
    required this.tasks,
    required this.onAddTask,
    required this.onDeleteTask,
    required this.onUpdateTask,
  }) : super(key: key);

  @override
  State<BoardsScreen> createState() => _BoardsScreenState();
}

class _BoardsScreenState extends State<BoardsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _tabs = ['Open', 'In Progress', 'Done'];
  final List<TaskStatus> _statuses = [
    TaskStatus.open,
    TaskStatus.inProgress,
    TaskStatus.done,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<TaskModel> _tasksForStatus(TaskStatus status) {
    return widget.tasks.where((t) => t.status == status).toList();
  }

  int _countForStatus(TaskStatus status) =>
      widget.tasks.where((t) => t.status == status).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () {},
        ),
        title: const Text(
          'Boards',
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: Colors.black),
                onPressed: () {},
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xFFE8B89A),
              child: ClipOval(
                child: Container(
                  color: const Color(0xFFE8B89A),
                  child: const Icon(Icons.person, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.black45,
            indicatorColor: const Color(0xFF4CAF8D),
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            tabs: _tabs.asMap().entries.map((e) {
              return Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e.value),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: e.key == _tabController.index
                            ? const Color(0xFF4CAF8D)
                            : Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_countForStatus(_statuses[e.key])}',
                        style: TextStyle(
                          fontSize: 10,
                          color: e.key == _tabController.index
                              ? Colors.white
                              : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _statuses.map((status) {
          final tasks = _tasksForStatus(status);
          return tasks.isEmpty
              ? _emptyState(status)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tasks.length,
                  itemBuilder: (_, i) => _TaskCard(
                    task: tasks[i],
                    onTap: () => widget.onAddTask(existing: tasks[i]),
                    onStatusChange: (newStatus) {
                      widget.onUpdateTask(
                          tasks[i].copyWith(status: newStatus));
                    },
                    onDelete: () => widget.onDeleteTask(tasks[i].id),
                  ),
                );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => widget.onAddTask(),
        backgroundColor: const Color(0xFF4CAF8D),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _emptyState(TaskStatus status) {
    final labels = {
      TaskStatus.open: 'No open tasks',
      TaskStatus.inProgress: 'Nothing in progress',
      TaskStatus.done: 'No completed tasks yet',
    };
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline,
              size: 64, color: Colors.black12),
          const SizedBox(height: 12),
          Text(
            labels[status]!,
            style: const TextStyle(color: Colors.black38, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  TASK CARD
// ─────────────────────────────────────────
class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onTap;
  final Function(TaskStatus) onStatusChange;
  final VoidCallback onDelete;

  const _TaskCard({
    required this.task,
    required this.onTap,
    required this.onStatusChange,
    required this.onDelete,
  });

  Color get _priorityColor {
    switch (task.priority) {
      case TaskPriority.low:
        return const Color(0xFF64B5F6);
      case TaskPriority.medium:
        return const Color(0xFFFFB74D);
      case TaskPriority.high:
        return const Color(0xFFEF5350);
      case TaskPriority.urgent:
        return const Color(0xFF9C27B0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final completedSubtasks =
        task.subtasks.where((s) => s.isCompleted).length;
    final totalSubtasks = task.subtasks.length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withOpacity(0.07)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Priority bar
            Row(
              children: [
                Container(
                  width: 20,
                  height: 3,
                  decoration: BoxDecoration(
                    color: _priorityColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (task.recurringType != RecurringType.none) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.repeat,
                      size: 12, color: const Color(0xFF4CAF8D)),
                ],
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz,
                      size: 18, color: Colors.black38),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'open', child: Text('Mark as Open')),
                    const PopupMenuItem(
                        value: 'progress',
                        child: Text('Mark as In Progress')),
                    const PopupMenuItem(
                        value: 'done', child: Text('Mark as Done')),
                    const PopupMenuItem(
                        value: 'delete', child: Text('Delete')),
                  ],
                  onSelected: (v) {
                    if (v == 'delete') {
                      onDelete();
                    } else if (v == 'open') {
                      onStatusChange(TaskStatus.open);
                    } else if (v == 'progress') {
                      onStatusChange(TaskStatus.inProgress);
                    } else if (v == 'done') {
                      onStatusChange(TaskStatus.done);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Title
            Text(
              task.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),

            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                task.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.black54, fontSize: 12.5),
              ),
            ],

            // Subtask progress
            if (totalSubtasks > 0) ...[
              const SizedBox(height: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$completedSubtasks/$totalSubtasks subtasks',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black45),
                      ),
                      Text(
                        '${(completedSubtasks / totalSubtasks * 100).toInt()}%',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF4CAF8D)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: completedSubtasks / totalSubtasks,
                      backgroundColor: Colors.black.withOpacity(0.06),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF4CAF8D)),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // Bottom row
            Row(
              children: [
                // Assignee avatars placeholder
                _avatarRow(),

                const Spacer(),

                // Due date
                if (task.dueDate != null)
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: _isDueOverdue ? Colors.red : Colors.black38,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${task.dueDate!.day}/${task.dueDate!.month}',
                        style: TextStyle(
                          fontSize: 11,
                          color: _isDueOverdue ? Colors.red : Colors.black38,
                          fontWeight: _isDueOverdue
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),

                // Attachment count
                if (task.attachments.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.attach_file,
                            size: 10, color: Color(0xFFFF9800)),
                        const SizedBox(width: 3),
                        Text(
                          '${task.attachments.length}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFFF9800),
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _isDueOverdue {
    if (task.dueDate == null) return false;
    return task.dueDate!.isBefore(DateTime.now()) &&
        task.status != TaskStatus.done;
  }

  Widget _avatarRow() {
    final colors = [
      const Color(0xFFE8B89A),
      const Color(0xFFA8D8C8),
      const Color(0xFF90CAF9),
      const Color(0xFFFFCC80),
    ];
    return SizedBox(
      height: 26,
      width: 60,
      child: Stack(
        children: List.generate(
          3.clamp(0, colors.length),
          (i) => Positioned(
            left: i * 16.0,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: colors[i],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Icon(Icons.person, size: 14, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  SCHEDULE SCREEN
// ─────────────────────────────────────────
class ScheduleScreen extends StatefulWidget {
  final List<TaskModel> tasks;
  final Function({TaskModel? existing}) onAddTask;

  const ScheduleScreen({
    Key? key,
    required this.tasks,
    required this.onAddTask,
  }) : super(key: key);

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedProject = 'All Project';

  final List<String> _projects = [
    'All Project',
    'Personal',
    'Work',
    'Shopping',
    'Health',
  ];

  List<TaskModel> get _filteredTasks {
    return widget.tasks.where((t) {
      if (t.dueDate == null) return false;
      final sameDay = t.dueDate!.year == _selectedDate.year &&
          t.dueDate!.month == _selectedDate.month &&
          t.dueDate!.day == _selectedDate.day;
      if (!sameDay) return false;
      if (_selectedProject == 'All Project') return true;
      return t.projectName == _selectedProject;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final month = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ][_selectedDate.month - 1];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () {},
        ),
        title: const Text(
          'Schedule',
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: Colors.black),
                onPressed: () {},
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xFFE8B89A),
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Month + Project filters
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                // Month Dropdown
                _FilterDropdown(
                  value: month,
                  items: [
                    'January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November',
                    'December'
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      final months = [
                        'January', 'February', 'March', 'April', 'May',
                        'June', 'July', 'August', 'September', 'October',
                        'November', 'December'
                      ];
                      setState(() {
                        _selectedDate = DateTime(
                          _selectedDate.year,
                          months.indexOf(v) + 1,
                          _selectedDate.day,
                        );
                      });
                    }
                  },
                ),
                const SizedBox(width: 10),
                _FilterDropdown(
                  value: _selectedProject,
                  items: _projects,
                  onChanged: (v) =>
                      setState(() => _selectedProject = v ?? 'All Project'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Date picker row
          SizedBox(
            height: 72,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 14,
              itemBuilder: (_, i) {
                final date = now.subtract(Duration(days: 3)).add(Duration(days: i));
                final isSelected = date.year == _selectedDate.year &&
                    date.month == _selectedDate.month &&
                    date.day == _selectedDate.day;
                final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                final dayName = dayNames[date.weekday - 1];

                return GestureDetector(
                  onTap: () => setState(() => _selectedDate = date),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 56,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFF5C842)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFF5C842)
                            : Colors.black.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                            color:
                                isSelected ? Colors.black : Colors.black,
                          ),
                        ),
                        Text(
                          dayName,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected
                                ? Colors.black54
                                : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1, color: Colors.black12),

          // Timeline
          Expanded(
            child: _filteredTasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_note,
                            size: 56, color: Colors.black12),
                        const SizedBox(height: 12),
                        const Text(
                          'No tasks for this day',
                          style: TextStyle(
                              color: Colors.black38, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    children: _buildTimeline(),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTimeline() {
    final hours = List.generate(13, (i) => i + 8); // 8 to 20
    final widgets = <Widget>[];

    for (final hour in hours) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  '$hour:00',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.black38),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Divider(height: 1, color: Colors.black12),
                    const SizedBox(height: 4),
                    ..._filteredTasks
                        .where((t) => t.dueDate?.hour == hour)
                        .map((t) => _ScheduleCard(
                              task: t,
                              onTap: () {},
                            )),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }
}

class _ScheduleCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onTap;

  const _ScheduleCard({required this.task, required this.onTap});

  Color get _cardColor {
    switch (task.priority) {
      case TaskPriority.low:
        return const Color(0xFFE8F5E9);
      case TaskPriority.medium:
        return const Color(0xFFFFF9C4);
      case TaskPriority.high:
        return const Color(0xFFFFEBEE);
      case TaskPriority.urgent:
        return const Color(0xFFF3E5F5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14),
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                task.description,
                style: const TextStyle(
                    color: Colors.black54, fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                _avatarRow(),
                const Spacer(),
                if (task.hasReminder)
                  const Icon(Icons.monitor,
                      size: 16, color: Colors.black38),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarRow() {
    return Row(
      children: List.generate(
        2,
        (i) => Container(
          width: 24,
          height: 24,
          margin: EdgeInsets.only(right: i == 0 ? -6 : 0),
          decoration: BoxDecoration(
            color: i == 0
                ? const Color(0xFFE8B89A)
                : const Color(0xFFA8D8C8),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: const Icon(Icons.person, size: 12, color: Colors.white),
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final Function(String?) onChanged;

  const _FilterDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<String>(
        value: value,
        isDense: true,
        underline: const SizedBox(),
        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
        style: const TextStyle(
            color: Colors.black, fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  PROFILE SCREEN
// ─────────────────────────────────────────
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 48,
              backgroundColor: Color(0xFFE8B89A),
              child: Icon(Icons.person, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your Name',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  color: Colors.black),
            ),
            const SizedBox(height: 4),
            const Text(
              'your@email.com',
              style: TextStyle(color: Colors.black45, fontSize: 14),
            ),
            const SizedBox(height: 32),
            _profileTile(Icons.settings_outlined, 'Settings'),
            _profileTile(Icons.notifications_outlined, 'Notifications'),
            _profileTile(Icons.help_outline, 'Help & Support'),
            _profileTile(Icons.logout, 'Log Out'),
          ],
        ),
      ),
    );
  }

  Widget _profileTile(IconData icon, String label) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFF0FAF5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF4CAF8D), size: 18),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: Colors.black26),
      onTap: () {},
    );
  }
}

// ─────────────────────────────────────────
//  BOTTOM NAVIGATION
// ─────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.grid_view_rounded, 'Boards', 0),
              _navItem(Icons.calendar_month_outlined, 'Schedule', 1),
              _navItem(Icons.person_outline, 'Profile', 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final isActive = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 24,
            color: isActive ? const Color(0xFF4CAF8D) : Colors.black38,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isActive ? const Color(0xFF4CAF8D) : Colors.black38,
              fontWeight:
                  isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}