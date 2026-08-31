import 'package:flutter/widgets.dart';

import 'device_health_repository.dart';

/// Exposes the shared [DeviceHealthRepository] to the widget tree.
class DeviceHealthScope extends InheritedNotifier<DeviceHealthRepository> {
  const DeviceHealthScope({
    super.key,
    required DeviceHealthRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static DeviceHealthRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<DeviceHealthScope>();
    assert(scope != null, 'DeviceHealthScope was not found in the widget tree');
    return scope!.notifier!;
  }
}
