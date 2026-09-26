import 'package:flutter/material.dart';

import '../../../app/widgets.dart';
import '../data/chat_repository.dart';
import 'chat_bubble.dart';
import 'chat_moon.dart';

/// Width of the reading column the transcript and composer share, as in the
/// Claude app: the conversation stays a comfortable line length however wide
/// the window gets.
const chatColumnWidth = 740.0;

/// Auto-scrolling transcript of a conversation, centred in a fixed-width
/// column, with the animated moon underneath while a reply is on its way.
class ChatMessageList extends StatefulWidget {
  const ChatMessageList({
    super.key,
    required this.stream,
    required this.onOpenQrPlugin,
    this.thinking = false,
  });

  final Stream<List<ChatMessageRecord>> stream;
  final VoidCallback onOpenQrPlugin;
  final bool thinking;

  @override
  State<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList> {
  final _scrollController = ScrollController();
  int _lastCount = 0;

  @override
  void didUpdateWidget(ChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream) _lastCount = 0;
    if (oldWidget.thinking != widget.thinking) _scrollToBottom();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeScrollToBottom(int count) {
    if (count == _lastCount) return;
    _lastCount = count;
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
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
        final lastAssistant = messages.lastIndexWhere(
          (m) => m.role != 'user' && m.role != 'error',
        );
        final itemCount = messages.length + (widget.thinking ? 1 : 0);
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          itemCount: itemCount,
          itemBuilder: (context, i) {
            final Widget child = i == messages.length
                ? const Padding(
                    padding: EdgeInsets.only(top: 14, bottom: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ChatMoon(size: 28, animating: true),
                    ),
                  )
                : ChatBubble(
                    key: ValueKey(messages[i].id),
                    message: messages[i],
                    isLast: i == lastAssistant && !widget.thinking,
                    onOpenQrPlugin: widget.onOpenQrPlugin,
                  );
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: chatColumnWidth),
                child: child,
              ),
            );
          },
        );
      },
    );
  }
}
