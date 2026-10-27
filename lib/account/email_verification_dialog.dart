import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/luma_theme.dart';

/// Proves this account owns its email address: asks the server to email a
/// 6-digit code ([sendCode]) and takes it back ([confirm]). Accepting a
/// family or chat invite needs this, because invites are addressed by email
/// and an account approved by hand was never asked to prove its address.
/// Returns true once the server has marked the address verified.
Future<bool> showEmailVerificationDialog(
  BuildContext context, {
  required Future<void> Function() sendCode,
  required Future<void> Function(String code) confirm,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _EmailVerificationDialog(sendCode: sendCode, confirm: confirm),
  );
  return result ?? false;
}

class _EmailVerificationDialog extends StatefulWidget {
  const _EmailVerificationDialog({required this.sendCode, required this.confirm});

  final Future<void> Function() sendCode;
  final Future<void> Function(String code) confirm;

  @override
  State<_EmailVerificationDialog> createState() =>
      _EmailVerificationDialogState();
}

class _EmailVerificationDialogState extends State<_EmailVerificationDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _send();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() => _run(widget.sendCode);

  Future<void> _submit() => _run(() async {
        await widget.confirm(_controller.text.replaceAll(' ', ''));
        if (mounted) Navigator.of(context).pop(true);
      });

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderSide: BorderSide(color: color),
          borderRadius: BorderRadius.circular(12),
        );
    return AlertDialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        t.emailVerifyTitle,
        style: TextStyle(
            color: luma.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.emailVerifyBody,
            style: TextStyle(color: luma.textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            maxLength: 7,
            style: TextStyle(
                color: luma.textPrimary, fontSize: 18, letterSpacing: 4),
            decoration: InputDecoration(
              hintText: t.emailVerifyCodeHint,
              hintStyle: TextStyle(color: luma.textMuted, letterSpacing: 0),
              counterText: '',
              errorText: _error,
              errorMaxLines: 3,
              errorStyle: TextStyle(color: luma.danger),
              enabledBorder: border(luma.border),
              focusedBorder: border(luma.accent),
              errorBorder: border(luma.danger),
              focusedErrorBorder: border(luma.danger),
            ),
            onSubmitted: (_) => _busy ? null : _submit(),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _busy ? null : _send,
              child: Text(t.emailVerifyResend,
                  style: TextStyle(color: luma.accent, fontSize: 13)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(t.commonCancel,
              style: TextStyle(color: luma.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: luma.accent,
            foregroundColor: luma.surface,
          ),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: luma.onAccent),
                )
              : Text(t.emailVerifyConfirm),
        ),
      ],
    );
  }
}
