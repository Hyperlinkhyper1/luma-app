import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import '../data/minecraft_launcher_database.dart';
import '../logic/microsoft_auth_client.dart';
import '../minecraft_launcher_repository.dart';
import '../minecraft_launcher_scope.dart';
import 'hover_sync_scroll.dart';

class AccountsTab extends StatefulWidget {
  const AccountsTab({super.key});

  @override
  State<AccountsTab> createState() => _AccountsTabState();
}

class _AccountsTabState extends State<AccountsTab> {
  @override
  Widget build(BuildContext context) {
    final repository = MinecraftLauncherScope.of(context);
    final t = L.of(context);
    return HoverSyncScroll(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.minecraftLauncherTabAccounts,
                  style: TextStyle(
                    color: context.luma.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              LumaGhostButton(
                label: t.minecraftLauncherAddOfflineAccount,
                icon: Icons.person_add_alt_rounded,
                onTap: () => _addOfflineAccount(context, repository),
              ),
              const SizedBox(width: 10),
              LumaPrimaryButton(
                label: t.minecraftLauncherSignInMicrosoft,
                icon: Icons.window_rounded,
                onTap: () => _signInMicrosoft(context, repository),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamData(
            stream: repository.watchAccounts(),
            builder: (context, accounts) {
              if (accounts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: LumaEmptyState(
                    icon: Icons.person_outline_rounded,
                    title: t.minecraftLauncherNoAccounts,
                    subtitle: t.minecraftLauncherNoAccountsSubtitle,
                  ),
                );
              }
              return Column(
                children: [
                  for (final account in accounts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AccountCard(
                        account: account,
                        repository: repository,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addOfflineAccount(
    BuildContext context,
    MinecraftLauncherRepository repository,
  ) async {
    final t = L.of(context);
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.minecraftLauncherAddOfflineAccount),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: t.commonUsername),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(t.commonAdd),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await repository.addOfflineAccount(name.trim());
    } on StateError catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _signInMicrosoft(
    BuildContext context,
    MinecraftLauncherRepository repository,
  ) async {
    final t = L.of(context);
    final client = MicrosoftAuthClient();
    if (!client.isConfigured) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(t.minecraftLauncherMicrosoftUnavailable),
          content: Text(t.minecraftLauncherMicrosoftUnavailableBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(t.commonOk),
            ),
          ],
        ),
      );
      return;
    }

    try {
      final device = await client.requestDeviceCode();
      if (!context.mounted) return;

      final navigator = Navigator.of(context);
      var cancelled = false;
      var dialogOpen = true;
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => _DeviceCodeDialog(
            device: device,
            onCancel: () {
              cancelled = true;
              dialogOpen = false;
              Navigator.pop(dialogContext);
            },
          ),
        ).whenComplete(() => dialogOpen = false),
      );
      unawaited(
        launchUrl(
          Uri.parse(device.verificationUri),
          mode: LaunchMode.externalApplication,
        ),
      );

      MicrosoftAuthResult result;
      try {
        result = await client.pollAndSignIn(device);
      } finally {
        // Only close the dialog if it's still up — the user's own Cancel
        // already popped it, and popping again here would remove whatever
        // route sits underneath.
        if (dialogOpen && navigator.canPop()) navigator.pop();
      }
      if (cancelled) return;

      await repository.addOrUpdateMicrosoftAccount(
        username: result.username,
        uuid: result.uuid,
        accessToken: result.mcAccessToken,
        refreshToken: result.msaRefreshToken,
        accessTokenExpiresAt: result.mcAccessTokenExpiresAt,
        avatarUrl: 'https://mc-heads.net/avatar/${result.uuid}/64',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

/// The "go to this URL and enter this code" dialog shown for the duration of
/// the device-code poll. Closed externally by the caller once the sign-in
/// future settles (see `_signInMicrosoft`); [onCancel] is only the user's
/// own cancel button.
class _DeviceCodeDialog extends StatelessWidget {
  const _DeviceCodeDialog({required this.device, required this.onCancel});
  final DeviceCodeInfo device;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return AlertDialog(
      title: Text(t.minecraftLauncherSignInMicrosoft),
      content: SizedBox(
        width: lumaDialogWidth(context, 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.minecraftLauncherDeviceCodeInstructions),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    device.userCode,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: t.minecraftLauncherCopyCode,
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: device.userCode),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t.minecraftLauncherCodeCopied)),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(t.minecraftLauncherWaitingForBrowser),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(device.verificationUri),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_browser_rounded),
              label: Text(t.minecraftLauncherOpenMicrosoftSignIn),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: onCancel, child: Text(t.commonCancel))],
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account, required this.repository});
  final McAccount account;
  final MinecraftLauncherRepository repository;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return LumaCard(
      child: Row(
        children: [
          LumaIconBadge(
            icon: account.type == 'microsoft'
                ? Icons.window_rounded
                : Icons.person_rounded,
            color: luma.accent,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.username,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  account.type == 'microsoft'
                      ? t.minecraftLauncherMicrosoftAccount
                      : t.minecraftLauncherOfflineAccount,
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (account.isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: luma.accentSubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                t.minecraftLauncherActive,
                style: TextStyle(
                  color: luma.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            TextButton(
              onPressed: () => repository.setActiveAccount(account.id),
              child: Text(t.minecraftLauncherUseAccount),
            ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: luma.textMuted),
            onPressed: () => repository.deleteAccount(account.id),
          ),
        ],
      ),
    );
  }
}
