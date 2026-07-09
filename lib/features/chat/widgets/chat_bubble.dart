import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../theme/luma_theme.dart';
import '../data/chat_repository.dart';

/// Renders a single message: user/assistant bubbles, plus an inline QR image
/// when the message carries `metadataJson: {"qrUrl": "..."}` from a
/// `generate_qr_code` tool call.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.onOpenQrPlugin,
  });

  final ChatMessageRecord message;
  final VoidCallback onOpenQrPlugin;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final isUser = message.role == 'user';
    final isError = message.role == 'error';

    final Color bg;
    final Color fg;
    if (isError) {
      bg = luma.danger.withValues(alpha: 0.14);
      fg = luma.danger;
    } else if (isUser) {
      bg = luma.accent;
      fg = luma.onAccent;
    } else {
      bg = luma.surface;
      fg = luma.textPrimary;
    }

    final qrUrl = _qrUrlFrom(message.metadataJson);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: isUser || isError ? null : Border.all(color: luma.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message.content,
                style: TextStyle(color: fg, fontSize: 14, height: 1.4),
              ),
              if (qrUrl != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: QrImageView(
                    data: qrUrl,
                    version: QrVersions.auto,
                    size: 140,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onOpenQrPlugin,
                  child: Text(
                    'Open in QR Generator',
                    style: TextStyle(
                      color: isUser ? luma.onAccent : luma.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ],
          ),
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
