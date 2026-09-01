import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../youtube_scope.dart';
import 'account_shared.dart';

/// Asks for a Google Cloud OAuth client and runs the consent flow.
Future<void> showYoutubeConnectDialog(BuildContext context) => showDialog<void>(
      context: context,
      builder: (_) => YoutubeScope(
        repository: YoutubeScope.of(context),
        child: const _YoutubeConnectDialog(),
      ),
    );

class _YoutubeConnectDialog extends StatefulWidget {
  const _YoutubeConnectDialog();

  @override
  State<_YoutubeConnectDialog> createState() => _YoutubeConnectDialogState();
}

class _YoutubeConnectDialogState extends State<_YoutubeConnectDialog> {
  final _clientIdController = TextEditingController();
  final _clientSecretController = TextEditingController();
  bool _obscured = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _clientIdController.dispose();
    _clientSecretController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final repository = YoutubeScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repository.connect(
        _clientIdController.text,
        _clientSecretController.text,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      // Validation failures belong next to the fields that caused them, not
      // in a toast that vanishes before it is read.
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repository = YoutubeScope.of(context);
    final existing = repository.credentials;

    return AlertDialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: context.lumaDecor.cardBorderRadius,
        side: BorderSide(color: luma.border),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
      title: Row(
        children: [
          Icon(Icons.smart_display_rounded, size: 20, color: luma.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              existing == null ? 'Connect YouTube' : 'Reconnect YouTube',
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (existing != null) ...[
                AccountNotice(
                  icon: Icons.check_circle_outline_rounded,
                  tone: luma.success,
                  message:
                      'Connected as ${existing.channelTitle ?? 'your channel'}. '
                      'Signing in again replaces the stored credentials.',
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'Client ID',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _CredentialField(
                controller: _clientIdController,
                hint: '…apps.googleusercontent.com',
                busy: _busy,
              ),
              const SizedBox(height: 14),
              Text(
                'Client secret',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _CredentialField(
                controller: _clientSecretController,
                hint: 'GOCSPX-…',
                busy: _busy,
                obscurable: true,
                obscured: _obscured,
                onToggleObscured: () => setState(() => _obscured = !_obscured),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(color: luma.danger, fontSize: 11.5, height: 1.4),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'These are stored encrypted on this device. Connecting opens '
                "a Google sign-in page in your browser; nothing about your "
                'account reaches a luma server.',
                style:
                    TextStyle(color: luma.textMuted, fontSize: 11, height: 1.45),
              ),
              const SizedBox(height: 18),
              const _SetupGuide(),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      actions: [
        if (existing != null)
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    final confirmed = await _confirmDisconnect(context);
                    if (!confirmed || !context.mounted) return;
                    await YoutubeScope.of(context).disconnect();
                    if (context.mounted) Navigator.of(context).pop();
                  },
            style: TextButton.styleFrom(foregroundColor: luma.danger),
            child: const Text('Disconnect'),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: luma.textSecondary),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 6),
        LumaPrimaryButton(
          label: 'Sign in with Google',
          icon: Icons.login_rounded,
          loading: _busy,
          onTap: _busy ? null : _submit,
        ),
      ],
    );
  }

  Future<bool> _confirmDisconnect(BuildContext context) async {
    final luma = context.luma;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: luma.surface,
        title: Text(
          'Disconnect YouTube?',
          style: TextStyle(color: luma.textPrimary, fontSize: 16),
        ),
        content: Text(
          'The stored credentials and every cached number are deleted from '
          'this device. Your Google account itself is untouched.',
          style: TextStyle(color: luma.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: luma.textSecondary),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: luma.danger),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _CredentialField extends StatelessWidget {
  const _CredentialField({
    required this.controller,
    required this.hint,
    required this.busy,
    this.obscurable = false,
    this.obscured = false,
    this.onToggleObscured,
  });

  final TextEditingController controller;
  final String hint;
  final bool busy;
  final bool obscurable;
  final bool obscured;
  final VoidCallback? onToggleObscured;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return TextField(
      controller: controller,
      obscureText: obscurable && obscured,
      enabled: !busy,
      style: TextStyle(color: luma.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: luma.textMuted, fontSize: 13),
        filled: true,
        fillColor: luma.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: luma.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: luma.accent, width: 2),
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (obscurable)
              IconButton(
                tooltip: obscured ? 'Show' : 'Hide',
                onPressed: onToggleObscured,
                icon: Icon(
                  obscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                ),
                color: luma.textMuted,
              ),
            IconButton(
              tooltip: 'Paste',
              onPressed: busy
                  ? null
                  : () async {
                      final data =
                          await Clipboard.getData(Clipboard.kTextPlain);
                      final text = data?.text?.trim();
                      if (text != null && text.isNotEmpty) {
                        controller.text = text;
                      }
                    },
              icon: const Icon(Icons.content_paste_rounded, size: 17),
              color: luma.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// The one-time Google Cloud setup, spelled out the same way the GitHub
/// dialog spells out which token scopes to tick — this is the step most
/// likely to go wrong on the first try.
class _SetupGuide extends StatelessWidget {
  const _SetupGuide();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: luma.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.key_rounded, size: 14, color: luma.textSecondary),
              const SizedBox(width: 8),
              Text(
                'One-time setup',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _step(context, '1', 'Create a project at Google Cloud Console.'),
          _step(
            context,
            '2',
            'Under "OAuth consent screen", set it to Testing and add your '
                'own Google account as a test user.',
          ),
          _step(
            context,
            '3',
            'Under "Library", enable "YouTube Data API v3" and "YouTube '
                'Analytics API".',
          ),
          _step(
            context,
            '4',
            'Under "Credentials", create an OAuth client ID of type '
                '"Desktop app", then paste its ID and secret above.',
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: AccountLinkButton(
              label: 'Open Google Cloud Console',
              icon: Icons.open_in_new_rounded,
              onTap: () => openExternal(
                  'https://console.cloud.google.com/apis/credentials'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(BuildContext context, String number, String text) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: luma.accentSubtle,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              number,
              style: TextStyle(
                color: luma.accent,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: luma.textSecondary,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
