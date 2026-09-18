import 'package:flutter/widgets.dart';

import 'ai_benchmark_repository.dart';

/// Exposes the shared [AiBenchmarkRepository] to the widget tree.
class AiBenchmarkScope extends InheritedNotifier<AiBenchmarkRepository> {
  const AiBenchmarkScope({
    super.key,
    required AiBenchmarkRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static AiBenchmarkRepository of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AiBenchmarkScope>();
    assert(scope != null, 'AiBenchmarkScope was not found in the widget tree');
    return scope!.notifier!;
  }
}
