import 'package:flutter/widgets.dart';

import 'ai_workbench_repository.dart';

/// Exposes the local Markdown and agent store to the AI Usage plugin tabs.
class AiWorkbenchScope extends InheritedNotifier<AiWorkbenchRepository> {
  const AiWorkbenchScope({
    super.key,
    required AiWorkbenchRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static AiWorkbenchRepository of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AiWorkbenchScope>();
    assert(scope != null, 'AiWorkbenchScope was not found in the widget tree');
    return scope!.notifier!;
  }
}
