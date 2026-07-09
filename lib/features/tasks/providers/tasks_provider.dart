import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import '../repositories/tasks_repository.dart';

final tasksRepositoryProvider = Provider((_) => TasksRepository());

// Family: one notifier per project (null = all tasks across projects)
final tasksProvider =
    AsyncNotifierProviderFamily<TasksNotifier, List<Task>, String?>(
        TasksNotifier.new);

class TasksNotifier extends FamilyAsyncNotifier<List<Task>, String?> {
  TasksRepository get _repo => ref.read(tasksRepositoryProvider);

  @override
  Future<List<Task>> build(String? arg) => _repo.fetchAll(projectId: arg);

  Future<void> create({
    required String title,
    String? sourceNoteId,
    TaskPriority priority = TaskPriority.none,
    DateTime? deadline,
  }) async {
    final current = state.value ?? [];
    final task = await _repo.create(
      title: title,
      projectId: arg,
      sourceNoteId: sourceNoteId,
      priority: priority,
      deadline: deadline,
      sortOrder: current.length,
    );
    state = AsyncData([...current, task]);
  }

  Future<void> toggle(String id) async {
    final current = state.value ?? [];
    final task = current.firstWhere((t) => t.id == id);
    final updated = await _repo.update(id, completed: !task.completed);
    state = AsyncData(
      current.map((t) => t.id == id ? updated : t).toList(),
    );
  }

  Future<void> updateTask(
    String id, {
    String? title,
    TaskPriority? priority,
    DateTime? deadline,
  }) async {
    final current = state.value ?? [];
    final updated = await _repo.update(
      id,
      title: title,
      priority: priority,
      deadline: deadline,
    );
    state = AsyncData(
      current.map((t) => t.id == id ? updated : t).toList(),
    );
  }

  Future<void> reorder(List<Task> reordered) async {
    // Optimistic update
    state = AsyncData(reordered);
    await _repo.reorder(reordered);
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    state = AsyncData(
      (state.value ?? []).where((t) => t.id != id).toList(),
    );
  }
}
