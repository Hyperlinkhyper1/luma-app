import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';

/// Floating panel chrome shared by the brush, colour and layer panels.
class StudioPanel extends StatelessWidget {
  const StudioPanel({
    super.key,
    required this.child,
    this.width = 300,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final double? width;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Material(
      color: luma.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: luma.border),
      ),
      shadowColor: Colors.black,
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: SizedBox(
          width: width,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class PanelHeader extends StatelessWidget {
  const PanelHeader({super.key, required this.title, this.trailing = const [], this.onClose});

  final String title;
  final List<Widget> trailing;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
          ),
          ...trailing,
          if (onClose != null)
            StudioIconButton(icon: Icons.close_rounded, tooltip: 'Close', size: 30, onTap: onClose),
        ],
      ),
    );
  }
}

class StudioIconButton extends StatelessWidget {
  const StudioIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.selected = false,
    this.size = 40,
    this.iconSize,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool selected;
  final double size;
  final double? iconSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: Material(
        color: selected ? luma.accentSubtle : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              size: iconSize ?? size * 0.5,
              color: !enabled
                  ? luma.textMuted.withValues(alpha: 0.45)
                  : selected
                      ? luma.accent
                      : color ?? luma.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// A tall slider for the tool rail, dragged up and down like the size and
/// opacity strips every tablet painting app has.
class VerticalSlider extends StatefulWidget {
  const VerticalSlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.min = 0,
    this.max = 1,
    this.curve = 1,
    this.height = 140,
    this.format,
  });

  final double value;
  final double min;
  final double max;

  /// Exponent applied to the slider position: 2 or 3 spends most of the
  /// travel on small sizes, where precision matters.
  final double curve;
  final double height;
  final String label;
  final ValueChanged<double> onChanged;
  final String Function(double value)? format;

  @override
  State<VerticalSlider> createState() => _VerticalSliderState();
}

class _VerticalSliderState extends State<VerticalSlider> {
  bool _dragging = false;

  double get _t {
    final range = widget.max - widget.min;
    if (range <= 0) return 0;
    final linear = ((widget.value - widget.min) / range).clamp(0.0, 1.0);
    return widget.curve == 1 ? linear : _pow(linear, 1 / widget.curve);
  }

  static double _pow(double x, double e) => x <= 0 ? 0 : math.pow(x, e).toDouble();

  void _update(double dy, double trackHeight) {
    final t = (1 - dy / trackHeight).clamp(0.0, 1.0);
    final curved = widget.curve == 1 ? t : _pow(t, widget.curve);
    widget.onChanged(widget.min + (widget.max - widget.min) * curved);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final track = widget.height;
    final t = _t;
    return Semantics(
      label: widget.label,
      value: widget.format?.call(widget.value) ?? widget.value.toStringAsFixed(2),
      child: Tooltip(
        message: widget.label,
        waitDuration: const Duration(milliseconds: 600),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (d) {
            setState(() => _dragging = true);
            _update(d.localPosition.dy, track);
          },
          onVerticalDragUpdate: (d) => _update(d.localPosition.dy, track),
          onVerticalDragEnd: (_) => setState(() => _dragging = false),
          onTapDown: (d) => _update(d.localPosition.dy, track),
          child: SizedBox(
            width: 40,
            height: track,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 10,
                  decoration: BoxDecoration(
                    color: luma.border,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: track * t,
                    decoration: BoxDecoration(
                      color: luma.accent.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                Positioned(
                  top: (track - 22) * (1 - t),
                  child: Container(
                    width: 24,
                    height: 22,
                    decoration: BoxDecoration(
                      color: luma.surface,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: luma.accent, width: 1.5),
                      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4)],
                    ),
                  ),
                ),
                if (_dragging && widget.format != null)
                  Positioned(
                    left: 44,
                    top: (track - 22) * (1 - t) - 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: luma.textPrimary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.format!(widget.value),
                        style: TextStyle(color: luma.surface, fontSize: 11.5, fontWeight: FontWeight.w600),
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

/// Colour swatch that shows transparency as a checkerboard.
class ColorDot extends StatelessWidget {
  const ColorDot({
    super.key,
    required this.color,
    this.size = 28,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.tooltip,
  });

  final Color color;
  final double size;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final dot = GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTap: onLongPress,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: selected ? luma.accent : luma.border,
            width: selected ? 2.5 : 1,
          ),
        ),
      ),
    );
    return tooltip == null ? dot : Tooltip(message: tooltip!, child: dot);
  }
}

/// A compact labelled slider for the settings panels.
class LabeledSlider extends StatelessWidget {
  const LabeledSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.display,
    this.onChangeEnd,
    this.highlighted = false,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final String display;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: highlighted ? luma.accent : luma.textSecondary,
                    fontSize: 12,
                    fontWeight: highlighted ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              Text(display, style: TextStyle(color: luma.textMuted, fontSize: 11.5)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: SizedBox(
              height: 26,
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
                onChangeEnd: onChangeEnd,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
