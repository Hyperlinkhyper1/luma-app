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
    return Dialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight:
              (MediaQuery.of(context).size.height - 48).clamp(280.0, 640.0),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(familyRepo: widget.familyRepo),
              const SizedBox(height: 16),
              Flexible(
                child: ListenableBuilder(
                  listenable: widget.familyRepo,
                  builder: (context, _) {
                    final invites = widget.familyRepo.pendingInvites;
                    if (invites.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: LumaEmptyState(
                            icon: Icons.inbox_rounded,
                            title: 'Nothing here yet',
                            subtitle: 'Family invites will show up here.',
                          ),
                        ),
                      );
                    }
                    return SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < invites.length; i++) ...[
                            if (i > 0) const SizedBox(height: 12),
                            _InviteCard(
                              invite: invites[i],
                              busy: _busyIds.contains(invites[i].id),
                              onAccept: () => _respond(
                                  invites[i].id, widget.familyRepo.acceptInvite),
                              onDecline: () => _respond(invites[i].id,
                                  widget.familyRepo.declineInvite),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child:
                      Text('Close', style: TextStyle(color: luma.textSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.familyRepo});
  final FamilyRepository familyRepo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return ListenableBuilder(
      listenable: familyRepo,
      builder: (context, _) {
        final count = familyRepo.pendingInvites.length;
        return Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: luma.accentSubtle,
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  Icon(Icons.inbox_rounded, color: luma.accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Inbox',
                      style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  if (count > 0)
                    Text('$count pending invite${count == 1 ? '' : 's'}',
                        style: TextStyle(
                            color: luma.textMuted, fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Close',
              icon: Icon(Icons.close_rounded,
                  size: 20, color: luma.textSecondary),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
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
    final created = DateTime.fromMillisecondsSinceEpoch(invite.createdAtMs);
    final expires = DateTime.fromMillisecondsSinceEpoch(invite.expiresAtMs);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: luma.accentSubtle,
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                Icon(Icons.diversity_3_rounded, color: luma.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(invite.familyName,
                    style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: 14, color: luma.textMuted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text('Invited by ${invite.inviterEmail}',
                          style: TextStyle(
                              color: luma.textMuted, fontSize: 12.5),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _MetaItem(
                      icon: Icons.schedule_rounded,
                      label: 'Sent ${_formatDate(created)}',
                    ),
                    _MetaItem(
                      icon: Icons.event_busy_rounded,
                      label: 'Expires ${_formatDate(expires)}',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    LumaPrimaryButton(
                      label: 'Accept',
                      icon: Icons.check_rounded,
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
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: luma.textMuted),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(color: luma.textMuted, fontSize: 11.5)),
      ],
    );
  }
}
