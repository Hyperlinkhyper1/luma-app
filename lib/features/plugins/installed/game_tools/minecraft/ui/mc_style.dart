import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../../app/widgets.dart';
import '../../../../../../l10n/app_localizations.dart';
import '../../../../../../theme/luma_theme.dart';

/// The Minecraft tools borrow Pugtools' look — a soft, lit page, white cards
/// with a picture on top and heavy headings — on luma's own tokens, so the
/// screens still follow the user's theme and accent.

/// The secondary hues Pugtools tags its tools with. The accent stays luma's;
/// these only tint card art and tags so a grid of tools is not one colour.
enum McHue {
  indigo(Color(0xFF657DF2)),
  violet(Color(0xFF8B5CF6)),
  mint(Color(0xFF24BFAE)),
  green(Color(0xFF5DB862)),
  orange(Color(0xFFEB8B3D)),
  rose(Color(0xFFE5577A)),
  sky(Color(0xFF3AA6E8)),
  amber(Color(0xFFD9A11E));

  const McHue(this.color);
  final Color color;
}

const _mono = TextStyle(
  fontFamily: 'Consolas',
  fontFamilyFallback: ['monospace', 'Courier New'],
);

/// `iron_ingot` → `Iron Ingot`, the way the game's English names read.
String mcPretty(String id) {
  final bare = id.startsWith('#') ? id.substring(1) : id;
  final colon = bare.indexOf(':');
  final name = colon < 0 ? bare : bare.substring(colon + 1);
  const small = {'of', 'and', 'on', 'a', 'the', 'in', 'to', 'with'};
  final words = name.split(RegExp(r'[_/]')).where((w) => w.isNotEmpty).toList();
  return [
    for (var i = 0; i < words.length; i++)
      i > 0 && small.contains(words[i])
          ? words[i]
          : words[i][0].toUpperCase() + words[i].substring(1),
  ].join(' ');
}

/// Copies [text] and says so.
Future<void> mcCopy(BuildContext context, String text, {String? what}) async {
  final t = L.of(context);
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(what ?? t.mcCopiedToClipboard),
        duration: const Duration(milliseconds: 1400),
      ),
    );
}

void mcToast(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// The page backdrop: the theme background lit by two soft blooms, the way
/// Pugtools' page glows behind its cards.
class McBackdrop extends StatelessWidget {
  const McBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(color: luma.background),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _BloomPainter(
                  first: luma.accent.withValues(alpha: dark ? 0.12 : 0.16),
                  second: McHue.sky.color.withValues(alpha: dark ? 0.08 : 0.14),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _BloomPainter extends CustomPainter {
  _BloomPainter({required this.first, required this.second});

  final Color first;
  final Color second;

  @override
  void paint(Canvas canvas, Size size) {
    void bloom(Offset center, double radius, Color color) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    final r = math.max(size.width, 600) * 0.42;
    bloom(Offset(size.width * 0.15, 0), r, first);
    bloom(Offset(size.width * 0.85, size.height * 0.08), r * 0.85, second);
  }

  @override
  bool shouldRepaint(_BloomPainter old) =>
      old.first != first || old.second != second;
}

/// A heavy display heading, Pugtools' signature.
class McHeading extends StatelessWidget {
  const McHeading(this.text, {super.key, this.size = 24, this.trailing});

  final String text;
  final double size;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final heading = Text(
      text,
      style: TextStyle(
        color: luma.textPrimary,
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        height: 1.15,
      ),
    );
    if (trailing == null) return heading;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: heading),
        trailing!,
      ],
    );
  }
}

/// Small uppercase label above a field or a group of controls.
class McLabel extends StatelessWidget {
  const McLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final label = Text(
      text.toUpperCase(),
      style: TextStyle(
        color: luma.textMuted,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: trailing == null
          ? label
          : Row(children: [Expanded(child: label), trailing!]),
    );
  }
}

/// A coloured tag pill — `GUIDE`, `3D`, `EXPORT`.
class McTag extends StatelessWidget {
  const McTag(this.text, {super.key, this.hue = McHue.indigo, this.solid = false});

  final String text;
  final McHue hue;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final color = hue.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: solid ? Colors.white : color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// A white (surface) card with the thin border Pugtools uses everywhere.
class McPanel extends StatelessWidget {
  const McPanel({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: luma.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 17, color: luma.accent),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

/// The frame every Minecraft tool sits in: a back link, the tool's name in a
/// heavy heading, and the tool below. Scrolls as a whole unless [scroll] is
/// false, for tools that manage their own scrolling (3D viewers, editors).
class McToolFrame extends StatelessWidget {
  const McToolFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.child,
    this.section,
    this.hue = McHue.indigo,
    this.icon,
    this.actions = const [],
    this.scroll = true,
  });

  final String title;
  final String subtitle;
  final String? section;
  final VoidCallback onBack;
  final Widget child;
  final McHue hue;
  final IconData? icon;
  final List<Widget> actions;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final phone = context.isPhoneWidth;
    final pad = phone ? 14.0 : 28.0;
    final header = Padding(
      padding: EdgeInsets.fromLTRB(pad, phone ? 12 : 20, pad, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackLink(onTap: onBack, section: section),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Container(
                  width: phone ? 38 : 46,
                  height: phone ? 38 : 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        hue.color,
                        Color.lerp(hue.color, Colors.black, 0.18)!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: hue.color.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: phone ? 20 : 24),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    McHeading(title, size: phone ? 21 : 27),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: luma.textSecondary,
                        fontSize: 13.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (actions.isNotEmpty && !phone) ...[
                const SizedBox(width: 12),
                Wrap(spacing: 8, children: actions),
              ],
            ],
          ),
          if (actions.isNotEmpty && phone) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );

    final body = Padding(
      padding: EdgeInsets.fromLTRB(pad, 0, pad, scroll ? 36 : pad),
      child: child,
    );

    return McBackdrop(
      child: scroll
          ? SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [header, body],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [header, Expanded(child: body)],
            ),
    );
  }
}

class _BackLink extends StatefulWidget {
  const _BackLink({required this.onTap, this.section});

  final VoidCallback onTap;
  final String? section;

  @override
  State<_BackLink> createState() => _BackLinkState();
}

class _BackLinkState extends State<_BackLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color = _hover ? luma.accent : luma.textSecondary;
    return Semantics(
      button: true,
      label: L.of(context).mcBackToTools,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_rounded, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                L.of(context).mcAllTools,
                style: TextStyle(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.section != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 15,
                    color: luma.textMuted,
                  ),
                ),
                Text(
                  widget.section!,
                  style: TextStyle(color: luma.textMuted, fontSize: 12.5),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Controls on the left, result on the right — or stacked on a narrow
/// window, controls first.
class McSplit extends StatelessWidget {
  const McSplit({
    super.key,
    required this.controls,
    required this.result,
    this.controlsWidth = 360,
    this.breakpoint = 820,
    this.expandResult = false,
  });

  final Widget controls;
  final Widget result;
  final double controlsWidth;
  final double breakpoint;

  /// For non-scrolling frames: let the result fill the height.
  final bool expandResult;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          if (expandResult) {
            return ListView(
              children: [
                controls,
                const SizedBox(height: 16),
                SizedBox(height: 520, child: result),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [controls, const SizedBox(height: 16), result],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: controlsWidth,
              child: expandResult
                  ? SingleChildScrollView(child: controls)
                  : controls,
            ),
            const SizedBox(width: 20),
            Expanded(child: result),
          ],
        );
      },
    );
  }
}

/// A responsive grid: as many columns of at least [minTileWidth] as fit.
class McGrid extends StatelessWidget {
  const McGrid({
    super.key,
    required this.children,
    this.minTileWidth = 240,
    this.spacing = 16,
  });

  final List<Widget> children;
  final double minTileWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = math.max(
          1,
          ((constraints.maxWidth + spacing) / (minTileWidth + spacing)).floor(),
        );
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

/// Generated output — a command or a JSON file — in a code box with Copy and,
/// optionally, Save.
class McCodeBox extends StatelessWidget {
  const McCodeBox({
    super.key,
    required this.code,
    this.title,
    this.onSave,
    this.maxHeight = 360,
    this.note,
  });

  final String code;
  final String? title;
  final VoidCallback? onSave;
  final double maxHeight;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0F0D16) : const Color(0xFF1B1D2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: luma.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 4),
            child: Row(
              children: [
                const Icon(
                  Icons.terminal_rounded,
                  size: 15,
                  color: Color(0xFF9AA3C7),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title ?? L.of(context).mcOutput,
                    style: const TextStyle(
                      color: Color(0xFFB8BFDD),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (onSave != null)
                  _CodeAction(
                    icon: Icons.download_rounded,
                    label: L.of(context).mcSave,
                    onTap: onSave!,
                  ),
                _CodeAction(
                  icon: Icons.copy_rounded,
                  label: L.of(context).mcCopy,
                  onTap: () => mcCopy(context, code),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: SelectableText(
                code,
                style: _mono.copyWith(
                  color: const Color(0xFFE6E9F8),
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text(
                note!,
                style: const TextStyle(color: Color(0xFF9AA3C7), fontSize: 11.5),
              ),
            ),
        ],
      ),
    );
  }
}

class _CodeAction extends StatelessWidget {
  const _CodeAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFCBD2F2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(0, 30),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      icon: Icon(icon, size: 15),
      label: Text(label),
    );
  }
}

/// Monospace text style for ids, counts and coordinates.
TextStyle mcMono(BuildContext context, {double size = 12.5, Color? color}) =>
    _mono.copyWith(fontSize: size, color: color ?? context.luma.textPrimary);

/// A compact stat: a big number over a small label.
class McStat extends StatelessWidget {
  const McStat({
    super.key,
    required this.value,
    required this.label,
    this.hue,
  });

  final String value;
  final String label;
  final McHue? hue;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color = hue?.color ?? luma.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(color: luma.textSecondary, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

/// A horizontal set of stats that wraps on narrow screens.
class McStatRow extends StatelessWidget {
  const McStatRow({super.key, required this.stats});

  final List<McStat> stats;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 10, runSpacing: 10, children: stats);
}

/// A prominent action, styled after luma's primary buttons.
class McButton extends StatelessWidget {
  const McButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.primary = true,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool primary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final child = busy
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: primary ? luma.onAccent : luma.accent,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17),
                const SizedBox(width: 7),
              ],
              Flexible(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          );
    final style = ButtonStyle(
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      // From the theme rather than a bare TextStyle, so the label keeps the
      // platform's typeface and its CJK fallbacks.
      textStyle: WidgetStatePropertyAll(
        Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    if (primary) {
      return FilledButton(
        onPressed: busy ? null : onTap,
        style: style.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? luma.accent.withValues(alpha: 0.4)
                : luma.accent,
          ),
          foregroundColor: WidgetStatePropertyAll(luma.onAccent),
        ),
        child: child,
      );
    }
    return OutlinedButton(
      onPressed: busy ? null : onTap,
      style: style.copyWith(
        foregroundColor: WidgetStatePropertyAll(luma.textPrimary),
        side: WidgetStatePropertyAll(BorderSide(color: luma.border)),
        backgroundColor: WidgetStatePropertyAll(luma.surface),
      ),
      child: child,
    );
  }
}

/// A row of selectable chips for a small closed set of options.
class McChoice<T> extends StatelessWidget {
  const McChoice({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelect,
    this.icon,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final IconData? Function(T)? icon;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final v in values)
          _ChoicePill(
            label: label(v),
            icon: icon?.call(v),
            selected: v == selected,
            onTap: () => onSelect(v),
            luma: luma,
          ),
      ],
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.luma,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? luma.accentSubtle : luma.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
          side: BorderSide(color: selected ? luma.accent : luma.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          hoverColor: luma.surfaceHover,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 15,
                    color: selected ? luma.accent : luma.textSecondary,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? luma.accent : luma.textSecondary,
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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

/// A themed single-line text field.
class McTextField extends StatelessWidget {
  const McTextField({
    super.key,
    this.controller,
    this.hint,
    this.onChanged,
    this.maxLines = 1,
    this.monospace = false,
    this.prefixIcon,
    this.keyboardType,
    this.inputFormatters,
    this.initialValue,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String? hint;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int maxLines;
  final bool monospace;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final style = monospace
        ? mcMono(context, size: 13)
        : TextStyle(color: luma.textPrimary, fontSize: 13.5);
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      maxLines: maxLines,
      minLines: 1,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: style,
      decoration: mcInputDecoration(context, hint: hint, prefixIcon: prefixIcon),
    );
  }
}

InputDecoration mcInputDecoration(
  BuildContext context, {
  String? hint,
  IconData? prefixIcon,
}) {
  final luma = context.luma;
  OutlineInputBorder border(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(9),
    borderSide: BorderSide(color: c),
  );
  return InputDecoration(
    isDense: true,
    hintText: hint,
    hintStyle: TextStyle(color: luma.textMuted, fontSize: 13),
    filled: true,
    fillColor: luma.surface,
    prefixIcon: prefixIcon == null
        ? null
        : Icon(prefixIcon, size: 18, color: luma.textMuted),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    border: border(luma.border),
    enabledBorder: border(luma.border),
    focusedBorder: border(luma.accent),
  );
}

/// An integer with − / + buttons and a typed value.
class McStepper extends StatelessWidget {
  const McStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 9999,
    this.step = 1,
    this.suffix,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    Widget button(IconData icon, int delta) => SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 16,
        color: luma.textSecondary,
        onPressed: () => onChanged((value + delta).clamp(min, max)),
        icon: Icon(icon),
      ),
    );
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.remove_rounded, -step),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44),
            child: Text(
              suffix == null ? '$value' : '$value $suffix',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: luma.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
          ),
          button(Icons.add_rounded, step),
        ],
      ),
    );
  }
}

/// A labelled slider with its value shown to the right.
class McSlider extends StatelessWidget {
  const McSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.format,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double)? format;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: luma.textSecondary, fontSize: 12.5),
              ),
            ),
            Text(
              format?.call(value) ?? value.round().toString(),
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            activeColor: luma.accent,
            inactiveColor: luma.border,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// A labelled switch row.
class McSwitch extends StatelessWidget {
  const McSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.detail,
  });

  final String label;
  final String? detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (detail != null)
                    Text(
                      detail!,
                      style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                    ),
                ],
              ),
            ),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeTrackColor: luma.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A themed dropdown over a list of values.
class McDropdown<T> extends StatelessWidget {
  const McDropdown({
    super.key,
    required this.values,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final List<T> values;
  final T value;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: luma.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: values.contains(value) ? value : null,
          isExpanded: true,
          isDense: true,
          dropdownColor: luma.surface,
          borderRadius: BorderRadius.circular(10),
          icon: Icon(Icons.expand_more_rounded, color: luma.textMuted, size: 18),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: luma.textPrimary,
            fontSize: 13.5,
          ),
          items: [
            for (final v in values)
              DropdownMenuItem<T>(
                value: v,
                child: Text(label(v), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

/// A namespaced-id field with suggestions from [options] — items, blocks,
/// entities. Free text is allowed so modded ids and tags still work.
class McIdField extends StatefulWidget {
  const McIdField({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.hint,
    this.allowTags = false,
  });

  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final bool allowTags;

  @override
  State<McIdField> createState() => _McIdFieldState();
}

class _McIdFieldState extends State<McIdField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(McIdField old) {
    super.didUpdateWidget(old);
    if (widget.value != _controller.text && !_focus.hasFocus) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return RawAutocomplete<String>(
      textEditingController: _controller,
      focusNode: _focus,
      optionsBuilder: (value) {
        final q = value.text
            .trim()
            .toLowerCase()
            .replaceFirst('minecraft:', '')
            .replaceAll(' ', '_');
        if (q.isEmpty) return const Iterable<String>.empty();
        final starts = <String>[];
        final contains = <String>[];
        for (final o in widget.options) {
          if (o.startsWith(q)) {
            starts.add(o);
          } else if (o.contains(q)) {
            contains.add(o);
          }
          if (starts.length > 40) break;
        }
        return [...starts, ...contains].take(40);
      },
      onSelected: (v) {
        _controller.text = v;
        widget.onChanged(v);
      },
      fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
        controller: controller,
        focusNode: focus,
        onChanged: (v) => widget.onChanged(v.trim()),
        onSubmitted: (_) => onSubmit(),
        style: mcMono(context, size: 13),
        decoration: mcInputDecoration(
          context,
          hint: widget.hint ?? L.of(context).mcSearchIds,
          prefixIcon: Icons.search_rounded,
        ),
      ),
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: luma.surface,
            elevation: 6,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260, maxWidth: 360),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (context, i) => InkWell(
                  onTap: () => onSelected(list[i]),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            mcPretty(list[i]),
                            style: TextStyle(
                              color: luma.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          list[i],
                          style: mcMono(
                            context,
                            size: 11,
                            color: luma.textMuted,
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
      },
    );
  }
}

/// Puts a list of controls one under another with a consistent gap, so tool
/// forms read as one column without a SizedBox between every child.
class McFormColumn extends StatelessWidget {
  const McFormColumn({super.key, required this.children, this.gap = 14});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          children[i],
        ],
      ],
    );
  }
}

/// A label over a control.
class McField extends StatelessWidget {
  const McField({super.key, required this.label, required this.child, this.trailing});

  final String label;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [McLabel(label, trailing: trailing), child],
    );
  }
}

/// A small square icon button with a tooltip.
class McIconButton extends StatelessWidget {
  const McIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 32,
        height: 32,
        child: IconButton(
          padding: EdgeInsets.zero,
          iconSize: 17,
          color: color ?? luma.textSecondary,
          onPressed: onTap,
          icon: Icon(icon),
        ),
      ),
    );
  }
}

/// An empty or idle state inside a tool, smaller than LumaEmptyState.
class McHint extends StatelessWidget {
  const McHint({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: luma.accentSubtle,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: luma.accent, size: 26),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: 4),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: TextStyle(color: luma.textSecondary, fontSize: 12.5),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}
