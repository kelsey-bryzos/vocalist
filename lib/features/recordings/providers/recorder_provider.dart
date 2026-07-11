import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recording.dart';
import '../services/live_speech_service.dart';
import '../services/pipeline_service.dart';
import '../services/recording_service.dart';

// ── Enum ───────────────────────────────────────────────────────────────────

enum RecorderState { idle, recording, paused, uploading, done }

// ── State ──────────────────────────────────────────────────────────────────

class RecorderStateData {
  const RecorderStateData({
    this.recorderState = RecorderState.idle,
    this.elapsedMs = 0,
    this.amplitude = 0.0,
    this.liveText = '',
    this.error,
    this.lastRecording,
  });

  final RecorderState recorderState;
  final int elapsedMs;
  final double amplitude;
  final String liveText;   // words spoken so far, shown live during recording
  final String? error;
  final Recording? lastRecording;

  bool get isRecording => recorderState == RecorderState.recording;
  bool get isPaused => recorderState == RecorderState.paused;
  bool get isUploading => recorderState == RecorderState.uploading;
  bool get isIdle => recorderState == RecorderState.idle;
  bool get isDone => recorderState == RecorderState.done;

  RecorderStateData copyWith({
    RecorderState? recorderState,
    int? elapsedMs,
    double? amplitude,
    String? liveText,
    String? error,
    Recording? lastRecording,
  }) =>
      RecorderStateData(
        recorderState: recorderState ?? this.recorderState,
        elapsedMs: elapsedMs ?? this.elapsedMs,
        amplitude: amplitude ?? this.amplitude,
        liveText: liveText ?? this.liveText,
        error: error,
        lastRecording: lastRecording ?? this.lastRecording,
      );
}

// ── Notifier ───────────────────────────────────────────────────────────────

class RecorderNotifier extends Notifier<RecorderStateData> {
  late RecordingService _service;
  final _pipeline = PipelineService();
  final _speech = LiveSpeechService();
  Timer? _timer;
  StreamSubscription<dynamic>? _amplitudeSub;
  StreamSubscription<String>? _speechSub;
  int _elapsedMs = 0;

  // Cap: warn at 8 min, stop at 10 min
  static const _maxMs = 10 * 60 * 1000;

  @override
  RecorderStateData build() {
    _service = RecordingService();
    ref.onDispose(() {
      _cleanup();
      _service.dispose();
      _speech.stop();
    });
    return const RecorderStateData();
  }

  Future<void> start({String? projectId}) async {
    state = const RecorderStateData(recorderState: RecorderState.recording);
    _elapsedMs = 0;

    try {
      await _service.start();
      _startTimer();
      _subscribeAmplitude();
      _startLiveSpeech();
    } catch (e) {
      state = RecorderStateData(error: e.toString());
    }
  }

  Future<void> pause() async {
    if (!state.isRecording) return;
    _timer?.cancel();
    _speech.stop();
    await _service.pause();
    state = state.copyWith(recorderState: RecorderState.paused, amplitude: 0);
  }

  Future<void> resume() async {
    if (!state.isPaused) return;
    await _service.resume();
    _startTimer();
    _startLiveSpeech();
    state = state.copyWith(recorderState: RecorderState.recording);
  }

  Future<Recording?> stop({String? projectId}) async {
    _cleanup();
    state = state.copyWith(recorderState: RecorderState.uploading, amplitude: 0);

    try {
      final recording = await _service.stopAndUpload(projectId: projectId);
      state = RecorderStateData(
        recorderState: RecorderState.done,
        lastRecording: recording,
        elapsedMs: _elapsedMs,
      );
      // Fire-and-forget — edge function runs async, Realtime delivers updates
      _pipeline.process(recording.id);
      return recording;
    } catch (e) {
      state = RecorderStateData(error: e.toString());
      return null;
    }
  }

  Future<void> cancel() async {
    _cleanup();
    await _service.cancel();
    state = const RecorderStateData();
  }

  void reset() {
    state = const RecorderStateData();
  }

  // ── private ────────────────────────────────────────────────────────────

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _elapsedMs += 100;

      if (_elapsedMs >= _maxMs) {
        stop();
        return;
      }

      state = state.copyWith(elapsedMs: _elapsedMs);
    });
  }

  void _subscribeAmplitude() {
    _amplitudeSub = _service.amplitudeStream.listen((amp) {
      final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
      state = state.copyWith(amplitude: normalized);
    });
  }

  void _startLiveSpeech() {
    _speechSub?.cancel();
    _speechSub = _speech.start().listen((text) {
      // Append new words to existing liveText
      final existing = state.liveText;
      final updated = existing.isEmpty ? text : '$existing $text';
      state = state.copyWith(liveText: updated);
    });
  }

  void _cleanup() {
    _timer?.cancel();
    _timer = null;
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _speechSub?.cancel();
    _speechSub = null;
    _speech.stop();
  }
}

final recorderProvider =
    NotifierProvider<RecorderNotifier, RecorderStateData>(RecorderNotifier.new);
