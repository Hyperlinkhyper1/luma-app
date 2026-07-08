import 'package:flutter/widgets.dart';

import 'storage_guard.dart';

/// Exposes the app-wide [StorageGuardService], mirroring the other feature
/// scopes (see `SyncScope`).
class StorageGuardScope extends InheritedWidget {
  const StorageGuardScope({super.key, required this.service, required super.child});

  final StorageGuardService service;

  static StorageGuardService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StorageGuardScope>();
    assert(scope != null, 'StorageGuardScope not found in widget tree');
    return scope!.service;
  }

  @override
  bool updateShouldNotify(StorageGuardScope oldWidget) =>
      service != oldWidget.service;
}
