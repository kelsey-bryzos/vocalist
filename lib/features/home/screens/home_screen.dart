import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/router.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notes/models/note.dart';
import '../../notes/repositories/notes_repository.dart';
import '../../projects/models/project.dart';
import '../../projects/repositories/projects_repository.dart';
import '../../recordings/models/recording.dart';
import '../../recordings/providers/recorder_provider.dart';
import '../../recordings/repositories/recordings_repository.dart';
import '../../recordings/widgets/audio_player_sheet.dart';
import '../../recordings/widgets/processing_status_chip.dart';
import '../../recordings/widgets/recording_sheet.dart';
import '../../tasks/models/task.dart';
import '../../tasks/repositories/tasks_repository.dart';

// ── Dashboard data providers ─────────────────────────────────────────────────

final _dashRecordingsProvider = FutureProvider<List<Recording>>((ref) {
  ref.watch(recorderProvider.select((s) => s.lastRecording));
  return RecordingsRepository().fetchAll();
});

final _dashNotesProvider = FutureProvider<List<Note>>(
  (_) => NotesRepository().fetchAll(),
);

final _dashTasksProvider = FutureProvider<List<Task>>(
  (_) => TasksRepository().fetchAll(),
);

final _dashProjectsProvider = FutureProvider<List<Project>>(
  (_) => ProjectsRepository().fetchAll(),
);

// ── Screen ───────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final recordings = ref.watch(_dashRecordingsProvider);
    final notes = ref.watch(_dashNotesProvider);
    final tasks = ref.watch(_dashTasksProvider);
    final projects = ref.watch(_dashProjectsProvider);

    // Tasks due within 10 days (not completed)
    final now = DateTime.now();
    final cutoff = now.add(const Duration(days: 10));
    final upcomingTasks = tasks.valueOrNull
        ?.where((t) =>
            !t.completed &&
            t.deadline != null &&
            t.deadline!.isBefore(cutoff))
        .toList()
      ?..sort((a, b) => a.deadline!.compareTo(b.deadline!));

    final recentNotes = (notes.valueOrNull ?? []).take(3).toList();
    final recentRecordings = (recordings.valueOrNull ?? []).take(5).toList();
    final allProjects = projects.valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'VOCALIST',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search',
            onPressed: () => context.push(kRouteSearch),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          // ── Record Now banner ─────────────────────────────────────────────
          _RecordNowBanner(theme: theme, cs: cs),
          const SizedBox(height: 24),

          // ── Upcoming Tasks ────────────────────────────────────────────────
          if (tasks.isLoading)
            _SectionSkeleton(label: 'UPCOMING TASKS')
          else if (upcomingTasks != null && upcomingTasks.isNotEmpty) ...[
            _SectionHeader(
              label: 'UPCOMING TASKS',
              onSeeAll: () => context.go(kRouteTasks),
            ),
            const SizedBox(height: 8),
            ...upcomingTasks.map((t) => _UpcomingTaskTile(task: t, theme: theme, cs: cs)),
            const SizedBox(height: 24),
          ],

          // ── Recent Notes ──────────────────────────────────────────────────
          if (notes.isLoading)
            _SectionSkeleton(label: 'RECENT NOTES')
          else if (recentNotes.isNotEmpty) ...[
            _SectionHeader(
              label: 'RECENT NOTES',
              onSeeAll: () => context.go(kRouteNotes),
            ),
            const SizedBox(height: 8),
            ...recentNotes.map((n) => _NoteCard(note: n, theme: theme, cs: cs)),
            const SizedBox(height: 24),
          ],

          // ── Projects ──────────────────────────────────────────────────────
          if (projects.isLoading)
            _SectionSkeleton(label: 'PROJECTS')
          else if (allProjects.isNotEmpty) ...[
            _SectionHeader(
              label: 'PROJECTS',
              onSeeAll: () => context.go(kRouteProjects),
            ),
            const SizedBox(height: 8),
            _ProjectsRow(projects: allProjects, cs: cs, theme: theme),
            const SizedBox(height: 24),
          ],

          // ── Recordings Library ────────────────────────────────────────────
          if (recordings.isLoading)
            _SectionSkeleton(label: 'RECORDINGS')
          else if (recentRecordings.isNotEmpty) ...[
            _SectionHeader(
              label: 'RECORDINGS',
              onSeeAll: null, // all recordings are shown here
            ),
            const SizedBox(height: 8),
            ...recentRecordings.map(
              (r) => _RecordingTile(recording: r, theme: theme, cs: cs),
            ),
          ] else
            _EmptyState(email: user?.email, cs: cs, theme: theme),
        ],
      ),
    );
  }
}

// ── Record Now Banner ─────────────────────────────────────────────────────────

class _RecordNowBanner extends StatelessWidget {
  const _RecordNowBanner({required this.theme, required this.cs});
  final ThemeData theme;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => RecordingSheet.show(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'START RECORDING',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to capture your next observation',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.7), size: 28),
          ],
        ),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.onSeeAll});
  final String label;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: Text(
              'SEE ALL',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.4),
                letterSpacing: 1.2,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Section Skeleton (loading state) ─────────────────────────────────────────

class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                )),
        const SizedBox(height: 8),
        Container(
          height: 72,
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Upcoming Task Tile ────────────────────────────────────────────────────────

class _UpcomingTaskTile extends StatelessWidget {
  const _UpcomingTaskTile(
      {required this.task, required this.theme, required this.cs});
  final Task task;
  final ThemeData theme;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final deadline = task.deadline!;
    final daysLeft = deadline.difference(now).inDays;
    final isOverdue = deadline.isBefore(now);
    final deadlineColor = isOverdue
        ? cs.error
        : daysLeft <= 2
            ? Colors.orange
            : cs.onSurface.withValues(alpha: 0.5);

    final priorityColor = switch (task.priority) {
      TaskPriority.urgent => const Color(0xFFEF4444),
      TaskPriority.high => const Color(0xFFF97316),
      TaskPriority.medium => const Color(0xFFF59E0B),
      TaskPriority.low => const Color(0xFF22C55E),
      TaskPriority.none => Colors.transparent,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: priorityColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Text(
          task.title,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          isOverdue
              ? 'Overdue'
              : daysLeft == 0
                  ? 'Due today'
                  : daysLeft == 1
                      ? 'Due tomorrow'
                      : 'Due in $daysLeft days',
          style: theme.textTheme.bodySmall?.copyWith(color: deadlineColor),
        ),
        trailing: Text(
          DateFormat('MMM d').format(deadline),
          style: theme.textTheme.bodySmall?.copyWith(color: deadlineColor),
        ),
        onTap: () => context.go(kRouteTasks),
      ),
    );
  }
}

// ── Note Card ─────────────────────────────────────────────────────────────────

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.theme, required this.cs});
  final Note note;
  final ThemeData theme;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final ago = _timeAgo(note.updatedAt);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            context.push(kRouteNoteDetail.replaceFirst(':id', note.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    ago,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
              if (note.summary.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  note.summary,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (note.sections.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${note.sections.length} section${note.sections.length == 1 ? '' : 's'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }
}

// ── Projects Row ──────────────────────────────────────────────────────────────

class _ProjectsRow extends StatelessWidget {
  const _ProjectsRow(
      {required this.projects, required this.cs, required this.theme});
  final List<Project> projects;
  final ColorScheme cs;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: projects.length,
        separatorBuilder: (context, i) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final p = projects[i];
          return GestureDetector(
            onTap: () => context.push(
              kRouteProjectDetail.replaceFirst(':id', p.id),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cs.onSurface.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_rounded, color: cs.primary, size: 20),
                  const SizedBox(height: 4),
                  Text(
                    p.name,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Recording Tile ────────────────────────────────────────────────────────────

class _RecordingTile extends StatelessWidget {
  const _RecordingTile(
      {required this.recording, required this.theme, required this.cs});
  final Recording recording;
  final ThemeData theme;
  final ColorScheme cs;

  Future<void> _handleTap(BuildContext context) async {
    if (recording.status == RecordingStatus.done) {
      // Check if there's a note — if yes, open it; otherwise open audio player
      final result = await supabase
          .from('notes')
          .select('id')
          .eq('recording_id', recording.id)
          .maybeSingle();
      if (!context.mounted) return;
      if (result != null) {
        context.push(kRouteNoteDetail.replaceFirst(':id', result['id'] as String));
      } else {
        AudioPlayerSheet.show(context, recording);
      }
    } else {
      // For any finished recording, allow audio playback
      AudioPlayerSheet.show(context, recording);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (recording.status) {
      RecordingStatus.done => cs.primary,
      RecordingStatus.error => cs.error,
      RecordingStatus.processing ||
      RecordingStatus.transcribing =>
        cs.secondary,
      _ => cs.onSurface.withValues(alpha: 0.4),
    };

    final statusIcon = switch (recording.status) {
      RecordingStatus.done => Icons.check_circle_outline_rounded,
      RecordingStatus.error => Icons.error_outline_rounded,
      RecordingStatus.processing ||
      RecordingStatus.transcribing =>
        Icons.autorenew_rounded,
      _ => Icons.graphic_eq_rounded,
    };

    final dur = recording.durationMs;
    final durLabel = dur != null
        ? '${dur ~/ 60000}m ${(dur ~/ 1000) % 60}s'
        : '';
    final ago = _timeAgo(recording.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        onTap: () => _handleTap(context),
        leading: Icon(statusIcon, color: statusColor),
        title: Text(
          durLabel.isNotEmpty ? '$durLabel recording' : 'Recording',
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          ago,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
        ),
        trailing: recording.status == RecordingStatus.done
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_outline_rounded,
                      color: cs.primary.withValues(alpha: 0.7), size: 20),
                  const SizedBox(width: 6),
                  _StatusBadge(status: recording.status, cs: cs, theme: theme),
                ],
              )
            : ProcessingStatusChip(recordingId: recording.id),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ── Status Badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(
      {required this.status, required this.cs, required this.theme});
  final RecordingStatus status;
  final ColorScheme cs;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      RecordingStatus.done => ('Done', cs.primary),
      RecordingStatus.error => ('Error', cs.error),
      RecordingStatus.processing => ('Processing', cs.secondary),
      RecordingStatus.transcribing => ('Transcribing', cs.secondary),
      RecordingStatus.transcribed => ('Transcribed', cs.tertiary),
      RecordingStatus.uploaded => ('Uploaded', cs.tertiary),
      RecordingStatus.uploading =>
        ('Uploading', cs.onSurface.withValues(alpha: 0.5)),
    };
    return Chip(
      label: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      backgroundColor: color.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {required this.email, required this.cs, required this.theme});
  final String? email;
  final ColorScheme cs;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic_none_rounded,
                size: 80, color: cs.onSurface.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            Text(
              'Ready to roll',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Hit the banner above to capture\nyour first site observation.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            if (email != null) ...[
              const SizedBox(height: 24),
              Text(
                email!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.3),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
