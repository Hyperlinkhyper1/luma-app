import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../account/plan_selection_page.dart';
import '../app/widgets.dart';
import '../sync/sync_api.dart';
import '../sync/sync_scope.dart';
import '../sync/sync_service.dart';
import '../theme/luma_theme.dart';

/// Shows the account setup/sign-in dialog. Used both from the Settings page
/// and as the app-wide first-run / re-authentication prompt (see
/// `maybePromptAccountSetup` in main.dart).
Future<void> showAccountSetupDialog(
  BuildContext context,
  SyncService sync, {
  int initialMode = 1,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _AccountDialog(sync: sync, initialMode: initialMode),
  );
}

/// The "Sync & account" block on the Settings page: account sign-in, storage
/// usage against the quota, and per-feature toggles (all off by default).
class SyncSection extends StatelessWidget {
  const SyncSection({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = SyncScope.of(context);
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) => LumaCard(
        child: sync.p2pReady
            ? _SignedInBody(sync: sync)
            : _SignedOutBody(sync: sync),
      ),
    );
  }
}

// ---- Signed out -------------------------------------------------------------

class _SignedOutBody extends StatelessWidget {
  const _SignedOutBody({required this.sync});
  final SyncService sync;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Keep your stuff on every device',
          style: TextStyle(
              color: luma.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Set up an account to sync features between devices. Just an '
          'email and password — no server needed. Everything is encrypted '
          'on this device before it leaves; nothing is synced until you turn '
          'it on per feature.',
          style: TextStyle(color: luma.textMuted, fontSize: 12, height: 1.5),
        ),
        if (sync.requiresReauth) ...[
          const SizedBox(height: 10),
          Text(
            'Your cloud session expired — please sign in again.',
            style: TextStyle(color: Colors.orange.shade400, fontSize: 12),
          ),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: LumaPrimaryButton(
            label: 'Set up account',
            icon: Icons.person_add_rounded,
            onTap: () => showAccountSetupDialog(context, sync),
          ),
        ),
      ],
    );
  }
}

// ---- Signed in --------------------------------------------------------------

class _SignedInBody extends StatelessWidget {
  const _SignedInBody({required this.sync});
  final SyncService sync;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final account = sync.account;
    final cloud = sync.signedIn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            LumaIconBadge(
                icon: cloud ? Icons.cloud_done_rounded : Icons.wifi_rounded,
                color: luma.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sync.email ?? '',
                      style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  Text(
                    cloud
                        ? (sync.serverUrl ?? '')
                        : 'Local only — syncs directly between your devices, '
                            'no server',
                    style: TextStyle(color: luma.textMuted, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (cloud)
              LumaGhostButton(
                label: 'Sign out',
                icon: Icons.logout_rounded,
                onTap: () => sync.signOut(),
              )
            else
              LumaGhostButton(
                label: 'Back up to a server…',
                icon: Icons.cloud_upload_rounded,
                onTap: () => showAccountSetupDialog(context, sync),
              ),
          ],
        ),

        // ---- Storage usage ------------------------------------------------
        if (cloud) ...[
          Divider(color: luma.border, height: 32),
          _StorageBar(account: account),
        ],

        // ---- Per-feature toggles -------------------------------------------
        Divider(color: luma.border, height: 32),
        Text('What syncs from this device',
            style: TextStyle(
                color: luma.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          'Everything is off by default. Only what you switch on here leaves '
          'this device — encrypted with your password before upload. When '
          'you first enable a feature that already has synced data, the '
          'server copy replaces this device\'s copy.',
          style: TextStyle(color: luma.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        for (final collection in sync.collections)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(collection.icon, size: 18, color: luma.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(collection.label,
                      style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                ),
                if (collection.id == 'settings')
                  Tooltip(
                    message: 'Theme and preferences always sync — this '
                        'can\'t be turned off.',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded,
                            size: 14, color: luma.textMuted),
                        const SizedBox(width: 6),
                        Text('Always on',
                            style: TextStyle(
                                color: luma.textMuted, fontSize: 12)),
                      ],
                    ),
                  )
                else
                  Switch(
                    value: sync.isEnabled(collection.id),
                    onChanged: (enabled) => _onToggle(
                        context, collection.id, collection.label, enabled),
                    activeThumbColor: luma.onAccent,
                    activeTrackColor: luma.accent,
                    inactiveThumbColor: luma.textSecondary,
                    inactiveTrackColor: luma.surfaceHover,
                  ),
              ],
            ),
          ),

        // ---- Actions & status ----------------------------------------------
        if (cloud) ...[
          Divider(color: luma.border, height: 32),
          Row(
            children: [
              LumaPrimaryButton(
                label: 'Sync now',
                icon: Icons.sync_rounded,
                loading: sync.status == SyncStatus.syncing,
                onTap: sync.status == SyncStatus.syncing
                    ? null
                    : () => sync.syncNow(),
              ),
              const SizedBox(width: 14),
              Expanded(child: _StatusText(sync: sync)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _ChangePasswordDialog(sync: sync),
                ),
                child: Text('Change password',
                    style: TextStyle(color: luma.textSecondary, fontSize: 13)),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _DeleteAccountDialog(sync: sync),
                ),
                child: Text('Delete account…',
                    style:
                        TextStyle(color: Colors.red.shade400, fontSize: 13)),
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 4),
          Text(
            'This data syncs directly with paired devices — see Devices '
            'below to connect one and turn it off.',
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Future<void> _onToggle(BuildContext context, String id, String label,
      bool enabled) async {
    if (enabled) {
      try {
        await sync.enableCollection(id);
      } on SyncLimitExceededException catch (e) {
        if (context.mounted) await _showLimitReached(context, e.limit);
      }
      return;
    }
    final removeRemote = await showDialog<bool>(
      context: context,
      builder: (context) {
        final luma = context.luma;
        return AlertDialog(
          backgroundColor: luma.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: luma.border),
          ),
          title: Text('Stop syncing $label?',
              style: TextStyle(color: luma.textPrimary)),
          content: Text(
            'This device stops uploading $label. Do you also want to delete '
            'the copy stored on the server? (Other devices that still sync '
            '$label may upload it again.)',
            style: TextStyle(color: luma.textSecondary, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel',
                  style: TextStyle(color: luma.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child:
                  Text('Keep on server', style: TextStyle(color: luma.accent)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Delete from server',
                  style: TextStyle(color: Colors.red.shade400)),
            ),
          ],
        );
      },
    );
    if (removeRemote == null) return; // cancelled — leave the toggle on
    await sync.disableCollection(id, removeRemote: removeRemote);
  }

  Future<void> _showLimitReached(BuildContext context, int limit) {
    final luma = context.luma;
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: luma.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: luma.border),
        ),
        title:
            Text('Sync limit reached', style: TextStyle(color: luma.textPrimary)),
        content: Text(
          'Your plan allows syncing up to $limit feature${limit == 1 ? '' : 's'} '
          'to the server at once. Turn one off, or upgrade your plan to sync '
          'more.',
          style: TextStyle(color: luma.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
          ),
          LumaPrimaryButton(
            label: 'Upgrade plan',
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PlanSelectionPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StorageBar extends StatelessWidget {
  const _StorageBar({required this.account});
  final RemoteAccount? account;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final used = account?.usedBytes ?? 0;
    final quota = account?.quotaBytes ?? (3 * 1024 * 1024 * 1024);
    final fraction = quota == 0 ? 0.0 : (used / quota).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Storage',
                style: TextStyle(
                    color: luma.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
              account == null
                  ? 'Sync to see usage'
                  : '${formatBytes(used)} of ${formatBytes(quota)} used',
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: luma.surfaceHover,
            valueColor: AlwaysStoppedAnimation(
                fraction > 0.9 ? Colors.red.shade400 : luma.accent),
          ),
        ),
      ],
    );
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({required this.sync});
  final SyncService sync;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final String text;
    Color color = luma.textMuted;
    switch (sync.status) {
      case SyncStatus.syncing:
        text = 'Syncing…';
      case SyncStatus.error:
        text = sync.lastError ?? 'Sync failed.';
        color = Colors.red.shade400;
      case SyncStatus.idle:
        final at = sync.lastSyncAt;
        text = at == null
            ? 'Not synced yet.'
            : 'Last synced ${DateFormat('d MMM, HH:mm').format(at)}';
    }
    return Text(text,
        style: TextStyle(color: color, fontSize: 12),
        maxLines: 3,
        overflow: TextOverflow.ellipsis);
  }
}

// ---- Dialogs ----------------------------------------------------------------

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

class _AccountDialog extends StatefulWidget {
  const _AccountDialog({required this.sync, this.initialMode = 1});
  final SyncService sync;

  /// 0 = sign in (cloud), 1 = create account (cloud).
  final int initialMode;

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  // Server address is always prefilled — from a previously-used one if this
  // device has it, otherwise the built-in default — so it's rare anyone has
  // to type it in.
  // There is only one luma sync server; its address is a fixed constant, not
  // something read from (possibly stale, device-specific) saved state.
  final _server = TextEditingController(text: kDefaultSyncServerUrl);
  late final _email = TextEditingController(text: widget.sync.email ?? '');
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  // true = cloud mode (server field visible, sign in / register tabs).
  // false = local mode (no server, just setLocalAccount).
  bool _cloudMode = true;

  late int _mode = widget.initialMode;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _server.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // ---- Common validation ------------------------------------------------
    if (_email.text.trim().isEmpty || !_email.text.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (_password.text.length < 10) {
      setState(() => _error =
          'Use at least 10 characters — this password protects your '
          'encrypted data.');
      return;
    }
    if (!_cloudMode && _password.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (_cloudMode && _mode == 1 && _password.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (_cloudMode && _mode == 0 && _password.text.isEmpty) {
      setState(() => _error = 'Enter your password.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      if (_cloudMode) {
        // ---- Cloud path -------------------------------------------------
        final urlError = SyncApi.validateServerUrl(_server.text);
        if (urlError != null) {
          setState(() {
            _busy = false;
            _error = urlError;
          });
          return;
        }
        if (_mode == 0) {
          await widget.sync.signIn(
            serverUrl: _server.text,
            email: _email.text,
            password: _password.text,
          );
        } else {
          final pendingMessage = await widget.sync.register(
            serverUrl: _server.text,
            email: _email.text,
            password: _password.text,
          );
          if (pendingMessage != null) {
            // Account created but not signed in yet — needs email
            // verification first. Stay on the dialog and switch to Sign in
            // so the user can come back once they've verified.
            if (mounted) {
              setState(() {
                _busy = false;
                _mode = 0;
                _info = pendingMessage;
              });
            }
            return;
          }
        }
      } else {
        // ---- Local (serverless) path ------------------------------------
        await widget.sync.setLocalAccount(
          email: _email.text,
          password: _password.text,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
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
      title: Text(_cloudMode
          ? (_mode == 0 ? 'Sign in' : 'Create account')
          : 'Set up account',
          style: TextStyle(color: luma.textPrimary)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_cloudMode) ...[
                LumaSegmentedTabs(
                  tabs: const ['Sign in', 'Create account'],
                  selectedIndex: _mode,
                  onSelect: (i) => setState(() {
                    _mode = i;
                    _error = null;
                    _info = null;
                  }),
                ),
                const SizedBox(height: 16),
              ] else
                Text(
                  'Enter an email and password. Use the exact same ones on '
                  'every device you want to pair — they never leave this '
                  'device or touch a server.',
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),

              if (_cloudMode)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() {
                        _cloudMode = false;
                        _error = null;
                        _info = null;
                      }),
                      icon: Icon(Icons.wifi_rounded,
                          size: 16, color: luma.textMuted),
                      label: Text('No server? Use local-only sync instead',
                          style:
                              TextStyle(color: luma.textMuted, fontSize: 12)),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: LumaGhostButton(
                      label: 'Use a cloud server instead',
                      icon: Icons.cloud_rounded,
                      onTap: () => setState(() => _cloudMode = true),
                    ),
                  ),
                ),

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
                onSubmitted: (_) =>
                    _cloudMode && _mode == 0 ? _submit() : null,
              ),
              // Confirm field: always shown for local mode and cloud register.
              if (!_cloudMode || _mode == 1) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _confirm,
                  enabled: !_busy,
                  obscureText: true,
                  style:
                      TextStyle(color: luma.textPrimary, fontSize: 14),
                  decoration: _fieldDecoration(context, 'Confirm password'),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                'Your password encrypts everything before it leaves this '
                'device. If you forget it, your synced data cannot be '
                'recovered — there is no reset.',
                style: TextStyle(
                    color: Colors.orange.shade400, fontSize: 12, height: 1.4),
              ),
              if (_info != null) ...[
                const SizedBox(height: 12),
                Text(_info!,
                    style: TextStyle(color: luma.accent, fontSize: 12)),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style:
                        TextStyle(color: Colors.red.shade400, fontSize: 12)),
              ],
              if (_busy) ...[
                const SizedBox(height: 12),
                Text('Securing your account… this can take a few seconds.',
                    style: TextStyle(color: luma.textMuted, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child:
              Text('Cancel', style: TextStyle(color: luma.textSecondary)),
        ),
        LumaPrimaryButton(
          label: _cloudMode
              ? (_mode == 0 ? 'Sign in' : 'Create account')
              : 'Set up',
          loading: _busy,
          onTap: _busy ? null : _submit,
        ),
      ],
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.sync});
  final SyncService sync;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_next.text.length < 10) {
      setState(() => _error = 'Use at least 10 characters.');
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _error = 'New passwords do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.sync.changePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
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
          Text('Change password', style: TextStyle(color: luma.textPrimary)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _current,
              enabled: !_busy,
              obscureText: true,
              style: TextStyle(color: luma.textPrimary, fontSize: 14),
              decoration: _fieldDecoration(context, 'Current password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _next,
              enabled: !_busy,
              obscureText: true,
              style: TextStyle(color: luma.textPrimary, fontSize: 14),
              decoration: _fieldDecoration(context, 'New password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              enabled: !_busy,
              obscureText: true,
              style: TextStyle(color: luma.textPrimary, fontSize: 14),
              decoration: _fieldDecoration(context, 'Confirm new password'),
            ),
            const SizedBox(height: 12),
            Text(
              'All synced data is re-encrypted with the new password. Other '
              'devices will ask you to sign in again.',
              style: TextStyle(color: luma.textMuted, fontSize: 12),
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
            label: 'Change password',
            loading: _busy,
            onTap: _busy ? null : _submit),
      ],
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.sync});
  final SyncService sync;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.sync.deleteAccount(password: _password.text);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
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
      title: Text('Delete account?',
          style: TextStyle(color: Colors.red.shade400)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'This permanently deletes your account and every synced '
              'snapshot from the server. Data on your devices is not '
              'touched. Enter your password to confirm.',
              style: TextStyle(color: luma.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              enabled: !_busy,
              obscureText: true,
              style: TextStyle(color: luma.textPrimary, fontSize: 14),
              decoration: _fieldDecoration(context, 'Password'),
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
        TextButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.red.shade400))
              : Text('Delete forever',
                  style: TextStyle(color: Colors.red.shade400)),
        ),
      ],
    );
  }
}
