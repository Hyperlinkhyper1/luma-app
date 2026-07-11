import 'package:flutter/material.dart';

import '../app/widgets.dart';
import '../theme/luma_theme.dart';
import 'family_api.dart';
import 'family_repository.dart';

/// Shows pending family invites addressed to this account, with Accept /
/// Decline actions. Opened from the top-right inbox icon (see
/// lib/family/inbox_button.dart).
Future<void> showInboxDialog(
  BuildContext context, {
  required FamilyRepository familyRepo,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _InboxDialog(familyRepo: familyRepo),
  );
}

class _InboxDialog extends StatefulWidget {
  const _InboxDialog({required this.familyRepo});
  final FamilyRepository familyRepo;

  @override
  State<_InboxDialog> createState() => _InboxDialogState();
}

class _InboxDialogState extends State<_InboxDialog> {
  final Set<String> _busyIds = {};

  Future<void> _respond(
      String inviteId, Future<void> Function(String) action) async {
    setState(() => _busyIds.add(inviteId));
    try {
      await action(inviteId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(inviteId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return AlertDialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.inbox_rounded, color: luma.accent, size: 20),
          const SizedBox(width: 10),
          Text('Inbox',
              style: TextStyle(
                  color: luma.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: ListenableBuilder(
          listenable: widget.familyRepo,
          builder: (context, _) {
            final invites = widget.familyRepo.pendingInvites;
            if (invites.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: LumaEmptyState(
                  icon: Icons.inbox_rounded,
                  title: 'Nothing here yet',
                  subtitle: 'Family invites will show up here.',
                ),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < invites.length; i++) ...[
                  if (i > 0) Divider(color: luma.border, height: 24),
                  _InviteRow(
                    invite: invites[i],
                    busy: _busyIds.contains(invites[i].id),
                    onAccept: () =>
                        _respond(invites[i].id, widget.familyRepo.acceptInvite),
                    onDecline: () =>
                        _respond(invites[i].id, widget.familyRepo.declineInvite),
                  ),
                ],
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close', style: TextStyle(color: luma.textSecondary)),
        ),
      ],
    );
  }
}

class _InviteRow extends StatelessWidget {
  const _InviteRow({
    required this.invite,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final RemoteIncomingInvite invite;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: luma.accentSubtle,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.diversity_3_rounded, color: luma.accent, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(invite.familyName,
                  style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('Invited by ${invite.inviterEmail}',
                  style: TextStyle(color: luma.textMuted, fontSize: 12)),
              const SizedBox(height: 10),
              Row(
                children: [
                  LumaPrimaryButton(
                    label: 'Accept',
                    loading: busy,
                    onTap: busy ? null : onAccept,
                  ),
                  const SizedBox(width: 8),
                  LumaGhostButton(
                    label: 'Decline',
                    onTap: busy ? null : onDecline,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
