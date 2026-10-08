import 'dart:typed_data';

import '../../l10n/current_l.dart';
import 'save_result.dart';

/// Fallback used when neither dart:io nor dart:js_interop is available.
Future<SaveResult> saveConvertedFile({
  required Uint8List bytes,
  required String suggestedName,
  required String mimeType,
  required List<String> extensions,
  String? dialogTitle,
}) {
  throw UnsupportedError(currentL.converterSaveUnsupported);
}

Future<SaveResult> replaceOriginalFile({
  required Uint8List bytes,
  required String originalPath,
  required String extension,
}) {
  throw UnsupportedError(currentL.converterReplaceUnsupported);
}
