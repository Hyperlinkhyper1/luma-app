import 'package:flutter/widgets.dart';

import 'plugin_repository.dart';

/// Provides the shared [PluginRepository] to the app.
class PluginScope extends InheritedWidget {
  const PluginScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final PluginRepository repository;

  static PluginRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PluginScope>();
    assert(scope != null, 'PluginScope was not found in the widget tree');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(PluginScope oldWidget) =>
      oldWidget.repository != repository;
}
