import 'package:flutter/material.dart';

/// The sixteen dyes, with the two colour tables the game keeps for them: the
/// texture tint used on banners, beds and leather, and the separate firework
/// colour.
enum McDye {
  white(0xF9FFFE, 0xF0F0F0),
  orange(0xF9801D, 0xEB8844),
  magenta(0xC74EBD, 0xC354CD),
  lightBlue(0x3AB3DA, 0x6689D3),
  yellow(0xFED83D, 0xDECF2A),
  lime(0x80C71F, 0x41CD34),
  pink(0xF38BAA, 0xD88198),
  gray(0x474F52, 0x434343),
  lightGray(0x9D9D97, 0xABABAB),
  cyan(0x169C9C, 0x287697),
  purple(0x8932B8, 0x7B2FBE),
  blue(0x3C44AA, 0x253192),
  brown(0x835432, 0x51301A),
  green(0x5E7C16, 0x3B511A),
  red(0xB02E26, 0xB3312C),
  black(0x1D1D21, 0x1E1B1B);

  const McDye(this.rgb, this.fireworkRgb);

  /// Texture tint (banners, leather armour, sheep).
  final int rgb;

  /// The colour a firework star of this dye bursts in.
  final int fireworkRgb;

  Color get color => Color(0xFF000000 | rgb);
  Color get fireworkColor => Color(0xFF000000 | fireworkRgb);

  /// `light_blue`, as ids and components spell it.
  String get id => name.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (m) => '_${m[0]!.toLowerCase()}',
  );

  String get label => id
      .split('_')
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  String get item => '${id}_dye';
}

/// A row of the sixteen dye swatches to pick one from.
class McDyePicker extends StatelessWidget {
  const McDyePicker({
    super.key,
    required this.selected,
    required this.onSelect,
    this.firework = false,
    this.size = 26,
  });

  final McDye? selected;
  final ValueChanged<McDye> onSelect;
  final bool firework;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        for (final dye in McDye.values)
          McSwatch(
            color: firework ? dye.fireworkColor : dye.color,
            tooltip: dye.label,
            selected: dye == selected,
            size: size,
            onTap: () => onSelect(dye),
          ),
      ],
    );
  }
}

/// A single colour swatch; a ring marks the selected one.
class McSwatch extends StatelessWidget {
  const McSwatch({
    super.key,
    required this.color,
    required this.onTap,
    this.selected = false,
    this.tooltip,
    this.size = 26,
    this.child,
  });

  final Color color;
  final VoidCallback onTap;
  final bool selected;
  final String? tooltip;
  final double size;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final swatch = Semantics(
      button: true,
      selected: selected,
      label: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(size / 4),
              border: Border.all(
                color: selected
                    ? scheme.primary
                    : Colors.black.withValues(alpha: 0.18),
                width: selected ? 2.5 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.35),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
            child: child,
          ),
        ),
      ),
    );
    return tooltip == null
        ? swatch
        : Tooltip(message: tooltip!, child: swatch);
  }
}

/// `#RRGGBB` for a colour.
String mcHex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// The 24-bit integer the item components store colours as.
int mcRgbInt(Color c) => c.toARGB32() & 0xFFFFFF;

Color? mcParseHex(String text) {
  final t = text.trim().replaceFirst('#', '');
  if (t.length != 6) return null;
  final v = int.tryParse(t, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}
