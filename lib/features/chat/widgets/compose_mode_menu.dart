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
class ComposeModeButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PlusButton(onTap: (buttonContext) => _openMenu(buttonContext)),
        if (artifactType != null)
          Flexible(
            child: Tooltip(
              message: '${assistantArtifactTypes[artifactType]} artifact',
              child: TextButton(
                onPressed: () => onArtifactTypeChanged?.call(null),
                child: Text(
                  '.$artifactType ×',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        if (mode != AssistantComposeMode.chat) ...[
          const SizedBox(width: 6),
          Flexible(
            child: _ModePill(
              mode: mode,
              onClear: () => onChanged(AssistantComposeMode.chat),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openMenu(BuildContext buttonContext) async {
    final luma = buttonContext.luma;
    final t = L.of(buttonContext);
    final button = buttonContext.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(buttonContext).context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );
    final available = await availability();
    if (!buttonContext.mounted) return;

    PopupMenuItem<Object> item(
      AssistantComposeMode value,
      String hint, {
      bool enabled = true,
    }) {
      final selected = value == mode;
      final color = !enabled
          ? luma.textMuted.withValues(alpha: 0.6)
          : selected
          ? luma.accent
          : luma.textPrimary;
      return PopupMenuItem<Object>(
        value: value,
        enabled: enabled,
        height: 40,
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

    final picked = await showMenu<Object>(
      context: buttonContext,
      position: position,
      constraints: BoxConstraints(
        minWidth: (overlay.size.width - 32).clamp(200, 320),
        maxWidth: (overlay.size.width - 32).clamp(200, 440),
      ),
      color: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: luma.border),
      ),
      items: [
        PopupMenuItem<Object>(
          enabled: false,
          height: 30,
          child: Text(
            t.assistantAddMenu,
            style: TextStyle(
              color: luma.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        PopupMenuItem<Object>(
          value: 'upload',
          enabled: filesAllowed && onUpload != null,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.attach_file_rounded, size: 18),
            title: const Text('Upload files'),
            subtitle: filesAllowed
                ? const Text('Text, PDF and supported images')
                : const Text('Requires Orbit or Nova'),
          ),
        ),
        PopupMenuItem<Object>(
          value: 'artifact',
          enabled: filesAllowed,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined, size: 18),
            title: const Text('Artifact generation'),
            subtitle: Text(
              filesAllowed ? 'Choose a file type' : 'Requires Orbit or Nova',
            ),
            trailing: const Icon(Icons.chevron_right_rounded, size: 18),
          ),
        ),
        const PopupMenuDivider(),
        item(
          AssistantComposeMode.plan,
          modesAllowed ? t.assistantModePlanHint : 'Requires Nova',
          enabled: modesAllowed,
        ),
        item(
          AssistantComposeMode.deepResearch,
          available.research
              ? t.assistantModeResearchHint
              : t.assistantModeResearchUnavailable,
          enabled: modesAllowed && available.research,
        ),
      ],
    );
    if (picked == null) return;
    if (picked == 'upload') {
      onUpload?.call();
      return;
    }
    if (picked == 'artifact') {
      if (!buttonContext.mounted) return;
      final type = await showMenu<String>(
        context: buttonContext,
        position: position,
        color: luma.surface,
        items: [
          for (final type in assistantArtifactTypes.entries)
            PopupMenuItem(
              value: type.key,
              child: Text('${type.value} (.${type.key})'),
            ),
          PopupMenuItem(
            value: 'picture',
            enabled: available.picture && available.picturePercent != null,
            child: Text(
              available.picturePercent != null
                  ? 'Picture · ${available.picturePercent}% weekly usage'
                  : 'Picture unavailable',
            ),
          ),
        ],
      );
      if (type == null) return;
      onChanged(
        type == 'picture'
            ? AssistantComposeMode.picture
            : AssistantComposeMode.chat,
      );
      onArtifactTypeChanged?.call(type == 'picture' ? null : type);
      return;
    }
    if (picked is AssistantComposeMode) {
      onArtifactTypeChanged?.call(null);
      onChanged(picked == mode ? AssistantComposeMode.chat : picked);
    }
  }
}

class _PlusButton extends StatefulWidget {
  const _PlusButton({required this.onTap});

  final ValueChanged<BuildContext> onTap;

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
          onTap: () => widget.onTap(context),
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
