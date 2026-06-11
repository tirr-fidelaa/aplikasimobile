import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import '../models/task_model.dart';
import '../services/google_calendar_service.dart';

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
      // Simpan ID event ke task agar dapat di‑hapus nanti
      await widget.onUpdateTask(task.copyWith(calendarEventId: eventId));   } catch (e) {
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