/// Cross-platform facade for the foreground-app tracker.
///
/// Always re-exports [UsageAppInfo] (the cross-platform snapshot record). The
/// [UsageTracker] implementation itself comes from one of:
///   * `usage_tracker_windows.dart` — real `win32`-backed implementation
///     on Windows desktop.
///   * `usage_tracker_stub.dart`    — no-op stub on every other target (macOS,
///     Linux, Android, iOS, web) that exposes `supported = false` so the page
///     can show a friendly "not available here" message.
library;

export 'usage_tracker_base.dart';
export 'usage_tracker_stub.dart'
    if (dart.library.io) 'usage_tracker_windows.dart';