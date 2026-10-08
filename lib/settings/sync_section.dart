import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../account/plan.dart';
import '../account/login_page.dart';
import '../account/plan_selection_page.dart';
import '../app/widgets.dart';
import '../l10n/app_localizations.dart';
import '../storage/storage_guard.dart';
import 'settings_scope.dart';
import '../sync/sync_api.dart';
import '../sync/sync_scope.dart';
import '../sync/sync_service.dart';
import '../sync/sync_state.dart';
import '../theme/luma_theme.dart';

/// Shows the sign-in screen. Kept here as the name every call site already
/// uses; the screen itself lives in [showLoginScreen], and its result
/// contract (true only when setup actually completed) is unchanged.
Future<bool> showAccountSetupDialog(
  BuildContext context,
  SyncService sync, {
  int initialMode = 1,
}) =>
    showLoginScreen(context, sync, initialMode: initialMode);

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
    final t = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.syncSettingsHeadline,
          style: TextStyle(
              color: luma.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          t.syncSettingsSignedOutBody,
          style: TextStyle(color: luma.textMuted, fontSize: 12, height: 1.5),
        ),
        if (sync.requiresReauth) ...[
          const SizedBox(height: 10),
          Text(
            t.syncSettingsSessionExpired,
            style: TextStyle(color: Colors.orange.shade400, fontSize: 12),
          ),
        ],
        if (sync.pendingApprovalEmail != null) ...[
          const SizedBox(height: 10),
          _PendingApprovalNotice(sync: sync),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: LumaPrimaryButton(
            label: sync.pendingApprovalEmail == null
                ? t.syncSettingsSetUpAccount
                : sync.pendingApprovalMode == ServerApprovalMode.email
                    ? t.syncSettingsEnterCode
                    : t.commonSignIn,
            icon: Icons.person_add_rounded,
            onTap: () => showAccountSetupDialog(context, sync,
                initialMode: sync.pendingApprovalEmail != null ? 0 : 1),
          ),
        ),
      ],
    );
  }
}

/// Shown while an account created on this device is still waiting to be
/// approved: nothing server-backed works yet, and this is where the user can
/// start over with a different address (or, when the server approves by
/// email rather than by hand, ask for another code).
class _PendingApprovalNotice extends StatefulWidget {
  const _PendingApprovalNotice({required this.sync});
  final SyncService sync;

  @override
  State<_PendingApprovalNotice> createState() => _PendingApprovalNoticeState();
}

class _PendingApprovalNoticeState extends State<_PendingApprovalNotice> {
  bool _busy = false;
  String? _message;

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final message = await widget.sync.resendApprovalEmail();
      if (mounted) setState(() => _message = message);
    } catch (e) {
      if (mounted) setState(() => _message = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final email = widget.sync.pendingApprovalEmail ?? '';
    final byEmail =
        widget.sync.pendingApprovalMode == ServerApprovalMode.email;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          byEmail
              ? t.syncSettingsPendingEmailCode(email)
              : t.syncSettingsPendingApproval(email),
          style: TextStyle(
              color: Colors.orange.shade400, fontSize: 12, height: 1.5),
        ),
        if (_message != null) ...[
          const SizedBox(height: 6),
          Text(_message!,
              style: TextStyle(color: luma.textMuted, fontSize: 12)),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (byEmail)
              LumaGhostButton(
                label: _busy ? t.loginSending : t.syncSettingsResendCode,
                icon: Icons.mail_outline_rounded,
                onTap: _busy ? null : _resend,
              ),
            LumaGhostButton(
              label: t.syncSettingsUseDifferentEmail,
              icon: Icons.close_rounded,
              onTap: () => widget.sync.cancelPendingApproval(),
            ),
          ],
        ),
      ],
    );
  }
}

// ---- Signed in --------------------------------------------------------------

class _SignedInBody extends StatelessWidget {
  const _SignedInBody({required this.sync});
  final SyncService sync;

  /// Names the sign-in methods that reach this account, so someone who once
  /// pressed "Continue with Google" can see it is still wired up — and so
  /// someone who has only ever used a password knows the buttons would work
  /// for them too once the addresses match.
  static String _cloudSubtitle(L t, List<String>? linkedProviders) {
    const names = {'google': 'Google', 'github': 'GitHub'};
    final linked = (linkedProviders ?? const [])
        .map((id) => names[id] ?? id)
        .toList();
    if (linked.isEmpty) return t.syncSettingsSyncedToCloud;
    return t.syncSettingsSyncedToCloudWith(
        linked.join(t.syncSettingsProviderSeparator));
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
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
                        ? _cloudSubtitle(t, account?.linkedProviders)
                        : t.syncSettingsLocalOnly,
                    style: TextStyle(color: luma.textMuted, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
],
              ),
            ),
            const SizedBox(width: 12),
            if (cloud)
              LumaGhostButton(
                label: t.commonSignOut,
                icon: Icons.logout_rounded,
                onTap: () => sync.signOut(),
              )
            else
              LumaGhostButton(
                label: t.syncSettingsBackUpToServer,
                icon: Icons.cloud_upload_rounded,
                onTap: () => showAccountSetupDialog(context, sync),
              ),
          ],
        ),

        // ---- Storage usage ------------------------------------------------
        if (cloud) ...[
          Divider(color: luma.border, height: 32),
          _StorageBar(sync: sync, account: account),
        ],

        // ---- Per-feature toggles -------------------------------------------
        Divider(color: luma.border, height: 32),
        Text(t.syncSettingsWhatSyncs,
            style: TextStyle(
                color: luma.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          t.syncSettingsWhatSyncsBody,
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
                if (isAutomaticSyncCollection(collection.id))
                  Tooltip(
                    message: t.syncSettingsAutomaticTooltip,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded,
                            size: 14, color: luma.textMuted),
                        const SizedBox(width: 6),
                        Text(t.syncSettingsAlwaysOn,
                            style: TextStyle(
                                color: luma.textMuted, fontSize: 12)),
                      ],
                    ),
                  )
                else if (!sync.planAllowsCollection(collection.id))
                  // Shown, but disabled with the reason stated: an option the
                  // plan does not cover should explain itself rather than
                  // silently vanish from the list.
                  Tooltip(
                    message: t.syncSettingsPlanSyncsOn(collection.label,
                        planById(collection.minPlanId!).name),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium_rounded,
                            size: 14, color: luma.accent),
                        const SizedBox(width: 6),
                        Text(
                            t.syncSettingsPlanBadge(
                                planById(collection.minPlanId!).name),
                            style:
                                TextStyle(color: luma.accent, fontSize: 12)),
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
                label: t.syncSettingsSyncNow,
                icon: Icons.sync_rounded,
                loading: sync.status == SyncStatus.syncing,
                onTap: sync.status == SyncStatus.syncing
                    ? null
                    : () => sync.syncNow(),
              ),
              const SizedBox(width: 14),
              if (SettingsScope.of(context).selectedPlanId == 'nova') ...[
                LumaGhostButton(
                  label: t.syncSettingsSyncAll,
                  icon: Icons.cloud_sync_rounded,
                  onTap: sync.status == SyncStatus.syncing
                      ? null
                      : () => sync.enableAllCollections(),
                ),
                const SizedBox(width: 14),
              ],
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
                child: Text(t.syncSettingsChangePassword,
                    style: TextStyle(color: luma.textSecondary, fontSize: 13)),
              ),
              TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _SessionsDialog(sync: sync),
                ),
                child: Text(t.syncSettingsDevicesSignedIn,
                    style: TextStyle(color: luma.textSecondary, fontSize: 13)),
              ),
              const Spacer(),
              // Both routes out of the account sit together, but the
              // irreversible one is last and the only one coloured as danger.
              TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _DataDeletionRequestDialog(sync: sync),
                ),
                child: Text(t.syncSettingsAskDeleteData,
                    style: TextStyle(color: luma.textSecondary, fontSize: 13)),
              ),
              TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _DeleteAccountDialog(sync: sync),
                ),
                child: Text(t.syncSettingsDeleteAccount,
                    style:
                        TextStyle(color: Colors.red.shade400, fontSize: 13)),
              ),
            ],
          ),
          _RecoveryKeyRow(sync: sync),
          _DeletionRequestStatus(sync: sync),
        ] else ...[
          const SizedBox(height: 4),
          Text(
            t.syncSettingsDataSyncsDirectly,
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
      } on SyncPlanRequiredException catch (e) {
        if (context.mounted) {
          await _showPlanRequired(context, e.requiredPlanId, e.label);
        }
      } on SyncLimitExceededException catch (e) {
        if (context.mounted) await _showLimitReached(context, e.limit);
      }
      return;
    }
    final removeRemote = await showDialog<bool>(
      context: context,
      builder: (context) {
        final luma = context.luma;
        final t = L.of(context);
        return AlertDialog(
          backgroundColor: luma.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: luma.border),
          ),
          title: Text(t.syncSettingsStopSyncingTitle(label),
              style: TextStyle(color: luma.textPrimary)),
          content: Text(
            t.syncSettingsStopSyncingBody(label),
            style: TextStyle(color: luma.textSecondary, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.commonCancel,
                  style: TextStyle(color: luma.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(t.syncSettingsKeepOnServer,
                  style: TextStyle(color: luma.accent)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(t.syncSettingsDeleteFromServer,
                  style: TextStyle(color: Colors.red.shade400)),
            ),
          ],
        );
      },
    );
    if (removeRemote == null) return; // cancelled — leave the toggle on
    await sync.disableCollection(id, removeRemote: removeRemote);
  }

  Future<void> _showPlanRequired(
    BuildContext context,
    String requiredPlanId,
    String label,
  ) {
    final luma = context.luma;
    final t = L.of(context);
    final plan = planById(requiredPlanId);
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: luma.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: luma.border),
        ),
        title: Text(t.syncSettingsPlanNeededTitle(plan.name),
            style: TextStyle(color: luma.textPrimary)),
        content: Text(
          t.syncSettingsPlanNeededBody(label, plan.name),
          style: TextStyle(color: luma.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.commonCancel,
                style: TextStyle(color: luma.textSecondary)),
          ),
          LumaPrimaryButton(
            label: t.syncSettingsSeePlans,
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PlanSelectionPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showLimitReached(BuildContext context, int limit) {
    final luma = context.luma;
    final t = L.of(context);
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: luma.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: luma.border),
        ),
        title: Text(t.syncSettingsLimitTitle,
            style: TextStyle(color: luma.textPrimary)),
        content: Text(
          t.syncSettingsLimitBody(limit),
          style: TextStyle(color: luma.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.commonCancel,
                style: TextStyle(color: luma.textSecondary)),
          ),
          LumaPrimaryButton(
            label: t.syncSettingsUpgradePlan,
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

/// One entry in the server storage breakdown: a feature's plain-language
/// name and how many bytes of it are saved on the server.
class _StorageEntry {
  const _StorageEntry({required this.label, required this.icon, required this.bytes});
  final String label;
  final IconData icon;
  final int bytes;
}

class _StorageBar extends StatefulWidget {
  const _StorageBar({required this.sync, required this.account});
  final SyncService sync;
  final RemoteAccount? account;

  @override
  State<_StorageBar> createState() => _StorageBarState();
}

class _StorageBarState extends State<_StorageBar> {
  bool _expanded = false;

  /// Turns the server's per-feature byte counts into the same plain names
  /// shown next to each sync toggle below, so "what's using my storage"
  /// reads the same way as "what syncs from this device" — never a raw
  /// server id like `mind_map` or `qr_codes`.
  List<_StorageEntry> _breakdown() {
    final account = widget.account;
    if (account == null) return const [];
    final knownById = {for (final c in widget.sync.collections) c.id: c};
    final entries = <_StorageEntry>[];
    for (final meta in account.collections.values) {
      if (meta.size <= 0) continue;
      final known = knownById[meta.name];
      entries.add(_StorageEntry(
        label: known?.label ?? _prettifyCollectionId(meta.name),
        icon: known?.icon ?? Icons.storage_rounded,
        bytes: meta.size,
      ));
    }
    entries.sort((a, b) => b.bytes.compareTo(a.bytes));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final account = widget.account;
    final used = account?.usedBytes ?? 0;
    final quota = account?.quotaBytes ?? (10 * 1024 * 1024);
    final fraction = quota == 0 ? 0.0 : (used / quota).clamp(0.0, 1.0);
    final breakdown = _breakdown();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: account == null
              ? null
              : () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              Text(t.syncSettingsStorage,
                  style: TextStyle(
                      color: luma.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                account == null
                    ? t.syncSettingsSyncToSeeUsage
                    : t.syncSettingsUsedOf(
                        StorageGuardService.formatBytes(used),
                        StorageGuardService.formatBytes(quota)),
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
              if (account != null) ...[
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(Icons.expand_more_rounded,
                      size: 18, color: luma.textMuted),
                ),
              ],
            ],
          ),
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
        if (_expanded) ...[
          const SizedBox(height: 12),
          if (breakdown.isEmpty)
            Text(
              t.syncSettingsNothingSavedYet,
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            )
          else
            for (final entry in breakdown)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(entry.icon, size: 16, color: luma.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(entry.label,
                          style:
                              TextStyle(color: luma.textPrimary, fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(StorageGuardService.formatBytes(entry.bytes),
                        style:
                            TextStyle(color: luma.textMuted, fontSize: 12)),
                  ],
                ),
              ),
        ],
      ],
    );
  }
}

/// Fallback name for a server collection id this app build doesn't
/// recognise (e.g. saved by a newer version) — `mind_map` -> `Mind map`.
String _prettifyCollectionId(String id) {
  final words = id.split('_').where((w) => w.isNotEmpty);
  return words
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

class _StatusText extends StatelessWidget {
  const _StatusText({required this.sync});
  final SyncService sync;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final String text;
    Color color = luma.textMuted;
    switch (sync.status) {
      case SyncStatus.syncing:
        text = t.syncSettingsSyncing;
      case SyncStatus.error:
        text = sync.lastError ?? t.syncSettingsSyncFailed;
        color = Colors.red.shade400;
      case SyncStatus.idle:
        final at = sync.lastSyncAt;
        text = at == null
            ? t.syncSettingsNotSyncedYet
            : t.syncSettingsLastSynced(DateFormat('d MMM, HH:mm').format(at));
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
    final t = L.of(context);
    if (_next.text.length < 10) {
      setState(() => _error = t.syncSettingsPasswordTooShort);
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _error = t.syncSettingsPasswordMismatch);
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
    final t = L.of(context);
    return AlertDialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: luma.border),
      ),
      title: Text(t.syncSettingsChangePassword,
          style: TextStyle(color: luma.textPrimary)),
      content: SizedBox(
        width: lumaDialogWidth(context, 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _current,
              enabled: !_busy,
              obscureText: true,
              style: TextStyle(color: luma.textPrimary, fontSize: 14),
              decoration:
                  _fieldDecoration(context, t.syncSettingsCurrentPassword),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _next,
              enabled: !_busy,
              obscureText: true,
              style: TextStyle(color: luma.textPrimary, fontSize: 14),
              decoration: _fieldDecoration(context, t.syncSettingsNewPassword),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              enabled: !_busy,
              obscureText: true,
              style: TextStyle(color: luma.textPrimary, fontSize: 14),
              decoration:
                  _fieldDecoration(context, t.syncSettingsConfirmNewPassword),
            ),
            const SizedBox(height: 12),
            Text(
              t.syncSettingsPasswordReencryptNote,
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
          child: Text(t.commonCancel,
              style: TextStyle(color: luma.textSecondary)),
        ),
        LumaPrimaryButton(
            label: t.syncSettingsChangePassword,
            loading: _busy,
            onTap: _busy ? null : _submit),
      ],
    );
  }
}

/// Whether the account has a recovery key, and the way to make one. Loud
/// while there is none, because then a forgotten password erases the synced
/// data.
class _RecoveryKeyRow extends StatelessWidget {
  const _RecoveryKeyRow({required this.sync});
  final SyncService sync;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final has = sync.hasRecoveryKey;
    final color = has ? luma.accent : luma.warning;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(has ? Icons.verified_user_rounded : Icons.key_off_rounded,
              size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              has
                  ? t.syncSettingsRecoveryKeySetUp
                  : t.syncSettingsRecoveryKeyMissing,
              style: TextStyle(color: luma.textSecondary, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _RecoveryKeyDialog(sync: sync),
            ),
            child: Text(
                has ? t.syncSettingsManage : t.syncSettingsSetUp,
                style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// Creates, replaces or removes the recovery key, and shows a new key the
/// one time it can be shown.
class _RecoveryKeyDialog extends StatefulWidget {
  const _RecoveryKeyDialog({required this.sync});
  final SyncService sync;

  @override
  State<_RecoveryKeyDialog> createState() => _RecoveryKeyDialogState();
}

class _RecoveryKeyDialogState extends State<_RecoveryKeyDialog> {
  bool _busy = false;
  String? _error;
  String? _newKey;

  Future<void> _act(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _create() => _act(() async {
        final key = await widget.sync.createRecoveryKey();
        _newKey = key;
      });

  Future<void> _remove() => _act(() async {
        await widget.sync.removeRecoveryKey();
        if (mounted) Navigator.of(context).pop();
      });

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final has = widget.sync.hasRecoveryKey;
    final key = _newKey;
    final body = TextStyle(color: luma.textSecondary, fontSize: 13, height: 1.4);

    final List<Widget> content;
    final List<Widget> actions;
    if (key != null) {
      content = [
        Text(
          t.syncSettingsRecoveryKeyWriteDown,
          style: body,
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: luma.surfaceHover,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: luma.border),
          ),
          child: SelectableText(
            key,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 15,
              fontFamily: 'monospace',
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          t.syncSettingsRecoveryKeyFooter,
          style: TextStyle(color: luma.textMuted, fontSize: 12),
        ),
      ];
      actions = [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: key));
            if (context.mounted) {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(content: Text(t.syncSettingsRecoveryKeyCopied)),
              );
            }
          },
          child: Text(t.commonCopy,
              style: TextStyle(color: luma.textSecondary)),
        ),
        LumaPrimaryButton(
          label: t.syncSettingsRecoveryKeySaved,
          onTap: () => Navigator.of(context).pop(),
        ),
      ];
    } else {
      content = [
        Text(
          has
              ? t.syncSettingsRecoveryHasKeyBody
              : t.syncSettingsRecoveryNoKeyBody,
          style: body,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
              style: TextStyle(color: Colors.red.shade400, fontSize: 12)),
        ],
      ];
      actions = [
        if (has)
          TextButton(
            onPressed: _busy ? null : _remove,
            child: Text(t.commonRemove,
                style: TextStyle(color: Colors.red.shade400)),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(t.commonCancel,
              style: TextStyle(color: luma.textSecondary)),
        ),
        LumaPrimaryButton(
          label: has
              ? t.syncSettingsMakeNewKey
              : t.syncSettingsCreateRecoveryKey,
          loading: _busy,
          onTap: _busy ? null : _create,
        ),
      ];
    }

    return AlertDialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: luma.border),
      ),
      title: Text(
          key != null
              ? t.syncSettingsYourRecoveryKey
              : t.syncSettingsRecoveryKeyTitle,
          style: TextStyle(color: luma.textPrimary)),
      content: SizedBox(
        width: lumaDialogWidth(context, 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: content,
        ),
      ),
      actions: actions,
    );
  }
}

/// Lists every active cloud session on this account and lets the user
/// revoke ones that aren't the device they're currently using.
class _SessionsDialog extends StatefulWidget {
  const _SessionsDialog({required this.sync});
  final SyncService sync;

  @override
  State<_SessionsDialog> createState() => _SessionsDialogState();
}

class _SessionsDialogState extends State<_SessionsDialog> {
  List<RemoteSession>? _sessions;
  String? _error;
  final _revoking = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final sessions = await widget.sync.listSessions();
      if (mounted) setState(() => _sessions = sessions);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _revoke(RemoteSession session) async {
    setState(() => _revoking.add(session.id));
    try {
      await widget.sync.revokeSession(session.id);
      if (mounted) {
        setState(() => _sessions?.removeWhere((s) => s.id == session.id));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _revoking.remove(session.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return AlertDialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: luma.border),
      ),
      title: Text(t.syncSettingsDevicesSignedInTitle,
          style: TextStyle(color: luma.textPrimary)),
      content: SizedBox(
        width: lumaDialogWidth(context, 420),
        child: _buildBody(luma),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.commonClose,
              style: TextStyle(color: luma.textSecondary)),
        ),
      ],
    );
  }

  Widget _buildBody(LumaPalette luma) {
    final t = L.of(context);
    if (_error != null) {
      return Text(_error!,
          style: TextStyle(color: Colors.red.shade400, fontSize: 13));
    }
    final sessions = _sessions;
    if (sessions == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final session in sessions)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(_iconFor(session.deviceLabel),
                    size: 20, color: luma.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.deviceLabel ?? t.syncSettingsUnknownDevice,
                          style: TextStyle(
                              color: luma.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                      Text(
                        session.isCurrent
                            ? t.syncSettingsThisDevice
                            : t.syncSettingsSignedInOn(DateFormat('d MMM yyyy')
                                .format(session.createdAt)),
                        style:
                            TextStyle(color: luma.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (session.isCurrent)
                  Text(t.syncSettingsCurrentSession,
                      style: TextStyle(color: luma.accent, fontSize: 12))
                else if (_revoking.contains(session.id))
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  TextButton(
                    onPressed: () => _revoke(session),
                    child: Text(t.syncSettingsRevoke,
                        style: TextStyle(
                            color: Colors.red.shade400, fontSize: 13)),
                  ),
              ],
            ),
          ),
        if (sessions.isEmpty)
          Text(t.syncSettingsNoOtherSessions,
              style: TextStyle(color: luma.textMuted, fontSize: 13)),
      ],
    );
  }

  IconData _iconFor(String? deviceLabel) {
    switch (deviceLabel) {
      case 'Android':
      case 'iPhone/iPad':
        return Icons.smartphone_rounded;
      case 'Windows':
      case 'Mac':
      case 'Linux':
        return Icons.computer_rounded;
      default:
        return Icons.devices_other_rounded;
    }
  }
}

/// The strip under the account actions that says where a filed data-deletion
/// request stands. Nothing at all while there is no request — this is not a
/// permanent piece of chrome.
///
/// Read straight off [SyncService.dataDeletionRequest], which rides along with
/// the /account snapshot, so the operator's decision appears on the next sync
/// without this widget polling anything.
class _DeletionRequestStatus extends StatelessWidget {
  const _DeletionRequestStatus({required this.sync});

  final SyncService sync;

  @override
  Widget build(BuildContext context) {
    final request = sync.dataDeletionRequest;
    if (request == null || request.status == DataDeletionRequest.statusAccepted) {
      return const SizedBox.shrink();
    }
    final luma = context.luma;
    final pending = request.isPending;
    final tint = pending ? luma.warning : luma.textMuted;
    final when = DateFormat.yMMMd().add_jm();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tint.withValues(alpha: 0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              pending
                  ? Icons.hourglass_top_rounded
                  : Icons.do_not_disturb_on_outlined,
              size: 16,
              color: tint,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pending
                        ? L.of(context).syncSettingsDeletionPending
                        : L.of(context).syncSettingsDeletionDeclined,
                    style: TextStyle(
                        color: luma.textPrimary, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    pending
                        ? L.of(context).syncSettingsDeletionSentNothingDeleted(
                            when.format(request.createdAt),
                          )
                        : request.adminNote == null
                        ? L.of(context).syncSettingsDeletionDecided(
                            when.format(
                              request.decidedAt ?? request.createdAt,
                            ),
                          )
                        : L.of(context).syncSettingsDeletionDecidedWithNote(
                            when.format(
                              request.decidedAt ?? request.createdAt,
                            ),
                            request.adminNote!,
                          ),
                    style: TextStyle(
                        color: luma.textMuted, fontSize: 12, height: 1.45),
                  ),
                ],
              ),
            ),
            if (pending)
              TextButton(
                onPressed: () => _withdraw(context),
                child: Text(L.of(context).syncSettingsWithdraw,
                    style:
                        TextStyle(color: luma.textSecondary, fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _withdraw(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await sync.cancelDataDeletionRequest();
      messenger?.showSnackBar(SnackBar(
        content: Text(L.of(context).syncSettingsDeletionWithdrawn),
      ));
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

/// Asks the server's operator to delete everything this account has on the
/// server — the route for someone who wants their data gone but wants (or is
/// owed) a human decision rather than the instant, password-confirmed
/// [_DeleteAccountDialog].
///
/// Files a request with the user's reason; it lands in the admin dashboard's
/// Inbox, and nothing is deleted until the operator accepts it.
class _DataDeletionRequestDialog extends StatefulWidget {
  const _DataDeletionRequestDialog({required this.sync});
  final SyncService sync;

  @override
  State<_DataDeletionRequestDialog> createState() =>
      _DataDeletionRequestDialogState();
}

class _DataDeletionRequestDialogState
    extends State<_DataDeletionRequestDialog> {
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.sync.requestDataDeletion(_reason.text.trim());
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          content: Text(L.of(context).syncSettingsRequestSent),
        ));
      }
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
    final t = L.of(context);
    final pending = widget.sync.dataDeletionRequest?.isPending ?? false;

    return AlertDialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: luma.border),
      ),
      title: Text(t.syncSettingsAskDeleteTitle,
          style: TextStyle(color: luma.textPrimary)),
      content: SizedBox(
        width: lumaDialogWidth(context, 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              pending
                  ? t.syncSettingsDeletionPendingBody
                  : t.syncSettingsDeletionRequestBody,
              style: TextStyle(
                  color: luma.textSecondary, fontSize: 14, height: 1.5),
            ),
            if (!pending) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _reason,
                enabled: !_busy,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: luma.textPrimary, fontSize: 14),
                decoration: _fieldDecoration(
                  context,
                  t.syncSettingsDeletionReasonLabel,
                  hint: t.syncSettingsDeletionReasonHint,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Semantics(
                  liveRegion: true,
                  child: Text(_error!,
                      style: TextStyle(
                          color: Colors.red.shade400, fontSize: 12.5)),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(pending ? t.commonClose : t.commonCancel,
              style: TextStyle(color: luma.textSecondary)),
        ),
        if (!pending)
          LumaPrimaryButton(
            label: t.syncSettingsSendRequest,
            loading: _busy,
            onTap: _busy ? null : _submit,
          ),
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
    final t = L.of(context);
    return AlertDialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: luma.border),
      ),
      title: Text(t.syncSettingsDeleteAccountTitle,
          style: TextStyle(color: Colors.red.shade400)),
      content: SizedBox(
        width: lumaDialogWidth(context, 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.syncSettingsDeleteAccountBody,
              style: TextStyle(color: luma.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              enabled: !_busy,
              obscureText: true,
              style: TextStyle(color: luma.textPrimary, fontSize: 14),
              decoration: _fieldDecoration(context, t.commonPassword),
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
          child: Text(t.commonCancel, style: TextStyle(color: luma.textSecondary)),
        ),
        TextButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.red.shade400))
              : Text(t.syncSettingsDeleteForever,
                  style: TextStyle(color: Colors.red.shade400)),
        ),
      ],
    );
  }
}
