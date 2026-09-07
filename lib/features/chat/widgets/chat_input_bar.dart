import 'package:flutter/material.dart';

import '../../../theme/luma_theme.dart';

/// Multiline input with a bottom toolbar row (model picker, send button)
/// inside the same card, plus a small usage caption underneath — the caller
/// decides what that says (a local "N messages left today" counter,
/// server-metered usage percentages, ...) and whether sending is currently
/// blocked.
///
/// The field and toolbar share one rounded border, Claude-composer style —
/// no separate bordered pill floating below with its own gap, so there's
/// nothing for extra spacing to visually collect around.
class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.onSend,
    required this.sending,
    required this.enabled,
    required this.caption,
    required this.modelSelector,
  });

  final ValueChanged<String> onSend;
  final bool sending;
  final bool enabled;
  final String caption;

  /// Rendered bottom-left inside the composer card, e.g. the model picker.
  final Widget modelSelector;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.sending || !widget.enabled) return;
    _controller.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final blocked = !widget.enabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: luma.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: luma.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: TextField(
                  controller: _controller,
                  enabled: !blocked,
                  minLines: 1,
                  maxLines: 5,
                  style: TextStyle(color: luma.textPrimary),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    hintText: blocked
                        ? "You're out of messages for now"
                        : 'Ask the assistant…',
                    hintStyle: TextStyle(color: luma.textMuted),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                child: Row(
                  children: [
                    widget.modelSelector,
                    const Spacer(),
                    IconButton.filled(
                      onPressed: !blocked && !widget.sending ? _submit : null,
                      icon: widget.sending
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(luma.onAccent),
                              ),
                            )
                          : const Icon(Icons.arrow_upward_rounded, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: luma.accent,
                        foregroundColor: luma.onAccent,
                        disabledBackgroundColor:
                            luma.accent.withValues(alpha: 0.4),
                        minimumSize: const Size(34, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (widget.caption.isNotEmpty) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              widget.caption,
              style: TextStyle(color: luma.textMuted, fontSize: 11),
            ),
          ),
        ],
      ],
    );
  }
}
