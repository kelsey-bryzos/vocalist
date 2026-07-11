/// Stub for non-web platforms. No-op — live speech not available on native yet.
class SpeechRecognitionImpl {
  SpeechRecognitionImpl({
    required void Function(String) onResult,
    required void Function(String) onError,
  });

  void start() {}
  void stop() {}
}
