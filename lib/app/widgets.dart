import 'package:flutter/material.dart';

import '../theme/luma_theme.dart';

/// Thin wrapper over [StreamBuilder] that shows a loader until the first value
/// arrives, then hands the non-null value to [builder].
class StreamData<T> extends StatelessWidget {
  const StreamData({
    super.key,
    required this.stream,
    required this.builder,
    this.loading,
  });

  final Stream<T> stream;
  final Widget Function(BuildContext context, T data) builder;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return loading ??
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              );
        }
        return builder(context, snapshot.data as T);
      },
    );
  }
}

/// Surface container with luma's card styling.
class LumaCard extends StatelessWidget {
  const LumaCard({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: luma.border),
      ),
      child: child,
    );
  }
}

/// Filled lavender call-to-action button with hover + loading states.
class LumaPrimaryButton extends StatefulWidget {
  const LumaPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.loading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  State<LumaPrimaryButton> createState() => _LumaPrimaryButtonState();
}

class _LumaPrimaryButtonState extends State<LumaPrimaryButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final enabled = widget.onTap != null && !widget.loading;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 44,
          width: widget.expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: !enabled
                ? luma.accent.withValues(alpha: 0.4)
                : (_hovering ? luma.accentHover : luma.accent),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: widget.loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation(luma.onAccent),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: luma.onAccent, size: 18),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.label,
                        style: TextStyle(
                          color: luma.onAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
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

/// Subtle bordered/secondary button.
class LumaGhostButton extends StatefulWidget {
  const LumaGhostButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  State<LumaGhostButton> createState() => _LumaGhostButtonState();
}

class _LumaGhostButtonState extends State<LumaGhostButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _hovering ? luma.surfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: luma.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: luma.textSecondary, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modrinth-style pill tab strip.
class LumaSegmentedTabs extends StatelessWidget {
  const LumaSegmentedTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < tabs.length; i++)
          _Pill(
            label: tabs[i],
            selected: i == selectedIndex,
            onTap: () => onSelect(i),
            luma: luma,
          ),
      ],
    );
  }
}

class _Pill extends StatefulWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.luma,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final LumaPalette luma;

  @override
  State<_Pill> createState() => _PillState();
}

class _PillState extends State<_Pill> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = widget.luma;
    final selected = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? luma.accentSubtle
                : (_hovering ? luma.surfaceHover : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? luma.accent : Colors.transparent,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: selected ? luma.accent : luma.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded square holding a colored icon (used for pots, categories, ...).
class LumaIconBadge extends StatelessWidget {
  const LumaIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
  });
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: color, size: size * 0.55),
    );
  }
}

/// A section header + body that starts collapsed and expands on tap, with an
/// animated chevron. Used for secondary settings blocks that shouldn't be
/// open by default (e.g. Account's "Sync & account", Settings' "AI
/// Assistant").
class LumaCollapsibleSection extends StatefulWidget {
  const LumaCollapsibleSection({
    super.key,
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
  State<LumaCollapsibleSection> createState() =>
      _LumaCollapsibleSectionState();
}

class _LumaCollapsibleSectionState extends State<LumaCollapsibleSection> {
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

/// Centered placeholder for an empty list/section.
class LumaEmptyState extends StatelessWidget {
  const LumaEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: luma.accentSubtle,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: luma.accent, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(color: luma.textMuted, fontSize: 13),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
