import 'dart:typed_data';

import 'save_result.dart';

/// Fallback used when neither dart:io nor dart:js_interop is available.
Future<SaveResult> saveConvertedFile({
  required Uint8List bytes,
  required String suggestedName,
  required String mimeType,
  required List<String> extensions,
}) {
  throw UnsupportedError('Saving files is not supported on this platform.');
}
