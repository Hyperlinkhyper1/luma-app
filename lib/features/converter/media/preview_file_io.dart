import 'dart:io';
import 'dart:typed_data';

/// Writes [bytes] to a fresh temp file and returns its path, or null if the
/// platform has no writable temp directory.
Future<String?> writePreviewFile(Uint8List bytes, String extension) async {
  final dir = await Directory.systemTemp.createTemp('luma_audio_preview_');
  final file =
      File('${dir.path}${Platform.pathSeparator}preview.$extension');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

/// Best-effort removal of a file previously produced by [writePreviewFile]
/// (deletes its scratch directory).
Future<void> deletePreviewFile(String path) async {
  try {
    await File(path).parent.delete(recursive: true);
  } catch (_) {}
}
