import 'dart:convert';

import 'package:flutter/foundation.dart';

@immutable
class NoteSection {
  const NoteSection({required this.heading, required this.bullets});

  final String heading;
  final List<String> bullets;

  factory NoteSection.fromJson(Map<String, dynamic> json) => NoteSection(
        heading: json['heading'] as String,
        bullets: List<String>.from(json['bullets'] as List),
      );

  Map<String, dynamic> toJson() => {
        'heading': heading,
        'bullets': bullets,
      };
}

/// Sections may arrive from Supabase as a JSON string or a pre-decoded List.
List<NoteSection> _parseSections(dynamic raw) {
  final list = raw is String ? (jsonDecode(raw) as List) : (raw as List);
  return list.map((s) => NoteSection.fromJson(s as Map<String, dynamic>)).toList();
}

@immutable
class Note {
  const Note({
    required this.id,
    required this.userId,
    required this.title,
    required this.summary,
    required this.sections,
    required this.createdAt,
    required this.updatedAt,
    this.recordingId,
    this.projectId,
  });

  final String id;
  final String userId;
  final String? recordingId;
  final String? projectId;
  final String title;
  final String summary;
  final List<NoteSection> sections;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        recordingId: json['recording_id'] as String?,
        projectId: json['project_id'] as String?,
        title: json['title'] as String,
        summary: json['summary'] as String,
        sections: _parseSections(json['sections']),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'recording_id': recordingId,
        'project_id': projectId,
        'title': title,
        'summary': summary,
        'sections': sections.map((s) => s.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Note copyWith({
    String? title,
    String? summary,
    List<NoteSection>? sections,
    String? projectId,
  }) =>
      Note(
        id: id,
        userId: userId,
        recordingId: recordingId,
        projectId: projectId ?? this.projectId,
        title: title ?? this.title,
        summary: summary ?? this.summary,
        sections: sections ?? this.sections,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
