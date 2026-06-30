/// Cross-platform facade for the in-app ffmpeg installer.
///
/// On dart:io desktop platforms this downloads and unpacks an ffmpeg binary;
/// elsewhere it resolves to a stub that reports "unsupported".
library;

export 'ffmpeg_installer_stub.dart'
    if (dart.library.io) 'ffmpeg_installer_io.dart';
