import 'package:flutter/material.dart';

/// Semantic color tokens for luma. Both the dark ("dark gray lavender") and
/// light ("white lavender") variants are expressed through the same fields so
/// widgets can read tokens without caring which theme is active.
@immutable
class LumaPalette extends ThemeExtension<LumaPalette> {
  const LumaPalette({
    required this.rail,
    required this.background,
    required this.surface,
    required this.surfaceHover,
    required this.border,
    required this.accent,
    required this.accentHover,
    required this.accentSubtle,
    required this.onAccent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.success,
    required this.danger,
  });

  /// The far-left vertical icon sidebar.
  final Color rail;

  /// Main content background.
  final Color background;

  /// Cards / panels sitting on top of [background].
  final Color surface;
  final Color surfaceHover;
  final Color border;

  /// Lavender brand accent.
  final Color accent;
  final Color accentHover;

  /// Translucent accent used for active states / soft fills.
  final Color accentSubtle;

  /// Text/icon color that reads well on top of [accent].
  final Color onAccent;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  final Color success;
  final Color danger;

  /// Dark gray lavender.
  static const dark = LumaPalette(
    rail: Color(0xFF121019),
    background: Color(0xFF17141F),
    surface: Color(0xFF1E1B28),
    surfaceHover: Color(0xFF272232),
    border: Color(0xFF2C2839),
    accent: Color(0xFFB49DF5),
    accentHover: Color(0xFFC6B4F8),
    accentSubtle: Color(0x33B49DF5),
    onAccent: Color(0xFF1A1526),
    textPrimary: Color(0xFFECEAF4),
    textSecondary: Color(0xFFA9A3BD),
    textMuted: Color(0xFF6F6981),
    success: Color(0xFF57D9A3),
    danger: Color(0xFFFF6B81),
  );

  /// White lavender.
  static const light = LumaPalette(
    rail: Color(0xFFEDE7FA),
    background: Color(0xFFF7F5FC),
    surface: Color(0xFFFFFFFF),
    surfaceHover: Color(0xFFF1ECFB),
    border: Color(0xFFE5DFF2),
    accent: Color(0xFF7C5AD9),
    accentHover: Color(0xFF6B49C8),
    accentSubtle: Color(0x1F7C5AD9),
    onAccent: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF221E2E),
    textSecondary: Color(0xFF5E5870),
    textMuted: Color(0xFF918BA1),
    success: Color(0xFF12A372),
    danger: Color(0xFFE5484D),
  );

  @override
  LumaPalette copyWith({
    Color? rail,
    Color? background,
    Color? surface,
    Color? surfaceHover,
    Color? border,
    Color? accent,
    Color? accentHover,
    Color? accentSubtle,
    Color? onAccent,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? success,
    Color? danger,
  }) {
    return LumaPalette(
      rail: rail ?? this.rail,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceHover: surfaceHover ?? this.surfaceHover,
      border: border ?? this.border,
      accent: accent ?? this.accent,
      accentHover: accentHover ?? this.accentHover,
      accentSubtle: accentSubtle ?? this.accentSubtle,
      onAccent: onAccent ?? this.onAccent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      success: success ?? this.success,
      danger: danger ?? this.danger,
    );
  }

  /// Returns a copy of this palette retuned to a new accent [seed], adapted to
  /// [brightness]. As well as the accent family, the neutral surfaces, rail,
  /// borders and text are re-hued to the seed's hue so the whole app picks up
  /// the chosen tint (rather than keeping the default lavender wash).
  LumaPalette withAccent(Color seed, Brightness brightness) {
    final hsl = HSLColor.fromColor(seed);
    final hue = hsl.hue;
    final isDark = brightness == Brightness.dark;

    final accent = hsl.withLightness(isDark ? 0.70 : 0.52).toColor();
    final accentHover = hsl.withLightness(isDark ? 0.80 : 0.44).toColor();
    final onAccent = accent.computeLuminance() > 0.55
        ? const Color(0xFF1A1526)
        : const Color(0xFFFFFFFF);

    // Shifts a near-neutral color to [hue], keeping its lightness/saturation so
    // a lavender-grey becomes the equivalent grey in the new hue.
    Color tint(Color c) => HSLColor.fromColor(c).withHue(hue).toColor();

    return copyWith(
      rail: tint(rail),
      background: tint(background),
      surface: tint(surface),
      surfaceHover: tint(surfaceHover),
      border: tint(border),
      accent: accent,
      accentHover: accentHover,
      accentSubtle: accent.withValues(alpha: isDark ? 0.22 : 0.14),
      onAccent: onAccent,
      textPrimary: tint(textPrimary),
      textSecondary: tint(textSecondary),
      textMuted: tint(textMuted),
    );
  }

  @override
  LumaPalette lerp(ThemeExtension<LumaPalette>? other, double t) {
    if (other is! LumaPalette) return this;
    return LumaPalette(
      rail: Color.lerp(rail, other.rail, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHover: Color.lerp(surfaceHover, other.surfaceHover, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentHover: Color.lerp(accentHover, other.accentHover, t)!,
      accentSubtle: Color.lerp(accentSubtle, other.accentSubtle, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

/// Convenience accessor: `context.luma` -> active [LumaPalette].
extension LumaThemeX on BuildContext {
  LumaPalette get luma => Theme.of(this).extension<LumaPalette>()!;
}

class LumaTheme {
  const LumaTheme._();

  static ThemeData get dark => _build(LumaPalette.dark, Brightness.dark);
  static ThemeData get light => _build(LumaPalette.light, Brightness.light);

  /// Builds the theme for [brightness], optionally recoloring the lavender
  /// accent with a chosen [accentSeed] (null keeps the default lavender).
  static ThemeData from(Brightness brightness, [Color? accentSeed]) {
    final base =
        brightness == Brightness.dark ? LumaPalette.dark : LumaPalette.light;
    final palette =
        accentSeed == null ? base : base.withAccent(accentSeed, brightness);
    return _build(palette, brightness);
  }

  static ThemeData _build(LumaPalette p, Brightness brightness) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: p.accent,
      brightness: brightness,
    ).copyWith(
      primary: p.accent,
      onPrimary: p.onAccent,
      surface: p.surface,
      onSurface: p.textPrimary,
      error: p.danger,
    );

    final textTheme = base.textTheme
        .apply(bodyColor: p.textPrimary, displayColor: p.textPrimary)
        .copyWith(
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: p.textPrimary,
            letterSpacing: -0.2,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: p.textPrimary,
          ),
        );

    return base.copyWith(
      extensions: [p],
      colorScheme: colorScheme,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      dividerColor: p.border,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: p.textSecondary),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.surfaceHover,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: p.border),
        ),
        textStyle: TextStyle(color: p.textPrimary, fontSize: 12),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: p.accent,
        inactiveTrackColor: p.border,
        thumbColor: p.accent,
        overlayColor: p.accentSubtle,
        trackHeight: 4,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceHover,
        contentTextStyle: TextStyle(color: p.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
