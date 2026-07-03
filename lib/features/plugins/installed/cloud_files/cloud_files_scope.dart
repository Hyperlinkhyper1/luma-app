import 'package:flutter/widgets.dart';

import 'cloud_files_controller.dart';

/// Exposes the app-wide [CloudFilesController] to the widget tree.
class CloudFilesScope extends InheritedNotifier<CloudFilesController> {
  const CloudFilesScope({
    super.key,
    required CloudFilesController controller,
    required super.child,
  }) : super(notifier: controller);

  static CloudFilesController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CloudFilesScope>();
    assert(scope != null, 'CloudFilesScope was not found in the widget tree');
    return scope!.notifier!;
  }
}
