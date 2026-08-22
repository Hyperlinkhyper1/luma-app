import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../sftp_dialogs.dart';
import '../sftp_paths.dart';
import 'host_crypto.dart';
import 'host_protocol.dart';
import 'host_server.dart';

/// The "Host" tab: the screen that turns this device into the one others
/// connect to, and shows the address and pairing password they need.
///
/// The hosting itself lives in [SftpHostServer]; this is only its face. The
/// server is owned by the page, not by this widget, so a rebuild never
/// restarts a listener and switching to another tab — or another plugin —
/// does not drop a transfer that is in flight.
class SftpHostPanel extends StatefulWidget {
  const SftpHostPanel({
    super.key,
    required this.server,
    required this.compact,
    required this.onAnnounce,
  });

  final SftpHostServer server;
  final bool compact;

  /// Shows a one-line message — copy confirmations and the like.
  final void Function(String message) onAnnounce;

  @override
  State<SftpHostPanel> createState() => _SftpHostPanelState();
}

class _SftpHostPanelState extends State<SftpHostPanel> {
  Directory? _directory;
  HostAccess _access = HostAccess.readOnly;
  bool _requireApproval = true;
  bool _ownPassword = false;
  final _passwordController = TextEditingController();
  final _portController =
      TextEditingController(text: '$kDefaultHostPort');

  List<String> _addresses = const [];
  bool _revealed = false;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    widget.server.addListener(_onServerChanged);
    unawaited(_loadAddresses());
    unawaited(_pickDefaultDirectory());
  }

  @override
  void dispose() {
    widget.server.removeListener(_onServerChanged);
    _passwordController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _onServerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAddresses() async {
    final addresses = await SftpHostServer.localAddresses();
    if (mounted) setState(() => _addresses = addresses);
  }

  /// Offers a sensible folder so the common case is one button press. The
  /// user can still pick another, and nothing is shared until they start.
  Future<void> _pickDefaultDirectory() async {
    if (widget.server.directory != null) {
      setState(() => _directory = widget.server.directory);
      return;
    }
    try {
      final home = Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'];
      if (home == null) return;
      for (final name in const ['Downloads', 'Documents']) {
        final candidate = Directory('$home${Platform.pathSeparator}$name');
        if (await candidate.exists()) {
          if (mounted) setState(() => _directory = candidate);
          return;
        }
      }
    } catch (_) {
      // Leave it unset; the user picks one.
    }
  }

  Future<void> _chooseDirectory() async {
    final picked = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose the folder to share',
    );
    if (picked == null || !mounted) return;
    setState(() => _directory = Directory(picked));
  }

  Future<void> _start() async {
    final directory = _directory;
    if (directory == null) {
      widget.onAnnounce('Choose a folder to share first.');
      return;
    }
    if (!await directory.exists()) {
      widget.onAnnounce('That folder is no longer there.');
      return;
    }

    final port = int.tryParse(_portController.text.trim());
    if (port == null || port < 1024 || port > 65535) {
      widget.onAnnounce('Pick a port between 1024 and 65535.');
      return;
    }

    String? password;
    if (_ownPassword) {
      password = _passwordController.text;
      if (password.length < kMinPairingPasswordLength) {
        widget.onAnnounce(
          'A pairing password needs at least '
          '$kMinPairingPasswordLength characters.',
        );
        return;
      }
    }

    setState(() => _starting = true);
    await widget.server.start(
      directory: directory,
      port: port,
      password: password,
      access: _access,
      requireApproval: _requireApproval,
    );
    if (!mounted) return;
    setState(() {
      _starting = false;
      _revealed = false;
    });
    unawaited(_loadAddresses());
  }

  Future<void> _stop() async {
    await widget.server.stop();
    if (mounted) setState(() => _revealed = false);
  }

  Future<void> _copy(String value, String what) async {
    await Clipboard.setData(ClipboardData(text: value));
    widget.onAnnounce('$what copied.');
  }

  @override
  Widget build(BuildContext context) {
    final server = widget.server;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        widget.compact ? 12 : 16,
        4,
        widget.compact ? 12 : 16,
        widget.compact ? 12 : 16,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (server.isRunning) ...[
                _PairingCard(
                  server: server,
                  addresses: _addresses,
                  revealed: _revealed,
                  onToggleReveal: () => setState(() => _revealed = !_revealed),
                  onCopy: _copy,
                  onRotate: () {
                    server.rotatePassword();
                    widget.onAnnounce(
                      'New pairing password. Devices already connected stay '
                      'connected.',
                    );
                  },
                  onStop: _stop,
                  compact: widget.compact,
                ),
                const SizedBox(height: 12),
                if (server.pendingApproval != null) ...[
                  _ApprovalCard(
                    client: server.pendingApproval!,
                    onAllow: server.approvePending,
                    onRefuse: server.rejectPending,
                  ),
                  const SizedBox(height: 12),
                ],
                _ClientsCard(server: server),
              ] else
                _SetupCard(
                  directory: _directory,
                  access: _access,
                  requireApproval: _requireApproval,
                  ownPassword: _ownPassword,
                  passwordController: _passwordController,
                  portController: _portController,
                  starting: _starting,
                  error: server.error,
                  onChooseDirectory: _chooseDirectory,
                  onAccessChanged: (value) => setState(() => _access = value),
                  onApprovalChanged: (value) =>
                      setState(() => _requireApproval = value),
                  onOwnPasswordChanged: (value) =>
                      setState(() => _ownPassword = value),
                  onStart: _start,
                ),
              const SizedBox(height: 12),
              const _SecurityNote(),
            ],
          ),
        ),
      ),
    );
  }
}

/// The pre-flight form: what to share, on what terms.
class _SetupCard extends StatelessWidget {
  const _SetupCard({
    required this.directory,
    required this.access,
    required this.requireApproval,
    required this.ownPassword,
    required this.passwordController,
    required this.portController,
    required this.starting,
    required this.error,
    required this.onChooseDirectory,
    required this.onAccessChanged,
    required this.onApprovalChanged,
    required this.onOwnPasswordChanged,
    required this.onStart,
  });

  final Directory? directory;
  final HostAccess access;
  final bool requireApproval;
  final bool ownPassword;
  final TextEditingController passwordController;
  final TextEditingController portController;
  final bool starting;
  final String? error;
  final VoidCallback onChooseDirectory;
  final ValueChanged<HostAccess> onAccessChanged;
  final ValueChanged<bool> onApprovalChanged;
  final ValueChanged<bool> onOwnPasswordChanged;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LumaIconBadge(
                icon: Icons.wifi_tethering_rounded,
                color: luma.accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Let another device connect to this one',
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Share one folder over your network. The other device '
                      'opens it in its own Servers tab.',
                      style: TextStyle(
                        color: luma.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _Label('Folder to share'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: luma.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: luma.border),
                  ),
                  child: Text(
                    directory?.path ?? 'No folder chosen yet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: directory == null
                          ? luma.textMuted
                          : luma.textPrimary,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              LumaGhostButton(
                label: 'Choose',
                icon: Icons.folder_open_rounded,
                onTap: onChooseDirectory,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Only this folder is served. Nothing above it is reachable, and '
            'links pointing out of it are refused.',
            style: TextStyle(color: luma.textMuted, fontSize: 11.5, height: 1.4),
          ),
          const SizedBox(height: 18),
          _Label('What the other device may do'),
          const SizedBox(height: 6),
          LumaSegmentedTabs(
            tabs: const ['Read only', 'Read and write'],
            selectedIndex: access == HostAccess.readOnly ? 0 : 1,
            onSelect: (index) => onAccessChanged(
              index == 0 ? HostAccess.readOnly : HostAccess.readWrite,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            access == HostAccess.readOnly
                ? 'It can browse and download. Nothing on this device changes.'
                : 'It can also upload, rename and delete inside the shared '
                    'folder.',
            style: TextStyle(color: luma.textMuted, fontSize: 11.5, height: 1.4),
          ),
          const SizedBox(height: 16),
          SftpCheckRow(
            value: requireApproval,
            label: 'Ask me before letting a device in',
            subtitle: 'Even with the right password, you approve each one.',
            onChanged: onApprovalChanged,
          ),
          const SizedBox(height: 4),
          SftpCheckRow(
            value: ownPassword,
            label: 'Choose the pairing password myself',
            subtitle: 'Off by default — luma generates a much stronger one.',
            onChanged: onOwnPasswordChanged,
          ),
          if (ownPassword) ...[
            const SizedBox(height: 10),
            _PasswordField(controller: passwordController),
          ],
          const SizedBox(height: 16),
          _Label('Port'),
          const SizedBox(height: 6),
          SizedBox(
            width: 140,
            child: TextField(
              controller: portController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(color: luma.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                filled: true,
                fillColor: luma.background,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: luma.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: luma.accent),
                ),
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: luma.danger.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: luma.danger.withValues(alpha: 0.35)),
              ),
              child: Text(
                error!,
                style: TextStyle(color: luma.danger, fontSize: 12, height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: 18),
          LumaPrimaryButton(
            label: 'Start hosting',
            icon: Icons.wifi_tethering_rounded,
            expand: true,
            loading: starting,
            onTap: onStart,
          ),
        ],
      ),
    );
  }
}

/// What the user reads off the screen and types into the other device.
class _PairingCard extends StatelessWidget {
  const _PairingCard({
    required this.server,
    required this.addresses,
    required this.revealed,
    required this.onToggleReveal,
    required this.onCopy,
    required this.onRotate,
    required this.onStop,
    required this.compact,
  });

  final SftpHostServer server;
  final List<String> addresses;
  final bool revealed;
  final VoidCallback onToggleReveal;
  final Future<void> Function(String value, String what) onCopy;
  final VoidCallback onRotate;
  final Future<void> Function() onStop;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final address = addresses.isEmpty ? null : addresses.first;
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: luma.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Hosting ${server.rootName}',
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              LumaGhostButton(
                label: 'Stop',
                icon: Icons.stop_rounded,
                onTap: () => unawaited(onStop()),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            server.access == HostAccess.readOnly
                ? 'Read only · ${server.requireApproval ? 'you approve each device' : 'password only'}'
                : 'Read and write · ${server.requireApproval ? 'you approve each device' : 'password only'}',
            style: TextStyle(color: luma.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 18),
          Text(
            'On the other device, open the SFTP plugin, add a site of type '
            '"luma device", and enter:',
            style: TextStyle(
              color: luma.textSecondary,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          _CopyRow(
            label: 'Address',
            value: address ?? 'No network connection',
            monospace: true,
            enabled: address != null,
            onCopy: address == null ? null : () => onCopy(address, 'Address'),
          ),
          if (addresses.length > 1) ...[
            const SizedBox(height: 4),
            Text(
              'Other addresses on this device: ${addresses.skip(1).join(', ')}',
              style: TextStyle(color: luma.textMuted, fontSize: 11),
            ),
          ],
          const SizedBox(height: 10),
          _CopyRow(
            label: 'Port',
            value: '${server.port}',
            monospace: true,
            onCopy: () => onCopy('${server.port}', 'Port'),
          ),
          const SizedBox(height: 10),
          _CopyRow(
            label: 'Pairing password',
            value: revealed ? server.password : '••••-••••-••••-••••-••••',
            monospace: true,
            trailing: IconButton(
              onPressed: onToggleReveal,
              iconSize: 18,
              tooltip: revealed ? 'Hide' : 'Show',
              icon: Icon(
                revealed
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: luma.textSecondary,
              ),
            ),
            onCopy: () => onCopy(server.password, 'Pairing password'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              LumaGhostButton(
                label: 'New password',
                icon: Icons.autorenew_rounded,
                onTap: onRotate,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The prompt shown when a device has the password but still needs a yes.
class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.client,
    required this.onAllow,
    required this.onRefuse,
  });

  final HostClient client;
  final VoidCallback onAllow;
  final VoidCallback onRefuse;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: luma.accentSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: luma.accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_add_alt_1_rounded, size: 18, color: luma.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${client.deviceName} wants to connect',
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'It is at ${client.address} and gave the right pairing password.',
            style: TextStyle(color: luma.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              LumaPrimaryButton(
                label: 'Allow',
                icon: Icons.check_rounded,
                onTap: onAllow,
              ),
              const SizedBox(width: 8),
              LumaGhostButton(
                label: 'Refuse',
                icon: Icons.close_rounded,
                onTap: onRefuse,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Who is attached right now, and the way to throw one off.
class _ClientsCard extends StatelessWidget {
  const _ClientsCard({required this.server});

  final SftpHostServer server;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final clients =
        server.clients.where((c) => !c.awaitingApproval).toList();
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            clients.isEmpty
                ? 'No devices connected'
                : '${clients.length} device${clients.length == 1 ? '' : 's'} connected',
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (clients.isEmpty)
            Text(
              'Nothing is reading this folder. It stays shared until you press '
              'Stop or close luma.',
              style: TextStyle(
                color: luma.textMuted,
                fontSize: 12,
                height: 1.4,
              ),
            )
          else
            for (final client in clients) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.devices_rounded,
                      size: 18,
                      color: luma.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            client.deviceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: luma.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${client.address} · '
                            'sent ${formatFileSize(client.bytesSent)} · '
                            'received ${formatFileSize(client.bytesReceived)}',
                            style: TextStyle(
                              color: luma.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    LumaGhostButton(
                      label: 'Disconnect',
                      icon: Icons.link_off_rounded,
                      onTap: () =>
                          unawaited(server.disconnectClient(client.id)),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}

/// The standing explanation of what hosting does and does not expose.
class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_rounded, size: 16, color: luma.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'The two devices agree on a key from the pairing password, then '
              'encrypt everything between them. luma\'s servers are not '
              'involved and never see the folder, the password or the files. '
              'Only the folder you pick is reachable. Hosting keeps running '
              'while luma is open — press Stop when you are done.',
              style: TextStyle(
                color: luma.textSecondary,
                fontSize: 11.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({
    required this.label,
    required this.value,
    required this.onCopy,
    this.monospace = false,
    this.enabled = true,
    this.trailing,
  });

  final String label;
  final String value;
  final Future<void> Function()? onCopy;
  final bool monospace;
  final bool enabled;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        SizedBox(
          width: 128,
          child: Text(
            label,
            style: TextStyle(
              color: luma.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 42,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: luma.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: luma.border),
            ),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: enabled ? luma.textPrimary : luma.textMuted,
                fontSize: monospace ? 14 : 13,
                fontWeight: monospace ? FontWeight.w700 : FontWeight.w500,
                fontFamily: monospace ? 'monospace' : null,
                letterSpacing: monospace ? 0.6 : null,
              ),
            ),
          ),
        ),
        ?trailing,
        IconButton(
          onPressed: onCopy == null ? null : () => unawaited(onCopy!()),
          iconSize: 18,
          tooltip: 'Copy',
          icon: Icon(Icons.copy_rounded, color: luma.textSecondary),
        ),
      ],
    );
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({required this.controller});

  final TextEditingController controller;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final strength = describePasswordStrength(widget.controller.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: luma.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'At least $kMinPairingPasswordLength characters',
            hintStyle: TextStyle(color: luma.textMuted, fontSize: 12.5),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: luma.background,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: luma.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: luma.accent),
            ),
          ),
        ),
        if (widget.controller.text.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            switch (strength) {
              PasswordStrength.tooShort =>
                'Too short — this will be refused.',
              PasswordStrength.weak =>
                'Weak. Anyone who can reach this port could work it out.',
              PasswordStrength.fair => 'Fair. A longer one would be better.',
              PasswordStrength.strong => 'Strong.',
            },
            style: TextStyle(
              color: switch (strength) {
                PasswordStrength.tooShort ||
                PasswordStrength.weak =>
                  luma.danger,
                PasswordStrength.fair => luma.textSecondary,
                PasswordStrength.strong => luma.success,
              },
              fontSize: 11.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          color: context.luma.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      );
}
