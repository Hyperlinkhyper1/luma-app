import 'package:flutter/widgets.dart';

import 'ai_usage_repository.dart';

/// Exposes the shared [AiUsageRepository] to the widget tree.
class AiUsageScope extends InheritedNotifier<AiUsageRepository> {
  const AiUsageScope({
    super.key,
    required AiUsageRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static AiUsageRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AiUsageScope>();
    assert(scope != null, 'AiUsageScope was not found in the widget tree');
    return scope!.notifier!;
  }
}
