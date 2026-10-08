import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/luma_theme.dart';
import '../assistant_compose_mode.dart';
import '../chat_usage.dart';
import '../memory/assistant_memory_repository.dart';
import '../memory/assistant_memory_scope.dart';
import '../data/chat_repository.dart';
import 'chat_markdown.dart';
import 'compose_mode_menu.dart';

/// Renders a single message the way the Claude app does: the user's turns
/// sit in a soft bubble on the right, the assistant's are unboxed prose
/// with a copy action underneath, and errors read as a quiet inline notice.
/// An inline QR image is added when the message carries
/// `metadataJson: {"qrUrl": "..."}` from a `generate_qr_code` tool call.
class ChatBubble extends StatefulWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.onOpenQrPlugin,
    this.isLast = false,
  });

  final ChatMessageRecord message;
  final VoidCallback onOpenQrPlugin;

  /// The newest assistant reply keeps its actions visible, as in Claude;
  /// older ones show them on hover.
  final bool isLast;

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  bool _hovering = false;
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.message.content));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.message.role;
    final Widget body = switch (role) {
      'user' => _userBubble(context),
      'error' => _errorNotice(context),
      _ => _assistantReply(context),
    };
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Padding(
        padding: EdgeInsets.only(
          top: role == 'user' ? 18 : 10,
          bottom: role == 'user' ? 10 : 6,
        ),
        child: body,
      ),
    );
  }

  Widget _userBubble(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: LayoutBuilder(
            builder: (context, constraints) => ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: luma.surfaceHover,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: SelectableText(
                  widget.message.content,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize:
                        15 *
                        (AssistantMemoryScope.maybeOf(
                              context,
                            )?.textSize.scale ??
                            1),
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
        _actions(context, visible: _hovering, alignEnd: true),
      ],
    );
  }

  Widget _assistantReply(BuildContext context) {
    final luma = context.luma;
    final qrUrl = _qrUrlFrom(widget.message.metadataJson);
    final composeMode = chatComposeModeOf(widget.message.metadataJson);
    final imagePath = chatImagePathOf(widget.message.metadataJson);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (composeMode != null &&
            composeMode != AssistantComposeMode.picture) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                composeModeIcon(composeMode),
                size: 14,
                color: luma.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                composeModeLabel(L.of(context), composeMode),
                style: TextStyle(
                  color: luma.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        if (imagePath != null) ...[
          _ChatPicture(path: imagePath),
          if (widget.message.content.trim().isNotEmpty)
            const SizedBox(height: 10),
        ],
        if (widget.message.content.trim().isNotEmpty || imagePath == null)
          ChatMarkdown(source: widget.message.content),
        if (qrUrl != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: luma.border),
            ),
            child: QrImageView(
              data: qrUrl,
              version: QrVersions.auto,
              size: 150,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: widget.onOpenQrPlugin,
            style: TextButton.styleFrom(
              foregroundColor: luma.accent,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: const Icon(Icons.open_in_new_rounded, size: 15),
            label: Text(L.of(context).chatBubbleOpenInQrGenerator),
          ),
        ],
        _actions(context, visible: widget.isLast || _hovering),
      ],
    );
  }

  Widget _errorNotice(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: luma.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: luma.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.error_outline_rounded,
              size: 17,
              color: luma.danger,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              widget.message.content,
              style: TextStyle(color: luma.danger, fontSize: 14, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  /// The small icon row under a message. It always takes up its space so
  /// hovering doesn't shift the transcript; it just fades in.
  Widget _actions(
    BuildContext context, {
    required bool visible,
    bool alignEnd = false,
  }) {
    final luma = context.luma;
    final t = L.of(context);
    return AnimatedOpacity(
      opacity: visible || _copied ? 1 : 0,
      duration: const Duration(milliseconds: 120),
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisAlignment: alignEnd
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            IconButton(
              tooltip: _copied ? t.assistantCopied : t.assistantCopy,
              onPressed: _copy,
              visualDensity: VisualDensity.compact,
              iconSize: 16,
              color: luma.textMuted,
              style: IconButton.styleFrom(
                minimumSize: const Size(30, 30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: Icon(
                _copied ? Icons.check_rounded : Icons.content_copy_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String? _qrUrlFrom(String? metadataJson) {
    if (metadataJson == null) return null;
    try {
      final decoded = jsonDecode(metadataJson) as Map<String, dynamic>;
      return decoded['qrUrl'] as String?;
    } catch (_) {
      return null;
    }
  }
}

/// A picture mode reply's picture, read from where the controller saved it
/// on this device. Chats synced from another device only carry the path,
/// so a missing file gets a quiet notice instead.
class _ChatPicture extends StatelessWidget {
  const _ChatPicture({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420, maxHeight: 420),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          File(path),
          fit: BoxFit.contain,
          errorBuilder: (context, _, _) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: luma.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: luma.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hide_image_outlined, size: 18, color: luma.textMuted),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    L.of(context).assistantPictureMissing,
                    style: TextStyle(color: luma.textMuted, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
