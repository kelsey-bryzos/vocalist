/// Stub for web — no local file I/O needed.
Future<String> tempFilePath(int ts) async => 'vocalist_$ts.webm';

Future<List<int>?> readFileBytes(String path) async => null;

Future<void> deleteFile(String path) async {}
