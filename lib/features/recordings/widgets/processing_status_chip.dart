import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recording.dart';
import '../providers/recording_status_provider.dart';

/// Shows a small status chip for a single recording's pipeline progress.
/// Auto-dismisses (removes itself) once status == done.
class ProcessingStatusChip extends ConsumerWidget {
  const ProcessingStatusChip({super.key, required this.recordingId});

  final String recordingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRecording = ref.watch(recordingStatusProvider(recordingId));

    return asyncRecording.when(
      loading: () => _chip(context, Icons.hourglass_empty, 'Preparing…', null),
      error: (e, _) =>
          _chip(context, Icons.error_outline, 'Error', Colors.red),
      data: (recording) {
        if (recording == null) return const SizedBox.shrink();
        return switch (recording.status) {
          RecordingStatus.uploading =>
            _chip(context, Icons.upload, 'Uploading…', null),
          RecordingStatus.uploaded =>
            _chip(context, Icons.cloud_done, 'Uploaded', null),
          RecordingStatus.transcribing =>
            _chip(context, Icons.transcribe, 'Transcribing…', null),
          RecordingStatus.transcribed =>
            _chip(context, Icons.text_snippet, 'Transcribed', null),
          RecordingStatus.processing =>
            _chip(context, Icons.auto_awesome, 'Structuring…', null),
          RecordingStatus.done => const SizedBox.shrink(),
          RecordingStatus.error => _chip(
              context,
              Icons.error_outline,
              recording.errorMessage ?? 'Error',
              Colors.red,
            ),
        };
      },
    );
  }

  Widget _chip(
    BuildContext context,
    IconData icon,
    String label,
    Color? color,
  ) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;
    return Chip(
      avatar: Icon(icon, size: 14, color: effectiveColor),
      label: Text(label, style: TextStyle(fontSize: 12, color: effectiveColor)),
      backgroundColor:
          effectiveColor.withAlpha(20),
      side: BorderSide(color: effectiveColor.withAlpha(60)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }
}
