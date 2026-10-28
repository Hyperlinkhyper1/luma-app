import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
}) => showDialog<void>(
  context: context,
  builder: (_) => Cs2InventoryDialog(
    steamId: steamId,
    onConnect: onConnect,
    onRefresh: onRefresh,
    onDisconnect: onDisconnect,
  ),
);

class Cs2InventoryDialog extends StatefulWidget {
  const Cs2InventoryDialog({
    super.key,
    required this.steamId,
    required this.onConnect,
    required this.onRefresh,
    required this.onDisconnect,
  });

  final String? steamId;
  final Future<String?> Function(String profile) onConnect;
  final Future<String?> Function() onRefresh;
  final Future<void> Function() onDisconnect;

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
                'your CS2 skins. No Steam password or API key is needed.',
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
                'Steam inventory does not include what you paid or whether '
                'an item came from a case. Set each item’s cost yourself '
                'to track profit and loss.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Text(
                'While CS2 Market is open, luma checks your inventory every '
                'six hours. Items removed from Steam stay tracked until you '
                'remove them yourself. Disconnecting also keeps imported items.',
                style: theme.textTheme.bodySmall,
              ),
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
