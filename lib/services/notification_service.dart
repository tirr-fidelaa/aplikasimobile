import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_model.dart';
import 'dart:convert';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // ── Init (dipanggil sekali di main()) ──────────────────
  static Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) async {
        if (details.payload == null) return;
        final data = jsonDecode(details.payload!);
        final type = data['type'] as String;
        final taskId = data['taskId'] as String;
        final title = data['title'] as String;
        final subtitle = data['subtitle'] as String;
        await saveToHistory(
          id: '${taskId}_$type',
          type: type,
          title: title,
          subtitle: subtitle,
        );
        // TODO: optionally navigate to task detail screen
      },
    );

    // Minta permission (Android 13+)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  // ── Cek apakah fitur notifikasi aktif di settings ──────
  static Future<bool> _isEnabled(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? true;
  }

  static Future<String> _getReminderMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('reminderBefore') ?? '30 menit';
  }

  // ── Convert string reminder → Duration ────────────────
  static Duration _parseDuration(String val) {
    switch (val) {
      case '15 menit':
        return const Duration(minutes: 15);
      case '1 jam':
        return const Duration(hours: 1);
      case '2 jam':
        return const Duration(hours: 2);
      case '1 hari':
        return const Duration(days: 1);
      default:
        return const Duration(minutes: 30);
    }
  }

  // ── Schedule reminder sebelum due date ─────────────────
  static Future<void> scheduleTaskReminder(TaskModel task) async {
    if (task.dueDate == null) return;
    if (!await _isEnabled('pushNotif')) return;
    if (!await _isEnabled('reminderNotif')) return;

    final reminderStr = await _getReminderMinutes();
    final reminderTime = task.dueDate!.subtract(_parseDuration(reminderStr));

    if (reminderTime.isBefore(DateTime.now())) return;

    // Schedule reminder without immediate history entry
    await _plugin.zonedSchedule(
      task.id.hashCode,
      '⏰ Reminder: ${task.title}',
      'Jatuh tempo dalam $reminderStr',
      tz.TZDateTime.from(reminderTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel',
          'Task Reminder',
          channelDescription: 'Pengingat sebelum batas waktu task',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({
        'type': 'reminder',
        'taskId': task.id,
        'title': task.title,
        'subtitle': 'Jatuh tempo dalam $reminderStr',
      }),
    );
  }

  // ── Schedule notifikasi tepat di hari due date ─────────
  static Future<void> scheduleDueDateNotif(TaskModel task) async {
    if (task.dueDate == null) return;
    if (!await _isEnabled('pushNotif')) return;
    if (!await _isEnabled('dueDateNotif')) return;

    final dueTime = task.dueDate!;
    if (dueTime.isBefore(DateTime.now())) return;

    // await saveToHistory(
    //   id: '${task.id}_duedate',
    //   type: 'duedate',
    //   title: '📅 Due Today: ${task.title}',
    //   subtitle: 'Task ini jatuh tempo hari ini',
    // );
    await _plugin.zonedSchedule(
      task.id.hashCode + 1,
      '📅 Due Today: ${task.title}',
      'Task ini jatuh tempo hari ini',
      tz.TZDateTime.from(dueTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'duedate_channel',
          'Due Date Notification',
          channelDescription: 'Notifikasi saat hari H due date',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({
        'type': 'duedate',
        'taskId': task.id,
        'title': task.title,
        'subtitle': 'Task ini jatuh tempo hari ini',
      }),
    );
  }

  // ── Schedule notifikasi overdue (H+1 jam setelah due) ──
  static Future<void> scheduleOverdueNotif(TaskModel task) async {
    if (task.dueDate == null) return;
    if (!await _isEnabled('pushNotif')) return;
    if (!await _isEnabled('overdueNotif')) return;

    final overdueTime = task.dueDate!.add(const Duration(hours: 1));
    if (overdueTime.isBefore(DateTime.now())) return;

    await saveToHistory(
      id: '${task.id}_overdue',
      type: 'overdue',
      title: '⚠️ Overdue: ${task.title}',
      subtitle: 'Task ini sudah melewati batas waktu!',
    );
    await _plugin.zonedSchedule(
      task.id.hashCode + 2,
      '⚠️ Overdue: ${task.title}',
      'Task ini sudah melewati batas waktu!',
      tz.TZDateTime.from(overdueTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'overdue_channel',
          'Overdue Notification',
          channelDescription: 'Notifikasi saat task terlambat',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ── Schedule ringkasan harian (setiap pagi jam 07:00) ──
  static Future<void> scheduleDailySummary() async {
    if (!await _isEnabled('pushNotif')) return;
    if (!await _isEnabled('dailySummary')) return;

    await cancelDailySummary();

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 7);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      999999,
      '📋 Ringkasan Harian TaskFlow',
      'Cek task kamu hari ini!',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_summary_channel',
          'Ringkasan Harian',
          channelDescription: 'Ringkasan task setiap pagi',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // repeat harian
    );
  }

  // ── Cancel notifikasi untuk 1 task ────────────────────
  static Future<void> cancelTaskNotifications(String taskId) async {
    await _plugin.cancel(taskId.hashCode);
    await _plugin.cancel(taskId.hashCode + 1);
    await _plugin.cancel(taskId.hashCode + 2);
  }

  // ── Cancel semua notifikasi ────────────────────────────
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ── Cancel hanya daily summary ─────────────────────────
  static Future<void> cancelDailySummary() async {
    await _plugin.cancel(999999);
  }

  // ── Re-schedule semua task (dipanggil saat toggle pushNotif) ──
  static Future<void> rescheduleAll(List<TaskModel> tasks) async {
    await cancelAll();
    for (final task in tasks) {
      if (task.status == TaskStatus.done) continue;
      await scheduleTaskReminder(task);
      await scheduleDueDateNotif(task);
      await scheduleOverdueNotif(task);
    }
    await scheduleDailySummary();
  }

  // ── Simpan notifikasi ke riwayat ───────────────────────
  static Future<void> saveToHistory({
    required String id,
    required String type, // 'reminder' | 'duedate' | 'overdue'
    required String title,
    required String subtitle,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList('notif_history') ?? [];

    final entry = jsonEncode({
      'id': id,
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'time': DateTime.now().toIso8601String(),
      'isRead': false,
    });

    // Hindari duplikat
    final alreadyExists = existing.any((e) {
      final decoded = jsonDecode(e);
      return decoded['id'] == id;
    });
    if (alreadyExists) return;

    existing.insert(0, entry); // terbaru di atas

    // Maksimal simpan 30 riwayat
    if (existing.length > 30) existing.removeLast();

    await prefs.setStringList('notif_history', existing);
  }

  // ── Ambil semua riwayat ────────────────────────────────
  static Future<List<Map<String, dynamic>>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('notif_history') ?? [];
    return raw.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  // ── Tandai satu notifikasi sebagai sudah dibaca ────────
  static Future<void> markAsRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('notif_history') ?? [];

    final updated = raw.map((e) {
      final decoded = jsonDecode(e) as Map<String, dynamic>;
      if (decoded['id'] == id) decoded['isRead'] = true;
      return jsonEncode(decoded);
    }).toList();

    await prefs.setStringList('notif_history', updated);
  }

  // ── Tandai semua sebagai sudah dibaca ─────────────────
  static Future<void> markAllAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('notif_history') ?? [];

    final updated = raw.map((e) {
      final decoded = jsonDecode(e) as Map<String, dynamic>;
      decoded['isRead'] = true;
      return jsonEncode(decoded);
    }).toList();

    await prefs.setStringList('notif_history', updated);
  }

  // ── Hitung unread ──────────────────────────────────────
  static Future<int> getUnreadCount() async {
    final history = await getHistory();
    return history.where((n) => n['isRead'] == false).length;
  }
}
