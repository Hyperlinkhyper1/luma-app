import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/widgets.dart';
import '../assistant_compose_mode.dart';
import '../chat_turn_activity.dart';
import '../data/chat_repository.dart';
import 'chat_activity_card.dart';
import 'chat_activity_timeline.dart';
import 'chat_bubble.dart';

/// Width of the reading column the transcript and composer share, as in the
/// Claude app: the conversation stays a comfortable line length however wide
/// the window gets.
const chatColumnWidth = 740.0;

/// Auto-scrolling transcript with activity and the draft of the active turn.
class ChatMessageList extends StatefulWidget {
  const ChatMessageList({
    super.key,
    required this.stream,
    required this.onOpenQrPlugin,
    this.thinking = false,
    this.draft,
    this.activity,
    this.turnActivity,
  });

  final Stream<List<ChatMessageRecord>> stream;
  final VoidCallback onOpenQrPlugin;
  final bool thinking;

  /// The partial reply while [thinking]; empty until the first words arrive.
  final ValueListenable<String>? draft;

  /// What a deep research or picture turn is busy with, shown in place of
  /// the moon until the reply starts arriving.
  final ValueListenable<AssistantActivity?>? activity;
  final ValueListenable<List<ChatTurnActivity>>? turnActivity;

  @override
  State<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList> {
  final _scrollController = ScrollController();
  late Listenable _pendingUpdates;
  int _lastCount = 0;
  bool _followScheduled = false;

  @override
  void didUpdateWidget(ChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream) _lastCount = 0;
    if (oldWidget.thinking != widget.thinking) _scrollToBottom();
    if (oldWidget.draft != widget.draft ||
        oldWidget.activity != widget.activity ||
        oldWidget.turnActivity != widget.turnActivity) {
      _pendingUpdates.removeListener(_followPending);
      _listenForPendingUpdates();
    }
  }

  @override
  void initState() {
    super.initState();
    _listenForPendingUpdates();
  }

  void _listenForPendingUpdates() {
    _pendingUpdates = Listenable.merge([
      widget.draft,
      widget.activity,
      widget.turnActivity,
    ])..addListener(_followPending);
  }

  @override
  void dispose() {
    _pendingUpdates.removeListener(_followPending);
    _scrollController.dispose();
    super.dispose();
  }

  void _followPending() {
    if (!widget.thinking || _followScheduled || !_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.extentAfter >= 160) return;
    _followScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _followScheduled = false;
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
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

  Widget _pendingReply() => ListenableBuilder(
    listenable: _pendingUpdates,
    builder: (context, _) {
      final text = widget.draft?.value ?? '';
      final activity = widget.activity?.value;
      final entries = widget.turnActivity?.value ?? const <ChatTurnActivity>[];
      final runningTool = entries.whereType<ChatToolActivity>().any(
        (tool) => tool.state == ChatToolState.running,
      );
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entries.isNotEmpty) ChatActivityTimeline(entries: entries),
            if (text.isNotEmpty)
              ChatBubble(
                message: ChatMessageRecord(
                  id: -1,
                  conversationId: -1,
                  role: 'assistant',
                  content: text,
                  createdAt: DateTime.now(),
                ),
                onOpenQrPlugin: widget.onOpenQrPlugin,
              )
            else if (activity != null)
              ChatActivityCard(activity: activity)
            else if (!runningTool)
              const ChatThinkingRow(),
          ],
        ),
      );
    },
  );

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
        final narrow = MediaQuery.sizeOf(context).width < 500;
        return ListView.builder(
          controller: _scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: narrow
              ? const EdgeInsets.fromLTRB(14, 4, 14, 16)
              : const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
