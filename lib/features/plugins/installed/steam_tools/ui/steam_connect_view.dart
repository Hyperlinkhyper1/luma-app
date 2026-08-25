import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../steam_scope.dart';

const _apiKeyUrl = 'https://steamcommunity.com/dev/apikey';

/// Asks for the one credential this plugin actually needs from the user.
///
/// Which games an account owns is private, so the library cannot be fetched
/// anonymously — that needs a Steam key and id, entered here once and kept
/// encrypted on this device, sent only to Steam. Price history is a separate
/// concern: it comes through the luma server's own IsThereAnyDeal proxy
/// using a key the *operator* configured, so there is nothing to ask the
/// user for there — only a signed-in luma account, which most people already
/// have for sync.
class SteamConnectView extends StatefulWidget {
  const SteamConnectView({super.key});

  @override
  State<SteamConnectView> createState() => _SteamConnectViewState();
}

class _SteamConnectViewState extends State<SteamConnectView> {
  final _keyController = TextEditingController();
  final _idController = TextEditingController();
  final _keyFocus = FocusNode();
  final _idFocus = FocusNode();

  bool _showKey = false;
  String? _keyError;
  String? _idError;

  @override
  void dispose() {
    _keyController.dispose();
    _idController.dispose();
    _keyFocus.dispose();
    _idFocus.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final repository = SteamScope.of(context);
    if (repository.connecting) return;

    final key = _keyController.text.trim();
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

    await repository.connect(apiKey: key, steamIdOrUrl: id);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repository = SteamScope.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: LumaCard(
            child: Column(
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
                            'Connect your Steam account',
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
                const SizedBox(height: 20),
                _Field(
                  label: 'Steam Web API key',
                  helper: 'Free, and tied to your own account.',
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
                      hint: 'e.g. 8A0F2C…',
                      hasError: _keyError != null,
                      suffix: IconButton(
                        onPressed: () => setState(() => _showKey = !_showKey),
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
                      if (_keyError != null) setState(() => _keyError = null);
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
                    onSubmitted: (_) => _connect(),
                    onChanged: (_) {
                      if (_idError != null) setState(() => _idError = null);
                    },
                  ),
                ),
                if (repository.error case final message?) ...[
                  const SizedBox(height: 16),
                  _ErrorBanner(message: message),
                ],
                const SizedBox(height: 20),
                LumaPrimaryButton(
                  label: 'Connect',
                  icon: Icons.link_rounded,
                  loading: repository.connecting,
                  expand: true,
                  onTap: repository.connecting ? null : _connect,
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
                          'Your key is stored encrypted on this device and is '
                          'sent only to Steam — never to a luma server.',
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
                  'Steam only returns your library when "Game details" is set '
                  'to Public in your privacy settings.',
                  style: TextStyle(
                    color: luma.textMuted,
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Price history needs a signed-in luma account too — it is '
                  'fetched through the server, so no separate key is needed '
                  'here.',
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
      ),
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
