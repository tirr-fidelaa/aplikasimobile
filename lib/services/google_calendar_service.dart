import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;
import '../models/task_model.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────
//  GoogleCalendarService
//  Mengurus login Google + sync task ke/dari Google Calendar
// ─────────────────────────────────────────────────────────
class GoogleCalendarService {
  static const String _webClientId =
      '165401827609-6t9klotcsnoiraodfdoqif4bfjbm40m4.apps.googleusercontent.com';

  // Scope yang diminta: akses penuh ke Google Calendar
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: _webClientId,
    scopes: [gcal.CalendarApi.calendarScope],
  );

  static GoogleSignInAccount? _currentUser;
  static gcal.CalendarApi? _calendarApi;

  // ── LOGIN ─────────────────────────────────────────────
  static Future<bool> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return false;

      _currentUser = account;
      final client = _AuthClient(account);
      _calendarApi = gcal.CalendarApi(client);

      return true;
    } catch (e) {
      print('Google Sign In error: $e');
      return false;
    }
  }

  // ── LOGOUT ───────────────────────────────────────────
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _calendarApi = null;
  }

  // ── CEK STATUS LOGIN ─────────────────────────────────
  static bool get isSignedIn => _currentUser != null;
  static String? get userEmail => _currentUser?.email;
  static String? get userName => _currentUser?.displayName;

  // ── SILENT SIGN IN (auto login kalau sudah pernah login) ──
  static Future<bool> trySilentSignIn() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) return false;

      _currentUser = account;
      final client = _AuthClient(account);
      _calendarApi = gcal.CalendarApi(client);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── AMBIL SEMUA EVENT DARI GOOGLE CALENDAR ───────────
  static Future<List<gcal.Event>> getCalendarEvents({
    DateTime? timeMin,
    DateTime? timeMax,
  }) async {
    if (_calendarApi == null) throw Exception('Belum login ke Google');

    final now = DateTime.now();
    final events = await _calendarApi!.events.list(
      'primary', // kalender utama
      timeMin: (timeMin ?? now.subtract(const Duration(days: 30))).toUtc(),
      timeMax: (timeMax ?? now.add(const Duration(days: 90))).toUtc(),
      singleEvents: true,
      orderBy: 'startTime',
    );

    return events.items ?? [];
  }

  // ── TAMBAH TASK KE GOOGLE CALENDAR ──────────────────
  static Future<String?> addTaskToCalendar(TaskModel task) async {
    if (_calendarApi == null) throw Exception('Belum login ke Google');
    if (task.dueDate == null) throw Exception('Task tidak punya due date');

    // Buat event dari task
    final event = gcal.Event()
      ..summary = task.title
      ..description = _buildDescription(task)
      ..colorId = _priorityToColorId(task.priority)
      ..reminders = gcal.EventReminders(
        useDefault: false,
        overrides: task.hasReminder
            ? [gcal.EventReminder(method: 'popup', minutes: 30)]
            : [],
      );

    // Set waktu event
    final dueDate = task.dueDate!;
    if (task.reminderTime != null) {
      // Kalau ada jam reminder, buat event berdurasi 1 jam
      final start = DateTime(
        dueDate.year,
        dueDate.month,
        dueDate.day,
        task.reminderTime!.hour,
        task.reminderTime!.minute,
      );
      final end = start.add(const Duration(hours: 1));
      event.start =
          gcal.EventDateTime(dateTime: start.toUtc(), timeZone: 'Asia/Jakarta');
      event.end =
          gcal.EventDateTime(dateTime: end.toUtc(), timeZone: 'Asia/Jakarta');
    } else {
      // Kalau tidak ada jam, buat all-day event
      final dateStr =
          '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';
      event.start = gcal.EventDateTime(date: DateTime.parse(dateStr));
      event.end = gcal.EventDateTime(
          date: DateTime.parse(dateStr).add(const Duration(days: 1)));
    }

    // Recurring event
    if (task.recurringType != RecurringType.none) {
      event.recurrence = [_buildRRule(task.recurringType)];
    }

    final created = await _calendarApi!.events.insert(event, 'primary');
    return created.id; // kembalikan event ID untuk disimpan
  }

  // ── UPDATE EVENT DI GOOGLE CALENDAR ─────────────────
  static Future<void> updateCalendarEvent(
      String eventId, TaskModel task) async {
    if (_calendarApi == null) throw Exception('Belum login ke Google');

    final existing = await _calendarApi!.events.get('primary', eventId);

    existing
      ..summary = task.title
      ..description = _buildDescription(task)
      ..colorId = _priorityToColorId(task.priority);

    // Update status: kalau done, tandai sebagai selesai di deskripsi
    if (task.status == TaskStatus.done) {
      existing.summary = '✅ ${task.title}';
    }

    await _calendarApi!.events.update(existing, 'primary', eventId);
  }

  // ── HAPUS EVENT DARI GOOGLE CALENDAR ────────────────
  static Future<void> deleteCalendarEvent(String eventId) async {
    if (_calendarApi == null) throw Exception('Belum login ke Google');
    await _calendarApi!.events.delete('primary', eventId);
  }

  // ── KONVERSI GOOGLE CALENDAR EVENT → TASKMODEL ──────
  static TaskModel eventToTask(gcal.Event event) {
    DateTime? dueDate;
    TimeOfDay? reminderTime;

    if (event.start?.dateTime != null) {
      final dt = event.start!.dateTime!.toLocal();
      dueDate = dt;
      reminderTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
    } else if (event.start?.date != null) {
      dueDate = event.start!.date;
    }

    return TaskModel(
      id: 'gcal_${event.id}',
      title: event.summary?.replaceAll('✅ ', '') ?? 'Tanpa Judul',
      description: event.description ?? '',
      status: (event.summary?.startsWith('✅') ?? false)
          ? TaskStatus.done
          : TaskStatus.open,
      priority: TaskPriority.medium,
      dueDate: dueDate,
      reminderTime: reminderTime,
      hasReminder: event.reminders?.overrides?.isNotEmpty ?? false,
      recurringType: RecurringType.none,
      createdAt: event.created?.toLocal() ?? DateTime.now(),
      projectName: 'Google Calendar',
      calendarEventId: event.id,
    );
  }

  // ── HELPER: Buat deskripsi event dari task ───────────
  static String _buildDescription(TaskModel task) {
    final buffer = StringBuffer();
    buffer.writeln('📋 TaskFlow Task');
    buffer.writeln('Status: ${_statusLabel(task.status)}');
    buffer.writeln('Prioritas: ${_priorityLabel(task.priority)}');
    if (task.description.isNotEmpty) {
      buffer.writeln('\n${task.description}');
    }
    if (task.subtasks.isNotEmpty) {
      buffer.writeln('\nSubtasks:');
      for (final s in task.subtasks) {
        buffer.writeln('${s.isCompleted ? '✅' : '⬜'} ${s.title}');
      }
    }
    return buffer.toString();
  }

  // ── HELPER: Priority → Google Calendar color ID ──────
  // Google Calendar color IDs: 1=Lavender, 2=Sage, 3=Grape,
  // 4=Flamingo, 5=Banana, 6=Tangerine, 7=Peacock, 8=Graphite,
  // 9=Blueberry, 10=Basil, 11=Tomato
  static String _priorityToColorId(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return '2'; // Sage (hijau)
      case TaskPriority.medium:
        return '5'; // Banana (kuning)
      case TaskPriority.high:
        return '6'; // Tangerine (oranye)
      case TaskPriority.urgent:
        return '11'; // Tomato (merah)
    }
  }

  // ── HELPER: RecurringType → Google Calendar RRULE ────
  static String _buildRRule(RecurringType type) {
    switch (type) {
      case RecurringType.daily:
        return 'RRULE:FREQ=DAILY';
      case RecurringType.weekly:
        return 'RRULE:FREQ=WEEKLY';
      case RecurringType.monthly:
        return 'RRULE:FREQ=MONTHLY';
      case RecurringType.yearly:
        return 'RRULE:FREQ=YEARLY';
      default:
        return '';
    }
  }

  static String _statusLabel(TaskStatus s) {
    switch (s) {
      case TaskStatus.open:
        return 'Open';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.done:
        return 'Done';
    }
  }

  static String _priorityLabel(TaskPriority p) {
    switch (p) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
      case TaskPriority.urgent:
        return 'Urgent';
    }
  }
}

// ─────────────────────────────────────────────────────────
//  _AuthClient
//  HTTP client yang otomatis menyisipkan token Google
// ─────────────────────────────────────────────────────────
class _AuthClient extends http.BaseClient {
  final GoogleSignInAccount _account;
  final http.Client _inner = http.Client();

  _AuthClient(this._account);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final authHeaders = await _account.authHeaders;
    request.headers.addAll(authHeaders);
    return _inner.send(request);
  }
}
