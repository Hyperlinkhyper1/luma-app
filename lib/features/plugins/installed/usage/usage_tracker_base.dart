import 'package:flutter/foundation.dart';

/// Snapshot of the foreground app at one poll. Two records with the same
/// [processName] belong to the same app session even if [windowTitle] differs
/// (e.g. you switched tabs in Chrome) — the repository only treats a new
/// [processName] as a session boundary.
@immutable
class UsageAppInfo {
  const UsageAppInfo({
    required this.appName,
    required this.processName,
    this.windowTitle,
  });

  /// Human-friendly label, e.g. "Google Chrome". Derived from the executable
  /// file name when no friendlier source is available.
  final String appName;

  /// Lower-cased executable / package identifier, e.g. "chrome.exe". Used as
  /// the stable identity for grouping sessions.
  final String processName;

  /// Active window title when known — null on platforms / sessions where it
  /// can't be read. Captured for context, not used for grouping.
  final String? windowTitle;

  @override
  bool operator ==(Object other) =>
      other is UsageAppInfo &&
      other.processName == processName &&
      other.windowTitle == windowTitle;

  @override
  int get hashCode => Object.hash(processName, windowTitle);
}