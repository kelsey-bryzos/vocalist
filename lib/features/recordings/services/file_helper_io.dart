import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Native implementation — uses dart:io for local file access.
Future<String> tempFilePath(int ts) async {
  final dir = await getTemporaryDirectory();
  return '${dir.path}/vocalist_$ts.m4a';
}

Future<List<int>?> readFileBytes(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  return file.readAsBytes();
}

Future<void> deleteFile(String path) async {
  try {
    await File(path).delete();
  } catch (_) {}
}
