import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import '../chat_repository.dart';
import '../data/chat_api.dart';

/// Prompts for an email address and sends a chat invite. Returns true if the
/// invite was sent, false if the dialog was cancelled. Mirrors
/// lib/account/family_invite_dialog.dart.
Future<bool> showChatInviteDialog(
  BuildContext context, {
  required ChatRepository chatRepo,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _ChatInviteDialog(chatRepo: chatRepo),
  );
  return result ?? false;
}

class _ChatInviteDialog extends StatefulWidget {
  const _ChatInviteDialog({required this.chatRepo});
  final ChatRepository chatRepo;

  @override
  State<_ChatInviteDialog> createState() => _ChatInviteDialogState();
}

class _ChatInviteDialogState extends State<_ChatInviteDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _controller.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.chatRepo.sendInvite(email);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e is ChatApiException ? e.message : '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return AlertDialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Start an encrypted chat',
        style: TextStyle(
            color: luma.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'They\'ll see the invite in Chat → Invites the next time they '
            'open Luma. Once accepted, every message is end-to-end '
            'encrypted — only the two of you can read them.',
            style: TextStyle(color: luma.textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: luma.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'name@example.com',
              hintStyle: TextStyle(color: luma.textMuted),
              errorText: _error,
              errorMaxLines: 3,
              errorStyle: TextStyle(color: luma.danger),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: luma.border),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: luma.accent),
                borderRadius: BorderRadius.circular(12),
              ),
              errorBorder: OutlineInputBorder(
                borderSide: BorderSide(color: luma.danger),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderSide: BorderSide(color: luma.danger),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: (_) => _sending ? null : _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: luma.accent,
            foregroundColor: luma.surface,
          ),
          onPressed: _sending ? null : _submit,
          child: _sending
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: luma.onAccent),
                )
              : const Text('Send invite'),
        ),
      ],
    );
  }
}
