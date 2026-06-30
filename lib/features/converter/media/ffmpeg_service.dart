/// Cross-platform facade for invoking a bundled/installed ffmpeg binary.
///
/// Resolves to the desktop implementation (spawns a process) on dart:io
/// platforms, or a stub that reports "unavailable" on the web.
library;

export 'ffmpeg_service_stub.dart'
    if (dart.library.io) 'ffmpeg_service_io.dart';
