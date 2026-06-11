import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../models/task_model.dart';

class ApiService {
  // Ganti IP ini sesuai komputer kamu
  // Kalau pakai emulator Android → 10.0.2.2
  // Kalau pakai HP fisik → IP komputer kamu (cek dengan ipconfig)
  static const String baseUrl = 'http://10.0.2.2:3000/api';

  // Header standar untuk semua request
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  // ── GET semua task ──────────────────────────────────
  static Future<List<TaskModel>> getTasks() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/tasks'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        final List<dynamic> data = json['data'];
        return data.map((e) => _taskFromApi(e)).toList();
      }
      throw Exception('Gagal mengambil tasks: ${response.statusCode}');
    } catch (e) {
      throw Exception('Tidak bisa konek ke server: $e');
    }
  }

  // ── POST buat task baru ─────────────────────────────
  static Future<TaskModel> createTask(TaskModel task) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/tasks'),
            headers: _headers,
            body: jsonEncode(_taskToApi(task)),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final json = jsonDecode(response.body);
        return _taskFromApi(json['data']);
      }
      throw Exception('Gagal membuat task: ${response.statusCode}');
    } catch (e) {
      throw Exception('Tidak bisa konek ke server: $e');
    }
  }

  // ── PUT update task ─────────────────────────────────
  static Future<TaskModel> updateTask(TaskModel task) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/tasks/${task.id}'),
            headers: _headers,
            body: jsonEncode(_taskToApi(task)),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return _taskFromApi(json['data']);
      }
      throw Exception('Gagal mengupdate task: ${response.statusCode}');
    } catch (e) {
      throw Exception('Tidak bisa konek ke server: $e');
    }
  }

  // ── DELETE hapus task ───────────────────────────────
  static Future<bool> deleteTask(String id) async {
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/tasks/$id'))
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Tidak bisa konek ke server: $e');
    }
  }

  // ── PATCH toggle subtask ────────────────────────────
  static Future<void> toggleSubtask(
      String taskId, String subtaskId, bool isCompleted) async {
    try {
      await http
          .patch(
            Uri.parse('$baseUrl/tasks/$taskId/subtasks/$subtaskId'),
            headers: _headers,
            body: jsonEncode({'is_completed': isCompleted}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw Exception('Tidak bisa konek ke server: $e');
    }
  }

  // ── Cek koneksi ke server ───────────────────────────
  static Future<bool> checkConnection() async {
    try {
      final response = await http
          .get(Uri.parse('http://10.0.2.2:3000'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ── Helper: konversi data API → TaskModel ───────────
  static TaskModel _taskFromApi(Map<String, dynamic> data) {
    // Konversi subtasks dari JSON
    List<SubTask> subtasks = [];
    if (data['subtasks'] != null && data['subtasks'] is List) {
      subtasks = (data['subtasks'] as List)
          .where((s) => s != null)
          .map((s) => SubTask(
                id: s['id'].toString(),
                title: s['title'] ?? '',
                isCompleted: s['is_completed'] == 1 || s['is_completed'] == true,
              ))
          .toList();
    }

    // Konversi reminder_time dari string "HH:mm:ss" → TimeOfDay
    TimeOfDay? reminderTime;
    if (data['reminder_time'] != null) {
      final parts = data['reminder_time'].toString().split(':');
      if (parts.length >= 2) {
        reminderTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }

    // Konversi status string → enum
    TaskStatus status;
    switch (data['status']) {
      case 'inProgress':
        status = TaskStatus.inProgress;
        break;
      case 'done':
        status = TaskStatus.done;
        break;
      default:
        status = TaskStatus.open;
    }

    // Konversi priority string → enum
    TaskPriority priority;
    switch (data['priority']) {
      case 'low':
        priority = TaskPriority.low;
        break;
      case 'high':
        priority = TaskPriority.high;
        break;
      case 'urgent':
        priority = TaskPriority.urgent;
        break;
      default:
        priority = TaskPriority.medium;
    }

    // Konversi recurring_type string → enum
    RecurringType recurringType;
    switch (data['recurring_type']) {
      case 'daily':
        recurringType = RecurringType.daily;
        break;
      case 'weekly':
        recurringType = RecurringType.weekly;
        break;
      case 'monthly':
        recurringType = RecurringType.monthly;
        break;
      case 'yearly':
        recurringType = RecurringType.yearly;
        break;
      default:
        recurringType = RecurringType.none;
    }

    return TaskModel(
      id: data['id'].toString(),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      status: status,
      priority: priority,
      dueDate: data['due_date'] != null
          ? DateTime.tryParse(data['due_date'])
          : null,
      reminderTime: reminderTime,
      hasReminder: data['has_reminder'] == 1 || data['has_reminder'] == true,
      subtasks: subtasks,
      recurringType: recurringType,
      projectName: data['project_name'],
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  // ── Helper: konversi TaskModel → format API ─────────
  static Map<String, dynamic> _taskToApi(TaskModel task) {
    // Konversi enum → string
    String status;
    switch (task.status) {
      case TaskStatus.inProgress:
        status = 'inProgress';
        break;
      case TaskStatus.done:
        status = 'done';
        break;
      default:
        status = 'open';
    }

    String priority;
    switch (task.priority) {
      case TaskPriority.low:
        priority = 'low';
        break;
      case TaskPriority.high:
        priority = 'high';
        break;
      case TaskPriority.urgent:
        priority = 'urgent';
        break;
      default:
        priority = 'medium';
    }

    String recurringType;
    switch (task.recurringType) {
      case RecurringType.daily:
        recurringType = 'daily';
        break;
      case RecurringType.weekly:
        recurringType = 'weekly';
        break;
      case RecurringType.monthly:
        recurringType = 'monthly';
        break;
      case RecurringType.yearly:
        recurringType = 'yearly';
        break;
      default:
        recurringType = 'none';
    }

    return {
      'title': task.title,
      'description': task.description,
      'status': status,
      'priority': priority,
      'due_date': task.dueDate?.toIso8601String().split('T')[0], // format YYYY-MM-DD
      'reminder_time': task.reminderTime != null
          ? '${task.reminderTime!.hour.toString().padLeft(2, '0')}:${task.reminderTime!.minute.toString().padLeft(2, '0')}:00'
          : null,
      'has_reminder': task.hasReminder,
      'recurring_type': recurringType,
      'project_name': task.projectName,
      'subtasks': task.subtasks
          .map((s) => {'title': s.title, 'is_completed': s.isCompleted})
          .toList(),
    };
  }
}