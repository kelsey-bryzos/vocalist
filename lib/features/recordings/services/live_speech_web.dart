import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Web implementation of live speech using the browser's SpeechRecognition API.
class SpeechRecognitionImpl {
  SpeechRecognitionImpl({
    required this.onResult,
    required this.onError,
  });

  final void Function(String text) onResult;
  final void Function(String error) onError;

  web.SpeechRecognition? _recognition;

  void start() {
    try {
      final recognition = web.SpeechRecognition();
      recognition.continuous = true;
      recognition.interimResults = true;
      recognition.lang = 'en-US';

      recognition.onresult = (web.SpeechRecognitionEvent event) {
        final results = event.results;
        final length = results.length;

        for (var i = event.resultIndex; i < length; i++) {
          final result = results.item(i);
          // item() can return null at runtime even if typed non-nullable
          // ignore: unnecessary_null_comparison
          if (result == null) continue;
          if (result.isFinal) {
            final alt = result.item(0);
            // ignore: unnecessary_null_comparison
            final transcript = alt == null ? '' : alt.transcript.trim();
            if (transcript.isNotEmpty) onResult(transcript);
          }
        }
      }.toJS;

      recognition.onerror = (web.SpeechRecognitionErrorEvent event) {
        onError(event.error);
      }.toJS;

      recognition.start();
      _recognition = recognition;
    } catch (e) {
      onError(e.toString());
    }
  }

  void stop() {
    _recognition?.stop();
    _recognition = null;
  }
}
