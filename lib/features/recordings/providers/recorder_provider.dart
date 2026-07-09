import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recording.dart';
import '../services/recording_service.dart';

// ── Enum ───────────────────────────────────────────────────────────────────

enum RecorderState { idle, recording, paused, uploading }

// ── State ──────────────────────────────────────────────────────────────────

class RecorderStateData {
  const RecorderStateData({
    this.recorderState = RecorderState.idle,
    this.elapsedMs = 0,
    this.amplitude = 0.0,
    this.error,
    this.lastRecording,
  });

  final RecorderState recorderState;
  final int elapsedMs;
  final double amplitude; // 0.0–1.0
  final String? error;
  final Recording? lastRecording;

  bool get isRecording => recorderState == RecorderState.recording;
  bool get isPaused => recorderState == RecorderState.paused;
  bool get isUploading => recorderState == RecorderState.uploading;
  bool get isIdle => recorderState == RecorderState.idle;

  RecorderStateData copyWith({
    RecorderState? recorderState,
    int? elapsedMs,
    double? amplitude,
    String? error,
    Recording? lastRecording,
  }) =>
      RecorderStateData(
        recorderState: recorderState ?? this.recorderState,
        elapsedMs: elapsedMs ?? this.elapsedMs,
        amplitude: amplitude ?? this.amplitude,
        error: error,
        lastRecording: lastRecording ?? this.lastRecording,
      );
}

// ── Notifier ───────────────────────────────────────────────────────────────

class RecorderNotifier extends Notifier<RecorderStateData> {
  late RecordingService _service;
  Timer? _timer;
  StreamSubscription<dynamic>? _amplitudeSub;
  int _elapsedMs = 0;

  // Cap: warn at 8 min (surfaced in UI via elapsedMs), stop at 10 min
  static const _maxMs = 10 * 60 * 1000;

  @override
  RecorderStateData build() {
    _service = RecordingService();
    ref.onDispose(() {
      _cleanup();
      _service.dispose();
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
    } catch (e) {
      state = RecorderStateData(error: e.toString());
    }
  }

  Future<void> pause() async {
    if (!state.isRecording) return;
    _timer?.cancel();
    await _service.pause();
    state = state.copyWith(recorderState: RecorderState.paused, amplitude: 0);
  }

  Future<void> resume() async {
    if (!state.isPaused) return;
    await _service.resume();
    _startTimer();
    state = state.copyWith(recorderState: RecorderState.recording);
  }

  Future<Recording?> stop({String? projectId}) async {
    _cleanup();
    state = state.copyWith(recorderState: RecorderState.uploading, amplitude: 0);

    try {
      final recording = await _service.stopAndUpload(projectId: projectId);
      state = RecorderStateData(lastRecording: recording);
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
      // Normalize dBFS (typically -160 to 0) to 0.0–1.0
      final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
      state = state.copyWith(amplitude: normalized);
    });
  }

  void _cleanup() {
    _timer?.cancel();
    _timer = null;
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
  }
}

final recorderProvider =
    NotifierProvider<RecorderNotifier, RecorderStateData>(RecorderNotifier.new);
