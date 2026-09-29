import 'package:flutter/widgets.dart';

import 'sync_service.dart';

/// Exposes the app-wide [SyncService], mirroring the other feature scopes.
class SyncScope extends InheritedWidget {
  const SyncScope({super.key, required this.service, required super.child});

  final SyncService service;

  static SyncService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SyncScope>();
    assert(scope != null, 'SyncScope not found in widget tree');
    return scope!.service;
  }

  /// Like [of], but null where no scope is above [context] — for widgets
  /// that also run standalone, such as in widget tests.
  static SyncService? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SyncScope>()?.service;

  @override
  bool updateShouldNotify(SyncScope oldWidget) => service != oldWidget.service;
}
