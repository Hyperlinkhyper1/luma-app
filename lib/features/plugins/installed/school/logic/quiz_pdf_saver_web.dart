import 'dart:typed_data';
import '../../../../converter/file_saver.dart';

Future<String?> saveQuizPdf(Uint8List bytes) async {
  final result = await saveConvertedFile(
    bytes: bytes,
    suggestedName: 'oefentoets.pdf',
    mimeType: 'application/pdf',
    extensions: ['pdf'],
  );
  if (!result.saved) return null;
  return result.location ?? 'oefentoets.pdf';
}
