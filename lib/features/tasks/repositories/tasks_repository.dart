import '../../../core/supabase/supabase_client.dart';
import '../models/task.dart';

class TasksRepository {
  static const _table = 'tasks';

  Future<List<Task>> fetchAll({String? projectId}) async {
    var query = supabase.from(_table).select();
    if (projectId != null) {
      query = query.eq('project_id', projectId);
    }
    final data = await query.order('sort_order', ascending: true);
    return (data as List)
        .map((j) => Task.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Task> create({
    required String title,
    String? projectId,
    String? sourceNoteId,
    TaskPriority priority = TaskPriority.none,
    DateTime? deadline,
    int sortOrder = 0,
  }) async {
    final data = await supabase
        .from(_table)
        .insert({
          'title': title,
          'project_id': projectId,
          'source_note_id': sourceNoteId,
          'priority': priority.name,
          'deadline': deadline?.toIso8601String(),
          'sort_order': sortOrder,
        })
        .select()
        .single();
    return Task.fromJson(data);
  }

  Future<Task> update(
    String id, {
    String? title,
    bool? completed,
    TaskPriority? priority,
    DateTime? deadline,
    int? sortOrder,
    String? projectId,
  }) async {
    // Only include fields that were explicitly provided — never overwrite with null.
    final patch = <String, dynamic>{};
    if (title != null) patch['title'] = title;
    if (completed != null) patch['completed'] = completed;
    if (priority != null) patch['priority'] = priority.name;
    if (deadline != null) patch['deadline'] = deadline.toIso8601String();
    if (sortOrder != null) patch['sort_order'] = sortOrder;
    if (projectId != null) patch['project_id'] = projectId;

    final data = await supabase
        .from(_table)
        .update(patch)
        .eq('id', id)
        .select()
        .single();
    return Task.fromJson(data);
  }

  /// Batch-update sort_order for a reordered list.
  Future<void> reorder(List<Task> tasks) async {
    final updates = tasks
        .asMap()
        .entries
        .map((e) => {'id': e.value.id, 'sort_order': e.key})
        .toList();
    await supabase.from(_table).upsert(updates);
  }

  Future<void> delete(String id) async {
    await supabase.from(_table).delete().eq('id', id);
  }
}
