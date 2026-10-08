import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app/widgets.dart';
import '../family/family_scope.dart';
import '../l10n/app_localizations.dart';
import '../settings/devices_section.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_scope.dart';
import '../settings/sync_section.dart';
import '../storage/storage_guard.dart';
import '../storage/storage_guard_scope.dart';
import '../theme/luma_theme.dart';
import 'family_page.dart';
import 'plan.dart';
import 'plan_selection_page.dart';
import 'stats_section.dart';

/// The Account destination: a Profile tab (profile picture, sync & paired
/// devices, storage, plan and family) and a Stats tab (lifetime totals and
/// the travel map). Pinned in the nav rail directly below Settings.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: LumaSegmentedTabs(
                  tabs: [t.accountTabProfile, t.accountTabStats],
                  selectedIndex: _tab,
                  onSelect: (index) => setState(() => _tab = index),
                ),
              ),
              const SizedBox(height: 20),
              if (_tab == 0) const _ProfileTab() else const StatsSection(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- Profile ------------------------------------------------
        _SectionHeader(
          icon: Icons.person_rounded,
          title: t.accountTabProfile,
          subtitle: t.accountProfileSubtitle,
        ),
        const SizedBox(height: 12),
        const _ProfileSection(),

        const SizedBox(height: 24),

        // ---- Sync & account (collapsible) ----------------------------
        LumaCollapsibleSection(
          icon: Icons.cloud_sync_rounded,
          title: t.accountSyncTitle,
          subtitle: t.accountSyncSubtitle,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SyncSection(),
              SizedBox(height: 16),
              DevicesSection(),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ---- Storage --------------------------------------------------
        _SectionHeader(
          icon: Icons.storage_rounded,
          title: t.accountStorageTitle,
          subtitle: t.accountStorageSubtitle,
        ),
        const SizedBox(height: 12),
        const LocalStorageCard(),

        const SizedBox(height: 24),

        // ---- Plan -------------------------------------------------------
        _SectionHeader(
          icon: Icons.workspace_premium_rounded,
          title: t.accountPlanTitle,
          subtitle: t.accountPlanSubtitle,
        ),
        const SizedBox(height: 12),
        const _PlanSummary(),

        const SizedBox(height: 24),

        // ---- Family -------------------------------------------------------
        _SectionHeader(
          icon: Icons.diversity_3_rounded,
          title: t.familyTitle,
          subtitle: t.accountFamilySubtitle,
        ),
        const SizedBox(height: 12),
        const _FamilySummary(),
      ],
    );
  }
}

// ---- Profile ------------------------------------------------------------

class _ProfileSection extends StatelessWidget {
  const _ProfileSection();

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final luma = context.luma;
    final t = L.of(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final path = settings.avatarPath;
        final hasImage = path != null && File(path).existsSync();
        return LumaCard(
          child: _AdaptiveCardRow(
            leading: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _pickAvatar(settings),
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: luma.accentSubtle,
                  backgroundImage: hasImage ? FileImage(File(path)) : null,
                  child: hasImage
                      ? null
                      : Icon(
                          Icons.person_rounded,
                          color: luma.accent,
                          size: 32,
                        ),
                ),
              ),
            ),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.accountProfilePicture,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t.accountProfilePictureNote,
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ],
            ),
            actionBuilder: (expand) => LumaGhostButton(
              label: hasImage ? t.accountChangePhoto : t.accountChoosePhoto,
              icon: Icons.image_rounded,
              expand: expand,
              onTap: () => _pickAvatar(settings),
            ),
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
        return LumaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Plan header row ------------------------------------------
              _AdaptiveCardRow(
                spacing: 14,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: luma.accentSubtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: luma.accent,
                    size: 22,
                  ),
                ),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plan.priceLabel,
                      style: TextStyle(
                        color: luma.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
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
              const SizedBox(height: 16),
              Divider(color: luma.border, height: 1),
              const SizedBox(height: 16),
              // ---- Feature pills -------------------------------------------
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final feature in plan.features)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: luma.accentSubtle,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: luma.accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            feature,
                            style: TextStyle(
                              color: luma.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
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
        if (family == null) {
          return LumaCard(
            child: _AdaptiveCardRow(
              spacing: 14,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: luma.accentSubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.diversity_3_rounded,
                  color: luma.accent,
                  size: 22,
                ),
              ),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.accountNoFamilyYet,
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 14,
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
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const FamilyPage())),
              ),
            ),
          );
        }
        return LumaCard(
          child: _AdaptiveCardRow(
            spacing: 14,
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: luma.accentSubtle,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.diversity_3_rounded,
                color: luma.accent,
                size: 22,
              ),
            ),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  family.name,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t.familySlotsUsed(
                    family.slotsUsed.toString(),
                    family.slotLimit?.toString() ?? '∞',
                  ),
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ],
            ),
            actionBuilder: (expand) => LumaGhostButton(
              label: t.accountManageFamily,
              icon: Icons.arrow_forward_rounded,
              expand: expand,
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const FamilyPage())),
            ),
          ),
        );
      },
    );
  }
}

// ---- Shared section header (mirrors settings_page.dart's) -----------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        Icon(icon, size: 18, color: luma.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
            ],
          ),
        ),
      ],
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
