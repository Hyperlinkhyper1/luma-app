import 'package:flutter/widgets.dart';

import 'chat_repository.dart';

/// Exposes the app-wide [ChatRepository] (end-to-end encrypted person-to-
/// person chat) to the widget tree. Named `SecureChatScope` to avoid
/// colliding with the existing AI-assistant `ChatScope`
/// (lib/features/chat/chat_scope.dart) — a different feature entirely.
class SecureChatScope extends InheritedNotifier<ChatRepository> {
  const SecureChatScope({
    super.key,
    required ChatRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static ChatRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SecureChatScope>();
    assert(scope != null, 'SecureChatScope was not found in the widget tree');
    return scope!.notifier!;
  }
}
