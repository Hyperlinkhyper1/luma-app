import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'save_result.dart';

/// Web implementation: wraps the bytes in a Blob and triggers a browser
/// download via a temporary anchor element.
Future<SaveResult> saveConvertedFile({
  required Uint8List bytes,
  required String suggestedName,
  required String mimeType,
  required List<String> extensions,
}) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = suggestedName
    ..style.display = 'none';
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);

  return SaveResult(saved: true, summary: 'Downloaded $suggestedName');
}
