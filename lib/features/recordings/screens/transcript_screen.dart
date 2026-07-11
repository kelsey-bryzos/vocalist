import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/recording.dart';
import '../providers/recording_status_provider.dart';
import '../providers/transcript_provider.dart';

class TranscriptScreen extends ConsumerWidget {
  const TranscriptScreen({super.key, required this.recordingId});

  final String recordingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final recordingAsync = ref.watch(recordingStatusProvider(recordingId));
    final transcriptAsync = ref.watch(transcriptProvider(recordingId));

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Transcript'),
        actions: [
          // Refresh button — re-fetch once processing completes
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(transcriptProvider(recordingId));
              ref.invalidate(recordingStatusProvider(recordingId));
            },
          ),
        ],
      ),
      body: recordingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (recording) {
          if (recording == null) {
            return const Center(child: Text('Recording not found.'));
          }
          return _body(context, theme, cs, recording, transcriptAsync);
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    Recording recording,
    AsyncValue transcriptAsync,
  ) {
    // Still processing — show status
    final isProcessing = recording.status == RecordingStatus.uploaded ||
        recording.status == RecordingStatus.transcribing ||
        recording.status == RecordingStatus.transcribed ||
        recording.status == RecordingStatus.processing;

    if (isProcessing) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              _statusLabel(recording.status),
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap refresh to check for updates.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
            ),
          ],
        ),
      );
    }

    if (recording.status == RecordingStatus.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: cs.error, size: 48),
            const SizedBox(height: 16),
            Text('Processing failed', style: theme.textTheme.titleMedium),
            if (recording.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                recording.errorMessage!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

    // Done — show transcript
    return transcriptAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading transcript: $e')),
      data: (transcript) {
        if (transcript == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.text_snippet_outlined,
                    size: 48, color: cs.onSurface.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text('No transcript yet.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic_rounded,
                        size: 14, color: cs.onPrimaryContainer),
                    const SizedBox(width: 6),
                    Text(
                      'Raw transcript — exactly as spoken',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: cs.onPrimaryContainer),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // The raw transcript text — run-on prose, no formatting
              Text(
                transcript.body,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.8,
                  color: cs.onSurface.withValues(alpha: 0.85),
                  letterSpacing: 0.1,
                ),
              ),

              const SizedBox(height: 32),

              // Timestamp footer
              Text(
                'Recorded ${_formatDate(transcript.createdAt)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurface.withValues(alpha: 0.4)),
              ),
            ],
          ),
        );
      },
    );
  }

  String _statusLabel(RecordingStatus status) {
    return switch (status) {
      RecordingStatus.uploaded => 'Waiting to transcribe…',
      RecordingStatus.transcribing => 'Transcribing…',
      RecordingStatus.transcribed => 'Organizing notes…',
      RecordingStatus.processing => 'Extracting tasks…',
      _ => 'Processing…',
    };
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
