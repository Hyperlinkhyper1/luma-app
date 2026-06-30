import 'package:flutter/widgets.dart';

import 'settings_controller.dart';

/// Provides the app-wide [SettingsController] to the widget tree and rebuilds
/// dependents whenever a preference changes.
class SettingsScope extends InheritedNotifier<SettingsController> {
  const SettingsScope({
    super.key,
    required SettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  static SettingsController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'SettingsScope was not found in the widget tree');
    return scope!.notifier!;
  }
}
