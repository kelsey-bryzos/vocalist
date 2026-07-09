import 'package:flutter/foundation.dart';

@immutable
class Transcript {
  const Transcript({
    required this.id,
    required this.userId,
    required this.recordingId,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String recordingId;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Transcript.fromJson(Map<String, dynamic> json) => Transcript(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        recordingId: json['recording_id'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}
