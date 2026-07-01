// Thin, web-safe wrapper around the desktop window (title bar, drag, caption
// buttons). On the web the stub is used and every call is a no-op, so the
// custom title bar simply renders without window controls.
//
// Mirrors the `file_saver_stub` / `file_saver_io` conditional-import pattern
// used elsewhere in the app so `dart:io`/`window_manager` never reach a web
// build.
export 'window_controls_stub.dart'
    if (dart.library.io) 'window_controls_io.dart';
