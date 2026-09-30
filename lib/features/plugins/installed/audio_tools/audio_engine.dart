/// Cross-platform facade over the real-time microphone → EQ → output path.
///
/// On dart:io platforms this drives WASAPI through the win32 package (and
/// reports unsupported anywhere but Windows); on the web it resolves to a
/// stub.
library;

export 'audio_engine_stub.dart' if (dart.library.io) 'audio_engine_io.dart';
