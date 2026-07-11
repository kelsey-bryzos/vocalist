import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transcript.dart';
import '../repositories/transcripts_repository.dart';

/// Fetches the transcript for a given recording ID. Null = not yet available.
final transcriptProvider =
    FutureProvider.family<Transcript?, String>((ref, recordingId) async {
  return TranscriptsRepository().fetchByRecordingId(recordingId);
});
