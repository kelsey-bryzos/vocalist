import 'dart:async';

import 'package:flutter/foundation.dart';

// Conditional import — web impl on web, stub on native
import 'live_speech_stub.dart'
    if (dart.library.html) 'live_speech_web.dart' as impl;

/// Streams partial transcription words live during recording.
/// On web: uses the browser's Web Speech API (SpeechRecognition).
/// On native: returns an empty stream (transcript comes post-upload via Groq).
class LiveSpeechService {
  StreamController<String>? _controller;
  impl.SpeechRecognitionImpl? _recognition;

  /// Returns a stream of partial words as the user speaks.
  Stream<String> start() {
    _controller?.close();
    _controller = StreamController<String>.broadcast();

    if (kIsWeb) {
      try {
        _recognition = impl.SpeechRecognitionImpl(
          onResult: (text) {
            if (!(_controller?.isClosed ?? true)) {
              _controller!.add(text);
            }
          },
          onError: (_) {}, // silently ignore — main recording still works
        );
        _recognition!.start();
      } catch (_) {
        // Browser doesn't support Web Speech API — degrade gracefully
      }
    }

    return _controller!.stream;
  }

  void stop() {
    _recognition?.stop();
    _recognition = null;
    _controller?.close();
    _controller = null;
  }
}
