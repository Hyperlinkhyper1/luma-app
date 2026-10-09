import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/luma_theme.dart';

/// The Claude-style composer: one rounded card holding a growing text field
/// and a toolbar row with the model picker and a square send button, plus a
/// small caption underneath — the caller decides what that says (a local
/// "N messages left today" counter, server-metered usage percentages, ...)
/// and whether sending is currently blocked.
///
/// Enter sends; Shift+Enter inserts a newline.
class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.onSend,
    required this.sending,
    required this.enabled,
    required this.caption,
    required this.modelSelector,
    this.leading,
    this.hintText,
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.minLines = 1,
    this.attachments,
    this.hasAttachments = false,
    this.onStartTyping,
  });

  final ValueChanged<String> onSend;
  final bool sending;
  final bool enabled;
  final String caption;

  /// Rendered bottom-right inside the composer, next to the send button.
  final Widget modelSelector;

  /// Rendered bottom-left inside the composer, e.g. the + menu.
  final Widget? leading;

  final String? hintText;

  /// Supply one to prefill the field from outside, e.g. a suggestion chip.
  final TextEditingController? controller;

  /// Supply one to move focus into the field from outside.
  final FocusNode? focusNode;

  final bool autofocus;

  /// The new-chat composer starts taller than the reply box, as in Claude.
  final int minLines;
  final Widget? attachments;
  final bool hasAttachments;

  /// Called each time the field goes from empty to holding text, e.g. to
  /// load a local model while the message is still being written.
  final VoidCallback? onStartTyping;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;
  bool _hasText = false;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  FocusNode get _focusNode =>
      (widget.focusNode ?? (_ownFocusNode ??= FocusNode()))
        ..onKeyEvent = _onKey;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _hasText = _controller.text.trim().isNotEmpty;
  }

  @override
  void didUpdateWidget(ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_onTextChanged);
      _controller.addListener(_onTextChanged);
      _onTextChanged();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText == _hasText) return;
    setState(() => _hasText = hasText);
    if (hasText) widget.onStartTyping?.call();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final enter =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (!enter || HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    _submit();
    return KeyEventResult.handled;
  }

  bool get _canSend =>
      (_hasText || widget.hasAttachments) && widget.enabled && !widget.sending;

  void _submit() {
    final typed = _controller.text.trim();
    if ((typed.isEmpty && !widget.hasAttachments) ||
        widget.sending ||
        !widget.enabled) {
      return;
    }
    final text = typed.isEmpty ? 'Please review the attached files.' : typed;
    _controller.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final blocked = !widget.enabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: luma.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _focusNode.hasFocus
                  ? luma.accent.withValues(alpha: 0.45)
                  : luma.border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.attachments != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: widget.attachments,
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                child: Focus(
                  onFocusChange: (_) => setState(() {}),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: !blocked,
                    autofocus: widget.autofocus,
                    minLines: widget.minLines,
                    maxLines: 10,
                    keyboardType: TextInputType.multiline,
                    textInputAction: switch (defaultTargetPlatform) {
                      TargetPlatform.android ||
                      TargetPlatform.iOS => TextInputAction.newline,
                      _ => TextInputAction.send,
                    },
                    onSubmitted: (_) => _submit(),
                    cursorColor: luma.accent,
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 15.5,
                      height: 1.5,
                    ),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      hintText: blocked
                          ? t.assistantOutOfMessages
                          : widget.hintText ?? t.assistantReplyHint,
                      hintStyle: TextStyle(color: luma.textMuted),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: widget.leading,
                      ),
                    ),
                    Flexible(
                      flex: 2,
                      fit: FlexFit.tight,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: widget.modelSelector,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _SendButton(
                      enabled: _canSend,
                      sending: widget.sending,
                      onTap: _submit,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (widget.caption.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            widget.caption,
            textAlign: TextAlign.center,
            style: TextStyle(color: luma.textMuted, fontSize: 11.5),
          ),
        ],
      ],
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.enabled,
    required this.sending,
    required this.onTap,
  });

  final bool enabled;
  final bool sending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: enabled ? luma.accent : luma.accent.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: sending
              ? SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(luma.onAccent),
                  ),
                )
              : Icon(
                  Icons.arrow_upward_rounded,
                  size: 19,
                  color: luma.onAccent,
                ),
        ),
      ),
    );
  }
}
