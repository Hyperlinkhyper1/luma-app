import 'dart:typed_data';

/// Web stub: there is no temp filesystem, so previews are unavailable.
Future<String?> writePreviewFile(Uint8List bytes, String extension) async =>
    null;

Future<void> deletePreviewFile(String path) async {}
