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

  /// For callers that only log into the repository and so neither need to
  /// rebuild on its changes nor fail when it is missing (a widget test).
  static AiUsageRepository? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AiUsageScope>()?.notifier;
}
