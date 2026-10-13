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
    final decor = context.lumaDecor;
    final coffee = decor.style == LumaDecor.coffee.style;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (decor.notched) {
      // A flat block with its corners knocked out, sitting on a hard ledge —
      // one cell of the falling-block board the Autumn style is drawn from.
      return Container(
        padding:
            padding ??
            (context.isPhoneWidth
                ? const EdgeInsets.all(14)
                : const EdgeInsets.fromLTRB(20, 18, 20, 20)),
        decoration: ShapeDecoration(
          color: luma.surface,
          shape: decor.cardShape(
            side: BorderSide(
              color: Color.lerp(luma.border, luma.accent, 0.18)!,
              width: decor.borderWidth,
            ),
          ),
          shadows: decor.blockShadow(luma),
        ),
        child: child,
      );
    }
    return Container(
      padding:
          padding ??
          (context.isPhoneWidth
              ? const EdgeInsets.all(14)
              : coffee
              ? const EdgeInsets.fromLTRB(22, 20, 22, 22)
              : const EdgeInsets.all(20)),
      decoration: BoxDecoration(
        color: luma.surface,
        gradient: coffee
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                    luma.surface,
                    isDark ? luma.accent : Colors.white,
                    isDark ? 0.08 : 0.22,
                  )!,
                  Color.lerp(
                    luma.surface,
                    isDark ? luma.background : luma.surfaceHover,
                    isDark ? 0.18 : 0.32,
                  )!,
                ],
              )
            : null,
        borderRadius: decor.cardBorderRadius,
        border: Border.all(
          color: coffee
              ? Color.lerp(luma.border, luma.accent, 0.14)!
              : luma.border,
          width: decor.borderWidth,
        ),
        boxShadow: decor.cardShadow,
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
  bool _pressed = false;

  void _press(bool down) {
    if (_pressed != down) setState(() => _pressed = down);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;
    final enabled = widget.onTap != null && !widget.loading;
    final coffee = decor.style == LumaDecor.coffee.style;
    final height = coffee ? 46.0 : 44.0;
    // Under a style with a ledge the button is an arcade key: pressing it
    // sinks the face onto the ledge instead of just changing color.
    final depth = decor.blockDepth;
    final sunk = enabled && _pressed && depth > 0;
    final Decoration decoration = decor.notched
        ? ShapeDecoration(
            color: !enabled
                ? luma.accent.withValues(alpha: 0.4)
                : (_hovering ? luma.accentHover : luma.accent),
            shape: decor.buttonShape(),
            shadows: enabled
                ? decor.blockShadow(
                    luma,
                    depth: sunk ? 1 : depth,
                    color: Color.lerp(luma.accent, const Color(0xFF2D0E09), 0.55),
                  )
                : const [],
          )
        : BoxDecoration(
            color: !enabled
                ? luma.accent.withValues(alpha: 0.4)
                : (!coffee
                      ? (_hovering ? luma.accentHover : luma.accent)
                      : null),
            gradient: enabled && coffee
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _hovering ? luma.accentHover : luma.accent,
                      _hovering
                          ? luma.accent
                          : Color.lerp(luma.accent, luma.accentHover, 0.28)!,
                    ],
                  )
                : null,
            borderRadius: decor.buttonBorderRadius,
            border: coffee
                ? Border.all(
                    color: luma.accentHover.withValues(
                      alpha: enabled ? 0.42 : 0.18,
                    ),
                  )
                : null,
          );
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() {
        _hovering = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTap: enabled ? widget.onTap : null,
        onTapDown: enabled ? (_) => _press(true) : null,
        onTapUp: enabled ? (_) => _press(false) : null,
        onTapCancel: enabled ? () => _press(false) : null,
        child: AnimatedContainer(
          // A key snaps down faster than a color fades.
          duration: Duration(milliseconds: depth > 0 ? 90 : 150),
          height: height,
          width: widget.expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          transform: depth > 0
              ? Matrix4.translationValues(0, sunk ? depth - 1 : 0, 0)
              : null,
          decoration: decoration,
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
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: luma.onAccent, size: 18),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          decor.labelText(widget.label),
                          style: decor.labelStyle(
                            TextStyle(
                              color: luma.onAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
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
    this.expand = false,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool expand;

  @override
  State<LumaGhostButton> createState() => _LumaGhostButtonState();
}

class _LumaGhostButtonState extends State<LumaGhostButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;
    final coffee = decor.style == LumaDecor.coffee.style;
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: coffee ? 46 : 44,
          width: widget.expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: decor.notched
              // No ledge here: the body is see-through, so a shadow under it
              // would show through the face.
              ? ShapeDecoration(
                  color: !enabled
                      ? luma.surfaceHover.withValues(alpha: 0.38)
                      : _hovering
                      ? luma.surfaceHover
                      : luma.surface.withValues(alpha: 0.5),
                  shape: decor.buttonShape(
                    side: BorderSide(
                      color: Color.lerp(luma.border, luma.accent, 0.3)!,
                      width: decor.borderWidth,
                    ),
                  ),
                )
              : BoxDecoration(
                  color: !enabled
                      ? luma.surfaceHover.withValues(alpha: 0.38)
                      : _hovering
                      ? luma.surfaceHover
                      : coffee
                      ? luma.surface.withValues(alpha: 0.38)
                      : Colors.transparent,
                  borderRadius: decor.buttonBorderRadius,
                  border: Border.all(
                    color: coffee
                        ? Color.lerp(luma.border, luma.accent, 0.16)!
                        : luma.border,
                    width: decor.borderWidth,
                  ),
                ),
          child: Center(
            // Scale a long label down rather than let it spill past the
            // border: these sit two-to-a-row inside dialogs, and a phone-width
            // half leaves less room than the label needs.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: luma.textSecondary, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    decor.labelText(widget.label),
                    style: decor.labelStyle(
                      TextStyle(
                        color: luma.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
    this.scrollable = false,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  /// When true the pills sit on a single horizontally-scrollable row instead
  /// of wrapping onto multiple lines. Use it where there are enough tabs to
  /// wrap into an ungainly stack on a phone (e.g. the School plugin's nine
  /// sections) so they stay one swipeable strip.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final pills = [
      for (var i = 0; i < tabs.length; i++)
        _Pill(
          label: tabs[i],
          selected: i == selectedIndex,
          onTap: () => onSelect(i),
          luma: luma,
        ),
    ];
    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < pills.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              pills[i],
            ],
          ],
        ),
      );
    }
    return Wrap(spacing: 6, runSpacing: 6, children: pills);
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
    final decor = context.lumaDecor;
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
          decoration: decor.notched
              // The selected tab is a solid lit block, like the piece in
              // play; the rest are outlined cells.
              ? ShapeDecoration(
                  color: selected
                      ? luma.accent
                      : (_hovering ? luma.surfaceHover : Colors.transparent),
                  shape: decor.pillShape(
                    side: BorderSide(
                      color: selected ? luma.accent : luma.border,
                      width: decor.borderWidth,
                    ),
                  ),
                )
              : BoxDecoration(
                  color: selected
                      ? luma.accentSubtle
                      : (_hovering ? luma.surfaceHover : Colors.transparent),
                  borderRadius: decor.pillBorderRadius,
                  border: Border.all(
                    color: selected ? luma.accent : Colors.transparent,
                    width: decor.borderWidth,
                  ),
                ),
          child: Text(
            decor.labelText(widget.label),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: decor.labelStyle(
              TextStyle(
                color: selected
                    ? (decor.notched ? luma.onAccent : luma.accent)
                    : luma.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
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
    final decor = context.lumaDecor;
    final radius = BorderRadius.circular(size * decor.badgeRadiusFactor);
    return Container(
      width: size,
      height: size,
      decoration: decor.notched
          ? ShapeDecoration(
              color: color.withValues(alpha: 0.16),
              shape: decor.shape(
                radius,
                side: BorderSide(color: color.withValues(alpha: 0.45)),
              ),
            )
          : BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: radius,
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
  State<LumaCollapsibleSection> createState() => _LumaCollapsibleSectionState();
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
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (widget.subtitle != null)
                        Text(
                          widget.subtitle!,
                          style: TextStyle(color: luma.textMuted, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: luma.textSecondary,
                  ),
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: ShapeDecoration(
                color: luma.accentSubtle,
                shape: context.lumaDecor.shape(
                  BorderRadius.circular(
                    56 * context.lumaDecor.badgeRadiusFactor,
                  ),
                ),
              ),
              child: Icon(icon, color: luma.accent, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
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
      ),
    );
  }
}

// ─── Responsive helpers ─────────────────────────────────────────────────────

/// Width under which the shell drops the side rail and the app is being used
/// on a phone. Shared so pages agree with `AppShell` on what "phone" means
/// instead of each picking its own number.
const double kPhoneBreakpoint = 700;

/// Layout questions every page ends up asking, answered in one place.
extension LumaLayout on BuildContext {
  /// True while this window is phone-narrow. Follows the window, so a
  /// half-screen desktop window gets the phone layout too — which is what it
  /// wants.
  bool get isPhoneWidth => MediaQuery.sizeOf(this).width < kPhoneBreakpoint;

  /// True on a phone-sized *device* in either orientation. Use this for
  /// layouts that should stay phone-shaped when the phone is turned sideways.
  bool get isPhoneForm =>
      MediaQuery.sizeOf(this).shortestSide < kPhoneBreakpoint;
}

// There is deliberately no `keyboardOpen` here. `Scaffold` strips the bottom
// view inset from its body — it has already shrunk the body by that much — so
// `MediaQuery.viewInsetsOf` reads zero everywhere inside the app shell and a
// helper built on it would quietly always be false. A page that needs to know
// should watch the focus of the field being typed into instead.

/// Width for a dialog's fixed-width content box.
///
/// A bare `SizedBox(width: 420)` inside an `AlertDialog` overflows on any
/// phone: the dialog's own inset padding plus its content padding eat about
/// 128px, so a 390px-wide screen has roughly 260px to give. This returns
/// [preferred] when it fits and the honest available width when it doesn't.
double lumaDialogWidth(BuildContext context, double preferred) {
  const chrome = 128.0;
  final available = MediaQuery.sizeOf(context).width - chrome;
  if (available >= preferred) return preferred;
  return available < 0 ? 0 : available;
}
