import 'package:flutter/material.dart';

import '../../../theme/luma_theme.dart';

/// Multiline input + send button, with a small "N messages left today"
/// caption tied to the local daily rate limit.
class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.onSend,
    required this.sending,
    required this.remainingToday,
  });

  final ValueChanged<String> onSend;
  final bool sending;
  final int remainingToday;

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
    if (text.isEmpty || widget.sending || widget.remainingToday <= 0) return;
    _controller.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final blocked = widget.remainingToday <= 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !blocked,
                minLines: 1,
                maxLines: 5,
                style: TextStyle(color: luma.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  hintText:
                      blocked ? "You're out of messages for today" : 'Ask the assistant…',
                  hintStyle: TextStyle(color: luma.textMuted),
                  filled: true,
                  fillColor: luma.background,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: luma.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: luma.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: luma.accent),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              onPressed: !blocked && !widget.sending ? _submit : null,
              icon: widget.sending
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(luma.onAccent),
                      ),
                    )
                  : const Icon(Icons.arrow_upward_rounded),
              style: IconButton.styleFrom(
                backgroundColor: luma.accent,
                foregroundColor: luma.onAccent,
                disabledBackgroundColor: luma.accent.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${widget.remainingToday} messages left today',
          style: TextStyle(color: luma.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}
