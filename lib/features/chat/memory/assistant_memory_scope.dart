import 'package:flutter/widgets.dart';

import 'assistant_memory_repository.dart';

/// Provides the assistant's memory, profile and chat preferences.
class AssistantMemoryScope
    extends InheritedNotifier<AssistantMemoryRepository> {
  const AssistantMemoryScope({
    super.key,
    required AssistantMemoryRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static AssistantMemoryRepository of(BuildContext context) {
    final repository = maybeOf(context);
    assert(repository != null, 'AssistantMemoryScope was not found');
    return repository!;
  }

  /// Null outside the app shell, e.g. in a widget test of a chat bubble.
  static AssistantMemoryRepository? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AssistantMemoryScope>()
      ?.notifier;
}
