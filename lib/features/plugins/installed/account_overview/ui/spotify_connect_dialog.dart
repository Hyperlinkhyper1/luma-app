import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
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
    final t = L.of(context);
    final repository = SpotifyScope.of(context);
    return AlertDialog(
      backgroundColor: luma.surface,
      title: Text(
        repository.connected
            ? t.spotifyAccountSettingsTitle
            : t.spotifyConnectTitle,
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
                  message: t.spotifyConnectedAs(
                      repository.credentials!.displayName),
                ),
                const SizedBox(height: 16),
                Text(
                  t.spotifyDisconnectNote,
                  style: TextStyle(color: luma.textMuted, fontSize: 11),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                t.spotifyClientIdLabel,
                style: TextStyle(color: luma.textPrimary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _id,
                enabled: !_busy,
                style: TextStyle(color: luma.textPrimary),
                decoration: InputDecoration(
                  hintText: t.spotifyClientIdHint,
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
                t.accountOverviewOneTimeSetup,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t.spotifySetupSteps,
                style: TextStyle(
                  color: luma.textSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              AccountLinkButton(
                label: t.spotifyOpenDashboard,
                icon: Icons.open_in_new_rounded,
                onTap: () =>
                    openExternal('https://developer.spotify.com/dashboard'),
              ),
              const SizedBox(height: 8),
              Text(
                t.spotifyTokensNote,
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
            child: Text(t.accountOverviewDisconnect),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(t.commonCancel),
        ),
        LumaPrimaryButton(
          label: repository.connected ? t.spotifyReconnect : t.spotifySignIn,
          icon: Icons.login_rounded,
          loading: _busy,
          onTap: _busy ? null : _connect,
        ),
      ],
    );
  }
}
