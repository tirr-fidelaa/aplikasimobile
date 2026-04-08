import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_model.dart';

class TaskServices {
  static const String _tasksKey = 'tasks';

  // Load all tasks
  static Future<List<TaskModel>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tasksJson = prefs.getString(_tasksKey);
    if (tasksJson == null) return [];
    final List<dynamic> decoded = jsonDecode(tasksJson);
    return decoded.map((item) => TaskModel.fromMap(item)).toList();
  }

  // Save all tasks
  static Future<void> saveTasks(List<TaskModel> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(tasks.map((t) => t.toMap()).toList());
    await prefs.setString(_tasksKey, encoded);
  }

  // Add a new task
  static Future<List<TaskModel>> addTask(
      List<TaskModel> tasks, TaskModel task) async {
    final updatedList = [...tasks, task];
    await saveTasks(updatedList);
    return updatedList;
  }

  // Update existing task
  static Future<List<TaskModel>> updateTask(
      List<TaskModel> tasks, TaskModel updatedTask) async {
    final updatedList = tasks.map((t) {
      return t.id == updatedTask.id ? updatedTask : t;
    }).toList();
    await saveTasks(updatedList);
    return updatedList;
  }

  // Delete a task
  static Future<List<TaskModel>> deleteTask(
      List<TaskModel> tasks, String taskId) async {
    final updatedList = tasks.where((t) => t.id != taskId).toList();
    await saveTasks(updatedList);
    return updatedList;
  }

  // Filter tasks by status
  static List<TaskModel> filterByStatus(
      List<TaskModel> tasks, TaskStatus status) {
    return tasks.where((t) => t.status == status).toList();
  }

  // Filter tasks by date
  static List<TaskModel> filterByDate(
      List<TaskModel> tasks, DateTime date) {
    return tasks.where((t) {
      if (t.dueDate == null) return false;
      return t.dueDate!.year == date.year &&
          t.dueDate!.month == date.month &&
          t.dueDate!.day == date.day;
    }).toList();
  }

  // Generate unique ID
  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // Get tasks due today
  static List<TaskModel> getTasksDueToday(List<TaskModel> tasks) {
    final now = DateTime.now();
    return filterByDate(tasks, now);
  }

  // Get overdue tasks
  static List<TaskModel> getOverdueTasks(List<TaskModel> tasks) {
    final now = DateTime.now();
    return tasks.where((t) {
      if (t.dueDate == null || t.status == TaskStatus.done) return false;
      return t.dueDate!.isBefore(now);
    }).toList();
  }

  // Get recurring next due date
  static DateTime? getNextRecurringDate(TaskModel task) {
    if (task.recurringType == RecurringType.none || task.dueDate == null) {
      return null;
    }
    switch (task.recurringType) {
      case RecurringType.daily:
        return task.dueDate!.add(const Duration(days: 1));
      case RecurringType.weekly:
        return task.dueDate!.add(const Duration(days: 7));
      case RecurringType.monthly:
        return DateTime(
            task.dueDate!.year, task.dueDate!.month + 1, task.dueDate!.day);
      case RecurringType.yearly:
        return DateTime(
            task.dueDate!.year + 1, task.dueDate!.month, task.dueDate!.day);
      default:
        return null;
    }
  }
}