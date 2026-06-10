import 'package:flutter/material.dart';
import '../models/task_model.dart';

class InboxPage extends StatefulWidget {
  final List<TaskModel> tasks;

  const InboxPage({Key? key, required this.tasks}) : super(key: key);

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  // ── Task yang overdue ──────────────────────────────
  List<TaskModel> get _overdueTasks {
    final now = DateTime.now();
    return widget.tasks.where((t) {
      if (t.dueDate == null || t.status == TaskStatus.done) return false;
      return t.dueDate!.isBefore(now);
    }).toList();
  }

  // ── Task yang due date-nya dalam 3 hari ke depan ──
  List<TaskModel> get _upcomingTasks {
    final now = DateTime.now();
    final threeDaysLater = now.add(const Duration(days: 3));
    return widget.tasks.where((t) {
      if (t.dueDate == null || t.status == TaskStatus.done) return false;
      return t.dueDate!.isAfter(now) &&
          t.dueDate!.isBefore(threeDaysLater);
    }).toList();
  }

  // ── Aktivitas terbaru (simulasi dari data task) ────
  List<Map<String, dynamic>> get _activities {
    final activities = <Map<String, dynamic>>[];

    for (final task in widget.tasks) {
      // Task selesai
      if (task.status == TaskStatus.done) {
        activities.add({
          'icon': Icons.check_circle,
          'color': const Color(0xFF4CAF8D),
          'title': 'Task selesai',
          'subtitle': '"${task.title}" telah diselesaikan',
          'time': task.createdAt,
          'type': 'done',
        });
      }

      // Task in progress
      if (task.status == TaskStatus.inProgress) {
        activities.add({
          'icon': Icons.timelapse,
          'color': const Color(0xFFFFB74D),
          'title': 'Task sedang dikerjakan',
          'subtitle': '"${task.title}" sedang dalam proses',
          'time': task.createdAt,
          'type': 'progress',
        });
      }

      // Task dengan recurring
      if (task.recurringType != RecurringType.none) {
        activities.add({
          'icon': Icons.repeat,
          'color': const Color(0xFF42A5F5),
          'title': 'Task berulang aktif',
          'subtitle': '"${task.title}" dijadwalkan berulang',
          'time': task.createdAt,
          'type': 'recurring',
        });
      }

      // Task baru dibuat
      activities.add({
        'icon': Icons.add_circle_outline,
        'color': const Color(0xFF9C27B0),
        'title': 'Task baru dibuat',
        'subtitle': '"${task.title}" ditambahkan',
        'time': task.createdAt,
        'type': 'created',
      });
    }

    // Urutkan dari terbaru
    activities.sort((a, b) =>
        (b['time'] as DateTime).compareTo(a['time'] as DateTime));

    return activities.take(20).toList();
  }

  @override
  Widget build(BuildContext context) {
    final overdueCount = _overdueTasks.length;
    final upcomingCount = _upcomingTasks.length;
    final totalBadge = overdueCount + upcomingCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Inbox',
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 18)),
            if (totalBadge > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF5350),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$totalBadge',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black45,
          indicatorColor: const Color(0xFF4CAF8D),
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: [
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('Semua'),
                if (totalBadge > 0) ...[
                  const SizedBox(width: 4),
                  _badgeWidget(totalBadge, const Color(0xFFEF5350)),
                ],
              ]),
            ),
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('Overdue'),
                if (overdueCount > 0) ...[
                  const SizedBox(width: 4),
                  _badgeWidget(overdueCount, const Color(0xFFEF5350)),
                ],
              ]),
            ),
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('Upcoming'),
                if (upcomingCount > 0) ...[
                  const SizedBox(width: 4),
                  _badgeWidget(upcomingCount, const Color(0xFFFFB74D)),
                ],
              ]),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab Semua: Aktivitas ──
          _buildAllTab(),

          // ── Tab Overdue ──
          _buildOverdueTab(),

          // ── Tab Upcoming ──
          _buildUpcomingTab(),
        ],
      ),
    );
  }

  // ── TAB SEMUA ──────────────────────────────────────
  Widget _buildAllTab() {
    if (_activities.isEmpty) {
      return _emptyState(
        icon: Icons.inbox_outlined,
        message: 'Belum ada aktivitas',
        subtitle: 'Aktivitas task akan muncul di sini',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activities.length,
      itemBuilder: (_, i) {
        final activity = _activities[i];
        return _activityCard(activity);
      },
    );
  }

  // ── TAB OVERDUE ────────────────────────────────────
  Widget _buildOverdueTab() {
    if (_overdueTasks.isEmpty) {
      return _emptyState(
        icon: Icons.check_circle_outline,
        message: 'Tidak ada task overdue',
        subtitle: 'Semua task masih dalam batas waktu',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _overdueTasks.length,
      itemBuilder: (_, i) {
        final task = _overdueTasks[i];
        return _overdueCard(task);
      },
    );
  }

  // ── TAB UPCOMING ───────────────────────────────────
  Widget _buildUpcomingTab() {
    if (_upcomingTasks.isEmpty) {
      return _emptyState(
        icon: Icons.event_available_outlined,
        message: 'Tidak ada task dalam 3 hari ke depan',
        subtitle: 'Task dengan due date akan muncul di sini',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _upcomingTasks.length,
      itemBuilder: (_, i) {
        final task = _upcomingTasks[i];
        return _upcomingCard(task);
      },
    );
  }

  // ── ACTIVITY CARD ──────────────────────────────────
  Widget _activityCard(Map<String, dynamic> activity) {
    final time = activity['time'] as DateTime;
    final timeStr = _timeAgo(time);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: (activity['color'] as Color).withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(activity['icon'] as IconData,
              color: activity['color'] as Color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(activity['title'],
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 2),
            Text(activity['subtitle'],
                style: const TextStyle(color: Colors.black54, fontSize: 12)),
            const SizedBox(height: 4),
            Text(timeStr,
                style: const TextStyle(color: Colors.black38, fontSize: 11)),
          ]),
        ),
      ]),
    );
  }

  // ── OVERDUE CARD ───────────────────────────────────
  Widget _overdueCard(TaskModel task) {
    final daysOverdue = DateTime.now().difference(task.dueDate!).inDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF5350).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFEF5350).withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFEF5350), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(task.title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 2),
            Text(
              daysOverdue == 0
                  ? 'Jatuh tempo hari ini'
                  : 'Terlambat $daysOverdue hari',
              style: const TextStyle(
                  color: Color(0xFFEF5350),
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(task.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black45, fontSize: 12)),
            ],
          ]),
        ),
        // Priority badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _priorityColor(task.priority).withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            _priorityLabel(task.priority),
            style: TextStyle(
                fontSize: 11,
                color: _priorityColor(task.priority),
                fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }

  // ── UPCOMING CARD ──────────────────────────────────
  Widget _upcomingCard(TaskModel task) {
    final daysLeft = task.dueDate!.difference(DateTime.now()).inDays;
    final isToday = daysLeft == 0;
    final isTomorrow = daysLeft == 1;

    String dayLabel;
    Color dayColor;
    if (isToday) {
      dayLabel = 'Hari ini';
      dayColor = const Color(0xFFEF5350);
    } else if (isTomorrow) {
      dayLabel = 'Besok';
      dayColor = const Color(0xFFFFB74D);
    } else {
      dayLabel = '$daysLeft hari lagi';
      dayColor = const Color(0xFF4CAF8D);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dayColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: dayColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.event, color: dayColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(task.title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 2),
            Row(children: [
              Icon(Icons.access_time, size: 12, color: dayColor),
              const SizedBox(width: 4),
              Text(dayLabel,
                  style: TextStyle(
                      color: dayColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text(
                '${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}',
                style: const TextStyle(color: Colors.black38, fontSize: 11),
              ),
            ]),
            if (task.subtasks.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${task.subtasks.where((s) => s.isCompleted).length}/${task.subtasks.length} subtasks selesai',
                style: const TextStyle(color: Colors.black45, fontSize: 11),
              ),
            ],
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _priorityColor(task.priority).withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            _priorityLabel(task.priority),
            style: TextStyle(
                fontSize: 11,
                color: _priorityColor(task.priority),
                fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }

  // ── EMPTY STATE ────────────────────────────────────
  Widget _emptyState({
    required IconData icon,
    required String message,
    required String subtitle,
  }) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 64, color: Colors.black12),
        const SizedBox(height: 12),
        Text(message,
            style: const TextStyle(
                color: Colors.black45,
                fontSize: 15,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(subtitle,
            style: const TextStyle(color: Colors.black26, fontSize: 13)),
      ]),
    );
  }

  // ── HELPERS ────────────────────────────────────────
  Widget _badgeWidget(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$count',
          style: const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  Color _priorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low: return const Color(0xFF64B5F6);
      case TaskPriority.medium: return const Color(0xFFFFB74D);
      case TaskPriority.high: return const Color(0xFFEF5350);
      case TaskPriority.urgent: return const Color(0xFF9C27B0);
    }
  }

  String _priorityLabel(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low: return 'Low';
      case TaskPriority.medium: return 'Medium';
      case TaskPriority.high: return 'High';
      case TaskPriority.urgent: return 'Urgent';
    }
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${time.day}/${time.month}/${time.year}';
  }
}
