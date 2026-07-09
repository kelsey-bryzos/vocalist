import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../auth/services/auth_service.dart';
import '../../recordings/providers/recorder_provider.dart';
import '../../recordings/repositories/recordings_repository.dart';
import '../../recordings/models/recording.dart';
import '../../recordings/widgets/processing_status_chip.dart';
import '../../recordings/widgets/recording_sheet.dart';

final _recentRecordingsProvider = FutureProvider<List<Recording>>((ref) {
  // Re-fetch when a new recording completes
  ref.watch(recorderProvider.select((s) => s.lastRecording));
  return RecordingsRepository().fetchAll();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final recordings = ref.watch(_recentRecordingsProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocalist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: recordings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => list.isEmpty
            ? _emptyState(theme, cs, user?.email)
            : _recordingsList(list, theme, cs),
      ),
      floatingActionButton: FloatingActionButton.large(
        onPressed: () => RecordingSheet.show(context),
        tooltip: 'New recording',
        child: const Icon(Icons.mic_rounded, size: 36),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _emptyState(ThemeData theme, ColorScheme cs, String? email) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic_none_rounded, size: 80,
              color: cs.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            'No recordings yet',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the mic to capture your first thought.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
          if (email != null) ...[
            const SizedBox(height: 24),
            Text(
              email,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _recordingsList(
      List<Recording> list, ThemeData theme, ColorScheme cs) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _RecordingTile(recording: list[i]),
    );
  }
}

class _RecordingTile extends StatelessWidget {
  const _RecordingTile({required this.recording});

  final Recording recording;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(
          _iconFor(recording.status),
          color: _colorFor(recording.status, cs),
        ),
        title: Text(
          _label(recording),
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          _subtitle(recording),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
        ),
        trailing: recording.status == RecordingStatus.done
            ? _StatusChip(status: recording.status)
            : ProcessingStatusChip(recordingId: recording.id),
      ),
    );
  }

  IconData _iconFor(RecordingStatus status) {
    return switch (status) {
      RecordingStatus.done => Icons.check_circle_outline_rounded,
      RecordingStatus.error => Icons.error_outline_rounded,
      RecordingStatus.processing ||
      RecordingStatus.transcribing =>
        Icons.autorenew_rounded,
      _ => Icons.graphic_eq_rounded,
    };
  }

  Color _colorFor(RecordingStatus status, ColorScheme cs) {
    return switch (status) {
      RecordingStatus.done => cs.primary,
      RecordingStatus.error => cs.error,
      RecordingStatus.processing ||
      RecordingStatus.transcribing =>
        cs.secondary,
      _ => cs.onSurface.withValues(alpha: 0.4),
    };
  }

  String _label(Recording r) {
    final d = r.durationMs;
    if (d != null) {
      final s = d ~/ 1000;
      final m = s ~/ 60;
      final sec = s % 60;
      return '${m}m ${sec}s recording';
    }
    return 'Recording';
  }

  String _subtitle(Recording r) {
    final diff = DateTime.now().difference(r.createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final RecordingStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (label, color) = switch (status) {
      RecordingStatus.done => ('Done', cs.primary),
      RecordingStatus.error => ('Error', cs.error),
      RecordingStatus.processing => ('Processing', cs.secondary),
      RecordingStatus.transcribing => ('Transcribing', cs.secondary),
      RecordingStatus.transcribed => ('Transcribed', cs.tertiary),
      RecordingStatus.uploaded => ('Uploaded', cs.tertiary),
      RecordingStatus.uploading => ('Uploading', cs.onSurface.withValues(alpha: 0.5)),
    };
    return Chip(
      label: Text(label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      backgroundColor: color.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }
}
