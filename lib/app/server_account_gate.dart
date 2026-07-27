import 'package:flutter/material.dart';

import '../settings/sync_section.dart';
import '../sync/sync_scope.dart';
import '../sync/sync_service.dart';
import '../theme/luma_theme.dart';
import 'widgets.dart';

/// The screen shown in place of anything that needs the luma server while
/// this device has no approved account: nothing here talks to the server, it
/// just explains what's missing and opens the account dialog.
///
/// Three states, driven by [SyncService]:
/// * no account at all → "create one";
/// * an account created here that is still waiting for approval → who we're
///   waiting for, plus a resend button;
/// * an approved account whose session expired → "sign in again".
class ServerAccountRequired extends StatefulWidget {
  const ServerAccountRequired({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.cloud_off_rounded,
  });

  /// What can't run, e.g. "Cloud Files needs an account".
  final String title;

  /// One or two sentences on what this particular feature uses the server
  /// for, so the message isn't the same wall of text everywhere.
  final String description;

  final IconData icon;

  @override
  State<ServerAccountRequired> createState() => _ServerAccountRequiredState();
}

class _ServerAccountRequiredState extends State<ServerAccountRequired> {
  bool _resending = false;
  String? _resendMessage;

  Future<void> _resend(SyncService sync) async {
    setState(() {
      _resending = true;
      _resendMessage = null;
    });
    try {
      final message = await sync.resendApprovalEmail();
      if (mounted) setState(() => _resendMessage = message);
    } catch (e) {
      if (mounted) setState(() => _resendMessage = '$e');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final sync = SyncScope.of(context);

    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        final pending = sync.pendingApprovalEmail;
        final expired = sync.signedIn && !sync.accountApproved;
        return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LumaIconBadge(
                    icon: widget.icon, color: luma.accent, size: 64),
                const SizedBox(height: 20),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  pending != null
                      ? 'Your account ($pending) is waiting to be approved. '
                          'Open the link in the email we sent, then sign in '
                          'here — until it is approved this device does not '
                          'contact the server at all.'
                      : expired
                          ? 'This account is not approved (any more). Once it '
                              'is approved, sign in again to switch this back '
                              'on.'
                          : '${widget.description} Create an account under '
                              'Settings → Sync & account, approve it from the '
                              'email you get, then sign in.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: luma.textMuted, fontSize: 13, height: 1.5),
                ),
                if (_resendMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _resendMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: luma.accent, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    LumaPrimaryButton(
                      label: pending != null ? 'Sign in' : 'Set up account',
                      icon: Icons.person_add_rounded,
                      onTap: () => showAccountSetupDialog(context, sync,
                          initialMode: pending != null ? 0 : 1),
                    ),
                    if (pending != null)
                      LumaGhostButton(
                        label: _resending
                            ? 'Sending…'
                            : 'Resend approval email',
                        icon: Icons.mail_outline_rounded,
                        onTap: _resending ? null : () => _resend(sync),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }
}

/// Wraps a page that cannot work without the server, swapping it for
/// [ServerAccountRequired] until this device has an approved account.
///
/// Used by `AppShell._pluginPageFor` for every plugin the registry marks
/// `requiresAccount`, so a server-only plugin is inert — not merely empty —
/// before an account exists.
class ServerAccountGate extends StatelessWidget {
  const ServerAccountGate({
    super.key,
    required this.title,
    required this.description,
    required this.child,
    this.icon = Icons.cloud_off_rounded,
  });

  final String title;
  final String description;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final sync = SyncScope.of(context);
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) => sync.serverReady
          ? child
          : ServerAccountRequired(
              title: title,
              description: description,
              icon: icon,
            ),
    );
  }
}
