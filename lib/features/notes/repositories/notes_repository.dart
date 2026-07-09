import '../../../core/supabase/supabase_client.dart';
import '../models/note.dart';

class NotesRepository {
  static const _table = 'notes';

  Future<List<Note>> fetchAll({String? projectId}) async {
    var query = supabase.from(_table).select();
    if (projectId != null) {
      query = query.eq('project_id', projectId);
    }
    final data = await query.order('created_at', ascending: false);
    return (data as List)
        .map((j) => Note.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Note> fetchById(String id) async {
    final data =
        await supabase.from(_table).select().eq('id', id).single();
    return Note.fromJson(data);
  }

  Future<Note> update(
    String id, {
    String? title,
    String? summary,
    List<NoteSection>? sections,
    String? projectId,
  }) async {
    final data = await supabase
        .from(_table)
        .update({
          'title': title,
          'summary': summary,
          'sections': sections?.map((s) => s.toJson()).toList(),
          'project_id': projectId,
        })
        .eq('id', id)
        .select()
        .single();
    return Note.fromJson(data);
  }

  Future<void> delete(String id) async {
    await supabase.from(_table).delete().eq('id', id);
  }
}
