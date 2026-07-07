/// Cross-platform facade over the mouse-click simulator.
///
/// On dart:io desktop platforms this drives the real Win32 `SendInput` API;
/// elsewhere (web) it resolves to a stub that reports "unsupported".
library;

export 'clicker_engine_stub.dart'
    if (dart.library.io) 'clicker_engine_io.dart';
