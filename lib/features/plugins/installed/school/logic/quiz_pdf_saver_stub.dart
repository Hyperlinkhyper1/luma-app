import 'dart:typed_data';

import '../../../../../l10n/current_l.dart';

Future<String?> saveQuizPdf(Uint8List bytes) => Future.error(
  UnsupportedError(currentL.schoolPdfSaveUnsupported),
);
