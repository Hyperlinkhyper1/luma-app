import 'package:flutter/material.dart';

import '../../../app/widgets.dart';
import '../data/chat_repository.dart';
import 'chat_bubble.dart';

/// Auto-scrolling list of messages in a conversation.
class ChatMessageList extends StatefulWidget {
  const ChatMessageList({
    super.key,
    required this.stream,
    required this.onOpenQrPlugin,
  });

  final Stream<List<ChatMessageRecord>> stream;
  final VoidCallback onOpenQrPlugin;

  @override
  State<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList> {
  final _scrollController = ScrollController();
  int _lastCount = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeScrollToBottom(int count) {
    if (count == _lastCount) return;
    _lastCount = count;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamData<List<ChatMessageRecord>>(
      stream: widget.stream,
      builder: (context, messages) {
        _maybeScrollToBottom(messages.length);
        if (messages.isEmpty) {
          return const LumaEmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Say hello',
            subtitle: 'Ask the assistant anything about luma.',
          );
        }
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          itemCount: messages.length,
          itemBuilder: (context, i) => ChatBubble(
            message: messages[i],
            onOpenQrPlugin: widget.onOpenQrPlugin,
          ),
        );
      },
    );
  }
}
