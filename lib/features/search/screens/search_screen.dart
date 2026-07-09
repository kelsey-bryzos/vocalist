import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/router.dart';
import '../../notes/models/note.dart';
import '../../tasks/models/task.dart';
import '../providers/search_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(searchQueryProvider.notifier).state = value.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final filter = ref.watch(searchFilterProvider);
    final results = ref.watch(searchResultsProvider);
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onQueryChanged,
          decoration: InputDecoration(
            hintText: 'Search notes and tasks…',
            border: InputBorder.none,
            hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.4)),
          ),
          style: theme.textTheme.bodyLarge,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                ref.read(searchQueryProvider.notifier).state = '';
              },
            ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(current: filter),
          const Divider(height: 1),
          Expanded(
            child: query.isEmpty
                ? _emptyPrompt(cs)
                : results.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (data) => data.isEmpty
                        ? _noResults(theme, cs, query)
                        : _ResultsList(results: data),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyPrompt(ColorScheme cs) {
    return Center(
      child: Icon(Icons.search_rounded,
          size: 72, color: cs.onSurface.withValues(alpha: 0.15)),
    );
  }

  Widget _noResults(ThemeData theme, ColorScheme cs, String query) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded,
              size: 56, color: cs.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Text(
            'No results for "$query"',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────────

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.current});
  final SearchFilter current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: SearchFilter.values.map((f) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(f.label),
              selected: current == f,
              onSelected: (_) =>
                  ref.read(searchFilterProvider.notifier).state = f,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Results list ──────────────────────────────────────────────────────────────

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.results});
  final List<SearchResult> results;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: results.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = results[i];
        return switch (r) {
          NoteResult(:final note) => _NoteResultTile(note: note),
          TaskResult(:final task) => _TaskResultTile(task: task),
        };
      },
    );
  }
}

// ── Note result tile ──────────────────────────────────────────────────────────

class _NoteResultTile extends StatelessWidget {
  const _NoteResultTile({required this.note});
  final Note note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListTile(
      leading: Icon(Icons.article_outlined, color: cs.primary),
      title: Text(
        note.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        note.summary,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: cs.onSurface.withValues(alpha: 0.55)),
      ),
      trailing: _TypeChip(label: 'Note', color: cs.primary),
      onTap: () => context
          .push(kRouteNoteDetail.replaceFirst(':id', note.id)),
    );
  }
}

// ── Task result tile ──────────────────────────────────────────────────────────

class _TaskResultTile extends StatelessWidget {
  const _TaskResultTile({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListTile(
      leading: Icon(
        task.completed
            ? Icons.check_circle_rounded
            : Icons.radio_button_unchecked_rounded,
        color: task.completed
            ? cs.primary.withValues(alpha: 0.5)
            : cs.secondary,
      ),
      title: Text(
        task.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          decoration: task.completed ? TextDecoration.lineThrough : null,
          color: task.completed
              ? cs.onSurface.withValues(alpha: 0.4)
              : null,
        ),
      ),
      subtitle: task.priority != TaskPriority.none
          ? Text(
              task.priority.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            )
          : null,
      trailing: _TypeChip(label: 'Task', color: cs.secondary),
      onTap: () => context.push(kRouteTasks),
    );
  }
}

// ── Small type label chip ─────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
