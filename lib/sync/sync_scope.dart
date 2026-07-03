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

  @override
  bool updateShouldNotify(SyncScope oldWidget) => service != oldWidget.service;
}
