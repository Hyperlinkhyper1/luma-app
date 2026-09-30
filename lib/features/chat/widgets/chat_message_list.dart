import 'package:flutter/foundation.dart';
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
/// column, with the animated moon underneath while a reply is on its way —
/// replaced by the reply itself as it is written, for providers that
/// stream it.
class ChatMessageList extends StatefulWidget {
  const ChatMessageList({
    super.key,
    required this.stream,
    required this.onOpenQrPlugin,
    this.thinking = false,
    this.draft,
  });

  final Stream<List<ChatMessageRecord>> stream;
  final VoidCallback onOpenQrPlugin;
  final bool thinking;

  /// The partial reply while [thinking]; empty until the first words arrive.
  final ValueListenable<String>? draft;

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
    if (oldWidget.draft != widget.draft) {
      oldWidget.draft?.removeListener(_followDraft);
      widget.draft?.addListener(_followDraft);
    }
  }

  @override
  void initState() {
    super.initState();
    widget.draft?.addListener(_followDraft);
  }

  @override
  void dispose() {
    widget.draft?.removeListener(_followDraft);
    _scrollController.dispose();
    super.dispose();
  }

  /// Keeps a growing draft in view, unless the user has scrolled up to read.
  void _followDraft() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.maxScrollExtent - position.pixels < 160) {
        _scrollController.jumpTo(position.maxScrollExtent);
      }
    });
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

  static const _moon = Padding(
    padding: EdgeInsets.only(top: 14, bottom: 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: ChatMoon(size: 28, animating: true),
    ),
  );

  Widget _pendingReply() {
    final draft = widget.draft;
    if (draft == null) return _moon;
    return ValueListenableBuilder<String>(
      valueListenable: draft,
      builder: (context, text, _) => text.isEmpty
          ? _moon
          : ChatBubble(
              message: ChatMessageRecord(
                id: -1,
                conversationId: -1,
                role: 'assistant',
                content: text,
                createdAt: DateTime.now(),
              ),
              onOpenQrPlugin: widget.onOpenQrPlugin,
            ),
    );
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
        // Once the finished reply is saved it is the newest message, so the
        // draft steps aside rather than showing the same text twice.
        final pending =
            widget.thinking &&
            (messages.isEmpty || messages.last.role == 'user');
        final itemCount = messages.length + (pending ? 1 : 0);
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          itemCount: itemCount,
          itemBuilder: (context, i) {
            final Widget child = i == messages.length
                ? _pendingReply()
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
