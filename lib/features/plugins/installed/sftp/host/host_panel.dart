import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import '../sftp_dialogs.dart';
import 'host_cards.dart';
import 'host_crypto.dart';
import 'host_protocol.dart';
import 'host_server.dart';

/// The "Host" tab: the screen that turns this device into the one others
/// connect to, and shows the address and pairing password they need.
///
/// The hosting itself lives in [SftpHostServer]; this is only its face. The
/// server belongs to the app (see `SftpHostScope`), not to this widget or
/// the page, so a rebuild never restarts a listener and switching to another
/// tab — or another plugin — does not drop a transfer that is in flight.
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
      dialogTitle: L.of(context).sftpHostChooseFolderTitle,
    );
    if (picked == null || !mounted) return;
    setState(() => _directory = Directory(picked));
  }

  Future<void> _start() async {
    final t = L.of(context);
    final directory = _directory;
    if (directory == null) {
      widget.onAnnounce(t.sftpHostChooseFolderFirst);
      return;
    }
    if (!await directory.exists()) {
      widget.onAnnounce(t.sftpHostFolderGone);
      return;
    }

    final port = int.tryParse(_portController.text.trim());
    if (port == null || port < 1024 || port > 65535) {
      widget.onAnnounce(t.sftpHostPickPort);
      return;
    }

    String? password;
    if (_ownPassword) {
      password = _passwordController.text;
      if (password.length < kMinPairingPasswordLength) {
        widget.onAnnounce(
          t.sftpHostPasswordTooShort('$kMinPairingPasswordLength'),
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
    final t = L.of(context);
    await Clipboard.setData(ClipboardData(text: value));
    widget.onAnnounce(t.sftpHostValueCopied(what));
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
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
                    widget.onAnnounce(t.sftpHostPasswordRotated);
                  },
                  onStop: _stop,
                  compact: widget.compact,
                ),
                const SizedBox(height: 12),
                HostStorageAccessCard(directory: server.directory?.path),
                if (server.pendingApproval != null) ...[
                  HostApprovalCard(
                    client: server.pendingApproval!,
                    onAllow: server.approvePending,
                    onRefuse: server.rejectPending,
                  ),
                  const SizedBox(height: 12),
                ],
                HostClientsCard(
                  server: server,
                  emptyMessage: t.sftpHostEmptyClients,
                ),
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
    final t = L.of(context);
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
                      t.sftpHostSetupTitle,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.sftpHostSetupSubtitle,
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
          _Label(t.sftpHostFolderLabel),
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
                    directory?.path ?? t.sftpHostNoFolderChosen,
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
                label: t.sftpHostChoose,
                icon: Icons.folder_open_rounded,
                onTap: onChooseDirectory,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            t.sftpHostFolderNote,
            style: TextStyle(color: luma.textMuted, fontSize: 11.5, height: 1.4),
          ),
          const SizedBox(height: 18),
          _Label(t.sftpHostAccessLabel),
          const SizedBox(height: 6),
          LumaSegmentedTabs(
            tabs: [t.sftpHostAccessReadOnlyTab, t.sftpHostAccessReadWriteTab],
            selectedIndex: access == HostAccess.readOnly ? 0 : 1,
            onSelect: (index) => onAccessChanged(
              index == 0 ? HostAccess.readOnly : HostAccess.readWrite,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            access == HostAccess.readOnly
                ? t.sftpHostAccessReadOnlyHint
                : t.sftpHostAccessReadWriteHint,
            style: TextStyle(color: luma.textMuted, fontSize: 11.5, height: 1.4),
          ),
          const SizedBox(height: 16),
          SftpCheckRow(
            value: requireApproval,
            label: t.sftpHostApprovalToggle,
            subtitle: t.sftpHostApprovalToggleSubtitle,
            onChanged: onApprovalChanged,
          ),
          const SizedBox(height: 4),
          SftpCheckRow(
            value: ownPassword,
            label: t.sftpHostOwnPasswordToggle,
            subtitle: t.sftpHostOwnPasswordSubtitle,
            onChanged: onOwnPasswordChanged,
          ),
          if (ownPassword) ...[
            const SizedBox(height: 10),
            _PasswordField(controller: passwordController),
          ],
          const SizedBox(height: 16),
          _Label(t.sftpHostFieldPort),
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
            label: t.sftpHostStartHosting,
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
    final t = L.of(context);
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
                  t.sftpHostHostingFolder(server.rootName),
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              LumaGhostButton(
                label: t.commonStop,
                icon: Icons.stop_rounded,
                onTap: () => unawaited(onStop()),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            server.access == HostAccess.readOnly
                ? (server.requireApproval
                    ? t.sftpHostAccessReadOnlyApproval
                    : t.sftpHostAccessReadOnlyPassword)
                : (server.requireApproval
                    ? t.sftpHostAccessReadWriteApproval
                    : t.sftpHostAccessReadWritePassword),
            style: TextStyle(color: luma.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 18),
          Text(
            t.sftpHostPairingInstructions,
            style: TextStyle(
              color: luma.textSecondary,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          HostCopyRow(
            label: t.sftpHostFieldAddress,
            value: address ?? t.sftpHostNoNetwork,
            monospace: true,
            enabled: address != null,
            onCopy: address == null
                ? null
                : () => onCopy(address, t.sftpHostFieldAddress),
          ),
          if (addresses.length > 1) ...[
            const SizedBox(height: 4),
            Text(
              t.sftpHostOtherAddresses(addresses.skip(1).join(', ')),
              style: TextStyle(color: luma.textMuted, fontSize: 11),
            ),
          ],
          const SizedBox(height: 10),
          HostCopyRow(
            label: t.sftpHostFieldPort,
            value: '${server.port}',
            monospace: true,
            onCopy: () => onCopy('${server.port}', t.sftpHostFieldPort),
          ),
          const SizedBox(height: 10),
          HostCopyRow(
            label: t.sftpHostFieldPassword,
            value: revealed ? server.password : '••••-••••-••••-••••-••••',
            monospace: true,
            trailing: IconButton(
              onPressed: onToggleReveal,
              iconSize: 18,
              tooltip: revealed ? t.sftpHostHide : t.sftpHostShow,
              icon: Icon(
                revealed
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: luma.textSecondary,
              ),
            ),
            onCopy: () => onCopy(server.password, t.sftpHostFieldPassword),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              LumaGhostButton(
                label: t.sftpHostNewPassword,
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

/// The standing explanation of what hosting does and does not expose.
class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
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
              t.sftpHostSecurityNote,
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

class _PasswordField extends StatefulWidget {
  const _PasswordField({required this.controller});

  final TextEditingController controller;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
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
            hintText: t.sftpHostPasswordHint('$kMinPairingPasswordLength'),
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
              PasswordStrength.tooShort => t.sftpHostPasswordTooShortWarn,
              PasswordStrength.weak => t.sftpHostPasswordWeak,
              PasswordStrength.fair => t.sftpHostPasswordFair,
              PasswordStrength.strong => t.sftpHostPasswordStrong,
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
