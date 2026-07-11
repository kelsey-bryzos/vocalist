import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;

import '../../../core/supabase/supabase_client.dart';
import '../models/recording.dart';
import '../repositories/recordings_repository.dart';
import 'file_helper_stub.dart'
    if (dart.library.io) 'file_helper_io.dart' as fh;

class RecordingSession {
  RecordingSession({required this.startedAt, this.durationMs = 0});

  final DateTime startedAt;
  int durationMs;
  String? stoppedPath;
}

/// Wraps the [record] package: record → local/blob → upload → DB row.
class RecordingService {
  RecordingService() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;
  RecordingSession? _session;

  Stream<Amplitude> get amplitudeStream =>
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 80));

  Future<void> start() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) throw Exception('Microphone permission denied');

    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = await fh.tempFilePath(ts);

    await _recorder.start(
      RecordConfig(
        encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );
    _session = RecordingSession(startedAt: DateTime.now());
  }

  Future<void> pause() async {
    _tick();
    await _recorder.pause();
  }

  Future<void> resume() async {
    await _recorder.resume();
  }

  Future<Recording> stopAndUpload({String? projectId}) async {
    _tick();
    final session = _session;
    if (session == null) throw StateError('No active recording session');

    final stoppedPath = await _recorder.stop();
    _session = null;
    session.stoppedPath = stoppedPath;

    if (stoppedPath == null) {
      throw Exception('Recorder returned no file path after stop');
    }

    final storagePath = await _uploadFile(session);
    final recording = await RecordingsRepository().create(
      storagePath: storagePath,
      projectId: projectId,
      durationMs: session.durationMs,
    );

    if (!kIsWeb) await fh.deleteFile(stoppedPath);

    return recording;
  }

  Future<void> cancel() async {
    final path = await _recorder.stop();
    _session = null;
    if (!kIsWeb && path != null) await fh.deleteFile(path);
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }

  // ── private ────────────────────────────────────────────────────────────────

  void _tick() {
    final session = _session;
    if (session == null) return;
    session.durationMs =
        DateTime.now().difference(session.startedAt).inMilliseconds;
  }

  Future<String> _uploadFile(RecordingSession session) async {
    final userId = supabase.auth.currentUser!.id;
    final ts = session.startedAt.millisecondsSinceEpoch;
    final ext = kIsWeb ? 'webm' : 'm4a';
    final storagePath = '$userId/vocalist_$ts.$ext';
    final contentType = kIsWeb ? 'audio/webm' : 'audio/mp4';

    final Uint8List bytes;
    if (kIsWeb) {
      // On web, record returns a blob: URL. We must fetch it via the browser's
      // native fetch API — Dart's http package cannot access blob: URLs.
      final blobUrl = session.stoppedPath!;
      bytes = await _fetchBlobBytes(blobUrl);
    } else {
      final path = session.stoppedPath!;
      final raw = await fh.readFileBytes(path);
      if (raw == null) throw Exception('Could not read audio file from disk');
      bytes = raw is Uint8List ? raw : Uint8List.fromList(raw);
    }

    if (bytes.isEmpty) throw Exception('Audio file is empty — nothing to upload');

    await supabase.storage.from('audio').uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );

    return storagePath;
  }

  /// Fetches a blob: URL using the browser's native fetch, returning raw bytes.
  Future<Uint8List> _fetchBlobBytes(String blobUrl) async {
    final response = await web.window.fetch(blobUrl.toJS).toDart;
    if (!response.ok) {
      throw Exception('Failed to fetch blob: HTTP ${response.status}');
    }
    final arrayBuffer = await response.arrayBuffer().toDart;
    return Uint8List.view(arrayBuffer.toDart);
  }
}
