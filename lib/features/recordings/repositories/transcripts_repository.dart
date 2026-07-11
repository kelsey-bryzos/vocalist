import '../../../core/supabase/supabase_client.dart';
import '../models/transcript.dart';

class TranscriptsRepository {
  static const _table = 'transcripts';

  Future<Transcript?> fetchByRecordingId(String recordingId) async {
    final data = await supabase
        .from(_table)
        .select()
        .eq('recording_id', recordingId)
        .maybeSingle();
    if (data == null) return null;
    return Transcript.fromJson(data);
  }
}
