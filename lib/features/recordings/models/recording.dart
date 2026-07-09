import 'package:flutter/foundation.dart';

enum RecordingStatus {
  uploading,
  uploaded,
  transcribing,
  transcribed,
  processing,
  done,
  error;

  static RecordingStatus fromString(String value) =>
      RecordingStatus.values.firstWhere(
        (e) => e.name == value,
        orElse: () => RecordingStatus.error,
      );
}

@immutable
class Recording {
  const Recording({
    required this.id,
    required this.userId,
    required this.storagePath,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.projectId,
    this.durationMs,
    this.errorMessage,
  });

  final String id;
  final String userId;
  final String? projectId;
  final String storagePath;
  final int? durationMs;
  final RecordingStatus status;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Recording.fromJson(Map<String, dynamic> json) => Recording(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        projectId: json['project_id'] as String?,
        storagePath: json['storage_path'] as String,
        durationMs: json['duration_ms'] as int?,
        status: RecordingStatus.fromString(json['status'] as String),
        errorMessage: json['error_message'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'project_id': projectId,
        'storage_path': storagePath,
        'duration_ms': durationMs,
        'status': status.name,
        'error_message': errorMessage,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Recording copyWith({
    String? projectId,
    int? durationMs,
    RecordingStatus? status,
    String? errorMessage,
  }) =>
      Recording(
        id: id,
        userId: userId,
        projectId: projectId ?? this.projectId,
        storagePath: storagePath,
        durationMs: durationMs ?? this.durationMs,
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
