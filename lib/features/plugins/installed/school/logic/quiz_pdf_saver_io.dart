import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<String?> saveQuizPdf(Uint8List bytes) async {
  if (Platform.isAndroid || Platform.isIOS) {
    final path = await FilePicker.saveFile(
      dialogTitle: 'Oefentoets opslaan als PDF',
      fileName: 'oefentoets.pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      bytes: bytes,
    );
    return path;
  }
  final picked = await FilePicker.saveFile(
    dialogTitle: 'Oefentoets opslaan als PDF',
    fileName: 'oefentoets.pdf',
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );
  if (picked == null) return null;
  var path = picked;
  if (!path.toLowerCase().endsWith('.pdf')) path = '$path.pdf';
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);
  return path;
}
