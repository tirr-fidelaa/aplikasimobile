import 'dart:convert';
import 'package:flutter/material.dart' show TimeOfDay;

enum TaskStatus { open, inProgress, done }
enum TaskPriority { low, medium, high, urgent }
enum RecurringType { none, daily, weekly, monthly, yearly }

class SubTask {
  String id;
  String title;
  bool isCompleted;

  SubTask({required this.id, required this.title, this.isCompleted = false});

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'isCompleted': isCompleted};
  factory SubTask.fromMap(Map<String, dynamic> map) =>
      SubTask(id: map['id'], title: map['title'], isCompleted: map['isCompleted'] ?? false);
}

class TaskModel {
  String id;
  String title;
  String description;
  TaskStatus status;
  TaskPriority priority;
  DateTime? dueDate;
  TimeOfDay? reminderTime;
  bool hasReminder;
  List<SubTask> subtasks;
  List<String> attachments;
  RecurringType recurringType;
  DateTime createdAt;
  List<String> assignees;
  String? projectName;
  String? calendarEventId;

  TaskModel({
    required this.id,
    required this.title,
    this.description = '',
    this.status = TaskStatus.open,
    this.priority = TaskPriority.medium,
    this.dueDate,
    this.reminderTime,
    this.hasReminder = false,
    this.subtasks = const [],
    this.attachments = const [],
    this.recurringType = RecurringType.none,
    required this.createdAt,
    this.assignees = const [],
    this.projectName,
    this.calendarEventId,
  });

  TaskModel copyWith({
    String? id, String? title, String? description, TaskStatus? status,
    TaskPriority? priority, DateTime? dueDate, TimeOfDay? reminderTime,
    bool? hasReminder, List<SubTask>? subtasks, List<String>? attachments,
    RecurringType? recurringType, DateTime? createdAt, List<String>? assignees, String? projectName, 
    String? calendarEventId,
  }) {
    return TaskModel(
      id: id ?? this.id, title: title ?? this.title, description: description ?? this.description,
      status: status ?? this.status, priority: priority ?? this.priority, dueDate: dueDate ?? this.dueDate,
      reminderTime: reminderTime ?? this.reminderTime, hasReminder: hasReminder ?? this.hasReminder,
      subtasks: subtasks ?? this.subtasks, attachments: attachments ?? this.attachments,
      recurringType: recurringType ?? this.recurringType, createdAt: createdAt ?? this.createdAt,
      assignees: assignees ?? this.assignees, projectName: projectName ?? this.projectName, 
      calendarEventId: calendarEventId ?? this.calendarEventId,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id, 'title': title, 'description': description, 'status': status.index,
    'priority': priority.index, 'dueDate': dueDate?.toIso8601String(),
    'reminderHour': reminderTime?.hour, 'reminderMinute': reminderTime?.minute,
    'hasReminder': hasReminder,
    'subtasks': subtasks.map((s) => s.toMap()).toList(),
    'attachments': attachments, 'recurringType': recurringType.index,
    'createdAt': createdAt.toIso8601String(), 'assignees': assignees, 'projectName': projectName,
    'calendarEventId': calendarEventId,
  };

  factory TaskModel.fromMap(Map<String, dynamic> map) => TaskModel(
    id: map['id'], title: map['title'], description: map['description'] ?? '',
    status: TaskStatus.values[map['status'] ?? 0], priority: TaskPriority.values[map['priority'] ?? 1],
    dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
    reminderTime: map['reminderHour'] != null
        ? TimeOfDay(hour: map['reminderHour'], minute: map['reminderMinute'] ?? 0) : null,
    hasReminder: map['hasReminder'] ?? false,
    subtasks: (map['subtasks'] as List<dynamic>? ?? []).map((s) => SubTask.fromMap(s)).toList(),
    attachments: List<String>.from(map['attachments'] ?? []),
    recurringType: RecurringType.values[map['recurringType'] ?? 0],
    createdAt: DateTime.parse(map['createdAt']),
    assignees: List<String>.from(map['assignees'] ?? []), projectName: map['projectName'],
    calendarEventId: map['calendarEventId'],
  );

  String toJson() => jsonEncode(toMap());
  factory TaskModel.fromJson(String source) => TaskModel.fromMap(jsonDecode(source));
}