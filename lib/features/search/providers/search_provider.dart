import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../notes/models/note.dart';
import '../../tasks/models/task.dart';

// ── Filter enum ───────────────────────────────────────────────────────────────

enum SearchFilter {
  all,
  notes,
  tasks;

  String get label => switch (this) {
        SearchFilter.all => 'All',
        SearchFilter.notes => 'Notes',
        SearchFilter.tasks => 'Tasks',
      };
}

// ── Result sealed types ───────────────────────────────────────────────────────

sealed class SearchResult {}

class NoteResult extends SearchResult {
  NoteResult(this.note);
  final Note note;
}

class TaskResult extends SearchResult {
  TaskResult(this.task);
  final Task task;
}

// ── State providers ───────────────────────────────────────────────────────────

final searchQueryProvider = StateProvider<String>((_) => '');

final searchFilterProvider =
    StateProvider<SearchFilter>((_) => SearchFilter.all);

// ── Results provider ──────────────────────────────────────────────────────────

final searchResultsProvider =
    FutureProvider.autoDispose<List<SearchResult>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final filter = ref.watch(searchFilterProvider);

  if (query.isEmpty) return [];

  final results = <SearchResult>[];

  // Search notes
  if (filter == SearchFilter.all || filter == SearchFilter.notes) {
    final notesData = await supabase
        .from('notes')
        .select()
        .or('title.ilike.%$query%,summary.ilike.%$query%')
        .order('updated_at', ascending: false)
        .limit(30);

    for (final row in notesData as List) {
      results.add(NoteResult(Note.fromJson(row as Map<String, dynamic>)));
    }
  }

  // Search tasks
  if (filter == SearchFilter.all || filter == SearchFilter.tasks) {
    final tasksData = await supabase
        .from('tasks')
        .select()
        .ilike('title', '%$query%')
        .order('updated_at', ascending: false)
        .limit(30);

    for (final row in tasksData as List) {
      results.add(TaskResult(Task.fromJson(row as Map<String, dynamic>)));
    }
  }

  // If "all", interleave: alternate note/task by updated_at
  if (filter == SearchFilter.all) {
    results.sort((a, b) {
      final aDate = switch (a) {
        NoteResult(:final note) => note.updatedAt,
        TaskResult(:final task) => task.updatedAt,
      };
      final bDate = switch (b) {
        NoteResult(:final note) => note.updatedAt,
        TaskResult(:final task) => task.updatedAt,
      };
      return bDate.compareTo(aDate);
    });
  }

  return results;
});
