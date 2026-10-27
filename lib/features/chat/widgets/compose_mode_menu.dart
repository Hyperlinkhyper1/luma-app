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
  final int? picturePercent;
}

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
    final maxWidth = (MediaQuery.sizeOf(context).width - 32).clamp(
      200.0,
      440.0,
    );
    final menuStyle = MenuStyle(
      backgroundColor: WidgetStatePropertyAll(luma.surface),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      maximumSize: WidgetStatePropertyAll(Size(maxWidth, double.infinity)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: luma.border),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MenuAnchor(
          controller: _menuController,
          consumeOutsideTap: true,
          crossAxisUnconstrained: false,
          style: menuStyle.copyWith(
            minimumSize: WidgetStatePropertyAll(
              Size(maxWidth.clamp(200.0, 320.0), 0),
            ),
          ),
          menuChildren: _menuItems(context, menuStyle),
          builder: (context, controller, child) =>
              _PlusButton(onTap: _toggleMenu),
        ),
        if (widget.artifactType != null)
          Flexible(
            child: Tooltip(
              message:
                  '${assistantArtifactTypes[widget.artifactType]} artifact',
              child: TextButton(
                onPressed: () => widget.onArtifactTypeChanged?.call(null),
                child: Text(
                  '.${widget.artifactType} ×',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        if (widget.mode != AssistantComposeMode.chat) ...[
          const SizedBox(width: 6),
          Flexible(
            child: _ModePill(
              mode: widget.mode,
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

  List<Widget> _menuItems(BuildContext context, MenuStyle menuStyle) {
    final luma = context.luma;
    final t = L.of(context);
    final artifactItemStyle = ButtonStyle(maximumSize: menuStyle.maximumSize);

    MenuItemButton item(
      AssistantComposeMode value,
      String hint, {
      bool enabled = true,
    }) {
      final selected = value == widget.mode;
      final color = !enabled
          ? luma.textMuted.withValues(alpha: 0.6)
          : selected
          ? luma.accent
          : luma.textPrimary;
      return MenuItemButton(
        onPressed: enabled
            ? () {
                widget.onArtifactTypeChanged?.call(null);
                widget.onChanged(selected ? AssistantComposeMode.chat : value);
              }
            : null,
        child: Row(
          children: [
            Icon(composeModeIcon(value), size: 18, color: color),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                composeModeLabel(t, value),
                style: TextStyle(
                  color: color,
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: luma.textMuted, fontSize: 12.5),
              ),
            ),
            SizedBox(
              width: 22,
              child: selected
                  ? Icon(Icons.check_rounded, size: 16, color: luma.accent)
                  : null,
            ),
          ],
        ),
      );
    }

    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          t.assistantAddMenu,
          style: TextStyle(
            color: luma.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      MenuItemButton(
        onPressed: widget.filesAllowed ? widget.onUpload : null,
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.attach_file_rounded, size: 18),
          title: const Text('Upload files'),
          subtitle: widget.filesAllowed
              ? const Text('Text, PDF and supported images')
              : const Text('Requires Orbit or Nova'),
        ),
      ),
      SubmenuButton(
        menuStyle: menuStyle,
        submenuIcon: const WidgetStatePropertyAll(
          Icon(Icons.chevron_right_rounded, size: 18),
        ),
        menuChildren: [
          if (widget.filesAllowed) ...[
            for (final type in assistantArtifactTypes.entries)
              MenuItemButton(
                style: artifactItemStyle,
                onPressed: () => _selectArtifact(type.key),
                child: Text(
                  '${type.value} (.${type.key})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          MenuItemButton(
            style: artifactItemStyle,
            onPressed: _available.picture && _available.picturePercent != null
                ? () => _selectArtifact('picture')
                : null,
            child: Text(
              _available.picturePercent != null
                  ? 'Picture · ${_available.picturePercent}% weekly usage'
                  : 'Picture unavailable',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.description_outlined, size: 18),
          title: const Text('Artifact generation'),
          subtitle: Text(
            widget.filesAllowed
                ? 'Choose a file type'
                : 'Pictures only · files need Orbit or Nova',
          ),
        ),
      ),
      const Divider(height: 16),
      item(
        AssistantComposeMode.plan,
        widget.modesAllowed ? t.assistantModePlanHint : 'Requires Nova',
        enabled: widget.modesAllowed,
      ),
      item(
        AssistantComposeMode.deepResearch,
        _available.research
            ? t.assistantModeResearchHint
            : t.assistantModeResearchUnavailable,
        enabled: widget.modesAllowed && _available.research,
      ),
    ];
  }
}

class _PlusButton extends StatefulWidget {
  const _PlusButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_PlusButton> createState() => _PlusButtonState();
}

class _PlusButtonState extends State<_PlusButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
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
              color: _hovering ? luma.surfaceHover : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: luma.border),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.add_rounded, size: 20, color: luma.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({required this.mode, required this.onClear});

  final AssistantComposeMode mode;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return Container(
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
          Icon(composeModeIcon(mode), size: 15, color: luma.accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              composeModeLabel(t, mode),
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
            tooltip: t.assistantModeOff,
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
  }
}
