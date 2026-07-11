import 'package:flutter/material.dart';

import '../app/widgets.dart';
import '../family/family_api.dart';
import '../family/family_repository.dart';
import '../family/family_scope.dart';
import '../theme/luma_theme.dart';
import 'family_invite_dialog.dart';

/// Full-screen family management page, navigated to from the account page's
/// "Family" section — mirrors [PlanSelectionPage]'s shell.
class FamilyPage extends StatefulWidget {
  const FamilyPage({super.key});

  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  bool _busy = false;

  void _setBusy(bool value) {
    if (mounted) setState(() => _busy = value);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final familyRepo = FamilyScope.of(context);
    return Scaffold(
      backgroundColor: luma.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: luma.textPrimary),
                    tooltip: 'Back to account',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Family',
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: familyRepo,
                builder: (context, _) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: familyRepo.family == null
                          ? _EmptyFamily(
                              familyRepo: familyRepo,
                              busy: _busy,
                              onBusy: _setBusy,
                            )
                          : _FamilyDetail(
                              familyRepo: familyRepo,
                              busy: _busy,
                              onBusy: _setBusy,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Empty state: create a family -----------------------------------------

class _EmptyFamily extends StatefulWidget {
  const _EmptyFamily({
    required this.familyRepo,
    required this.busy,
    required this.onBusy,
  });
  final FamilyRepository familyRepo;
  final bool busy;
  final ValueChanged<bool> onBusy;

  @override
  State<_EmptyFamily> createState() => _EmptyFamilyState();
}

class _EmptyFamilyState extends State<_EmptyFamily> {
  final _name = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a family name.');
      return;
    }
    widget.onBusy(true);
    setState(() => _error = null);
    try {
      await widget.familyRepo.createFamily(name);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      widget.onBusy(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: luma.accentSubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.diversity_3_rounded, color: luma.accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Start a family',
                        style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('Invite people and share calendar plans together.',
                        style: TextStyle(color: luma.textMuted, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            style: TextStyle(color: luma.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Family name',
              labelStyle: TextStyle(color: luma.textMuted),
              errorText: _error,
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: luma.border),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: luma.accent),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: (_) => widget.busy ? null : _create(),
          ),
          const SizedBox(height: 16),
          LumaPrimaryButton(
            label: 'Create family',
            icon: Icons.add_rounded,
            loading: widget.busy,
            expand: true,
            onTap: widget.busy ? null : _create,
          ),
        ],
      ),
    );
  }
}

// ---- Populated state --------------------------------------------------------

class _FamilyDetail extends StatelessWidget {
  const _FamilyDetail({
    required this.familyRepo,
    required this.busy,
    required this.onBusy,
  });

  final FamilyRepository familyRepo;
  final bool busy;
  final ValueChanged<bool> onBusy;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final family = familyRepo.family!;
    final isOwner = familyRepo.isOwner;
    final myUserId = familyRepo.myUserId;
    final limit = family.slotLimit;
    final used = family.slotsUsed;
    final fraction = limit == null || limit == 0
        ? 0.0
        : (used / limit).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- Header ------------------------------------------------------
        LumaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: luma.accentSubtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.diversity_3_rounded,
                        color: luma.accent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(family.name,
                            style: TextStyle(
                                color: luma.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('$used of ${limit ?? '∞'} slots used',
                            style:
                                TextStyle(color: luma.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 8,
                  backgroundColor: luma.surfaceHover,
                  valueColor: AlwaysStoppedAnimation(
                      fraction >= 1 ? Colors.red.shade400 : luma.accent),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ---- Members -------------------------------------------------------
        Text('Members',
            style: TextStyle(
                color: luma.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        LumaCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < family.members.length; i++) ...[
                if (i > 0) Divider(height: 1, color: luma.border),
                _MemberRow(
                  member: family.members[i],
                  isOwner: isOwner,
                  isSelf: family.members[i].userId == myUserId,
                  busy: busy,
                  onRemove: () => _removeMember(context, family.members[i].userId),
                ),
              ],
            ],
          ),
        ),

        // ---- Pending invites (owner only) ----------------------------------
        if (isOwner) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text('Pending invites',
                    style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
              LumaGhostButton(
                label: 'Invite by email',
                icon: Icons.person_add_alt_1_rounded,
                onTap: busy ? null : () => _invite(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (family.pendingInvites.isEmpty)
            LumaCard(
              child: Text('No pending invites.',
                  style: TextStyle(color: luma.textMuted, fontSize: 13)),
            )
          else
            LumaCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < family.pendingInvites.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: luma.border),
                    _PendingInviteRow(invite: family.pendingInvites[i]),
                  ],
                ],
              ),
            ),
        ],

        const SizedBox(height: 28),

        // ---- Danger zone -----------------------------------------------------
        if (isOwner)
          LumaGhostButton(
            label: 'Delete family',
            icon: Icons.delete_outline_rounded,
            onTap: busy ? null : () => _deleteFamily(context),
          )
        else
          LumaGhostButton(
            label: 'Leave family',
            icon: Icons.logout_rounded,
            onTap: busy ? null : () => _leaveFamily(context),
          ),
      ],
    );
  }

  Future<void> _invite(BuildContext context) async {
    await showFamilyInviteDialog(context, familyRepo: familyRepo);
  }

  Future<void> _removeMember(BuildContext context, String userId) async {
    final confirmed = await _confirm(context,
        title: 'Remove member?',
        message: 'They will lose access to shared events immediately.',
        confirmLabel: 'Remove');
    if (!confirmed) return;
    onBusy(true);
    try {
      await familyRepo.removeMember(userId);
    } catch (e) {
      if (context.mounted) _showError(context, '$e');
    } finally {
      onBusy(false);
    }
  }

  Future<void> _leaveFamily(BuildContext context) async {
    final confirmed = await _confirm(context,
        title: 'Leave family?',
        message: 'You will lose access to shared events.',
        confirmLabel: 'Leave');
    if (!confirmed) return;
    onBusy(true);
    try {
      await familyRepo.leaveFamily();
    } catch (e) {
      if (context.mounted) _showError(context, '$e');
    } finally {
      onBusy(false);
    }
  }

  Future<void> _deleteFamily(BuildContext context) async {
    final confirmed = await _confirm(context,
        title: 'Delete family?',
        message:
            'This removes every member and every shared event. This cannot be undone.',
        confirmLabel: 'Delete');
    if (!confirmed) return;
    onBusy(true);
    try {
      await familyRepo.deleteFamily();
    } catch (e) {
      if (context.mounted) _showError(context, '$e');
    } finally {
      onBusy(false);
    }
  }

  void _showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final luma = context.luma;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: luma.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: TextStyle(
                color: luma.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text(message,
            style: TextStyle(color: luma.textMuted, fontSize: 13, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: luma.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isOwner,
    required this.isSelf,
    required this.busy,
    required this.onRemove,
  });

  final RemoteFamilyMember member;
  final bool isOwner;
  final bool isSelf;
  final bool busy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final roleLabel = member.isOwner ? 'Owner' : (isSelf ? 'You' : 'Member');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: luma.accentSubtle,
            child: Text(
              member.email.isEmpty ? '?' : member.email[0].toUpperCase(),
              style: TextStyle(
                  color: luma.accent, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(member.email,
                style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: luma.surfaceHover,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(roleLabel,
                style: TextStyle(
                    color: luma.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
          if (isOwner && !member.isOwner) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Remove',
              icon: Icon(Icons.close_rounded, size: 18, color: luma.textMuted),
              onPressed: busy ? null : onRemove,
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingInviteRow extends StatelessWidget {
  const _PendingInviteRow({required this.invite});
  final RemoteOutgoingInvite invite;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.mail_outline_rounded, size: 18, color: luma.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(invite.email,
                style: TextStyle(color: luma.textPrimary, fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
          Text('Pending',
              style: TextStyle(
                  color: luma.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
