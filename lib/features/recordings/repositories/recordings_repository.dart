import '../../../core/supabase/supabase_client.dart';
import '../models/recording.dart';

class RecordingsRepository {
  static const _table = 'recordings';

  Future<List<Recording>> fetchAll() async {
    final data = await supabase
        .from(_table)
        .select()
        .order('created_at', ascending: false);
    return (data as List)
        .map((j) => Recording.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Recording> create({
    required String storagePath,
    String? projectId,
  }) async {
    final data = await supabase
        .from(_table)
        .insert({
          'storage_path': storagePath,
          'project_id': projectId,
        })
        .select()
        .single();
    return Recording.fromJson(data);
  }

  Future<Recording> updateStatus(
    String id,
    RecordingStatus status, {
    int? durationMs,
    String? errorMessage,
  }) async {
    final data = await supabase
        .from(_table)
        .update({
          'status': status.name,
          'duration_ms': durationMs,
          'error_message': errorMessage,
        })
        .eq('id', id)
        .select()
        .single();
    return Recording.fromJson(data);
  }

  Future<void> delete(String id) async {
    await supabase.from(_table).delete().eq('id', id);
  }
}
