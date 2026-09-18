import 'dart:typed_data';

Future<String?> saveQuizPdf(Uint8List bytes) => Future.error(
  UnsupportedError('PDF opslaan wordt op dit apparaat niet ondersteund.'),
);
