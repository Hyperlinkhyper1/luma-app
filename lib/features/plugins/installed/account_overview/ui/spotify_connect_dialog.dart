import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../spotify_scope.dart';
import 'account_shared.dart';

Future<void> showSpotifyConnectDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => SpotifyScope(
    repository: SpotifyScope.of(context),
    child: const _SpotifyConnectDialog(),
  ),
);

class _SpotifyConnectDialog extends StatefulWidget {
  const _SpotifyConnectDialog();
  @override
  State<_SpotifyConnectDialog> createState() => _SpotifyConnectDialogState();
}

class _SpotifyConnectDialogState extends State<_SpotifyConnectDialog> {
  final _id = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SpotifyScope.of(context).connect(_id.text);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repository = SpotifyScope.of(context);
    return AlertDialog(
      backgroundColor: luma.surface,
      title: Text(
        repository.connected ? 'Spotify account settings' : 'Connect Spotify',
        style: TextStyle(color: luma.textPrimary, fontSize: 17),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 470),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (repository.connected) ...[
                AccountNotice(
                  icon: Icons.check_circle_outline_rounded,
                  tone: luma.success,
                  message:
                      'Connected as ${repository.credentials!.displayName}.',
                ),
                const SizedBox(height: 16),
                Text(
                  'Disconnecting removes the stored listening total from this device.',
                  style: TextStyle(color: luma.textMuted, fontSize: 11),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                'Spotify Client ID',
                style: TextStyle(color: luma.textPrimary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _id,
                enabled: !_busy,
                style: TextStyle(color: luma.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Paste your Client ID',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(color: luma.danger, fontSize: 12),
                ),
              ],
              const SizedBox(height: 18),
              Text(
                'One-time setup',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '1. Create an app in the Spotify Developer Dashboard (Web API).\n'
                '2. Add http://127.0.0.1/callback as its redirect URI. '
                'Spotify allows luma to use a dynamic port for this loopback address.\n'
                '3. Copy the app Client ID here, then sign in through your browser. '
                'A development-mode app requires Spotify Premium.',
                style: TextStyle(
                  color: luma.textSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              AccountLinkButton(
                label: 'Open Spotify Developer Dashboard',
                icon: Icons.open_in_new_rounded,
                onTap: () =>
                    openExternal('https://developer.spotify.com/dashboard'),
              ),
              const SizedBox(height: 8),
              Text(
                'Tokens stay in this device’s secure storage. luma reads your Spotify data directly.',
                style: TextStyle(color: luma.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (repository.connected)
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    try {
                      await repository.disconnect();
                      if (context.mounted) Navigator.of(context).pop();
                    } catch (e) {
                      if (context.mounted) {
                        setState(() => _error = e.toString());
                      }
                    }
                  },
            style: TextButton.styleFrom(foregroundColor: luma.danger),
            child: const Text('Disconnect'),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        LumaPrimaryButton(
          label: repository.connected ? 'Reconnect' : 'Sign in with Spotify',
          icon: Icons.login_rounded,
          loading: _busy,
          onTap: _busy ? null : _connect,
        ),
      ],
    );
  }
}
