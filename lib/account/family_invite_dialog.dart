import 'package:flutter/material.dart';

import '../family/family_repository.dart';
import '../theme/luma_theme.dart';

/// Prompts for an email address and sends a family invite. Returns true if
/// the invite was sent, false if the dialog was cancelled.
Future<bool> showFamilyInviteDialog(
  BuildContext context, {
  required FamilyRepository familyRepo,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _FamilyInviteDialog(familyRepo: familyRepo),
  );
  return result ?? false;
}

class _FamilyInviteDialog extends StatefulWidget {
  const _FamilyInviteDialog({required this.familyRepo});
  final FamilyRepository familyRepo;

  @override
  State<_FamilyInviteDialog> createState() => _FamilyInviteDialogState();
}

class _FamilyInviteDialogState extends State<_FamilyInviteDialog> {
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
      await widget.familyRepo.inviteMember(email);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = '$e';
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
        'Invite by email',
        style: TextStyle(
            color: luma.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'They\'ll see the invite in their inbox (top-right icon) the '
            'next time they open Luma.',
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
