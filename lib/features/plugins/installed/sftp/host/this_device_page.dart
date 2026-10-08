import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../l10n/current_l.dart';
import '../../../../../theme/luma_theme.dart';
import '../sftp_dialogs.dart';
import 'host_cards.dart';
import 'host_crypto.dart';
import 'host_protocol.dart';
import 'host_server.dart';

/// "This device": everything another device needs to connect *to* this one,
/// on a page that is only open while you are looking at it.
///
/// It is deliberately not the Host tab. The Host tab keeps serving while you
/// wander off to another plugin, because a transfer should not die because
/// you looked at something else. This page makes the opposite promise: the
/// listener starts when the page opens and is torn down the moment it closes
/// — or the moment luma goes to the background — so the window in which this
/// device is reachable is exactly the window in which its credentials are on
/// screen. Anything connected at that point is dropped with it.
///
/// The server here is its own [SftpHostServer] instance, not the page's
/// long-lived one, so closing this screen never stops a share the user
/// started from the Host tab.
class SftpThisDevicePage extends StatefulWidget {
  const SftpThisDevicePage({super.key, this.initialDirectory});

  /// The folder to share instead of the one the page would pick for itself.
  /// Only the tests pass it; the screen otherwise offers Downloads and lets
  /// the user change it.
  final Directory? initialDirectory;

  @override
  State<SftpThisDevicePage> createState() => _SftpThisDevicePageState();
}

class _SftpThisDevicePageState extends State<SftpThisDevicePage>
    with WidgetsBindingObserver {
  final SftpHostServer _server = SftpHostServer();

  /// Generated once for the life of the page rather than per start, so a
  /// folder change or a return from the background does not invalidate the
  /// password someone is halfway through typing on the other device.
  String _password = generatePairingPassword();

  Directory? _directory;
  HostAccess _access = HostAccess.readOnly;
  bool _requireApproval = true;

  List<String> _addresses = const [];
  bool _revealed = false;
  bool _busy = true;

  /// True while hosting is stopped because luma is in the background. The
  /// page restarts it on the way back rather than making the user press
  /// anything.
  bool _suspended = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _server.addListener(_onServerChanged);
    unawaited(_boot());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _server.removeListener(_onServerChanged);
    // Closes the listener and drops every connected device — the whole point
    // of this screen.
    _server.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_suspended) unawaited(_resume());
      case AppLifecycleState.paused ||
          AppLifecycleState.hidden ||
          AppLifecycleState.detached:
        unawaited(_suspend());
      case AppLifecycleState.inactive:
        // Fires for things as small as the notification shade; not worth
        // dropping a transfer over.
        break;
    }
  }

  void _onServerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _boot() async {
    await _loadAddresses();
    final directory = widget.initialDirectory ?? await _defaultDirectory();
    if (!mounted) return;
    setState(() => _directory = directory);
    if (directory == null) {
      setState(() => _busy = false);
      return;
    }
    await _start();
  }

  /// The folder offered without asking. Downloads is what a quick hand-off is
  /// almost always about; Documents is the fallback. Neither existing leaves
  /// the page asking for a folder rather than guessing at the home directory,
  /// which would share far more than the user meant.
  Future<Directory?> _defaultDirectory() async {
    try {
      final home =
          Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
      if (home == null) return null;
      for (final name in const ['Downloads', 'Documents']) {
        final candidate = Directory('$home${Platform.pathSeparator}$name');
        if (await candidate.exists()) return candidate;
      }
    } catch (_) {
      // Fall through: the user picks one.
    }
    return null;
  }

  Future<void> _loadAddresses() async {
    final addresses = await SftpHostServer.localAddresses();
    if (mounted) setState(() => _addresses = addresses);
  }

  Future<void> _start() async {
    final directory = _directory;
    if (directory == null) return;
    if (!await directory.exists()) {
      if (mounted) {
        setState(() {
          _directory = null;
          _busy = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _busy = true);
    await _server.start(
      directory: directory,
      port: kDefaultHostPort,
      password: _password,
      access: _access,
      requireApproval: _requireApproval,
    );
    // The Host tab may already be sitting on the usual port. Rather than
    // making the user pick another, take whatever the OS hands out — the
    // port is on screen either way.
    if (_server.status == HostStatus.failed) {
      await _server.start(
        directory: directory,
        port: 0,
        password: _password,
        access: _access,
        requireApproval: _requireApproval,
      );
    }
    if (!mounted) return;
    setState(() => _busy = false);
    unawaited(_loadAddresses());
  }

  Future<void> _suspend() async {
    if (!_server.isRunning) return;
    await _server.stop();
    if (mounted) setState(() => _suspended = true);
  }

  Future<void> _resume() async {
    if (mounted) setState(() => _suspended = false);
    await _start();
  }

  Future<void> _chooseDirectory() async {
    final picked = await FilePicker.getDirectoryPath(
      dialogTitle: L.of(context).sftpThisDeviceChooseFolderTitle,
    );
    if (picked == null || !mounted) return;
    setState(() => _directory = Directory(picked));
    await _start();
  }

  Future<void> _setAccess(HostAccess access) async {
    if (access == _access) return;
    setState(() => _access = access);
    if (_server.isRunning || _busy) await _start();
  }

  Future<void> _setRequireApproval(bool value) async {
    if (value == _requireApproval) return;
    setState(() => _requireApproval = value);
    if (_server.isRunning || _busy) await _start();
  }

  void _rotatePassword() {
    _server.rotatePassword();
    setState(() {
      _password = _server.password;
      _revealed = false;
    });
    _announce(L.of(context).sftpThisDevicePasswordRotated);
  }

  Future<void> _copy(String value, String what) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    _announce(L.of(context).sftpThisDeviceCopied(what));
  }

  void _announce(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  /// The account name this device runs under. luma-to-luma pairing does not
  /// use it — the pairing password is the whole of the authentication — but
  /// it is what tells two similar-looking machines apart, so it is shown.
  static String get _userName {
    try {
      return Platform.environment['USERNAME'] ??
          Platform.environment['USER'] ??
          currentL.sftpThisDeviceUnknown;
    } catch (_) {
      return currentL.sftpThisDeviceUnknown;
    }
  }

  static String get _deviceName {
    try {
      return Platform.localHostname;
    } catch (_) {
      return currentL.sftpThisDeviceTitle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        surfaceTintColor: Colors.transparent,
        title: Text(t.sftpThisDeviceTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusCard(
                  running: _server.isRunning,
                  busy: _busy,
                  suspended: _suspended,
                  error: _server.error,
                  directory: _directory,
                  onChooseDirectory: _chooseDirectory,
                ),
                const SizedBox(height: 12),
                _CredentialsCard(
                  deviceName: _deviceName,
                  userName: _userName,
                  addresses: _addresses,
                  port: _server.port,
                  password: _password,
                  live: _server.isRunning,
                  revealed: _revealed,
                  onToggleReveal: () => setState(() => _revealed = !_revealed),
                  onCopy: _copy,
                  onRotate: _server.isRunning ? _rotatePassword : null,
                ),
                const SizedBox(height: 12),
                HostStorageAccessCard(directory: _directory?.path),
                if (_server.pendingApproval != null) ...[
                  HostApprovalCard(
                    client: _server.pendingApproval!,
                    onAllow: _server.approvePending,
                    onRefuse: _server.rejectPending,
                  ),
                  const SizedBox(height: 12),
                ],
                _TermsCard(
                  access: _access,
                  requireApproval: _requireApproval,
                  onAccessChanged: (value) => unawaited(_setAccess(value)),
                  onApprovalChanged: (value) =>
                      unawaited(_setRequireApproval(value)),
                ),
                const SizedBox(height: 12),
                HostClientsCard(
                  server: _server,
                  emptyMessage: t.sftpThisDeviceEmptyClients,
                ),
                const SizedBox(height: 12),
                const _LifetimeNote(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Whether this device is reachable right now, and what it is offering.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.running,
    required this.busy,
    required this.suspended,
    required this.error,
    required this.directory,
    required this.onChooseDirectory,
  });

  final bool running;
  final bool busy;
  final bool suspended;
  final String? error;
  final Directory? directory;
  final Future<void> Function() onChooseDirectory;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final (Color dot, String title, String subtitle) = switch ((
      running,
      busy,
      suspended,
      directory == null,
    )) {
      (_, _, _, true) => (
          luma.textMuted,
          t.sftpThisDeviceStatusChooseTitle,
          t.sftpThisDeviceStatusChooseBody,
        ),
      (_, true, _, _) => (
          luma.textMuted,
          t.sftpThisDeviceStatusOpeningTitle,
          t.sftpThisDeviceStatusOpeningBody,
        ),
      (_, _, true, _) => (
          luma.accent,
          t.sftpThisDeviceStatusPausedTitle,
          t.sftpThisDeviceStatusPausedBody,
        ),
      (true, _, _, _) => (
          luma.success,
          t.sftpThisDeviceStatusReachableTitle,
          t.sftpThisDeviceStatusReachableBody,
        ),
      _ => (
          luma.danger,
          t.sftpThisDeviceStatusUnreachableTitle,
          error ?? t.sftpThisDeviceStatusFailedBody,
        ),
    };

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: luma.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            t.sftpThisDeviceFolderLabel,
            style: TextStyle(
              color: luma.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
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
                    directory?.path ?? t.sftpThisDeviceNoFolder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          directory == null ? luma.textMuted : luma.textPrimary,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              LumaGhostButton(
                label: t.sftpThisDeviceChange,
                icon: Icons.folder_open_rounded,
                onTap: () => unawaited(onChooseDirectory()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What to type on the other device.
class _CredentialsCard extends StatelessWidget {
  const _CredentialsCard({
    required this.deviceName,
    required this.userName,
    required this.addresses,
    required this.port,
    required this.password,
    required this.live,
    required this.revealed,
    required this.onToggleReveal,
    required this.onCopy,
    required this.onRotate,
  });

  final String deviceName;
  final String userName;
  final List<String> addresses;
  final int port;
  final String password;

  /// False while nothing is listening — the values are still shown, but the
  /// card says plainly that they will not connect yet.
  final bool live;

  final bool revealed;
  final VoidCallback onToggleReveal;
  final Future<void> Function(String value, String what) onCopy;
  final VoidCallback? onRotate;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final address = addresses.isEmpty ? null : addresses.first;
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.sftpThisDeviceCredentialsTitle,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t.sftpThisDeviceCredentialsHelp,
            style: TextStyle(
              color: luma.textSecondary,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          HostCopyRow(
            label: t.sftpThisDeviceFieldDevice,
            value: deviceName,
            onCopy: () => onCopy(deviceName, t.sftpThisDeviceFieldDeviceName),
          ),
          const SizedBox(height: 10),
          HostCopyRow(
            label: t.sftpThisDeviceFieldUser,
            value: userName,
            onCopy: () => onCopy(userName, t.sftpThisDeviceFieldUserName),
          ),
          const SizedBox(height: 10),
          HostCopyRow(
            label: t.sftpThisDeviceFieldAddress,
            value: address ?? t.sftpThisDeviceNoNetwork,
            monospace: true,
            enabled: address != null,
            onCopy: address == null
                ? null
                : () => onCopy(address, t.sftpThisDeviceFieldAddress),
          ),
          if (addresses.length > 1) ...[
            const SizedBox(height: 4),
            Text(
              t.sftpThisDeviceOtherAddresses(addresses.skip(1).join(', ')),
              style: TextStyle(color: luma.textMuted, fontSize: 11),
            ),
          ],
          const SizedBox(height: 10),
          HostCopyRow(
            label: t.sftpThisDeviceFieldPort,
            value: live ? '$port' : '—',
            monospace: true,
            enabled: live,
            onCopy: live
                ? () => onCopy('$port', t.sftpThisDeviceFieldPort)
                : null,
          ),
          const SizedBox(height: 10),
          HostCopyRow(
            label: t.sftpThisDeviceFieldPassword,
            value: revealed ? password : '••••-••••-••••-••••-••••',
            monospace: true,
            trailing: IconButton(
              onPressed: onToggleReveal,
              iconSize: 18,
              tooltip:
                  revealed ? t.sftpThisDeviceHide : t.sftpThisDeviceShow,
              icon: Icon(
                revealed
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: luma.textSecondary,
              ),
            ),
            onCopy: () => onCopy(password, t.sftpThisDeviceFieldPassword),
          ),
          const SizedBox(height: 6),
          Text(
            t.sftpThisDeviceUserNameNote,
            style: TextStyle(
              color: luma.textMuted,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              LumaGhostButton(
                label: t.sftpThisDeviceNewPassword,
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

/// What a device that gets in is allowed to do.
class _TermsCard extends StatelessWidget {
  const _TermsCard({
    required this.access,
    required this.requireApproval,
    required this.onAccessChanged,
    required this.onApprovalChanged,
  });

  final HostAccess access;
  final bool requireApproval;
  final ValueChanged<HostAccess> onAccessChanged;
  final ValueChanged<bool> onApprovalChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.sftpThisDeviceTermsTitle,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          LumaSegmentedTabs(
            tabs: [t.sftpThisDeviceReadOnly, t.sftpThisDeviceReadWrite],
            selectedIndex: access == HostAccess.readOnly ? 0 : 1,
            onSelect: (index) => onAccessChanged(
              index == 0 ? HostAccess.readOnly : HostAccess.readWrite,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            access == HostAccess.readOnly
                ? t.sftpThisDeviceReadOnlyHelp
                : t.sftpThisDeviceReadWriteHelp,
            style: TextStyle(
              color: luma.textMuted,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SftpCheckRow(
            value: requireApproval,
            label: t.sftpThisDeviceAskApproval,
            subtitle: t.sftpThisDeviceAskApprovalSub,
            onChanged: onApprovalChanged,
          ),
          const SizedBox(height: 8),
          Text(
            t.sftpThisDeviceRestartNote,
            style: TextStyle(
              color: luma.textMuted,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// The standing promise this page makes about how long it lasts.
class _LifetimeNote extends StatelessWidget {
  const _LifetimeNote();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
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
          Icon(Icons.timer_outlined, size: 16, color: luma.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t.sftpThisDeviceLifetimeNote,
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
