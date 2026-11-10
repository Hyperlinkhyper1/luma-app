import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../l10n/app_localizations.dart';
import '../cs2_inventory_controller.dart';
import 'cs2_steam_session_browser.dart';

/// Connects a public Steam profile to the CS2 inventory importer.
///
/// The callbacks return a user-facing error, or null when the operation
/// succeeds. The caller owns the account and inventory state.
Future<void> showCs2InventoryDialog(
  BuildContext context, {
  required String? steamId,
  required Future<String?> Function(String profile) onConnect,
  required Future<String?> Function() onRefresh,
  required Future<void> Function() onDisconnect,
  int Function()? hiddenCount,
  Future<String?> Function(String signedInId)? onSignIn,
  Future<String?> Function()? onSignOut,
  bool Function()? sessionEnabled,
  Cs2SteamSessionStatus Function()? sessionStatus,
  String? Function()? purchaseHistoryError,
}) => showDialog<void>(
  context: context,
  builder: (_) => Cs2InventoryDialog(
    steamId: steamId,
    onConnect: onConnect,
    onRefresh: onRefresh,
    onDisconnect: onDisconnect,
    hiddenCount: hiddenCount,
    onSignIn: onSignIn,
    onSignOut: onSignOut,
    sessionEnabled: sessionEnabled,
    sessionStatus: sessionStatus,
    purchaseHistoryError: purchaseHistoryError,
  ),
);

class Cs2InventoryDialog extends StatefulWidget {
  const Cs2InventoryDialog({
    super.key,
    required this.steamId,
    required this.onConnect,
    required this.onRefresh,
    required this.onDisconnect,
    this.hiddenCount,
    this.onSignIn,
    this.onSignOut,
    this.sessionEnabled,
    this.sessionStatus,
    this.purchaseHistoryError,
  });

  final String? steamId;
  final Future<String?> Function(String profile) onConnect;
  final Future<String?> Function() onRefresh;
  final Future<void> Function() onDisconnect;

  /// Trade-protected items the last read could not see; re-read after
  /// every operation so the note follows the latest snapshot.
  final int Function()? hiddenCount;

  /// The optional Steam sign-in that reads trade-protected items too. Both
  /// callbacks return a user-facing error, or null on success; the getters
  /// are re-read on every build. Absent, the section is not shown.
  final Future<String?> Function(String signedInId)? onSignIn;
  final Future<String?> Function()? onSignOut;
  final bool Function()? sessionEnabled;
  final Cs2SteamSessionStatus Function()? sessionStatus;
  final String? Function()? purchaseHistoryError;

  @override
  State<Cs2InventoryDialog> createState() => _Cs2InventoryDialogState();
}

class _Cs2InventoryDialogState extends State<Cs2InventoryDialog> {
  late final TextEditingController _profile;
  late bool _connected;
  bool _busy = false;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    _profile = TextEditingController(text: widget.steamId ?? '');
    _connected = widget.steamId != null && widget.steamId!.isNotEmpty;
  }

  @override
  void dispose() {
    _profile.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() operation, String success) async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final error = await operation();
      if (!mounted) return;
      setState(() {
        _error = error;
        if (error == null) _message = success;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() async {
    final profile = _profile.text.trim();
    if (profile.isEmpty) {
      setState(() => _error = 'Enter your Steam profile URL or Steam ID.');
      return;
    }
    await _run(() async {
      final error = await widget.onConnect(profile);
      if (error == null && mounted) setState(() => _connected = true);
      return error;
    }, 'Inventory imported.');
  }

  Future<void> _disconnect() async {
    await _run(() async {
      await widget.onDisconnect();
      if (mounted) setState(() => _connected = false);
      return null;
    }, 'Steam inventory disconnected.');
  }

  Future<void> _signIn() async {
    final onSignIn = widget.onSignIn;
    if (onSignIn == null) return;
    final l = L.of(context);
    final id = await showCs2SteamSignIn(context);
    if (id == null || !mounted) return;
    await _run(() async {
      final error = await onSignIn(id);
      if (error == null && mounted) {
        setState(() {
          _connected = true;
          _profile.text = id;
        });
      }
      return error;
    }, l.steamCs2SessionActive);
  }

  Future<void> _signOut() async {
    final onSignOut = widget.onSignOut;
    if (onSignOut == null) return;
    await _run(onSignOut, L.of(context).steamCs2SignedOut);
  }

  List<Widget> _sessionSection(ThemeData theme) {
    if (widget.onSignIn == null || !cs2SteamSessionSupported) return const [];
    final l = L.of(context);
    final enabled = widget.sessionEnabled?.call() ?? false;
    final status = widget.sessionStatus?.call() ?? Cs2SteamSessionStatus.off;
    final note = !enabled
        ? l.steamCs2SignInExplain
        : switch (status) {
            Cs2SteamSessionStatus.off ||
            Cs2SteamSessionStatus.active => l.steamCs2SessionActive,
            Cs2SteamSessionStatus.signedOut => l.steamCs2SessionExpired,
            Cs2SteamSessionStatus.otherAccount => l.steamCs2SessionOtherAccount,
            Cs2SteamSessionStatus.failed => l.steamCs2SessionFailed,
          };
    final healthy = enabled &&
        (status == Cs2SteamSessionStatus.active || status == Cs2SteamSessionStatus.off);
    return [
      const SizedBox(height: 12),
      Text(note, style: theme.textTheme.bodySmall),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8,
        children: [
          if (!healthy)
            OutlinedButton.icon(
              onPressed: _busy ? null : _signIn,
              icon: const Icon(Icons.login, size: 16),
              label: Text(l.steamCs2SignInButton),
            ),
          if (enabled)
            TextButton.icon(
              onPressed: _busy ? null : _signOut,
              icon: const Icon(Icons.logout, size: 16),
              label: Text(l.steamCs2SignOutButton),
            ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Steam CS2 inventory'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your Steam profile URL or 17-digit Steam ID to import '
                'your CS2 skins, stickers, cases and everything else the '
                'market sells. No Steam password or API key is needed.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _profile,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Steam profile URL or Steam ID',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _connect(),
              ),
              const SizedBox(height: 12),
              Text(
                'Your Steam profile and inventory must be public for luma '
                'to read them.',
                style: theme.textTheme.bodySmall,
              ),
              TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse('https://steamcommunity.com/my/edit/settings'),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open Steam privacy settings'),
              ),
              Text(
                L.of(context).steamCs2PurchaseHistoryExplain,
                style: theme.textTheme.bodySmall,
              ),
              if (widget.purchaseHistoryError?.call() case final error?) ...[
                const SizedBox(height: 12),
                Text(
                  L.of(context).steamCs2PurchaseHistoryFailed(error),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'While CS2 Market is open, luma checks your inventory every '
                'six hours. Items you sell or trade away are removed when it '
                'next checks. Disconnecting keeps imported items.',
                style: theme.textTheme.bodySmall,
              ),
              if (_connected && (widget.hiddenCount?.call() ?? 0) > 0) ...[
                const SizedBox(height: 12),
                Text(
                  L.of(context).steamCs2InventoryHidden(widget.hiddenCount!()),
                  style: theme.textTheme.bodySmall,
                ),
              ],
              ..._sessionSection(theme),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(_message!),
              ],
              if (_busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (_connected)
          TextButton(
            onPressed: _busy ? null : _disconnect,
            child: const Text('Disconnect'),
          ),
        if (_connected)
          TextButton(
            onPressed: _busy
                ? null
                : () => _run(widget.onRefresh, 'Inventory refreshed.'),
            child: const Text('Refresh inventory'),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: _busy ? null : _connect,
          child: Text(_connected ? 'Connect another profile' : 'Connect'),
        ),
      ],
    );
  }
}
