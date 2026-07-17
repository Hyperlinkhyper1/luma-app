/// Cross-platform facade for stashing rendered preview audio in a temp file
/// so the audio player can stream it from disk.
///
/// Resolves to the dart:io implementation on desktop, or a stub that reports
/// "unavailable" on the web (where the audio editor can't run anyway, since
/// it needs ffmpeg).
library;

export 'preview_file_stub.dart' if (dart.library.io) 'preview_file_io.dart';
