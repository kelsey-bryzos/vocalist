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

  Future<Recording?> fetchById(String id) async {
    final data = await supabase
        .from(_table)
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return Recording.fromJson(data);
  }

  Future<Recording> create({
    required String storagePath,
    String? projectId,
    int? durationMs,
  }) async {
    final data = await supabase
        .from(_table)
        .insert({
          'storage_path': storagePath,
          // ignore: use_null_aware_elements
          if (projectId != null) 'project_id': projectId,
          // ignore: use_null_aware_elements
          if (durationMs != null) 'duration_ms': durationMs,
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
