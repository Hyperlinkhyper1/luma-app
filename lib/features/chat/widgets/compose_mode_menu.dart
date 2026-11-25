import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/luma_theme.dart';
import '../assistant_compose_mode.dart';
import '../assistant_files.dart';

/// Which + menu entries can be picked right now.
class ComposeModeAvailability {
  const ComposeModeAvailability({
    required this.research,
    required this.picture,
    this.picturePercent,
  });

  final bool research;
  final bool picture;

  /// Share of the weekly limit one picture costs on this plan.
  final double? picturePercent;
}

/// A picture's weekly share as shown in menus: `1.5` → "1.5", `3.0` → "3".
String formatPicturePercent(double pct) =>
    pct == pct.roundToDouble() ? pct.toInt().toString() : pct.toString();

IconData composeModeIcon(AssistantComposeMode mode) => switch (mode) {
  AssistantComposeMode.plan => Icons.lightbulb_outline_rounded,
  AssistantComposeMode.deepResearch => Icons.travel_explore_rounded,
  AssistantComposeMode.picture => Icons.image_outlined,
  AssistantComposeMode.chat => Icons.chat_bubble_outline_rounded,
};

String composeModeLabel(L t, AssistantComposeMode mode) => switch (mode) {
  AssistantComposeMode.plan => t.assistantModePlan,
  AssistantComposeMode.deepResearch => t.assistantModeResearch,
  AssistantComposeMode.picture => t.assistantModePicture,
  AssistantComposeMode.chat => '',
};

IconData artifactTypeIcon(String type) => switch (type) {
  'docx' => Icons.article_outlined,
  'pptx' => Icons.slideshow_outlined,
  'xlsx' => Icons.grid_on_rounded,
  'pdf' => Icons.picture_as_pdf_outlined,
  'md' => Icons.tag_rounded,
  'txt' => Icons.notes_rounded,
  'csv' => Icons.table_rows_outlined,
  'json' => Icons.data_object_rounded,
  'html' => Icons.language_rounded,
  'svg' => Icons.draw_outlined,
  _ => Icons.insert_drive_file_outlined,
};

/// The file-type submenu's sections, in order. Any type missing here still
/// shows, at the end of the last section.
List<(String, List<String>)> _artifactGroups(L t) {
  final groups = <(String, List<String>)>[
    (t.assistantArtifactGroupOffice, ['docx', 'pptx', 'xlsx']),
    (t.assistantArtifactGroupText, ['pdf', 'md', 'txt']),
    (t.assistantArtifactGroupData, ['csv', 'json', 'html', 'svg']),
  ];
  final listed = {for (final g in groups) ...g.$2};
  final rest = [
    for (final type in assistantArtifactTypes.keys)
      if (!listed.contains(type)) type,
  ];
  return [
    for (final (i, g) in groups.indexed)
      (
        g.$1,
        [
          for (final type in g.$2)
            if (assistantArtifactTypes.containsKey(type)) type,
          if (i == groups.length - 1) ...rest,
        ],
      ),
  ];
}

/// The composer's bottom-left corner: a round + that opens the "Add" menu
/// of modes, and — once one is on — a pill naming it that turns it back
/// off, like plan mode in the Claude app.
class ComposeModeButton extends StatefulWidget {
  const ComposeModeButton({
    super.key,
    required this.mode,
    required this.onChanged,
    required this.availability,
    this.filesAllowed = true,
    this.modesAllowed = true,
    this.artifactType,
    this.onArtifactTypeChanged,
    this.onUpload,
  });

  final AssistantComposeMode mode;
  final ValueChanged<AssistantComposeMode> onChanged;
  final Future<ComposeModeAvailability> Function() availability;
  final bool filesAllowed;
  final bool modesAllowed;
  final String? artifactType;
  final ValueChanged<String?>? onArtifactTypeChanged;
  final VoidCallback? onUpload;

  @override
  State<ComposeModeButton> createState() => _ComposeModeButtonState();
}

class _ComposeModeButtonState extends State<ComposeModeButton> {
  final _menuController = MenuController();
  ComposeModeAvailability _available = const ComposeModeAvailability(
    research: false,
    picture: false,
  );
  bool _loadingAvailability = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final maxWidth = (MediaQuery.sizeOf(context).width - 32).clamp(
      200.0,
      360.0,
    );
    final menuStyle = MenuStyle(
      backgroundColor: WidgetStatePropertyAll(luma.surface),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      shadowColor: WidgetStatePropertyAll(Colors.black.withValues(alpha: 0.4)),
      elevation: const WidgetStatePropertyAll(12),
      padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
      maximumSize: WidgetStatePropertyAll(Size(maxWidth, double.infinity)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: luma.border),
        ),
      ),
    );
    final artifactType = widget.artifactType;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MenuAnchor(
          controller: _menuController,
          consumeOutsideTap: true,
          crossAxisUnconstrained: false,
          alignmentOffset: const Offset(0, 6),
          style: menuStyle.copyWith(
            minimumSize: WidgetStatePropertyAll(
              Size(maxWidth.clamp(200.0, 320.0), 0),
            ),
          ),
          menuChildren: _menuItems(context, menuStyle),
          builder: (context, controller, child) =>
              _PlusButton(onTap: _toggleMenu, open: controller.isOpen),
        ),
        if (artifactType != null) ...[
          const SizedBox(width: 6),
          Flexible(
            child: _ComposePill(
              icon: artifactTypeIcon(artifactType),
              label: '.$artifactType',
              tooltip: assistantArtifactTypes[artifactType] ?? '.$artifactType',
              clearTooltip: t.assistantModeOff,
              onClear: () => widget.onArtifactTypeChanged?.call(null),
            ),
          ),
        ],
        if (widget.mode != AssistantComposeMode.chat) ...[
          const SizedBox(width: 6),
          Flexible(
            child: _ComposePill(
              icon: composeModeIcon(widget.mode),
              label: composeModeLabel(t, widget.mode),
              clearTooltip: t.assistantModeOff,
              onClear: () => widget.onChanged(AssistantComposeMode.chat),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _toggleMenu() async {
    if (_menuController.isOpen) {
      _menuController.close();
      return;
    }
    if (_loadingAvailability) return;
    _loadingAvailability = true;
    try {
      final available = await widget.availability();
      if (!mounted) return;
      setState(() => _available = available);
      _menuController.open();
    } finally {
      _loadingAvailability = false;
    }
  }

  void _selectArtifact(String type) {
    widget.onChanged(
      type == 'picture'
          ? AssistantComposeMode.picture
          : AssistantComposeMode.chat,
    );
    widget.onArtifactTypeChanged?.call(type == 'picture' ? null : type);
  }

  ButtonStyle _itemStyle(
    BuildContext context,
    MenuStyle menuStyle, {
    double minHeight = 52,
    double vertical = 6,
  }) {
    final luma = context.luma;
    final panelMax = menuStyle.maximumSize?.resolve({}) ?? Size.infinite;
    return ButtonStyle(
      maximumSize: WidgetStatePropertyAll(
        Size(panelMax.width - 12, panelMax.height),
      ),
      minimumSize: WidgetStatePropertyAll(Size(0, minHeight)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 8, vertical: vertical),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      overlayColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused) ||
                states.contains(WidgetState.pressed)
            ? luma.surfaceHover
            : null,
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.focused) ? luma.surfaceHover : null,
      ),
    );
  }

  List<Widget> _menuItems(BuildContext context, MenuStyle menuStyle) {
    final luma = context.luma;
    final t = L.of(context);
    final rowStyle = _itemStyle(context, menuStyle);
    final typeStyle = _itemStyle(
      context,
      menuStyle,
      minHeight: 36,
      vertical: 3,
    );
    final artifactType = widget.artifactType;

    MenuItemButton modeItem(
      AssistantComposeMode value,
      String hint, {
      bool enabled = true,
    }) {
      final selected = value == widget.mode;
      return MenuItemButton(
        style: rowStyle,
        onPressed: enabled
            ? () {
                widget.onArtifactTypeChanged?.call(null);
                widget.onChanged(selected ? AssistantComposeMode.chat : value);
              }
            : null,
        child: _MenuRow(
          icon: composeModeIcon(value),
          title: composeModeLabel(t, value),
          subtitle: hint,
          selected: selected,
          enabled: enabled,
          trailing: selected
              ? Icon(Icons.check_rounded, size: 18, color: luma.accent)
              : !enabled
              ? Icon(
                  Icons.lock_outline_rounded,
                  size: 15,
                  color: luma.textMuted,
                )
              : null,
        ),
      );
    }

    MenuItemButton typeItem(String type) {
      final selected = type == artifactType;
      return MenuItemButton(
        style: typeStyle,
        onPressed: () => _selectArtifact(type),
        child: _MenuRow(
          icon: artifactTypeIcon(type),
          title: assistantArtifactTypes[type]!,
          selected: selected,
          compact: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ExtensionBadge('.$type', selected: selected),
              SizedBox(
                width: 24,
                child: selected
                    ? Icon(Icons.check_rounded, size: 16, color: luma.accent)
                    : null,
              ),
            ],
          ),
        ),
      );
    }

    final pictureCost = _available.picturePercent;
    final pictureEnabled = _available.picture && pictureCost != null;
    final pictureSelected = widget.mode == AssistantComposeMode.picture;

    return [
      _MenuHeader(t.assistantAddMenu),
      MenuItemButton(
        style: rowStyle,
        onPressed: widget.filesAllowed ? widget.onUpload : null,
        child: _MenuRow(
          icon: Icons.attach_file_rounded,
          title: t.assistantUploadFiles,
          subtitle: widget.filesAllowed
              ? t.assistantUploadFilesHint
              : t.assistantRequiresOrbitOrNova,
          enabled: widget.filesAllowed,
          trailing: widget.filesAllowed
              ? null
              : Icon(
                  Icons.lock_outline_rounded,
                  size: 15,
                  color: luma.textMuted,
                ),
        ),
      ),
      SubmenuButton(
        style: rowStyle,
        menuStyle: menuStyle,
        submenuIcon: WidgetStatePropertyAll(
          Icon(Icons.chevron_right_rounded, size: 18, color: luma.textMuted),
        ),
        menuChildren: [
          _MenuHeader(t.assistantArtifactGroupImage),
          MenuItemButton(
            style: typeStyle,
            onPressed: pictureEnabled ? () => _selectArtifact('picture') : null,
            child: _MenuRow(
              icon: Icons.image_outlined,
              title: t.assistantModePicture,
              subtitle: pictureEnabled
                  ? t.assistantPictureWeeklyCost(
                      formatPicturePercent(pictureCost),
                    )
                  : t.assistantPictureUnavailable,
              selected: pictureSelected,
              enabled: pictureEnabled,
              compact: true,
              trailing: pictureSelected
                  ? Icon(Icons.check_rounded, size: 16, color: luma.accent)
                  : null,
            ),
          ),
          if (widget.filesAllowed)
            for (final (label, types) in _artifactGroups(t)) ...[
              _MenuHeader(label),
              for (final type in types) typeItem(type),
            ],
        ],
        child: _MenuRow(
          icon: artifactType != null
              ? artifactTypeIcon(artifactType)
              : Icons.auto_awesome_outlined,
          title: t.assistantArtifactGeneration,
          subtitle: !widget.filesAllowed
              ? t.assistantArtifactPicturesOnly
              : artifactType != null
              ? t.assistantArtifactSelected(
                  assistantArtifactTypes[artifactType] ?? artifactType,
                )
              : t.assistantArtifactChooseType,
          selected: artifactType != null || pictureSelected,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Divider(height: 1, thickness: 1, color: luma.border),
      ),
      _MenuHeader(t.assistantModesHeader),
      modeItem(
        AssistantComposeMode.plan,
        widget.modesAllowed
            ? t.assistantModePlanHint
            : t.assistantUltraReasoningPlan,
        enabled: widget.modesAllowed,
      ),
      modeItem(
        AssistantComposeMode.deepResearch,
        _available.research
            ? t.assistantModeResearchHint
            : t.assistantModeResearchUnavailable,
        enabled: widget.modesAllowed && _available.research,
      ),
    ];
  }
}

class _MenuHeader extends StatelessWidget {
  const _MenuHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
    child: Text(
      text,
      style: TextStyle(
        color: context.luma.textMuted,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    ),
  );
}

/// One + menu row: an icon tile, a title with an optional second line that
/// wraps instead of being cut off, and a trailing marker.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.selected = false,
    this.enabled = true,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool selected;
  final bool enabled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final tile = compact ? 28.0 : 34.0;
    final iconColor = !enabled
        ? luma.textMuted.withValues(alpha: 0.6)
        : selected
        ? luma.accent
        : luma.textSecondary;
    final titleColor = !enabled
        ? luma.textMuted
        : selected
        ? luma.accent
        : luma.textPrimary;
    return Row(
      children: [
        Container(
          width: tile,
          height: tile,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected && enabled
                ? luma.accent.withValues(alpha: 0.16)
                : luma.background.withValues(alpha: enabled ? 0.7 : 0.35),
            borderRadius: BorderRadius.circular(compact ? 8 : 10),
            border: Border.all(
              color: selected && enabled
                  ? luma.accent.withValues(alpha: 0.35)
                  : luma.border.withValues(alpha: 0.7),
            ),
          ),
          child: Icon(icon, size: compact ? 15 : 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: titleColor,
                  fontSize: compact ? 13 : 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: luma.textMuted.withValues(alpha: enabled ? 1 : 0.8),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

class _ExtensionBadge extends StatelessWidget {
  const _ExtensionBadge(this.text, {required this.selected});

  final String text;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: selected
            ? luma.accent.withValues(alpha: 0.14)
            : luma.background.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: selected ? luma.accent : luma.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _PlusButton extends StatefulWidget {
  const _PlusButton({required this.onTap, this.open = false});

  final VoidCallback onTap;
  final bool open;

  @override
  State<_PlusButton> createState() => _PlusButtonState();
}

class _PlusButtonState extends State<_PlusButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final active = widget.open || _hovering;
    return Tooltip(
      message: L.of(context).assistantAddMenu,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: active ? luma.surfaceHover : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.open
                    ? luma.accent.withValues(alpha: 0.5)
                    : luma.border,
              ),
            ),
            alignment: Alignment.center,
            child: AnimatedRotation(
              turns: widget.open ? 0.125 : 0,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              child: Icon(
                Icons.add_rounded,
                size: 20,
                color: widget.open ? luma.accent : luma.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A chip beside the + naming what is switched on, with an × to clear it.
class _ComposePill extends StatelessWidget {
  const _ComposePill({
    required this.icon,
    required this.label,
    required this.clearTooltip,
    required this.onClear,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final String? tooltip;
  final String clearTooltip;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final pill = Container(
      height: 30,
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: BoxDecoration(
        color: luma.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: luma.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: luma.accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: luma.accent,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            tooltip: clearTooltip,
            onPressed: onClear,
            iconSize: 14,
            color: luma.accent,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 22, height: 22),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
    return tooltip == null ? pill : Tooltip(message: tooltip!, child: pill);
  }
}
