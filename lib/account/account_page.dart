import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app/widgets.dart';
import '../settings/devices_section.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_scope.dart';
import '../settings/sync_section.dart';
import '../storage/storage_guard.dart';
import '../storage/storage_guard_scope.dart';
import '../theme/luma_theme.dart';
import 'plan.dart';
import 'plan_selection_page.dart';

/// The Account destination: profile picture, sync & paired devices (moved
/// here from Settings, now collapsible), local storage usage, and the plan
/// picker. Pinned in the nav rail directly below Settings.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- Profile ------------------------------------------------
              _SectionHeader(
                icon: Icons.person_rounded,
                title: 'Profile',
                subtitle: 'How you show up on this device.',
              ),
              const SizedBox(height: 12),
              const _ProfileSection(),

              const SizedBox(height: 24),

              // ---- Sync & account (collapsible) ----------------------------
              _CollapsibleSection(
                icon: Icons.cloud_sync_rounded,
                title: 'Sync & account',
                subtitle:
                    'Your data on every device, and devices paired to this one.',
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
                title: 'Storage',
                subtitle: 'How much room luma is using on this device.',
              ),
              const SizedBox(height: 12),
              const _LocalStorageBar(),

              const SizedBox(height: 24),

              // ---- Plan -------------------------------------------------------
              _SectionHeader(
                icon: Icons.workspace_premium_rounded,
                title: 'Plan',
                subtitle: 'Your active plan and what it includes.',
              ),
              const SizedBox(height: 12),
              const _PlanSummary(),
            ],
          ),
        ),
      ),
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
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final path = settings.avatarPath;
        final hasImage = path != null && File(path).existsSync();
        return LumaCard(
          child: Row(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _pickAvatar(settings),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: luma.accentSubtle,
                    backgroundImage: hasImage ? FileImage(File(path)) : null,
                    child: hasImage
                        ? null
                        : Icon(Icons.person_rounded, color: luma.accent, size: 32),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Profile picture',
                        style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('Shown on this device only.',
                        style: TextStyle(color: luma.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              LumaGhostButton(
                label: hasImage ? 'Change photo' : 'Choose photo',
                icon: Icons.image_rounded,
                onTap: () => _pickAvatar(settings),
              ),
            ],
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

// ---- Collapsible section wrapper -----------------------------------------

class _CollapsibleSection extends StatefulWidget {
  const _CollapsibleSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Icon(widget.icon, size: 18, color: luma.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title,
                          style: TextStyle(
                              color: luma.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      if (widget.subtitle != null)
                        Text(widget.subtitle!,
                            style:
                                TextStyle(color: luma.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(Icons.expand_more_rounded,
                      color: luma.textSecondary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _expanded
              ? widget.child
              : const SizedBox(width: double.infinity, height: 0),
        ),
      ],
    );
  }
}

// ---- Storage --------------------------------------------------------------

class _LocalStorageBar extends StatelessWidget {
  const _LocalStorageBar();

  @override
  Widget build(BuildContext context) {
    final guard = StorageGuardScope.of(context);
    final luma = context.luma;
    return ListenableBuilder(
      listenable: guard,
      builder: (context, _) {
        final used = guard.usedBytes;
        final limit = guard.limitBytes;
        final fraction = (used / limit).clamp(0.0, 1.0);
        return LumaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Local storage',
                      style: TextStyle(
                          color: luma.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(
                    '${StorageGuardService.formatBytes(used)} of '
                    '${StorageGuardService.formatBytes(limit)} used',
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
              if (guard.isOverLimit) ...[
                const SizedBox(height: 10),
                Text(
                  "You've reached your storage limit — new data won't be "
                  'saved, and sync is paused, until you free up space.',
                  style: TextStyle(
                      color: Colors.red.shade400, fontSize: 12, height: 1.4),
                ),
              ],
            ],
          ),
        );
      },
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
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final plan = planById(settings.selectedPlanId);
        return LumaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Plan header row ------------------------------------------
              Row(
                children: [
                  // Accent icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: luma.accentSubtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.workspace_premium_rounded,
                        color: luma.accent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
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
                  ),
                  LumaGhostButton(
                    label: 'Change plan',
                    icon: Icons.swap_horiz_rounded,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PlanSelectionPage(),
                      ),
                    ),
                  ),
                ],
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
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: luma.accentSubtle,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded,
                              size: 14, color: luma.accent),
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
              Text(title,
                  style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              if (subtitle != null)
                Text(subtitle!,
                    style: TextStyle(color: luma.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}
