import 'package:flutter/material.dart';
import 'models/task_model.dart';
import 'services/task_services.dart';
import 'pages/add_task_page.dart';
import 'pages/settings_page.dart';
import 'pages/notifications_page.dart';
import 'pages/help_support_page.dart';
import 'services/google_calendar_service.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;

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

// ─────────────────────────────────────────
//  MAIN SCREEN
// ─────────────────────────────────────────
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
    setState(() { _tasks = tasks; _isLoading = false; });
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
          ScheduleScreen(tasks: _tasks, onAddTask: _openAddTask, onUpdateTask: _saveTask,),
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
  final List<TaskStatus> _statuses = [
    TaskStatus.open, TaskStatus.inProgress, TaskStatus.done,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<TaskModel> _tasksForStatus(TaskStatus status) =>
      widget.tasks.where((t) => t.status == status).toList();
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
          onPressed: () => _openDrawer(context),
        ),
        title: const Text('Boards',
            style: TextStyle(
                color: Colors.black, fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: true,
        actions: [
          Stack(children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.black),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NotificationsPage())),
            ),
            Positioned(
              right: 10, top: 10,
              child: Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
              ),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xFFE8B89A),
              child: const Icon(Icons.person, color: Colors.white, size: 18),
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
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            tabs: ['Open', 'In Progress', 'Done'].asMap().entries.map((e) {
              return Tab(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(e.value),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: e.key == _tabController.index
                          ? const Color(0xFF4CAF8D) : Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_countForStatus(_statuses[e.key])}',
                      style: TextStyle(
                        fontSize: 10,
                        color: e.key == _tabController.index
                            ? Colors.white : Colors.black54,
                      ),
                    ),
                  ),
                ]),
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
              ? _emptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tasks.length,
                  itemBuilder: (_, i) => _TaskCard(
                    task: tasks[i],
                    onTap: () => widget.onAddTask(existing: tasks[i]),
                    onStatusChange: (s) =>
                        widget.onUpdateTask(tasks[i].copyWith(status: s)),
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

  Widget _emptyState() {
    return const Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.check_circle_outline, size: 64, color: Colors.black12),
        SizedBox(height: 12),
        Text('Tidak ada task di sini',
            style: TextStyle(color: Colors.black38, fontSize: 15)),
      ]),
    );
  }

  // ── Drawer / Hamburger Menu ──────────────────────────
  void _openDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _DrawerMenu(),
    );
  }
}

// ─────────────────────────────────────────
//  DRAWER MENU (Hamburger)
// ─────────────────────────────────────────
class _DrawerMenu extends StatelessWidget {
  const _DrawerMenu();

  @override
  Widget build(BuildContext context) {
    final projects = ['Personal', 'Work', 'Shopping', 'Health', 'Finance'];
    final projectColors = [
      const Color(0xFF4CAF8D),
      const Color(0xFF42A5F5),
      const Color(0xFFFFB74D),
      const Color(0xFFEF5350),
      const Color(0xFF9C27B0),
    ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF8D).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.task_alt,
                    color: Color(0xFF4CAF8D), size: 22),
              ),
              const SizedBox(width: 12),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('TaskFlow',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                Text('Semua Project', style: TextStyle(color: Colors.black45, fontSize: 13)),
              ]),
            ]),
          ),

          const Divider(height: 1),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Menu utama
                _drawerItem(context, Icons.grid_view_rounded, 'Boards', true, () => Navigator.pop(context)),
                _drawerItem(context, Icons.calendar_month_outlined, 'Schedule', false, () => Navigator.pop(context)),
                _drawerItem(context, Icons.inbox_outlined, 'Inbox', false, () => Navigator.pop(context)),

                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text('PROJECTS',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: Colors.black38, letterSpacing: 0.8)),
                ),

                // Project list
                ...projects.asMap().entries.map((e) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: projectColors[e.key],
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(e.value,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  trailing: Text(
                    '${(e.key + 1) * 2}',
                    style: const TextStyle(color: Colors.black38, fontSize: 12),
                  ),
                  onTap: () => Navigator.pop(context),
                )),

                const Divider(height: 24),

                // Pengaturan
                _drawerItem(context, Icons.settings_outlined, 'Settings', false, () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SettingsPage()));
                }),
                _drawerItem(context, Icons.help_outline, 'Help & Support', false, () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const HelpSupportPage()));
                }),
              ],
            ),
          ),

          // Footer
          const Divider(height: 1),
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            leading: const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFE8B89A),
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),
            title: const Text('Itonk',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            // subtitle: const Text('your@email.com',
            //     style: TextStyle(color: Colors.black45, fontSize: 12)),
            // trailing: IconButton(
            //   icon: const Icon(Icons.logout, color: Colors.black38, size: 20),
            //   onPressed: () => _showLogoutDialog(context),
            // ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(BuildContext context, IconData icon, String label,
      bool isActive, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF4CAF8D).withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon,
            color: isActive ? const Color(0xFF4CAF8D) : Colors.black54,
            size: 18),
      ),
      title: Text(label,
          style: TextStyle(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? const Color(0xFF4CAF8D) : Colors.black)),
      onTap: onTap,
    );
  }

  // void _showLogoutDialog(BuildContext context) {
  //   Navigator.pop(context);
  //   showDialog(
  //     context: context,
  //     builder: (_) => AlertDialog(
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  //       title: const Text('Keluar dari aplikasi?'),
  //       content: const Text('Semua data tersimpan dan bisa diakses lagi saat login.'),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text('Batal'),
  //         ),
  //         ElevatedButton(
  //           onPressed: () => Navigator.pop(context),
  //           style: ElevatedButton.styleFrom(
  //             backgroundColor: const Color(0xFF4CAF8D),
  //           ),
  //           child: const Text('Keluar', style: TextStyle(color: Colors.white)),
  //         ),
  //       ],
  //     ),
  //   );
  // }
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
      case TaskPriority.low: return const Color(0xFF64B5F6);
      case TaskPriority.medium: return const Color(0xFFFFB74D);
      case TaskPriority.high: return const Color(0xFFEF5350);
      case TaskPriority.urgent: return const Color(0xFF9C27B0);
    }
  }

  bool get _isDueOverdue {
    if (task.dueDate == null) return false;
    return task.dueDate!.isBefore(DateTime.now()) &&
        task.status != TaskStatus.done;
  }

  @override
  Widget build(BuildContext context) {
    final completedSubs = task.subtasks.where((s) => s.isCompleted).length;
    final totalSubs = task.subtasks.length;

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
              blurRadius: 8, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 20, height: 3,
              decoration: BoxDecoration(
                color: _priorityColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (task.recurringType != RecurringType.none) ...[
              const SizedBox(width: 6),
              const Icon(Icons.repeat, size: 12, color: Color(0xFF4CAF8D)),
            ],
            const Spacer(),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz, size: 18, color: Colors.black38),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'open', child: Text('Mark as Open')),
                const PopupMenuItem(value: 'progress', child: Text('Mark as In Progress')),
                const PopupMenuItem(value: 'done', child: Text('Mark as Done')),
                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
              onSelected: (v) {
                if (v == 'delete') onDelete();
                else if (v == 'open') onStatusChange(TaskStatus.open);
                else if (v == 'progress') onStatusChange(TaskStatus.inProgress);
                else if (v == 'done') onStatusChange(TaskStatus.done);
              },
            ),
          ]),
          const SizedBox(height: 8),
          Text(task.title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black)),
          if (task.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(task.description,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54, fontSize: 12.5)),
          ],
          if (totalSubs > 0) ...[
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('$completedSubs/$totalSubs subtasks',
                  style: const TextStyle(fontSize: 11, color: Colors.black45)),
              Text('${(completedSubs / totalSubs * 100).toInt()}%',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF4CAF8D))),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: completedSubs / totalSubs,
                backgroundColor: Colors.black.withOpacity(0.06),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF8D)),
                minHeight: 4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(children: [
            // Avatar placeholder
            SizedBox(
              height: 26, width: 60,
              child: Stack(
                children: List.generate(3, (i) => Positioned(
                  left: i * 16.0,
                  child: Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: [const Color(0xFFE8B89A), const Color(0xFFA8D8C8), const Color(0xFF90CAF9)][i],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(Icons.person, size: 14, color: Colors.white),
                  ),
                )),
              ),
            ),
            const Spacer(),
            if (task.dueDate != null)
              Row(children: [
                Icon(Icons.calendar_today, size: 12,
                    color: _isDueOverdue ? Colors.red : Colors.black38),
                const SizedBox(width: 4),
                Text(
                  '${task.dueDate!.day}/${task.dueDate!.month}',
                  style: TextStyle(
                      fontSize: 11,
                      color: _isDueOverdue ? Colors.red : Colors.black38,
                      fontWeight: _isDueOverdue ? FontWeight.w600 : FontWeight.normal),
                ),
                const SizedBox(width: 8),
              ]),
            if (task.attachments.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(children: [
                  const Icon(Icons.attach_file, size: 10, color: Color(0xFFFF9800)),
                  const SizedBox(width: 3),
                  Text('${task.attachments.length}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFFFF9800), fontWeight: FontWeight.w600)),
                ]),
              ),
          ]),
        ]),
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
  final Function(TaskModel) onUpdateTask;
 
  const ScheduleScreen({
    Key? key,
    required this.tasks,
    required this.onAddTask,
    required this.onUpdateTask,
  }) : super(key: key);
 
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}
 
class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedProject = 'All Project';
 
  // Google Calendar state
  bool _isGCalConnected = false;
  bool _isGCalLoading = false;
  bool _showGCalEvents = true;
  List<gcal.Event> _googleEvents = [];
  String? _syncMessage;
 
  final List<String> _projects = [
    'All Project', 'Personal', 'Work', 'Shopping', 'Health', 'Google Calendar'
  ];
 
  @override
  void initState() {
    super.initState();
    _trySilentLogin();
  }
 
  // Auto login kalau sudah pernah login sebelumnya
  Future<void> _trySilentLogin() async {
    final success = await GoogleCalendarService.trySilentSignIn();
    if (success && mounted) {
      setState(() => _isGCalConnected = true);
      _loadGoogleEvents();
    }
  }
 
  // Login ke Google
  Future<void> _connectGoogleCalendar() async {
    setState(() => _isGCalLoading = true);
    try {
      final success = await GoogleCalendarService.signIn();
      if (success && mounted) {
        setState(() { _isGCalConnected = true; _isGCalLoading = false; });
        _loadGoogleEvents();
        _showSyncMessage('✅ Terhubung ke Google Calendar!');
      } else {
        setState(() => _isGCalLoading = false);
      }
    } catch (e) {
      setState(() => _isGCalLoading = false);
      _showSyncMessage('❌ Gagal konek: $e');
    }
  }
 
  // Logout dari Google
  Future<void> _disconnectGoogle() async {
    await GoogleCalendarService.signOut();
    setState(() {
      _isGCalConnected = false;
      _googleEvents = [];
    });
    _showSyncMessage('Berhasil disconnect dari Google Calendar');
  }
 
  // Ambil events dari Google Calendar
  Future<void> _loadGoogleEvents() async {
    if (!_isGCalConnected) return;
    try {
      final events = await GoogleCalendarService.getCalendarEvents(
        timeMin: DateTime.now().subtract(const Duration(days: 7)),
        timeMax: DateTime.now().add(const Duration(days: 90)),
      );
      if (mounted) setState(() => _googleEvents = events);
    } catch (e) {
      _showSyncMessage('Gagal memuat Google Calendar: $e');
    }
  }
 
  // Sync SATU task ke Google Calendar
  Future<void> _syncTaskToGoogle(TaskModel task) async {
    if (!_isGCalConnected) {
      _showSyncMessage('Hubungkan Google Calendar dulu');
      return;
    }
    if (task.dueDate == null) {
      _showSyncMessage('Task harus punya due date untuk di-sync');
      return;
    }
 
    setState(() => _isGCalLoading = true);
    try {
      final eventId = await GoogleCalendarService.addTaskToCalendar(task);
      _showSyncMessage('✅ "${task.title}" berhasil di-sync ke Google Calendar');
      await _loadGoogleEvents(); // refresh
    } catch (e) {
      _showSyncMessage('❌ Gagal sync: $e');
    } finally {
      setState(() => _isGCalLoading = false);
    }
  }
 
  // Sync SEMUA task ke Google Calendar
  Future<void> _syncAllTasks() async {
    if (!_isGCalConnected) return;
 
    final tasksWithDate = widget.tasks.where((t) => t.dueDate != null).toList();
    if (tasksWithDate.isEmpty) {
      _showSyncMessage('Tidak ada task dengan due date untuk di-sync');
      return;
    }
 
    setState(() => _isGCalLoading = true);
    int success = 0;
 
    for (final task in tasksWithDate) {
      try {
        await GoogleCalendarService.addTaskToCalendar(task);
        success++;
      } catch (e) {
        // lanjut ke task berikutnya
      }
    }
 
    await _loadGoogleEvents();
    setState(() => _isGCalLoading = false);
    _showSyncMessage('✅ $success/${tasksWithDate.length} task berhasil di-sync');
  }
 
  // Import event Google Calendar → TaskFlow
  Future<void> _importFromGoogle(gcal.Event event) async {
    final task = GoogleCalendarService.eventToTask(event);
    widget.onUpdateTask(task);
    _showSyncMessage('✅ "${event.summary}" berhasil diimport ke TaskFlow');
  }
 
  void _showSyncMessage(String msg) {
    setState(() => _syncMessage = msg);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _syncMessage = null);
    });
  }
 
  // ── Filter tasks untuk tanggal yang dipilih ──────────
  List<TaskModel> get _filteredLocalTasks {
    return widget.tasks.where((t) {
      if (t.dueDate == null) return false;
      final sameDay = t.dueDate!.year == _selectedDate.year &&
          t.dueDate!.month == _selectedDate.month &&
          t.dueDate!.day == _selectedDate.day;
      if (!sameDay) return false;
      if (_selectedProject == 'All Project' || _selectedProject == 'Google Calendar') return true;
      return t.projectName == _selectedProject;
    }).toList();
  }
 
  // Filter Google Calendar events untuk tanggal yang dipilih
  List<gcal.Event> get _filteredGCalEvents {
    if (!_isGCalConnected || !_showGCalEvents) return [];
    return _googleEvents.where((e) {
      DateTime? eventDate;
      if (e.start?.dateTime != null) {
        eventDate = e.start!.dateTime!.toLocal();
      } else if (e.start?.date != null) {
        eventDate = e.start!.date;
      }
      if (eventDate == null) return false;
      return eventDate.year == _selectedDate.year &&
          eventDate.month == _selectedDate.month &&
          eventDate.day == _selectedDate.day;
    }).toList();
  }
 
  // Cek apakah tanggal tertentu punya task/event
  bool _hasTaskOnDate(DateTime date) {
    final hasLocal = widget.tasks.any((t) =>
        t.dueDate != null &&
        t.dueDate!.year == date.year &&
        t.dueDate!.month == date.month &&
        t.dueDate!.day == date.day);
 
    final hasGCal = _googleEvents.any((e) {
      DateTime? d;
      if (e.start?.dateTime != null) d = e.start!.dateTime!.toLocal();
      else if (e.start?.date != null) d = e.start!.date;
      if (d == null) return false;
      return d.year == date.year && d.month == date.month && d.day == date.day;
    });
 
    return hasLocal || hasGCal;
  }
 
  @override
  Widget build(BuildContext context) {
    final months = ['January','February','March','April','May','June',
        'July','August','September','October','November','December'];
    final month = months[_selectedDate.month - 1];
    final now = DateTime.now();
 
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () {},
        ),
        title: const Text('Schedule',
            style: TextStyle(
                color: Colors.black, fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: true,
        actions: [
          // Tombol sync Google Calendar
          if (_isGCalConnected)
            IconButton(
              icon: _isGCalLoading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF4CAF8D)))
                  : const Icon(Icons.sync, color: Color(0xFF4CAF8D)),
              tooltip: 'Sync semua ke Google Calendar',
              onPressed: _isGCalLoading ? null : _syncAllTasks,
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
          // ── Google Calendar Banner ──────────────────
          _buildGCalBanner(),
 
          // ── Sync message ────────────────────────────
          if (_syncMessage != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFEDF7F3),
              child: Row(children: [
                const Icon(Icons.info_outline, size: 16, color: Color(0xFF4CAF8D)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_syncMessage!,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF2E7D5E))),
                ),
              ]),
            ),
 
          // ── Filter ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              _FilterDropdown(
                value: month,
                items: months,
                onChanged: (v) {
                  if (v != null) setState(() {
                    _selectedDate = DateTime(
                        _selectedDate.year, months.indexOf(v) + 1, _selectedDate.day);
                  });
                },
              ),
              const SizedBox(width: 10),
              _FilterDropdown(
                value: _selectedProject,
                items: _projects,
                onChanged: (v) =>
                    setState(() => _selectedProject = v ?? 'All Project'),
              ),
              if (_isGCalConnected) ...[
                const Spacer(),
                // Toggle tampilkan Google Calendar events
                GestureDetector(
                  onTap: () => setState(() => _showGCalEvents = !_showGCalEvents),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: _showGCalEvents
                          ? const Color(0xFF4285F4).withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Image.network(
                        'https://www.gstatic.com/images/branding/product/1x/calendar_2020q4_48dp.png',
                        width: 16, height: 16,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.calendar_month, size: 16, color: Color(0xFF4285F4)),
                      ),
                      const SizedBox(width: 4),
                      Text(_showGCalEvents ? 'ON' : 'OFF',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _showGCalEvents
                                  ? const Color(0xFF4285F4)
                                  : Colors.black38)),
                    ]),
                  ),
                ),
              ],
            ]),
          ),
 
          const SizedBox(height: 16),
 
          // ── Date picker ─────────────────────────────
          SizedBox(
            height: 72,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 30,
              itemBuilder: (_, i) {
                final date = now.subtract(const Duration(days: 3))
                    .add(Duration(days: i));
                final isSelected = date.year == _selectedDate.year &&
                    date.month == _selectedDate.month &&
                    date.day == _selectedDate.day;
                final hasTask = _hasTaskOnDate(date);
                final dayNames = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
 
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
                      Text('${date.day}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 20)),
                      Text(dayNames[date.weekday - 1],
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black54)),
                      // Titik indikator ada task
                      if (hasTask)
                        Container(
                          width: 5, height: 5,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.black45
                                : const Color(0xFF4CAF8D),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ]),
                  ),
                );
              },
            ),
          ),
 
          const SizedBox(height: 8),
          const Divider(height: 1, color: Colors.black12),
 
          // ── Timeline ────────────────────────────────
          Expanded(
            child: (_filteredLocalTasks.isEmpty && _filteredGCalEvents.isEmpty)
                ? _emptyState()
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
 
  // ── Google Calendar connection banner ───────────────
  Widget _buildGCalBanner() {
    if (_isGCalConnected) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF4CAF8D).withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle, color: Color(0xFF4CAF8D), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Terhubung ke Google Calendar',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF2E7D5E))),
              Text(GoogleCalendarService.userEmail ?? '',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF4CAF8D))),
            ]),
          ),
          TextButton(
            onPressed: _disconnectGoogle,
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
            child: const Text('Putus',
                style: TextStyle(color: Colors.red, fontSize: 12)),
          ),
        ]),
      );
    }
 
    // Belum terhubung
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4285F4), Color(0xFF34A853)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.calendar_month, color: Colors.white, size: 22),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Sync dengan Google Calendar',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
            Text('Lihat semua event dalam satu tampilan',
                style: TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
        ),
        ElevatedButton(
          onPressed: _isGCalLoading ? null : _connectGoogleCalendar,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF4285F4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            minimumSize: const Size(0, 0),
          ),
          child: _isGCalLoading
              ? const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF4285F4)))
              : const Text('Hubungkan',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        ),
      ]),
    );
  }
 
  // ── Build timeline dengan local tasks + Google events ─
  List<Widget> _buildTimeline() {
    final hours = List.generate(15, (i) => i + 7); // 07:00 - 21:00
    final widgets = <Widget>[];
 
    for (final hour in hours) {
      // Local tasks untuk jam ini
      final localTasks = _filteredLocalTasks.where((t) {
        if (t.reminderTime != null) return t.reminderTime!.hour == hour;
        return t.dueDate?.hour == hour;
      }).toList();
 
      // Google Calendar events untuk jam ini
      final gcalEvents = _filteredGCalEvents.where((e) {
        if (e.start?.dateTime != null) {
          return e.start!.dateTime!.toLocal().hour == hour;
        }
        return hour == 8; // all-day events tampil di jam 8
      }).toList();
 
      if (localTasks.isEmpty && gcalEvents.isEmpty) {
        // Baris kosong lebih kecil
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 44,
              child: Text('$hour:00',
                  style: const TextStyle(fontSize: 11, color: Colors.black26)),
            ),
            Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.only(top: 8),
                color: Colors.black.withOpacity(0.05),
              ),
            ),
          ]),
        ));
        continue;
      }
 
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 44,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('$hour:00',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black38,
                      fontWeight: FontWeight.w500)),
            ),
          ),
          Expanded(
            child: Column(children: [
              const Divider(height: 1, color: Colors.black12),
              const SizedBox(height: 6),
              // Local tasks
              ...localTasks.map((t) => _LocalTaskCard(
                task: t,
                onTap: () => widget.onAddTask(existing: t),
                onSync: _isGCalConnected
                    ? () => _syncTaskToGoogle(t)
                    : null,
              )),
              // Google Calendar events
              ...gcalEvents.map((e) => _GCalEventCard(
                event: e,
                onImport: () => _importFromGoogle(e),
              )),
            ]),
          ),
        ]),
      ));
    }
    return widgets;
  }
 
  Widget _emptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.event_note, size: 56, color: Colors.black12),
        const SizedBox(height: 12),
        const Text('Tidak ada task hari ini',
            style: TextStyle(color: Colors.black38, fontSize: 14)),
        if (_isGCalConnected) ...[
          const SizedBox(height: 6),
          const Text('Google Calendar juga kosong untuk hari ini',
              style: TextStyle(color: Colors.black26, fontSize: 12)),
        ],
      ]),
    );
  }
}
 
// ─────────────────────────────────────────
//  LOCAL TASK CARD (dengan tombol sync)
// ─────────────────────────────────────────
class _LocalTaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onTap;
  final VoidCallback? onSync;
 
  const _LocalTaskCard({
    required this.task,
    required this.onTap,
    this.onSync,
  });
 
  Color get _cardColor {
    switch (task.priority) {
      case TaskPriority.low: return const Color(0xFFE8F5E9);
      case TaskPriority.medium: return const Color(0xFFFFF9C4);
      case TaskPriority.high: return const Color(0xFFFFEBEE);
      case TaskPriority.urgent: return const Color(0xFFF3E5F5);
    }
  }
 
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(task.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
              if (task.description.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(task.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.black54, fontSize: 12)),
              ],
              if (task.reminderTime != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.alarm, size: 11, color: Colors.black38),
                  const SizedBox(width: 3),
                  Text(
                    '${task.reminderTime!.hour.toString().padLeft(2, '0')}:${task.reminderTime!.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.black45),
                  ),
                ]),
              ],
            ]),
          ),
          // Tombol sync ke Google Calendar
          if (onSync != null)
            GestureDetector(
              onTap: onSync,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.sync,
                    size: 16, color: Color(0xFF4285F4)),
              ),
            ),
        ]),
      ),
    );
  }
}
 
// ─────────────────────────────────────────
//  GOOGLE CALENDAR EVENT CARD
// ─────────────────────────────────────────
class _GCalEventCard extends StatelessWidget {
  final gcal.Event event;
  final VoidCallback onImport;
 
  const _GCalEventCard({required this.event, required this.onImport});
 
  String get _timeLabel {
    if (event.start?.dateTime != null) {
      final dt = event.start!.dateTime!.toLocal();
      final end = event.end?.dateTime?.toLocal();
      final startStr =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      if (end != null) {
        final endStr =
            '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
        return '$startStr – $endStr';
      }
      return startStr;
    }
    return 'All Day';
  }
 
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF4285F4).withOpacity(0.3)),
      ),
      child: Row(children: [
        // Google icon indicator
        Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF4285F4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.calendar_month,
                  size: 12, color: Color(0xFF4285F4)),
              const SizedBox(width: 4),
              const Text('Google Calendar',
                  style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF4285F4),
                      fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 2),
            Text(
              event.summary ?? 'Tanpa Judul',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.black87),
            ),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.access_time, size: 11, color: Colors.black38),
              const SizedBox(width: 3),
              Text(_timeLabel,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.black45)),
            ]),
          ]),
        ),
        // Tombol import ke TaskFlow
        GestureDetector(
          onTap: onImport,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF4285F4).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.download_outlined,
                  size: 13, color: Color(0xFF4285F4)),
              SizedBox(width: 3),
              Text('Import',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF4285F4),
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }
}
 
// ─────────────────────────────────────────
//  FILTER DROPDOWN
// ─────────────────────────────────────────
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
            color: Colors.black,
            fontSize: 13,
            fontWeight: FontWeight.w500),
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
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Profile',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          // Header profil
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(children: [
              Stack(
                children: [
                  const CircleAvatar(
                    radius: 44,
                    backgroundColor: Color(0xFFE8B89A),
                    child: Icon(Icons.person, size: 44, color: Colors.white),
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 26, height: 26,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF8D), shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Itonk',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
              const SizedBox(height: 4),
              // const Text('l200230129@student.ums.ac.id',
              //     style: TextStyle(color: Colors.black45, fontSize: 14)),
              // const SizedBox(height: 16),
              // Stats row
              // Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              //   _statItem('12', 'Total Task'),
              //   Container(width: 1, height: 32, color: Colors.black12),
              //   _statItem('8', 'Selesai'),
              //   Container(width: 1, height: 32, color: Colors.black12),
              //   _statItem('4', 'Aktif'),
              // ]),
            ]),
          ),

          const SizedBox(height: 16),

          // Menu
          Container(
            color: Colors.white,
            child: Column(children: [
              _profileTile(
                context,
                Icons.settings_outlined,
                'Settings',
                'Tampilan, bahasa, dan preferensi',
                const Color(0xFF4CAF8D),
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsPage())),
              ),
              const Divider(height: 1, indent: 66),
              _profileTile(
                context,
                Icons.notifications_outlined,
                'Notifications',
                'Atur pengingat dan notifikasi',
                const Color(0xFFFFB74D),
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const NotificationsPage())),
              ),
              const Divider(height: 1, indent: 66),
              _profileTile(
                context,
                Icons.help_outline,
                'Help & Support',
                'FAQ dan hubungi kami',
                const Color(0xFF42A5F5),
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const HelpSupportPage())),
              ),
              // const Divider(height: 1, indent: 66),
              // _profileTile(
              //   context,
              //   Icons.logout,
              //   'Log Out',
              //   'Keluar dari akun',
              //   const Color(0xFFEF5350),
              //   () => _showLogoutDialog(context),
              // ),
            ]),
          ),

          const SizedBox(height: 32),
          const Center(
            child: Text('TaskFlow v1.0.0',
                style: TextStyle(color: Colors.black26, fontSize: 12)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Column(children: [
      Text(value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 22, color: Color(0xFF4CAF8D))),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Colors.black45, fontSize: 12)),
    ]);
  }

  Widget _profileTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.black38, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: Colors.black26),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out?'),
        content: const Text('Kamu akan keluar dari aplikasi TaskFlow.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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
            blurRadius: 12, offset: const Offset(0, -2),
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
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 24,
            color: isActive ? const Color(0xFF4CAF8D) : Colors.black38),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
              fontSize: 11,
              color: isActive ? const Color(0xFF4CAF8D) : Colors.black38,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            )),
      ]),
    );
  }
}