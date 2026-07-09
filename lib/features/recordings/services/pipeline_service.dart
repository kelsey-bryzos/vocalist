import '../../../core/supabase/supabase_client.dart';

/// Triggers the process-recording edge function for a given recording ID.
/// The edge function runs async — status updates come via Realtime.
class PipelineService {
  Future<void> process(String recordingId) async {
    await supabase.functions.invoke(
      'process-recording',
      body: {'recording_id': recordingId},
    );
  }
}
