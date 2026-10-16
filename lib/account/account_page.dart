import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/widgets.dart';
import '../family/family_scope.dart';
import '../l10n/app_localizations.dart';
import '../settings/devices_section.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_scope.dart';
import '../settings/sync_section.dart';
import '../storage/storage_guard.dart';
import '../storage/storage_guard_scope.dart';
import '../sync/sync_scope.dart';
import '../sync/sync_service.dart';
import '../theme/luma_theme.dart';
import 'family_page.dart';
import 'loyalty.dart';
import 'loyalty_card.dart';
import 'plan.dart';
import 'plan_selection_page.dart';
import 'stats_section.dart';

/// The sections the Account page's navigation switches between.
enum _AccountSection { profile, sync, storage, plan, family, stats }

/// The Account destination, laid out like a settings screen: a page header,
/// a section list down the left (a swipeable tab strip on phones) and the
/// picked section's cards on the right. Pinned in the nav rail directly
/// below Settings.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  _AccountSection _section = _AccountSection.profile;

  static const _wideBreakpoint = 820.0;

  void _select(_AccountSection section) {
    if (section == _section) return;
    setState(() => _section = section);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideBreakpoint;
        final content = _SectionBody(
          key: ValueKey(_section),
          section: _section,
          onSelect: _select,
        );
        final body = AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          child: content,
        );

        if (!wide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _PageHeader(),
                const SizedBox(height: 16),
                LumaSegmentedTabs(
                  scrollable: true,
                  tabs: [
                    for (final section in _AccountSection.values)
                      _sectionLabel(context, section),
                  ],
                  selectedIndex: _section.index,
                  onSelect: (i) => _select(_AccountSection.values[i]),
                ),
                const SizedBox(height: 20),
                body,
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _PageHeader(),
              const SizedBox(height: 24),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 248,
                      child: _SideNav(
                        selected: _section,
                        onSelect: _select,
                      ),
                    ),
                    const SizedBox(width: 28),
                    Expanded(
                      child: SingleChildScrollView(
                        key: PageStorageKey('account-${_section.name}'),
                        padding: const EdgeInsets.only(bottom: 40),
                        child: body,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _sectionLabel(BuildContext context, _AccountSection section) {
  final t = L.of(context);
  return switch (section) {
    _AccountSection.profile => t.accountTabProfile,
    _AccountSection.sync => t.accountNavSync,
    _AccountSection.storage => t.accountStorageTitle,
    _AccountSection.plan => t.accountPlanTitle,
    _AccountSection.family => t.familyTitle,
    _AccountSection.stats => t.accountTabStats,
  };
}

IconData _sectionIcon(_AccountSection section) => switch (section) {
      _AccountSection.profile => Icons.person_rounded,
      _AccountSection.sync => Icons.cloud_sync_rounded,
      _AccountSection.storage => Icons.storage_rounded,
      _AccountSection.plan => Icons.workspace_premium_rounded,
      _AccountSection.family => Icons.diversity_3_rounded,
      _AccountSection.stats => Icons.insights_rounded,
    };

// ---- Page chrome ------------------------------------------------------------

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.navAccount,
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          t.accountPageSubtitle,
          style: TextStyle(color: luma.textMuted, fontSize: 13),
        ),
      ],
    );
  }
}

class _SideNav extends StatelessWidget {
  const _SideNav({required this.selected, required this.onSelect});

  final _AccountSection selected;
  final ValueChanged<_AccountSection> onSelect;

  @override
  Widget build(BuildContext context) {
    return LumaCard(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final section in _AccountSection.values) ...[
            if (section == _AccountSection.stats) const _NavDivider(),
            _SideNavItem(
              icon: _sectionIcon(section),
              label: _sectionLabel(context, section),
              selected: section == selected,
              onTap: () => onSelect(section),
            ),
          ],
        ],
      ),
    );
  }
}

class _NavDivider extends StatelessWidget {
  const _NavDivider();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Divider(color: context.luma.border, height: 1),
      );
}

class _SideNavItem extends StatefulWidget {
  const _SideNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SideNavItem> createState() => _SideNavItemState();
}

class _SideNavItemState extends State<_SideNavItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;
    final selected = widget.selected;
    final foreground = selected ? luma.accent : luma.textSecondary;
    final shape = decor.buttonShape();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Semantics(
        button: true,
        selected: selected,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: shape,
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: ShapeDecoration(
                  color: selected
                      ? luma.accentSubtle
                      : (_hovering ? luma.surfaceHover : Colors.transparent),
                  shape: shape,
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 3,
                      height: selected ? 18 : 0,
                      decoration: BoxDecoration(
                        color: luma.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(width: selected ? 9 : 0),
                    Icon(widget.icon, size: 18, color: foreground),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        decor.labelText(widget.label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: decor.labelStyle(
                          TextStyle(
                            color: selected ? luma.accent : luma.textPrimary,
                            fontSize: 14,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The title row above a section's cards, the "My Profile" of the page.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: TextStyle(color: luma.textMuted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

/// A card's own heading with an optional action on the right, like
/// "Personal Information ... Edit".
class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ?action,
      ],
    );
  }
}

class _SectionBody extends StatelessWidget {
  const _SectionBody({
    super.key,
    required this.section,
    required this.onSelect,
  });

  final _AccountSection section;
  final ValueChanged<_AccountSection> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final (title, subtitle, children) = switch (section) {
      _AccountSection.profile => (
          t.accountTabProfile,
          t.accountProfileSubtitle,
          <Widget>[
            const _IdentityCard(),
            const SizedBox(height: 16),
            const LoyaltyCard(),
            const SizedBox(height: 16),
            _AccountDetailsCard(
              onManage: () => onSelect(_AccountSection.sync),
            ),
          ],
        ),
      _AccountSection.sync => (
          t.accountNavSync,
          t.accountSyncSubtitle,
          const <Widget>[
            SyncSection(),
            SizedBox(height: 16),
            DevicesSection(),
          ],
        ),
      _AccountSection.storage => (
          t.accountStorageTitle,
          t.accountStorageSubtitle,
          const <Widget>[LocalStorageCard()],
        ),
      _AccountSection.plan => (
          t.accountPlanTitle,
          t.accountPlanSubtitle,
          const <Widget>[_PlanSummary()],
        ),
      _AccountSection.family => (
          t.familyTitle,
          t.accountFamilySubtitle,
          const <Widget>[_FamilySummary()],
        ),
      _AccountSection.stats => (
          t.accountTabStats,
          t.accountStatsSubtitle,
          const <Widget>[StatsSection()],
        ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(title: title, subtitle: subtitle),
        ...children,
      ],
    );
  }
}

// ---- Profile ------------------------------------------------------------

/// Who this account is, at a glance: the photo, the signed-in address, the
/// plan and whether the server has approved the account.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard();

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final sync = SyncScope.of(context);
    final luma = context.luma;
    final t = L.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([settings, sync]),
      builder: (context, _) {
        final path = settings.avatarPath;
        final hasImage = path != null && File(path).existsSync();
        final plan = planById(settings.selectedPlanId);
        final loyalty = loyaltyStatusOf(settings);
        final email = sync.email;
        return LumaCard(
          child: _AdaptiveCardRow(
            spacing: 18,
            leading: _Avatar(
              path: hasImage ? path : null,
              onTap: () => _pickAvatar(settings),
            ),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email == null || email.isEmpty
                      ? t.accountLocalProfile
                      : email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Tag(
                      icon: Icons.workspace_premium_rounded,
                      label: plan.name,
                      color: luma.accent,
                    ),
                    if (loyalty.active)
                      _Tag(
                        icon: loyalty.rank.icon,
                        label: loyalty.rank.name,
                        color: luma.accent,
                      ),
                    _StatusTag(sync: sync),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  t.accountProfilePictureNote,
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ],
            ),
            actionBuilder: (expand) {
              final change = LumaGhostButton(
                label: hasImage ? t.accountChangePhoto : t.accountChoosePhoto,
                icon: Icons.image_rounded,
                expand: expand,
                onTap: () => _pickAvatar(settings),
              );
              if (!hasImage) return change;
              final remove = TextButton(
                onPressed: () => settings.setAvatarPath(null),
                style: TextButton.styleFrom(
                  foregroundColor: luma.textMuted,
                  minimumSize: const Size(48, 44),
                ),
                child: Text(t.commonRemove),
              );
              if (expand) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [change, const SizedBox(height: 4), remove],
                );
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [remove, const SizedBox(width: 4), change],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _pickAvatar(SettingsController settings) async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    if (path != null) settings.setAvatarPath(path);
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.path, required this.onTap});

  final String? path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final image = path;
    return Semantics(
      button: true,
      label: t.accountProfilePicture,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: luma.accent.withValues(alpha: 0.55),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    backgroundColor: luma.accentSubtle,
                    backgroundImage:
                        image != null ? FileImage(File(image)) : null,
                    child: image != null
                        ? null
                        : Icon(
                            Icons.person_rounded,
                            color: luma.accent,
                            size: 34,
                          ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: luma.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: luma.surface, width: 2.5),
                    ),
                    child: Icon(
                      Icons.photo_camera_rounded,
                      size: 13,
                      color: luma.onAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 13, color: color)
          else
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The account's standing on the server, shown as a dot-and-label tag.
class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.sync});

  final SyncService sync;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _accountStatus(context, sync);
    return _Tag(label: label, color: color);
  }
}

(String, Color) _accountStatus(BuildContext context, SyncService sync) {
  final luma = context.luma;
  final t = L.of(context);
  if (sync.signedIn && sync.serverReady) {
    return (t.accountStatusActive, luma.success);
  }
  if (sync.awaitingApproval) return (t.accountStatusPending, luma.warning);
  if (sync.isLocalOnly) return (t.accountStatusLocal, luma.textSecondary);
  return (t.accountNotSignedIn, luma.textMuted);
}

/// The label/value grid under the identity card: everything the account
/// page knows about this account, read-only, with a jump to where it's
/// changed.
class _AccountDetailsCard extends StatelessWidget {
  const _AccountDetailsCard({required this.onManage});

  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final sync = SyncScope.of(context);
    final family = FamilyScope.of(context);
    final luma = context.luma;
    final t = L.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([settings, sync, family]),
      builder: (context, _) {
        final plan = planById(settings.selectedPlanId);
        final account = sync.account;
        final group = family.family;
        final lastSync = sync.lastSyncAt;
        final locale = Localizations.localeOf(context).toString();
        final (status, statusColor) = _accountStatus(context, sync);
        final email = sync.email;
        final fields = <_DetailField>[
          _DetailField(
            label: t.commonEmail,
            value: email == null || email.isEmpty
                ? '—'
                : email,
          ),
          _DetailField(
            label: t.commonStatus,
            value: status,
            dotColor: statusColor,
          ),
          _DetailField(
            label: t.accountPlanTitle,
            value: '${plan.name} · ${plan.priceLabelFor(
              loyal: loyaltyStatusOf(settings).discountUnlocked,
            )}',
          ),
          _DetailField(
            label: t.familyTitle,
            value: group == null
                ? t.accountNoFamilyYet
                : '${group.name} · ${t.familySlotsUsed(
                    group.slotsUsed.toString(),
                    group.slotLimit?.toString() ?? '∞',
                  )}',
          ),
          _DetailField(
            label: t.accountFieldLastSynced,
            value: lastSync == null
                ? t.commonNever
                : DateFormat.yMMMd(locale).add_jm().format(lastSync.toLocal()),
          ),
          _DetailField(
            label: t.accountFieldSyncStorage,
            value: account == null
                ? '—'
                : t.accountStorageOf(
                    StorageGuardService.formatBytes(account.usedBytes),
                    StorageGuardService.formatBytes(account.quotaBytes),
                  ),
          ),
        ];
        return LumaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CardHeader(
                title: t.accountDetailsTitle,
                action: LumaGhostButton(
                  label: t.accountManage,
                  icon: Icons.tune_rounded,
                  onTap: onManage,
                ),
              ),
              const SizedBox(height: 14),
              Divider(color: luma.border, height: 1),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 24.0;
                  final columns = constraints.maxWidth >= 900
                      ? 3
                      : (constraints.maxWidth >= 440 ? 2 : 1);
                  final width =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: 18,
                    children: [
                      for (final field in fields)
                        SizedBox(width: width, child: field),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({
    required this.label,
    required this.value,
    this.dotColor,
  });

  final String label;
  final String value;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final dot = dotColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: luma.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (dot != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---- Storage --------------------------------------------------------------

class LocalStorageCard extends StatefulWidget {
  const LocalStorageCard({super.key});

  @override
  State<LocalStorageCard> createState() => _LocalStorageCardState();
}

class _LocalStorageCardState extends State<LocalStorageCard> {
  bool _expanded = false;
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final guard = StorageGuardScope.of(context);
    final luma = context.luma;
    final t = L.of(context);
    return ListenableBuilder(
      listenable: guard,
      builder: (context, _) {
        final used = guard.usedBytes;
        final decor = context.lumaDecor;
        return Semantics(
          button: true,
          expanded: _expanded,
          label: t.accountLocalStorage,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovering = true),
            onExit: (_) => setState(() => _hovering = false),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey('local-storage-card'),
                borderRadius: decor.cardBorderRadius,
                onTap: () => setState(() => _expanded = !_expanded),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOut,
                  foregroundDecoration: _hovering
                      ? BoxDecoration(
                          color: luma.surfaceHover.withValues(alpha: 0.22),
                          borderRadius: decor.cardBorderRadius,
                          border: Border.all(
                            color: luma.accent.withValues(alpha: 0.45),
                            width: decor.borderWidth,
                          ),
                        )
                      : null,
                  child: LumaCard(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _StorageHeader(
                            used: used,
                            expanded: _expanded,
                          ),
                          if (_expanded) ...[
                            const SizedBox(height: 16),
                            Divider(color: luma.border, height: 1),
                            const SizedBox(height: 14),
                            _StorageBreakdown(
                              categories: guard.breakdown,
                              used: used,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StorageHeader extends StatelessWidget {
  const _StorageHeader({
    required this.used,
    required this.expanded,
  });

  final int used;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final summary = Text(
      t.accountUsedLocally(StorageGuardService.formatBytes(used)),
      style: TextStyle(color: luma.textMuted, fontSize: 12),
      textAlign: TextAlign.end,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final title = Text(
      t.accountLocalStorage,
      style: TextStyle(
        color: luma.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final chevron = AnimatedRotation(
      turns: expanded ? 0.5 : 0,
      duration: const Duration(milliseconds: 150),
      child: Icon(
        Icons.expand_more_rounded,
        size: 20,
        color: luma.textMuted,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [Expanded(child: title), chevron]),
              const SizedBox(height: 4),
              Align(alignment: Alignment.centerRight, child: summary),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: title),
            summary,
            const SizedBox(width: 6),
            chevron,
          ],
        );
      },
    );
  }
}

class _StorageBreakdown extends StatelessWidget {
  const _StorageBreakdown({required this.categories, required this.used});

  final List<StorageCategory> categories;
  final int used;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.accountWhatUsingSpace,
          style: TextStyle(
            color: luma.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        if (categories.isEmpty)
          Text(
            t.accountNothingCounted,
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          )
        else
          for (final category in categories)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _StorageCategoryRow(category: category, used: used),
            ),
      ],
    );
  }
}

class _StorageCategoryRow extends StatelessWidget {
  const _StorageCategoryRow({required this.category, required this.used});

  final StorageCategory category;
  final int used;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final fraction = used <= 0 ? 0.0 : (category.bytes / used).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                category.name,
                style: TextStyle(color: luma.textPrimary, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              StorageGuardService.formatBytes(category.bytes),
              style: TextStyle(color: luma.textMuted, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 5,
            backgroundColor: luma.surfaceHover,
            valueColor: AlwaysStoppedAnimation(luma.accent),
          ),
        ),
      ],
    );
  }
}

// ---- Plan -------------------------------------------------------------------

class _PlanSummary extends StatelessWidget {
  const _PlanSummary();

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final luma = context.luma;
    final t = L.of(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final plan = planById(settings.selectedPlanId);
        final loyal = loyaltyStatusOf(settings).discountUnlocked;
        return LumaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AdaptiveCardRow(
                spacing: 14,
                leading: LumaIconBadge(
                  icon: Icons.workspace_premium_rounded,
                  color: luma.accent,
                  size: 48,
                ),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          plan.name,
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          plan.priceLabelFor(loyal: loyal),
                          style: TextStyle(
                            color: luma.accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (loyal && plan.isPaid)
                          Text(
                            plan.priceLabel,
                            style: TextStyle(
                              color: luma.textMuted,
                              fontSize: 12,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.blurb,
                      style: TextStyle(color: luma.textMuted, fontSize: 12),
                    ),
                  ],
                ),
                actionBuilder: (expand) => LumaGhostButton(
                  label: t.accountChangePlan,
                  icon: Icons.swap_horiz_rounded,
                  expand: expand,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PlanSelectionPage(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Divider(color: luma.border, height: 1),
              const SizedBox(height: 18),
              Text(
                t.accountPlanIncluded,
                style: TextStyle(
                  color: luma.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 20.0;
                  final columns = constraints.maxWidth >= 1000
                      ? 3
                      : (constraints.maxWidth >= 520 ? 2 : 1);
                  final width =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: 12,
                    children: [
                      for (final feature in plan.features)
                        SizedBox(
                          width: width,
                          child: _FeatureLine(text: feature),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: luma.accentSubtle,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_rounded, size: 13, color: luma.accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: luma.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

// ---- Family -----------------------------------------------------------------

class _FamilySummary extends StatelessWidget {
  const _FamilySummary();

  @override
  Widget build(BuildContext context) {
    final familyRepo = FamilyScope.of(context);
    final luma = context.luma;
    final t = L.of(context);
    return ListenableBuilder(
      listenable: familyRepo,
      builder: (context, _) {
        final family = familyRepo.family;
        void openFamily() => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const FamilyPage()));
        final badge = LumaIconBadge(
          icon: Icons.diversity_3_rounded,
          color: luma.accent,
          size: 48,
        );
        if (family == null) {
          return LumaCard(
            child: _AdaptiveCardRow(
              spacing: 14,
              leading: badge,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.accountNoFamilyYet,
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.accountStartFamilyHint,
                    style: TextStyle(color: luma.textMuted, fontSize: 12),
                  ),
                ],
              ),
              actionBuilder: (expand) => LumaPrimaryButton(
                label: t.accountCreateFamily,
                icon: Icons.add_rounded,
                expand: expand,
                onTap: openFamily,
              ),
            ),
          );
        }
        final limit = family.slotLimit;
        return LumaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AdaptiveCardRow(
                spacing: 14,
                leading: badge,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      family.name,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.familySlotsUsed(
                        family.slotsUsed.toString(),
                        limit?.toString() ?? '∞',
                      ),
                      style: TextStyle(color: luma.textMuted, fontSize: 12),
                    ),
                  ],
                ),
                actionBuilder: (expand) => LumaGhostButton(
                  label: t.accountManageFamily,
                  icon: Icons.arrow_forward_rounded,
                  expand: expand,
                  onTap: openFamily,
                ),
              ),
              if (limit != null && limit > 0) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (family.slotsUsed / limit).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: luma.surfaceHover,
                    valueColor: AlwaysStoppedAnimation(luma.accent),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A leading icon/avatar + flexible text column + trailing action button.
///
/// A fixed-width button competing with the text column for space in a plain
/// [Row] is what collapses the text into a near-vertical stack of one word
/// per line on phone-width screens. Below [_narrowBreakpoint] this instead
/// stacks the button under a full-width text row, so the text always keeps
/// its full share of the available width.
class _AdaptiveCardRow extends StatelessWidget {
  const _AdaptiveCardRow({
    required this.leading,
    required this.content,
    required this.actionBuilder,
    this.spacing = 16,
  });

  final Widget leading;
  final Widget content;
  final Widget Function(bool expand) actionBuilder;
  final double spacing;

  static const _narrowBreakpoint = 380.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < _narrowBreakpoint;
        final headerRow = Row(
          children: [
            leading,
            SizedBox(width: spacing),
            Expanded(child: content),
            if (!narrow) actionBuilder(false),
          ],
        );
        if (!narrow) return headerRow;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            headerRow,
            const SizedBox(height: 12),
            actionBuilder(true),
          ],
        );
      },
    );
  }
}
