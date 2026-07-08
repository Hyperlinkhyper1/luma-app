import 'usage_tracker_base.dart';

/// Placeholder tracker for platforms we haven't implemented yet (macOS,
/// Linux, Android, iOS, web). Always reports [supported] = false so the page
/// can show a friendly message instead of silently doing nothing.
class UsageTracker {
  UsageTracker._();

  static bool get supported => false;

  /// Always null on unsupported platforms — callers should check [supported]
  /// first and skip the call.
  static UsageAppInfo? current() => null;
}