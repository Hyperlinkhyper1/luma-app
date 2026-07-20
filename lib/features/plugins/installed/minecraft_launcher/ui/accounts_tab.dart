import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../data/minecraft_launcher_database.dart';
import '../logic/launcher_settings_store.dart';
import '../logic/microsoft_auth_client.dart';
import '../minecraft_launcher_repository.dart';
import '../minecraft_launcher_scope.dart';

class AccountsTab extends StatefulWidget {
  const AccountsTab({super.key});

  @override
  State<AccountsTab> createState() => _AccountsTabState();
}

class _AccountsTabState extends State<AccountsTab> {
  @override
  Widget build(BuildContext context) {
    final repository = MinecraftLauncherScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Accounts',
                style: TextStyle(
                  color: context.luma.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            LumaGhostButton(
              label: 'Add offline account',
              icon: Icons.person_add_alt_rounded,
              onTap: () => _addOfflineAccount(context, repository),
            ),
            const SizedBox(width: 10),
            LumaPrimaryButton(
              label: 'Sign in with Microsoft',
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
              return const Padding(
                padding: EdgeInsets.only(top: 60),
                child: LumaEmptyState(
                  icon: Icons.person_outline_rounded,
                  title: 'No accounts yet',
                  subtitle: 'Add an offline profile to start playing right away, '
                      'or sign in with Microsoft for online-mode servers.',
                ),
              );
            }
            return Column(
              children: [
                for (final account in accounts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AccountCard(account: account, repository: repository),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _addOfflineAccount(
      BuildContext context, MinecraftLauncherRepository repository) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add offline account'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Username'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    await repository.addOfflineAccount(name.trim());
  }

  Future<void> _signInMicrosoft(
      BuildContext context, MinecraftLauncherRepository repository) async {
    var clientId = await LauncherSettingsStore.getMicrosoftClientId();
    if (clientId == null || clientId.isEmpty) {
      if (!context.mounted) return;
      clientId = await _promptClientId(context);
      if (clientId == null || clientId.isEmpty) return;
      await LauncherSettingsStore.setMicrosoftClientId(clientId);
    }

    final client = MicrosoftAuthClient(clientId);
    if (!context.mounted) return;

    try {
      final device = await client.requestDeviceCode();
      if (!context.mounted) return;

      final navigator = Navigator.of(context);
      var cancelled = false;
      var dialogOpen = true;
      unawaited(showDialog<void>(
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
      ).whenComplete(() => dialogOpen = false));

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

  Future<String?> _promptClientId(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Microsoft sign-in needs an Azure app'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Online-mode sign-in requires your own free Azure AD (Entra ID) '
                'app registration — Mojang does not let third-party launchers '
                'reuse its own client ID. Create a public-client app with the '
                '"XboxLive.signin offline_access" scope, then paste its '
                'Application (client) ID below.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Application (client) ID'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
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
    return AlertDialog(
      title: const Text('Sign in with Microsoft'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Go to ${device.verificationUri} and enter this code:'),
            const SizedBox(height: 12),
            SelectableText(
              device.userCode,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 2),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 10),
                Expanded(child: Text('Waiting for you to finish in the browser…')),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: onCancel, child: const Text('Cancel')),
      ],
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
    return LumaCard(
      child: Row(
        children: [
          LumaIconBadge(
            icon: account.type == 'microsoft' ? Icons.window_rounded : Icons.person_rounded,
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
                  account.type == 'microsoft' ? 'Microsoft account' : 'Offline account',
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
                'Active',
                style: TextStyle(color: luma.accent, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            )
          else
            TextButton(
              onPressed: () => repository.setActiveAccount(account.id),
              child: const Text('Use this account'),
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
