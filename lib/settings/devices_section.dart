import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../app/widgets.dart';
import '../p2p/peer_debug_log.dart';
import '../p2p/peer_discovery.dart';
import '../p2p/peer_sync_controller.dart';
import '../p2p/peer_sync_scope.dart';
import '../sync/sync_scope.dart';
import '../sync/sync_service.dart';
import '../theme/luma_theme.dart';

/// The "Devices" block on the Settings page: discover and connect to other
/// devices on the same account, over Wi-Fi / LAN. Reuses the same encryption
/// and merge logic as cloud sync — the cloud stays optional.
class DevicesSection extends StatelessWidget {
  const DevicesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = SyncScope.of(context);
    final peers = PeerSyncScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([sync, peers]),
      builder: (context, _) => LumaCard(
        child: sync.p2pReady
            ? _SignedInBody(sync: sync, peers: peers)
            : _SetupBody(sync: sync),
      ),
    );
  }
}

// ---- Not set up yet ---------------------------------------------------------

/// No encryption key at all yet (no cloud account, no local identity). A
/// switch right here starts local (serverless) setup — no need to visit the
/// cloud "Sync & account" section at all.
class _SetupBody extends StatelessWidget {
  const _SetupBody({required this.sync});
  final SyncService sync;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LumaIconBadge(icon: Icons.devices_other_rounded, color: luma.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sync directly between devices',
                style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'No server needed — just an email + password shared between '
                'your devices, used only to recognize each other over '
                'Wi-Fi. Already have a luma cloud account? Sign in above '
                'instead and this turns on automatically.',
                style:
                    TextStyle(color: luma.textMuted, fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: false,
          onChanged: (_) => showDialog<void>(
            context: context,
            builder: (_) => _LocalAccountDialog(sync: sync),
          ),
          activeThumbColor: luma.onAccent,
          activeTrackColor: luma.accent,
          inactiveThumbColor: luma.textSecondary,
          inactiveTrackColor: luma.surfaceHover,
        ),
      ],
    );
  }
}

class _LocalAccountDialog extends StatefulWidget {
  const _LocalAccountDialog({required this.sync});
  final SyncService sync;

  @override
  State<_LocalAccountDialog> createState() => _LocalAccountDialogState();
}

class _LocalAccountDialogState extends State<_LocalAccountDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || !_email.text.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (_password.text.length < 10) {
      setState(() => _error =
          'Use at least 10 characters — this password also protects your '
          'encrypted data.');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.sync
          .setLocalAccount(email: _email.text, password: _password.text);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return AlertDialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: luma.border),
      ),
      title:
          Text('Enable device sync', style: TextStyle(color: luma.textPrimary)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter the same email and password on every device you want '
                'to pair — they never leave this device or touch a server. '
                'They just prove your devices belong to the same person.',
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: luma.textPrimary, fontSize: 14),
                decoration: _fieldDecoration(context, 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                enabled: !_busy,
                obscureText: true,
                style: TextStyle(color: luma.textPrimary, fontSize: 14),
                decoration: _fieldDecoration(context, 'Password'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirm,
                enabled: !_busy,
                obscureText: true,
                style: TextStyle(color: luma.textPrimary, fontSize: 14),
                decoration: _fieldDecoration(context, 'Confirm password'),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              Text(
                'If you mistype the password while pairing a second device, '
                'it just won\'t be recognized as the same account — there\'s '
                'no server to check against or reset it with.',
                style: TextStyle(
                    color: Colors.orange.shade400, fontSize: 12, height: 1.4),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style:
                        TextStyle(color: Colors.red.shade400, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
        ),
        LumaPrimaryButton(
          label: 'Enable',
          loading: _busy,
          onTap: _busy ? null : _submit,
        ),
      ],
    );
  }
}

// ---- Signed in ------------------------------------------------------------

class _SignedInBody extends StatelessWidget {
  const _SignedInBody({required this.sync, required this.peers});
  final SyncService sync;
  final PeerSyncController peers;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- Discovery toggle + status -----------------------------------
        Row(
          children: [
            LumaIconBadge(
                icon: Icons.devices_other_rounded, color: luma.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('This device',
                      style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  Text(
                    peers.isRunning && peers.listenPort != 0
                        ? '${peers.state.deviceName} · listening on port ${peers.listenPort}'
                        : peers.state.deviceName,
                    style: TextStyle(color: luma.textMuted, fontSize: 12),
                  ),
                  if (peers.isRunning && peers.listenPort != 0)
                    FutureBuilder<List<String>>(
                      future: peers.localAddresses(),
                      builder: (context, snapshot) {
                        final addrs = snapshot.data ?? const <String>[];
                        if (addrs.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'IP: ${addrs.join(', ')} — the other device '
                            'must be on the same network to find this one.',
                            style: TextStyle(
                                color: luma.textMuted, fontSize: 11),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            Switch(
              value: peers.isRunning,
              onChanged: (on) =>
                  on ? peers.start() : peers.stop(),
              activeThumbColor: luma.onAccent,
              activeTrackColor: luma.accent,
              inactiveThumbColor: luma.textSecondary,
              inactiveTrackColor: luma.surfaceHover,
            ),
          ],
        ),
        if (peers.lastError != null) ...[
          const SizedBox(height: 8),
          Text(peers.lastError!,
              style:
                  TextStyle(color: Colors.orange.shade400, fontSize: 12)),
        ],
        if (sync.isLocalOnly) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Local only — ${sync.email ?? ''} (not backed up anywhere)',
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: () => _confirmTurnOff(context, sync, peers),
                child: Text('Turn off',
                    style: TextStyle(color: Colors.red.shade400, fontSize: 12)),
              ),
            ],
          ),
        ],

        // ---- Connected devices -------------------------------------------
        Divider(color: luma.border, height: 32),
        Text('Connected',
            style: TextStyle(
                color: luma.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (peers.connected.isEmpty)
          Text('No devices connected yet.',
              style: TextStyle(color: luma.textMuted, fontSize: 12))
        else
          for (final p in peers.connected)
            _ConnectedRow(peer: p, controller: peers),

        // ---- Nearby devices ----------------------------------------------
        Divider(color: luma.border, height: 32),
        Text('Nearby',
            style: TextStyle(
                color: luma.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (!peers.isRunning)
          Text('Turn on discovery to find other devices on this Wi-Fi.',
              style: TextStyle(color: luma.textMuted, fontSize: 12))
        else if (peers.discovered.isEmpty)
          Text('Searching… no other devices found yet.',
              style: TextStyle(color: luma.textMuted, fontSize: 12))
        else
          for (final d in peers.discovered)
            _DiscoveredRow(peer: d, controller: peers),
        if (peers.isRunning) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Both devices must be on the same network. On mobile '
                  'data (5G/4G)? Use a hotspot instead.',
                  style: TextStyle(color: luma.textMuted, fontSize: 11),
                ),
              ),
              TextButton(
                onPressed: () => _showHotspotHelp(context),
                child:
                    Text('How?', style: TextStyle(color: luma.accent, fontSize: 11)),
              ),
            ],
          ),
        ],

        // ---- Manual connect + auto-sync ----------------------------------
        Divider(color: luma.border, height: 32),
        Row(
          children: [
            LumaGhostButton(
              label: 'Connect manually…',
              icon: Icons.cable_rounded,
              onTap: () => _showManualConnect(context, peers),
            ),
            const Spacer(),
            Text('Auto-sync',
                style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 10),
            Switch(
              value: peers.state.autoSync,
              onChanged: peers.setAutoSync,
              activeThumbColor: luma.onAccent,
              activeTrackColor: luma.accent,
              inactiveThumbColor: luma.textSecondary,
              inactiveTrackColor: luma.surfaceHover,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Auto-sync pushes changes to connected devices within a couple of '
          'seconds. Off, you tap a device and choose Sync now.',
          style: TextStyle(color: luma.textMuted, fontSize: 12, height: 1.4),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => _showDebugLog(context),
            child: Text('View debug log',
                style: TextStyle(color: luma.textMuted, fontSize: 11)),
          ),
        ),
      ],
    );
  }
}

class _ConnectedRow extends StatelessWidget {
  const _ConnectedRow({required this.peer, required this.controller});
  final ConnectedPeer peer;
  final PeerSyncController controller;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final lastSeen =
        controller.state.lastSeenMs[peer.deviceId];
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: Row(
        children: [
          Icon(_platformIcon(peer.platform),
              size: 18, color: luma.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(peer.deviceName,
                    style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                Text(
                  lastSeen == null
                      ? peer.address
                      : '${peer.address} · last seen '
                          '${DateFormat('d MMM, HH:mm').format(
                              DateTime.fromMillisecondsSinceEpoch(lastSeen))}',
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          LumaGhostButton(
            label: 'Sync',
            icon: Icons.sync_rounded,
            onTap: () => controller.syncNow(peer.deviceId),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Disconnect',
            icon: Icon(Icons.link_off_rounded,
                size: 18, color: luma.textSecondary),
            onPressed: () => controller.disconnect(peer.deviceId),
          ),
        ],
      ),
    );
  }
}

class _DiscoveredRow extends StatelessWidget {
  const _DiscoveredRow({
    required this.peer,
    required this.controller,
  });
  final DiscoveredPeer peer;
  final PeerSyncController controller;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: Row(
        children: [
          Icon(Icons.wifi_rounded, size: 18, color: luma.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(peer.host.isNotEmpty ? peer.host : peer.name,
                style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ),
          LumaPrimaryButton(
            label: 'Connect',
            icon: Icons.link_rounded,
            onTap: () => controller.connectToDiscovered(peer),
          ),
        ],
      ),
    );
  }
}

// ---- Hotspot fallback help --------------------------------------------------

/// Discovery needs both devices on the same local network. There's no way
/// around that over plain Wi-Fi/LAN — if a phone is on mobile data (5G/4G)
/// instead of Wi-Fi, the fix is to put both devices on ONE network via the
/// phone's own hotspot, which the existing Wi-Fi discovery/connect code
/// already handles with no changes (it doesn't care whether the network was
/// created by a router or a phone).
void _showHotspotHelp(BuildContext context) {
  final luma = context.luma;
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: luma.border),
      ),
      title: Text('No shared Wi-Fi? Use a hotspot',
          style: TextStyle(color: luma.textPrimary)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Discovery only finds devices on the same network. If your '
              'phone is on mobile data instead of Wi-Fi, there\'s no LAN to '
              'find each other on — turn on the phone\'s own hotspot instead '
              'and have the other device join it. Once both are on that one '
              'network, everything here works exactly the same.',
              style: TextStyle(color: luma.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 14),
            _HotspotStep(
                number: '1',
                text: 'On the phone: Settings → Network & internet → '
                    'Hotspot & tethering → turn on Wi-Fi hotspot.'),
            _HotspotStep(
                number: '2',
                text: 'On the other device: connect to that hotspot\'s '
                    'Wi-Fi network like any other.'),
            _HotspotStep(
                number: '3',
                text: 'Come back here and turn discovery on (or off and '
                    'back on) on both devices.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text('Got it', style: TextStyle(color: luma.accent)),
        ),
      ],
    ),
  );
}

class _HotspotStep extends StatelessWidget {
  const _HotspotStep({required this.number, required this.text});
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: luma.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(number,
                style: TextStyle(
                    color: luma.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: luma.textSecondary, fontSize: 12, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

// ---- Debug log ---------------------------------------------------------

/// Shows the rolling P2P debug log (connection attempts, handshake steps,
/// and any "malformed control message" forensic detail) with a Copy button
/// — for reporting an issue from a release/installed build with no visible
/// console.
void _showDebugLog(BuildContext context) {
  final luma = context.luma;
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: luma.border),
      ),
      title: Text('P2P debug log', style: TextStyle(color: luma.textPrimary)),
      content: SizedBox(
        width: 520,
        height: 400,
        child: FutureBuilder<String>(
          future: readP2pDebugLog(),
          builder: (context, snapshot) {
            final content = snapshot.data;
            if (content == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return SingleChildScrollView(
              child: SelectableText(
                content,
                style: TextStyle(
                    color: luma.textSecondary,
                    fontSize: 11,
                    fontFamily: 'monospace'),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await clearP2pDebugLog();
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          },
          child: Text('Clear', style: TextStyle(color: Colors.red.shade400)),
        ),
        TextButton(
          onPressed: () async {
            final content = await readP2pDebugLog();
            await Clipboard.setData(ClipboardData(text: content));
          },
          child: Text('Copy', style: TextStyle(color: luma.accent)),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text('Close', style: TextStyle(color: luma.textSecondary)),
        ),
      ],
    ),
  );
}

// ---- Turn off local device sync --------------------------------------------

Future<void> _confirmTurnOff(
    BuildContext context, SyncService sync, PeerSyncController peers) async {
  final luma = context.luma;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: luma.border),
      ),
      title:
          Text('Turn off device sync?', style: TextStyle(color: luma.textPrimary)),
      content: Text(
        'This disconnects every paired device and forgets this device\'s '
        'sync identity. You can set it up again any time with the same '
        'email and password.',
        style: TextStyle(color: luma.textSecondary, fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child:
              Text('Turn off', style: TextStyle(color: Colors.red.shade400)),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await peers.stop();
  await sync.clearLocalAccount();
}

IconData _platformIcon(String platform) {
  switch (platform) {
    case 'android':
    case 'ios':
      return Icons.phone_android_rounded;
    case 'windows':
    case 'macos':
    case 'linux':
      return Icons.laptop_rounded;
    default:
      return Icons.devices_rounded;
  }
}

// ---- Manual connect dialog -------------------------------------------------

Future<void> _showManualConnect(
    BuildContext context, PeerSyncController peers) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _ManualConnectDialog(peers: peers),
  );
}

class _ManualConnectDialog extends StatefulWidget {
  const _ManualConnectDialog({required this.peers});
  final PeerSyncController peers;

  @override
  State<_ManualConnectDialog> createState() => _ManualConnectDialogState();
}

class _ManualConnectDialogState extends State<_ManualConnectDialog> {
  final _host = TextEditingController();
  final _port = TextEditingController(text: '0');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final host = _host.text.trim();
    final port = int.tryParse(_port.text.trim());
    if (host.isEmpty || port == null || port <= 0 || port > 65535) {
      setState(() => _error = 'Enter a host and a valid port (1–65535).');
      return;
    }
    if (!widget.peers.isRunning) {
      await widget.peers.start();
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    widget.peers.connectManually(host, port);
    // The connection resolves async via the listener; pop immediately and
    // surface any failure in the section's status line.
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return AlertDialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: luma.border),
      ),
      title: Text('Connect manually',
          style: TextStyle(color: luma.textPrimary)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Use this when discovery can\'t see the other device — e.g. a '
              'firewall is blocking mDNS. Enter the address it shows on its '
              'Devices screen.',
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _host,
              enabled: !_busy,
              style: TextStyle(color: luma.textPrimary, fontSize: 14),
              decoration: _fieldDecoration(context, 'Host',
                  hint: '192.168.1.20'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _port,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              style: TextStyle(color: luma.textPrimary, fontSize: 14),
              decoration: _fieldDecoration(context, 'Port'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: Colors.red.shade400, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
        ),
        LumaPrimaryButton(
          label: 'Connect',
          loading: _busy,
          onTap: _busy ? null : _submit,
        ),
      ],
    );
  }
}

InputDecoration _fieldDecoration(BuildContext context, String label,
    {String? hint}) {
  final luma = context.luma;
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: TextStyle(color: luma.textMuted, fontSize: 13),
    hintStyle: TextStyle(color: luma.textMuted, fontSize: 13),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: luma.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: luma.accent),
    ),
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}
