import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../steam_repository.dart';
import '../steam_scope.dart';

const _apiKeyUrl = 'https://steamcommunity.com/dev/apikey';

/// Opens the Steam account settings dialog — the one place this plugin ever
/// asks for a credential.
Future<void> showSteamAccountDialog(BuildContext context) => showDialog<void>(
      context: context,
      builder: (_) => const SteamAccountDialog(),
    );

/// Add, replace, or remove the Steam Web API key and id this plugin's
/// library is read with.
///
/// This lives behind a settings icon rather than gating the whole tab: the
/// library and everything else in Price Tracker is empty without an account,
/// but that is an empty state to show, not a wall to put in front of the
/// rest of the UI. Price history is a separate concern — it comes through
/// the luma server's own IsThereAnyDeal proxy using a key the *operator*
/// configured, so there is nothing to ask for here beyond the Steam
/// credential; a signed-in luma account is all that chart needs.
class SteamAccountDialog extends StatefulWidget {
  const SteamAccountDialog({super.key});

  @override
  State<SteamAccountDialog> createState() => _SteamAccountDialogState();
}

class _SteamAccountDialogState extends State<SteamAccountDialog> {
  final _keyController = TextEditingController();
  final _idController = TextEditingController();
  final _keyFocus = FocusNode();
  final _idFocus = FocusNode();

  bool _showKey = false;
  String? _keyError;
  String? _idError;
  bool _prefilled = false;

  @override
  void dispose() {
    _keyController.dispose();
    _idController.dispose();
    _keyFocus.dispose();
    _idFocus.dispose();
    super.dispose();
  }

  Future<void> _connect(SteamRepository repository) async {
    if (repository.connecting) return;

    // A blank key field means "keep the saved one" once connected — the raw
    // key lives in memory on the credentials object for exactly this, since
    // it can't be read back out of encrypted storage once round-tripped.
    final typedKey = _keyController.text.trim();
    final key =
        typedKey.isNotEmpty ? typedKey : (repository.credentials?.apiKey ?? '');
    final id = _idController.text.trim();
    setState(() {
      _keyError = key.isEmpty ? 'Paste your Steam Web API key.' : null;
      _idError = id.isEmpty ? 'Enter your Steam ID or profile URL.' : null;
    });
    // Focus the first field that needs fixing rather than leaving the user
    // to work out which one the message belongs to.
    if (_keyError != null) {
      _keyFocus.requestFocus();
      return;
    }
    if (_idError != null) {
      _idFocus.requestFocus();
      return;
    }

    final ok = await repository.connect(apiKey: key, steamIdOrUrl: id);
    if (ok && mounted) Navigator.of(context).pop();
  }

  Future<void> _disconnect(SteamRepository repository) async {
    await repository.disconnect();
    if (!mounted) return;
    setState(() {
      _keyController.clear();
      _idController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repository = SteamScope.of(context);

    // The Steam id isn't secret, so a reconnect can start from what is
    // already saved rather than making the user go find it again. The key
    // itself can never be read back out of encrypted storage, so that field
    // always starts blank — same as every other credential dialog in the
    // app.
    if (!_prefilled) {
      _prefilled = true;
      final steamId = repository.credentials?.steamId;
      if (steamId != null) _idController.text = steamId;
    }

    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) {
        final connected = repository.connected;
        return Dialog(
          backgroundColor: luma.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: luma.border),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      LumaIconBadge(
                        icon: Icons.videogame_asset_rounded,
                        color: luma.accent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Steam account',
                              style: TextStyle(
                                color: luma.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'So luma can list the games you own.',
                              style: TextStyle(
                                color: luma.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (connected) ...[
                    const SizedBox(height: 16),
                    _ConnectedStatus(
                      maskedKey: repository.credentials?.maskedKey,
                    ),
                  ],
                  const SizedBox(height: 20),
                  _Field(
                    label: 'Steam Web API key',
                    helper: connected
                        ? 'Leave blank to keep the saved key.'
                        : 'Free, and tied to your own account.',
                    error: _keyError,
                    child: TextField(
                      controller: _keyController,
                      focusNode: _keyFocus,
                      obscureText: !_showKey,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: TextStyle(color: luma.textPrimary, fontSize: 13),
                      decoration: _decoration(
                        context,
                        hint: connected
                            ? 'Enter a new key to replace it'
                            : 'e.g. 8A0F2C…',
                        hasError: _keyError != null,
                        suffix: IconButton(
                          onPressed: () =>
                              setState(() => _showKey = !_showKey),
                          icon: Icon(
                            _showKey
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            size: 18,
                            color: luma.textMuted,
                          ),
                          tooltip: _showKey ? 'Hide key' : 'Show key',
                        ),
                      ),
                      onChanged: (_) {
                        if (_keyError != null) {
                          setState(() => _keyError = null);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  LumaGhostButton(
                    label: 'Get a key from Steam',
                    icon: Icons.open_in_new_rounded,
                    onTap: () => launchUrl(
                      Uri.parse(_apiKeyUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _Field(
                    label: 'Steam ID or profile URL',
                    helper:
                        'Your 17-digit ID, or a link like steamcommunity.com/id/yourname.',
                    error: _idError,
                    child: TextField(
                      controller: _idController,
                      focusNode: _idFocus,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: TextStyle(color: luma.textPrimary, fontSize: 13),
                      decoration: _decoration(
                        context,
                        hint: '76561198…',
                        hasError: _idError != null,
                      ),
                      onSubmitted: (_) => _connect(repository),
                      onChanged: (_) {
                        if (_idError != null) {
                          setState(() => _idError = null);
                        }
                      },
                    ),
                  ),
                  if (repository.error case final message?) ...[
                    const SizedBox(height: 16),
                    _ErrorBanner(message: message),
                  ],
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      LumaPrimaryButton(
                        label: connected ? 'Update' : 'Connect',
                        icon: Icons.link_rounded,
                        loading: repository.connecting,
                        onTap: repository.connecting
                            ? null
                            : () => _connect(repository),
                      ),
                      if (connected)
                        LumaGhostButton(
                          label: 'Disconnect',
                          icon: Icons.link_off_rounded,
                          onTap: () => _disconnect(repository),
                        ),
                      LumaGhostButton(
                        label: 'Close',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: luma.accentSubtle,
                      borderRadius: BorderRadius.circular(
                        context.lumaDecor.cardRadius * 0.6,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lock_outline_rounded,
                            size: 15, color: luma.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your key is stored encrypted on this device and '
                            'is sent only to Steam — never to a luma server.',
                            style: TextStyle(
                              color: luma.textSecondary,
                              fontSize: 11.5,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Steam only returns your library when "Game details" is '
                    'set to Public in your privacy settings.',
                    style: TextStyle(
                      color: luma.textMuted,
                      fontSize: 11.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Price history needs a signed-in luma account too — it '
                    'is fetched through the server, so no separate key is '
                    'needed for it.',
                    style: TextStyle(
                      color: luma.textMuted,
                      fontSize: 11.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  InputDecoration _decoration(
    BuildContext context, {
    required String hint,
    required bool hasError,
    Widget? suffix,
  }) {
    final luma = context.luma;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color),
        );
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: TextStyle(color: luma.textMuted, fontSize: 13),
      filled: true,
      fillColor: luma.background,
      suffixIcon: suffix,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      enabledBorder: border(hasError ? luma.danger : luma.border),
      focusedBorder: border(hasError ? luma.danger : luma.accent),
      border: border(luma.border),
    );
  }
}

class _ConnectedStatus extends StatelessWidget {
  const _ConnectedStatus({required this.maskedKey});

  final String? maskedKey;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: luma.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 15, color: luma.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              maskedKey == null ? 'Connected' : 'Connected — $maskedKey',
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled field with helper text above the input and any error directly
/// below it — a placeholder alone is not a label, and an error shown far
/// from its field is a hunt.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.helper,
    required this.child,
    this.error,
  });

  final String label;
  final String helper;
  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(helper, style: TextStyle(color: luma.textMuted, fontSize: 11.5)),
        const SizedBox(height: 8),
        child,
        if (error case final message?) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 14, color: luma.danger),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: luma.danger, fontSize: 11.5),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: luma.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: luma.danger.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, size: 16, color: luma.danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
