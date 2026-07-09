import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/router.dart';
import '../../notes/providers/notes_provider.dart';
import '../../tasks/models/task.dart';
import '../../tasks/providers/tasks_provider.dart';
import '../providers/projects_provider.dart';

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);
    final project = projectsAsync.valueOrNull
        ?.where((p) => p.id == projectId)
        .firstOrNull;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(project?.name ?? 'Project'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.notes_rounded), text: 'Notes'),
              Tab(icon: Icon(Icons.checklist_rounded), text: 'Tasks'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _NotesTab(projectId: projectId),
            _TasksTab(projectId: projectId),
          ],
        ),
      ),
    );
  }
}

// ── Notes tab ─────────────────────────────────────────────────────────────────

class _NotesTab extends ConsumerWidget {
  const _NotesTab({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider(projectId));

    return notesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (notes) {
        if (notes.isEmpty) {
          return _EmptyTab(
            icon: Icons.notes_rounded,
            label: 'No notes in this project yet.',
            actionLabel: 'View all notes',
            onAction: () => context.push(
              '$kRouteNotes?projectId=$projectId',
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: notes.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final note = notes[i];
            return ListTile(
              title: Text(
                note.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: note.summary.isNotEmpty
                  ? Text(
                      note.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/notes/${note.id}'),
            );
          },
        );
      },
    );
  }
}

// ── Tasks tab ─────────────────────────────────────────────────────────────────

class _TasksTab extends ConsumerWidget {
  const _TasksTab({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider(projectId));

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (tasks) {
        if (tasks.isEmpty) {
          return _EmptyTab(
            icon: Icons.checklist_rounded,
            label: 'No tasks in this project yet.',
            actionLabel: 'View all tasks',
            onAction: () => context.push(
              '$kRouteTasks?projectId=$projectId',
            ),
          );
        }
        final open = tasks.where((t) => !t.completed).toList();
        final done = tasks.where((t) => t.completed).toList();

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            if (open.isNotEmpty) ...[
              _SectionHeader(
                  label: 'Open (${open.length})',
                  onViewAll: () => context
                      .push('$kRouteTasks?projectId=$projectId')),
              ...open.map((t) => _TaskRow(task: t, ref: ref)),
            ],
            if (done.isNotEmpty) ...[
              _SectionHeader(label: 'Completed (${done.length})'),
              ...done.map((t) => _TaskRow(task: t, ref: ref)),
            ],
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.onViewAll});

  final String label;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          if (onViewAll != null)
            TextButton(
              onPressed: onViewAll,
              child: const Text('View all'),
            ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.ref});

  final Task task;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: task.completed,
      onChanged: (_) => ref
          .read(tasksProvider(task.projectId).notifier)
          .toggle(task.id),
      title: Text(
        task.title,
        style: task.completed
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: Theme.of(context).colorScheme.outline,
              )
            : null,
      ),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}

// ── Empty tab ─────────────────────────────────────────────────────────────────

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({
    required this.icon,
    required this.label,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String label;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
