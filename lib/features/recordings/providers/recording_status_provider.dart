import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../models/recording.dart';
import '../repositories/recordings_repository.dart';

/// Watches a single recording's status via Supabase Realtime.
/// Emits the latest [Recording] every time the row is updated.
class RecordingStatusNotifier
    extends FamilyStreamNotifier<Recording?, String> {
  @override
  Stream<Recording?> build(String arg) {
    return _statusStream(arg);
  }

  Stream<Recording?> _statusStream(String recordingId) {
    final controller = StreamController<Recording?>();

    // Seed with current DB value immediately
    RecordingsRepository().fetchById(recordingId).then((r) {
      if (!controller.isClosed) controller.add(r);
    });

    final channel = supabase
        .channel('recording:$recordingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'recordings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: recordingId,
          ),
          callback: (payload) {
            final updated = Recording.fromJson(payload.newRecord);
            if (!controller.isClosed) controller.add(updated);
          },
        )
        .subscribe();

    ref.onDispose(() {
      channel.unsubscribe();
      controller.close();
    });

    return controller.stream;
  }
}

/// Family provider — one notifier per recording ID.
final recordingStatusProvider =
    StreamNotifierProvider.family<RecordingStatusNotifier, Recording?, String>(
  RecordingStatusNotifier.new,
);
