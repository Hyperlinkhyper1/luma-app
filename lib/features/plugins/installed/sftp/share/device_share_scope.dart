import 'package:flutter/widgets.dart';

import 'device_share_repository.dart';

/// Exposes the shared-folder mirror down the tree.
///
/// The repository is created in `main.dart` rather than by the plugin page,
/// so files keep arriving from the user's other devices while they are
/// somewhere else in the app — a folder that only syncs while you are looking
/// at it isn't a synced folder. Null until it has been built, and while the
/// plan is below Nova.
class DeviceShareScope extends InheritedNotifier<DeviceShareRepository> {
  const DeviceShareScope({
    super.key,
    required DeviceShareRepository? repository,
    required super.child,
  }) : super(notifier: repository);

  static DeviceShareRepository? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DeviceShareScope>()?.notifier;
}
