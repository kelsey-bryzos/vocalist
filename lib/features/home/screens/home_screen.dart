import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
import '../../recordings/widgets/recording_sheet.dart';
import '../../tasks/models/task.dart';
import '../../tasks/repositories/tasks_repository.dart';

// ── Dashboard data providers ─────────────────────────────────────────────────
//
// We use supabase.auth.currentUser (synchronous) as the fast path — if the
// session is already restored from storage, we fetch immediately.  We also
// watch authStateProvider so we re-fetch when sign-in/sign-out events fire.

// Realtime invalidation counter — incremented when recordings/notes/tasks change
final _realtimeTickProvider = StateProvider<int>((ref) => 0);

final _dashRecordingsProvider = FutureProvider<List<Recording>>((ref) async {
  ref.watch(authStateProvider);
  ref.watch(recorderProvider.select((s) => s.lastRecording));
  ref.watch(_realtimeTickProvider);
  if (supabase.auth.currentUser == null) return [];
  return RecordingsRepository().fetchAll();
});

final _dashNotesProvider = FutureProvider<List<Note>>((ref) async {
  ref.watch(authStateProvider);
  ref.watch(_realtimeTickProvider);
  if (supabase.auth.currentUser == null) return [];
  return NotesRepository().fetchAll();
});

final _dashTasksProvider = FutureProvider<List<Task>>((ref) async {
  ref.watch(authStateProvider);
  ref.watch(_realtimeTickProvider);
  if (supabase.auth.currentUser == null) return [];
  return TasksRepository().fetchAll();
});

final _dashProjectsProvider = FutureProvider<List<Project>>((ref) async {
  ref.watch(authStateProvider);
  if (supabase.auth.currentUser == null) return [];
  return ProjectsRepository().fetchAll();
});

// Subscribes to Realtime on recordings/notes/tasks and increments the tick.
// Mounted once at the HomeScreen level.
class _RealtimeWatcher extends ConsumerStatefulWidget {
  const _RealtimeWatcher({required this.child});
  final Widget child;

  @override
  ConsumerState<_RealtimeWatcher> createState() => _RealtimeWatcherState();
}

class _RealtimeWatcherState extends ConsumerState<_RealtimeWatcher> {
  dynamic _channel;

  @override
  void initState() {
    super.initState();
    _channel = supabase
        .channel('dashboard-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'recordings',
          callback: (_) =>
              ref.read(_realtimeTickProvider.notifier).state++,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notes',
          callback: (_) =>
              ref.read(_realtimeTickProvider.notifier).state++,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tasks',
          callback: (_) =>
              ref.read(_realtimeTickProvider.notifier).state++,
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

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

    final now = DateTime.now();
    final cutoff = now.add(const Duration(days: 10));

    final upcomingTasks = (tasks.valueOrNull ?? [])
        .where((t) =>
            !t.completed && t.deadline != null && t.deadline!.isBefore(cutoff))
        .toList()
      ..sort((a, b) => a.deadline!.compareTo(b.deadline!));
    final topTasks = upcomingTasks.take(3).toList();

    final recentNotes = (notes.valueOrNull ?? []).take(3).toList();
    final recentRecordings = (recordings.valueOrNull ?? []).take(3).toList();
    final allProjects = projects.valueOrNull ?? [];

    return _RealtimeWatcher(
      child: Scaffold(
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
          const SizedBox(height: 20),

          // ── Top row: Tasks + Notes tiles ──────────────────────────────────
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _DashTile(
                    label: 'UPCOMING TASKS',
                    icon: Icons.task_alt_rounded,
                    count: upcomingTasks.length,
                    onSeeAll: () => context.go(kRouteTasks),
                    loading: tasks.isLoading,
                    child: topTasks.isEmpty
                        ? const _TileEmpty(text: 'No tasks due soon')
                        : Column(
                            children: topTasks
                                .map((t) => _CompactTaskRow(
                                    task: t, cs: cs, theme: theme))
                                .toList(),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DashTile(
                    label: 'RECENT NOTES',
                    icon: Icons.notes_rounded,
                    count: notes.valueOrNull?.length,
                    onSeeAll: () => context.go(kRouteNotes),
                    loading: notes.isLoading,
                    child: recentNotes.isEmpty
                        ? const _TileEmpty(text: 'No notes yet')
                        : Column(
                            children: recentNotes
                                .map((n) => _CompactNoteRow(
                                    note: n, cs: cs, theme: theme))
                                .toList(),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Bottom row: Projects + Recordings tiles ───────────────────────
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _DashTile(
                    label: 'PROJECTS',
                    icon: Icons.folder_rounded,
                    count: allProjects.length,
                    onSeeAll: () => context.go(kRouteProjects),
                    loading: projects.isLoading,
                    child: allProjects.isEmpty
                        ? const _TileEmpty(text: 'No projects')
                        : Column(
                            children: allProjects
                                .take(4)
                                .map((p) => _CompactProjectRow(
                                    project: p, cs: cs, theme: theme))
                                .toList(),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DashTile(
                    label: 'RECORDINGS',
                    icon: Icons.mic_rounded,
                    count: recordings.valueOrNull?.length,
                    onSeeAll: null,
                    loading: recordings.isLoading,
                    child: recentRecordings.isEmpty
                        ? const _TileEmpty(text: 'No recordings yet')
                        : Column(
                            children: recentRecordings
                                .map((r) => _CompactRecordingRow(
                                    recording: r, cs: cs, theme: theme))
                                .toList(),
                          ),
                  ),
                ),
              ],
            ),
          ),

          // ── Empty state ───────────────────────────────────────────────────
          if (!tasks.isLoading &&
              !notes.isLoading &&
              !recordings.isLoading &&
              upcomingTasks.isEmpty &&
              recentNotes.isEmpty &&
              recentRecordings.isEmpty)
            _EmptyState(email: user?.email, cs: cs, theme: theme),
        ],
      ),
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

// ── Dashboard Tile Container ──────────────────────────────────────────────────

class _DashTile extends StatelessWidget {
  const _DashTile({
    required this.label,
    required this.icon,
    required this.child,
    required this.loading,
    this.count,
    this.onSeeAll,
  });

  final String label;
  final IconData icon;
  final Widget child;
  final bool loading;
  final int? count;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tile header
          Row(
            children: [
              Icon(icon, size: 14, color: cs.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    fontSize: 10,
                  ),
                ),
              ),
              if (count != null && count! > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 10),

          // Content
          if (loading) _TileSkeleton(cs: cs) else child,

          // See all link
          if (onSeeAll != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onSeeAll,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'SEE ALL',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.35),
                      fontSize: 9,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded,
                      size: 12,
                      color: cs.onSurface.withValues(alpha: 0.35)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TileSkeleton extends StatelessWidget {
  const _TileSkeleton({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            height: 12,
            width: double.infinity,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }
}

class _TileEmpty extends StatelessWidget {
  const _TileEmpty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.3),
              fontStyle: FontStyle.italic,
            ),
      ),
    );
  }
}

// ── Compact row widgets ───────────────────────────────────────────────────────

class _CompactTaskRow extends StatelessWidget {
  const _CompactTaskRow(
      {required this.task, required this.cs, required this.theme});
  final Task task;
  final ColorScheme cs;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final deadline = task.deadline!;
    final isOverdue = deadline.isBefore(now);
    final daysLeft = deadline.difference(now).inDays;
    final deadlineColor = isOverdue
        ? cs.error
        : daysLeft <= 1
            ? Colors.orange
            : cs.onSurface.withValues(alpha: 0.45);

    final priorityColor = switch (task.priority) {
      TaskPriority.urgent => const Color(0xFFEF4444),
      TaskPriority.high => const Color(0xFFF97316),
      TaskPriority.medium => const Color(0xFFF59E0B),
      TaskPriority.low => const Color(0xFF22C55E),
      TaskPriority.none => Colors.transparent,
    };

    return GestureDetector(
      onTap: () => context.go(kRouteTasks),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 32,
              decoration: BoxDecoration(
                color: priorityColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isOverdue
                        ? 'Overdue'
                        : daysLeft == 0
                            ? 'Due today'
                            : DateFormat('MMM d').format(deadline),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: deadlineColor, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactNoteRow extends StatelessWidget {
  const _CompactNoteRow(
      {required this.note, required this.cs, required this.theme});
  final Note note;
  final ColorScheme cs;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final diff = DateTime.now().difference(note.updatedAt);
    final ago = diff.inDays >= 1
        ? DateFormat('MMM d').format(note.updatedAt)
        : diff.inHours >= 1
            ? '${diff.inHours}h ago'
            : '${diff.inMinutes}m ago';

    return GestureDetector(
      onTap: () =>
          context.push(kRouteNoteDetail.replaceFirst(':id', note.id)),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(Icons.article_outlined,
                size: 14, color: cs.onSurface.withValues(alpha: 0.35)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                note.title,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              ago,
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.35),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactProjectRow extends StatelessWidget {
  const _CompactProjectRow(
      {required this.project, required this.cs, required this.theme});
  final Project project;
  final ColorScheme cs;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(
        kRouteProjectDetail.replaceFirst(':id', project.id),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(Icons.folder_outlined,
                size: 14, color: cs.primary.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                project.name,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 14, color: cs.onSurface.withValues(alpha: 0.25)),
          ],
        ),
      ),
    );
  }
}

class _CompactRecordingRow extends StatelessWidget {
  const _CompactRecordingRow(
      {required this.recording, required this.cs, required this.theme});
  final Recording recording;
  final ColorScheme cs;
  final ThemeData theme;

  Future<void> _handleTap(BuildContext context) async {
    if (recording.status == RecordingStatus.done) {
      final result = await supabase
          .from('notes')
          .select('id')
          .eq('recording_id', recording.id)
          .maybeSingle();
      if (!context.mounted) return;
      if (result != null) {
        context.push(
            kRouteNoteDetail.replaceFirst(':id', result['id'] as String));
      } else {
        AudioPlayerSheet.show(context, recording);
      }
    } else {
      AudioPlayerSheet.show(context, recording);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDone = recording.status == RecordingStatus.done;
    final isError = recording.status == RecordingStatus.error;
    final iconColor = isError
        ? cs.error
        : isDone
            ? cs.primary
            : cs.onSurface.withValues(alpha: 0.4);

    final dur = recording.durationMs;
    final durLabel = dur != null
        ? '${dur ~/ 60000}:${((dur ~/ 1000) % 60).toString().padLeft(2, '0')}'
        : '--:--';

    final diff = DateTime.now().difference(recording.createdAt);
    final ago = diff.inDays >= 1
        ? DateFormat('MMM d').format(recording.createdAt)
        : diff.inHours >= 1
            ? '${diff.inHours}h ago'
            : '${diff.inMinutes}m ago';

    return GestureDetector(
      onTap: () => _handleTap(context),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(
              isDone
                  ? Icons.play_circle_outline_rounded
                  : Icons.graphic_eq_rounded,
              size: 14,
              color: iconColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                durLabel,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              ago,
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.35),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
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
