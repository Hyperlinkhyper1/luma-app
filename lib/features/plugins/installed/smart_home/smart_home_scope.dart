import 'package:flutter/widgets.dart';

import 'smart_home_repository.dart';

class SmartHomeScope extends InheritedNotifier<SmartHomeRepository> {
  const SmartHomeScope({
    super.key,
    required SmartHomeRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static SmartHomeRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SmartHomeScope>();
    assert(scope != null, 'SmartHomeScope was not found in the widget tree');
    return scope!.notifier!;
  }
}
