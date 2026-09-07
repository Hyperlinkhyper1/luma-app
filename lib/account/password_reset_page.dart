import 'package:flutter/material.dart';

import '../app/widgets.dart';
import '../sync/sync_service.dart';
import '../theme/luma_theme.dart';

/// The screen a user is met with after the server's operator reset their
/// password from the admin dashboard: choose a new one, right here, before
/// anything else.
///
/// It sits over the whole app (see `_BootGate` in main.dart) rather than
/// being a page you can navigate away from, because the account is in a state
/// where the old password no longer signs in anywhere. This device is the way
/// out of it: it still holds the encryption key, so setting the new password
/// here also re-seals every synced snapshot under it
/// ([SyncService.completePasswordReset]) — which is exactly why an admin reset
/// leaves signed-in devices signed in.
class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({super.key, required this.sync});

  final SyncService sync;

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  static const _minLength = 10;

  final _next = TextEditingController();
  final _confirm = TextEditingController();
  final _nextFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _obscure = true;
  bool _busy = false;

  /// Per-field errors, shown under the field they belong to. Set on blur and
  /// on submit — never on every keystroke, which would scold the user while
  /// they are still typing.
  String? _nextError;
  String? _confirmError;

  /// Whatever the server said went wrong, shown above the button.
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _nextFocus.addListener(() {
      if (!_nextFocus.hasFocus) setState(() => _nextError = _validateNext());
    });
    _confirmFocus.addListener(() {
      if (!_confirmFocus.hasFocus && _confirm.text.isNotEmpty) {
        setState(() => _confirmError = _validateConfirm());
      }
    });
  }

  @override
  void dispose() {
    _next.dispose();
    _confirm.dispose();
    _nextFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  String? _validateNext() {
    if (_next.text.isEmpty) return 'Choose a new password.';
    if (_next.text.length < _minLength) {
      return 'Use at least $_minLength characters.';
    }
    return null;
  }

  String? _validateConfirm() =>
      _confirm.text == _next.text ? null : 'The two passwords do not match.';

  Future<void> _submit() async {
    final nextError = _validateNext();
    final confirmError = nextError == null ? _validateConfirm() : null;
    if (nextError != null || confirmError != null) {
      setState(() {
        _nextError = nextError;
        _confirmError = confirmError;
        _submitError = null;
      });
      // Land the caret on the first field that needs fixing.
      (nextError != null ? _nextFocus : _confirmFocus).requestFocus();
      return;
    }

    setState(() {
      _busy = true;
      _submitError = null;
    });
    try {
      await widget.sync.completePasswordReset(newPassword: _next.text);
      // Nothing to pop: SyncService.passwordResetRequired goes false and the
      // app underneath is revealed again.
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _submitError = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final email = widget.sync.email;

    return Material(
      color: luma.background,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: LumaCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        LumaIconBadge(
                            icon: Icons.password_rounded, color: luma.accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Choose a new password',
                            style: TextStyle(
                              color: luma.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      email == null
                          ? 'The server operator reset this account\'s '
                              'password, so the old one no longer works.'
                          : 'The server operator reset the password for '
                              '$email, so the old one no longer works.',
                      style: TextStyle(
                          color: luma.textSecondary, fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Set a new one here and luma re-encrypts your synced '
                      'data under it, so nothing is lost. Your other devices '
                      'will ask for the new password the next time they sync.',
                      style: TextStyle(
                          color: luma.textMuted, fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 22),
                    _PasswordField(
                      controller: _next,
                      focusNode: _nextFocus,
                      label: 'New password',
                      helper: 'At least $_minLength characters.',
                      error: _nextError,
                      obscure: _obscure,
                      enabled: !_busy,
                      autofillHints: const [AutofillHints.newPassword],
                      onToggleObscure: () =>
                          setState(() => _obscure = !_obscure),
                      onSubmitted: (_) => _confirmFocus.requestFocus(),
                    ),
                    const SizedBox(height: 16),
                    _PasswordField(
                      controller: _confirm,
                      focusNode: _confirmFocus,
                      label: 'Repeat new password',
                      error: _confirmError,
                      obscure: _obscure,
                      enabled: !_busy,
                      autofillHints: const [AutofillHints.newPassword],
                      onToggleObscure: () =>
                          setState(() => _obscure = !_obscure),
                      onSubmitted: (_) => _busy ? null : _submit(),
                    ),
                    if (_submitError != null) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: luma.danger.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: luma.danger.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.error_outline_rounded,
                                  size: 16, color: luma.danger),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _submitError!,
                                  style: TextStyle(
                                      color: luma.danger,
                                      fontSize: 13,
                                      height: 1.45),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    LumaPrimaryButton(
                      label: 'Set new password',
                      icon: Icons.check_rounded,
                      expand: true,
                      loading: _busy,
                      onTap: _busy ? null : _submit,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Everything else in luma stays locked until this is '
                      'done. Your local data on this device is untouched.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: luma.textMuted, fontSize: 12, height: 1.45),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled password field with a show/hide toggle, persistent helper text
/// and its error directly underneath — the shape both fields on this screen
/// need, so neither has to repeat it.
class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.obscure,
    required this.enabled,
    required this.onToggleObscure,
    this.helper,
    this.error,
    this.autofillHints,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String? helper;
  final String? error;
  final bool obscure;
  final bool enabled;
  final VoidCallback onToggleObscure;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final borderColor = error != null ? luma.danger : luma.border;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          obscureText: obscure,
          autofillHints: autofillHints,
          textInputAction: TextInputAction.next,
          onSubmitted: onSubmitted,
          style: TextStyle(color: luma.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: luma.textMuted, fontSize: 13),
            errorStyle: const TextStyle(height: 0, fontSize: 0),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: error != null ? luma.danger : luma.accent, width: 2),
            ),
            suffixIcon: IconButton(
              // 44x44 minimum hit area, which the default IconButton
              // constraints already satisfy — spelled out so a future padding
              // tweak can't quietly shrink it.
              constraints:
                  const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: enabled ? onToggleObscure : null,
              icon: Icon(
                obscure
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                size: 18,
                color: luma.textMuted,
              ),
              tooltip: obscure ? 'Show password' : 'Hide password',
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Semantics(
              liveRegion: true,
              child: Text(error!,
                  style: TextStyle(color: luma.danger, fontSize: 12)),
            ),
          )
        else if (helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(helper!,
                style: TextStyle(color: luma.textMuted, fontSize: 12)),
          ),
      ],
    );
  }
}
