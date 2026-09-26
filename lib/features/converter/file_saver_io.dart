import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'save_result.dart';

/// Desktop/mobile implementation: opens a native "Save As" dialog and writes
/// the bytes to the chosen location.
Future<SaveResult> saveConvertedFile({
  required Uint8List bytes,
  required String suggestedName,
  required String mimeType,
  required List<String> extensions,
  String? dialogTitle,
}) async {
  final path = await FilePicker.saveFile(
    dialogTitle: dialogTitle ?? 'Save converted image',
    fileName: suggestedName,
    type: FileType.custom,
    allowedExtensions: extensions,
  );
  if (path == null) return SaveResult.cancelled();

  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);
  return SaveResult(saved: true, location: path, summary: 'Saved to $path');
}

/// Overwrites the picked source file with [bytes]. When the output format
/// differs from the original's extension, the result takes the new extension
/// next to it and the original is deleted.
Future<SaveResult> replaceOriginalFile({
  required Uint8List bytes,
  required String originalPath,
  required String extension,
}) async {
  final dot = originalPath.lastIndexOf('.');
  final sep = originalPath.lastIndexOf(RegExp(r'[\/]'));
  final stem = dot > sep + 1 ? originalPath.substring(0, dot) : originalPath;
  final target = '$stem.$extension';
  await File(target).writeAsBytes(bytes, flush: true);
  if (target.toLowerCase() != originalPath.toLowerCase()) {
    final original = File(originalPath);
    if (await original.exists()) await original.delete();
  }
  return SaveResult(
      saved: true, location: target, summary: 'Replaced original: $target');
}
