import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../services/task_services.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _pushNotif = true;
  bool _reminderNotif = true;
  bool _dueDateNotif = true;
  bool _overdueNotif = false;
  bool _dailySummary = false;
  String _reminderBefore = '30 menit';
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushNotif = prefs.getBool('pushNotif') ?? true;
      _reminderNotif = prefs.getBool('reminderNotif') ?? true;
      _dueDateNotif = prefs.getBool('dueDateNotif') ?? true;
      _overdueNotif = prefs.getBool('overdueNotif') ?? false;
      _dailySummary = prefs.getBool('dailySummary') ?? false;
      _reminderBefore = prefs.getString('reminderBefore') ?? '30 menit';
    });
    await _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await NotificationService.getHistory();
    setState(() => _notifications = history);
  }

  IconData _notifIcon(String type) {
    switch (type) {
      case 'reminder':
        return Icons.alarm;
      case 'duedate':
        return Icons.calendar_today_outlined;
      case 'overdue':
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _notifColor(String type) {
    switch (type) {
      case 'reminder':
        return const Color(0xFFFFB74D);
      case 'duedate':
        return const Color(0xFF26A69A);
      case 'overdue':
        return const Color(0xFFEF5350);
      default:
        return const Color(0xFF42A5F5);
    }
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${(diff.inDays / 7).floor()} minggu lalu';
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is String) await prefs.setString(key, value);
    await _rescheduleTasks();
  }

  Future<void> _rescheduleTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final pushNotif = prefs.getBool('pushNotif') ?? true;
    if (pushNotif) {
      final tasks = await TaskServices.loadTasks();
      await NotificationService.rescheduleAll(tasks);
    } else {
      await NotificationService.cancelAll();
    }
  }

  // Simulasi data notifikasi masuk
  List<Map<String, dynamic>> _notifications = [];

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n['isRead']).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () async {
                await NotificationService.markAllAsRead();
                await _loadHistory();
              },
              child: const Text('Tandai semua',
                  style: TextStyle(color: Color(0xFF4CAF8D), fontSize: 13)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Pengaturan Notifikasi ──
          _sectionHeader('Pengaturan Notifikasi'),
          _settingsCard([
            _switchTile(
              icon: Icons.notifications_active_outlined,
              iconColor: const Color(0xFF4CAF8D),
              title: 'Push Notification',
              subtitle: 'Aktifkan semua notifikasi',
              value: _pushNotif,
              onChanged: (v) {
                setState(() => _pushNotif = v);
                _saveSetting('pushNotif', v);
              },
            ),
            const Divider(height: 1, indent: 56),
            _switchTile(
              icon: Icons.alarm_outlined,
              iconColor: const Color(0xFFFFB74D),
              title: 'Reminder Task',
              subtitle: 'Ingatkan sebelum batas waktu',
              value: _reminderNotif,
              onChanged: (v) {
                setState(() => _reminderNotif = v);
                _saveSetting('reminderNotif', v);
              },
            ),
            const Divider(height: 1, indent: 56),
            _dropdownTile(
              icon: Icons.schedule_outlined,
              iconColor: const Color(0xFF5C6BC0),
              title: 'Ingatkan sebelum',
              value: _reminderBefore,
              items: ['15 menit', '30 menit', '1 jam', '2 jam', '1 hari'],
              onChanged: (v) {
                setState(() => _reminderBefore = v!);
                _saveSetting('reminderBefore', v!);
              },
            ),
            const Divider(height: 1, indent: 56),
            _switchTile(
              icon: Icons.calendar_today_outlined,
              iconColor: const Color(0xFF26A69A),
              title: 'Notifikasi Due Date',
              subtitle: 'Ingatkan saat hari H',
              value: _dueDateNotif,
              onChanged: (v) {
                setState(() => _dueDateNotif = v);
                _saveSetting('dueDateNotif', v);
              },
            ),
            const Divider(height: 1, indent: 56),
            _switchTile(
              icon: Icons.warning_amber_outlined,
              iconColor: const Color(0xFFEF5350),
              title: 'Notifikasi Overdue',
              subtitle: 'Ingatkan saat task terlambat',
              value: _overdueNotif,
              onChanged: (v) {
                setState(() => _overdueNotif = v);
                _saveSetting('overdueNotif', v);
              },
            ),
            const Divider(height: 1, indent: 56),
            _switchTile(
              icon: Icons.summarize_outlined,
              iconColor: const Color(0xFF42A5F5),
              title: 'Ringkasan Harian',
              subtitle: 'Kirim ringkasan tugas setiap pagi',
              value: _dailySummary,
              onChanged: (v) {
                setState(() => _dailySummary = v);
                _saveSetting('dailySummary', v);
              },
            ),
          ]),

          const SizedBox(height: 20),

          // ── Riwayat Notifikasi ──
          Row(
            children: [
              _sectionHeader('Riwayat'),
              if (unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF8D),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$unreadCount baru',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),

          ..._notifications.asMap().entries.map((entry) {
            final i = entry.key;
            final n = entry.value;
            return _notifCard(n, i);
          }),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _notifCard(Map<String, dynamic> n, int index) {
    return GestureDetector(
      onTap: () async {
        await NotificationService.markAsRead(_notifications[index]['id']);
        await _loadHistory();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: n['isRead'] ? Colors.white : const Color(0xFFEDF7F3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: n['isRead']
                ? Colors.transparent
                : const Color(0xFF4CAF8D).withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _notifColor(n['type']).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_notifIcon(n['type']),
                  color: _notifColor(n['type']), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n['title'],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          n['isRead'] ? FontWeight.w500 : FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    n['subtitle'],
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timeAgo(DateTime.parse(n['time'])),
                    style: const TextStyle(fontSize: 11, color: Colors.black38),
                  ),
                ],
              ),
            ),
            if (!n['isRead'])
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFF4CAF8D),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.black45,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _settingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.black45)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF4CAF8D),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _dropdownTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      trailing: DropdownButton<String>(
        value: value,
        isDense: true,
        underline: const SizedBox(),
        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
        items: items
            .map((e) => DropdownMenuItem(
                value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
