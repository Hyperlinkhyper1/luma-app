import 'package:flutter/widgets.dart';

import 'data/chat_repository.dart';

/// Provides the shared [ChatRepository] to the AI Assistant feature.
class ChatScope extends InheritedWidget {
  const ChatScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final ChatRepository repository;

  static ChatRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ChatScope>();
    assert(scope != null, 'ChatScope was not found in the widget tree');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(ChatScope oldWidget) =>
      oldWidget.repository != repository;
}
