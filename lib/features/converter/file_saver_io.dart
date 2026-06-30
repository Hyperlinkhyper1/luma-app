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
}) async {
  final path = await FilePicker.saveFile(
    dialogTitle: 'Save converted image',
    fileName: suggestedName,
    type: FileType.custom,
    allowedExtensions: extensions,
  );
  if (path == null) return SaveResult.cancelled();

  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);
  return SaveResult(saved: true, location: path, summary: 'Saved to $path');
}
