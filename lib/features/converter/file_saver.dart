/// Cross-platform facade for persisting a converted image.
///
/// Resolves to the desktop/mobile implementation (native save dialog) or the
/// web implementation (browser download) at compile time.
library;

export 'save_result.dart';
export 'file_saver_stub.dart'
    if (dart.library.io) 'file_saver_io.dart'
    if (dart.library.js_interop) 'file_saver_web.dart';
