import 'package:flutter/foundation.dart';

enum TaskPriority {
  none,
  low,
  medium,
  high,
  urgent;

  static TaskPriority fromString(String value) =>
      TaskPriority.values.firstWhere(
        (e) => e.name == value,
        orElse: () => TaskPriority.none,
      );

  String get label => switch (this) {
        TaskPriority.none => 'No Priority',
        TaskPriority.low => 'Low',
        TaskPriority.medium => 'Medium',
        TaskPriority.high => 'High',
        TaskPriority.urgent => 'Urgent',
      };
}

@immutable
class Task {
  const Task({
    required this.id,
    required this.userId,
    required this.title,
    required this.completed,
    required this.priority,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.projectId,
    this.sourceNoteId,
    this.deadline,
  });

  final String id;
  final String userId;
  final String? projectId;
  final String? sourceNoteId;
  final String title;
  final bool completed;
  final TaskPriority priority;
  final DateTime? deadline;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        projectId: json['project_id'] as String?,
        sourceNoteId: json['source_note_id'] as String?,
        title: json['title'] as String,
        completed: json['completed'] as bool,
        priority: TaskPriority.fromString(json['priority'] as String),
        deadline: json['deadline'] != null
            ? DateTime.parse(json['deadline'] as String)
            : null,
        sortOrder: json['sort_order'] as int,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'project_id': projectId,
        'source_note_id': sourceNoteId,
        'title': title,
        'completed': completed,
        'priority': priority.name,
        'deadline': deadline?.toIso8601String(),
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Task copyWith({
    String? title,
    bool? completed,
    TaskPriority? priority,
    DateTime? deadline,
    int? sortOrder,
    String? projectId,
  }) =>
      Task(
        id: id,
        userId: userId,
        projectId: projectId ?? this.projectId,
        sourceNoteId: sourceNoteId,
        title: title ?? this.title,
        completed: completed ?? this.completed,
        priority: priority ?? this.priority,
        deadline: deadline ?? this.deadline,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
