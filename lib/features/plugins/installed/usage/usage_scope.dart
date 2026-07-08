import 'package:flutter/widgets.dart';

import 'usage_repository.dart';

/// Exposes the app-wide [UsageRepository] to the widget tree.
class UsageScope extends InheritedNotifier<UsageRepository> {
  const UsageScope({
    super.key,
    required UsageRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static UsageRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<UsageScope>();
    assert(scope != null, 'UsageScope was not found in the widget tree');
    return scope!.notifier!;
  }
}
