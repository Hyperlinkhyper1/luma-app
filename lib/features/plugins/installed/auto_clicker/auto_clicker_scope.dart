import 'package:flutter/widgets.dart';

import 'auto_clicker_repository.dart';

/// Exposes the app-wide [AutoClickerRepository] to the widget tree.
class AutoClickerScope extends InheritedNotifier<AutoClickerRepository> {
  const AutoClickerScope({
    super.key,
    required AutoClickerRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static AutoClickerRepository of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AutoClickerScope>();
    assert(scope != null, 'AutoClickerScope was not found in the widget tree');
    return scope!.notifier!;
  }
}
