import 'package:flutter/material.dart';

import 'theme_style.dart';

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

  /// Espresso — the dark half of the Coffee style. Roasted browns under a
  /// crema accent, with cream (not white) text so nothing glares.
  static const coffeeDark = LumaPalette(
    rail: Color(0xFF150E08),
    background: Color(0xFF1D140D),
    surface: Color(0xFF291D13),
    surfaceHover: Color(0xFF35261A),
    border: Color(0xFF46331F),
    accent: Color(0xFFDDA96A),
    accentHover: Color(0xFFF0C68D),
    accentSubtle: Color(0x3DDDA96A),
    onAccent: Color(0xFF21150A),
    textPrimary: Color(0xFFF8EFE2),
    textSecondary: Color(0xFFCDB69A),
    textMuted: Color(0xFFA18B70),
    success: Color(0xFF8FBF6F),
    danger: Color(0xFFE8836A),
  );

  /// Latte — the light half of the Coffee style. Steamed-milk surfaces over a
  /// warm oat background, accented with a dark roast that still clears 4.5:1.
  static const coffeeLight = LumaPalette(
    rail: Color(0xFFEDE0CE),
    background: Color(0xFFF6EEE3),
    surface: Color(0xFFFFFAF3),
    surfaceHover: Color(0xFFF2E7D7),
    border: Color(0xFFE0CFB6),
    accent: Color(0xFF8A5A2E),
    accentHover: Color(0xFF6D4522),
    accentSubtle: Color(0x1F8A5A2E),
    onAccent: Color(0xFFFFF9F2),
    textPrimary: Color(0xFF2B1D12),
    textSecondary: Color(0xFF634F3B),
    textMuted: Color(0xFF836C55),
    success: Color(0xFF3C6F3F),
    danger: Color(0xFFAF4229),
  );

  /// The base palette for [style] at [brightness], before any accent seed.
  static LumaPalette forStyle(LumaThemeStyle style, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return switch (style) {
      LumaThemeStyle.coffee => isDark ? coffeeDark : coffeeLight,
      LumaThemeStyle.standard => isDark ? dark : light,
    };
  }

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

/// The decorative layer a style paints behind the app's content.
enum LumaOrnament {
  /// A flat [LumaPalette.background] — luma's default.
  none,

  /// Drifting coffee beans over a warm two-pool gradient wash.
  coffeeBeans,
}

/// Shape, weight and ornament tokens for the active [LumaThemeStyle].
///
/// [LumaPalette] answers "what color"; this answers "what shape". Keeping the
/// two apart means a style can round every corner in the app without touching
/// a single color, and widgets read both from the theme rather than
/// hardcoding a radius.
@immutable
class LumaDecor extends ThemeExtension<LumaDecor> {
  const LumaDecor({
    required this.style,
    required this.cardRadius,
    required this.buttonRadius,
    required this.pillRadius,
    required this.badgeRadiusFactor,
    required this.borderWidth,
    required this.cardShadow,
    required this.displayFontFamily,
    required this.displayFontFallback,
    required this.ornament,
  });

  final LumaThemeStyle style;

  /// Corner radius for [LumaCard] and other panel surfaces.
  final double cardRadius;

  /// Corner radius for buttons. Values at or above half the 44px button
  /// height read as a stadium.
  final double buttonRadius;

  /// Corner radius for the segmented-tab pills.
  final double pillRadius;

  /// [LumaIconBadge]'s radius as a fraction of its size — 0.5 is a circle.
  final double badgeRadiusFactor;

  /// Stroke width for card and button borders.
  final double borderWidth;

  /// Shadow cast by cards. Empty for flat styles.
  final List<BoxShadow> cardShadow;

  /// Typeface for titles and headings, or null to keep the platform default.
  final String? displayFontFamily;

  /// Fallback chain for [displayFontFamily]. Matters for the CJK locales,
  /// where a Latin-only display face has no glyphs to offer.
  final List<String> displayFontFallback;

  final LumaOrnament ornament;

  /// luma's built-in look. These are the values the shared widgets used to
  /// hardcode, so the default theme is pixel-identical to before.
  static const standard = LumaDecor(
    style: LumaThemeStyle.standard,
    cardRadius: 16,
    buttonRadius: 12,
    pillRadius: 10,
    badgeRadiusFactor: 0.3,
    borderWidth: 1,
    cardShadow: [],
    displayFontFamily: null,
    displayFontFallback: [],
    ornament: LumaOrnament.none,
  );

  /// Rounder, softer and warmer: cup-round cards, stadium buttons, circular
  /// badges and a serif display face.
  static const coffee = LumaDecor(
    style: LumaThemeStyle.coffee,
    cardRadius: 24,
    buttonRadius: 999,
    pillRadius: 999,
    badgeRadiusFactor: 0.5,
    borderWidth: 1.4,
    cardShadow: [
      BoxShadow(
        color: Color(0x1F2B1A0C),
        blurRadius: 22,
        offset: Offset(0, 8),
      ),
    ],
    displayFontFamily: 'Georgia',
    displayFontFallback: ['Times New Roman', 'Noto Serif', 'serif'],
    ornament: LumaOrnament.coffeeBeans,
  );

  static LumaDecor forStyle(LumaThemeStyle style) => switch (style) {
        LumaThemeStyle.coffee => coffee,
        LumaThemeStyle.standard => standard,
      };

  /// A [BorderRadius] for cards, clamped so a stadium radius can't invert on
  /// a very short surface.
  BorderRadius get cardBorderRadius => BorderRadius.circular(cardRadius);
  BorderRadius get buttonBorderRadius => BorderRadius.circular(buttonRadius);
  BorderRadius get pillBorderRadius => BorderRadius.circular(pillRadius);

  /// The display [TextStyle] merged onto [base], or [base] unchanged when the
  /// style keeps the platform typeface.
  TextStyle? applyDisplayFont(TextStyle? base) {
    if (displayFontFamily == null) return base;
    return (base ?? const TextStyle()).copyWith(
      fontFamily: displayFontFamily,
      fontFamilyFallback: displayFontFallback,
    );
  }

  @override
  LumaDecor copyWith({
    LumaThemeStyle? style,
    double? cardRadius,
    double? buttonRadius,
    double? pillRadius,
    double? badgeRadiusFactor,
    double? borderWidth,
    List<BoxShadow>? cardShadow,
    String? displayFontFamily,
    List<String>? displayFontFallback,
    LumaOrnament? ornament,
  }) {
    return LumaDecor(
      style: style ?? this.style,
      cardRadius: cardRadius ?? this.cardRadius,
      buttonRadius: buttonRadius ?? this.buttonRadius,
      pillRadius: pillRadius ?? this.pillRadius,
      badgeRadiusFactor: badgeRadiusFactor ?? this.badgeRadiusFactor,
      borderWidth: borderWidth ?? this.borderWidth,
      cardShadow: cardShadow ?? this.cardShadow,
      displayFontFamily: displayFontFamily ?? this.displayFontFamily,
      displayFontFallback: displayFontFallback ?? this.displayFontFallback,
      ornament: ornament ?? this.ornament,
    );
  }

  @override
  LumaDecor lerp(ThemeExtension<LumaDecor>? other, double t) {
    if (other is! LumaDecor) return this;
    // The discrete fields (style, font, ornament) can't be interpolated, so
    // they flip at the halfway point of the theme crossfade.
    final past = t < 0.5;
    return LumaDecor(
      style: past ? style : other.style,
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t),
      buttonRadius: lerpDouble(buttonRadius, other.buttonRadius, t),
      pillRadius: lerpDouble(pillRadius, other.pillRadius, t),
      badgeRadiusFactor:
          lerpDouble(badgeRadiusFactor, other.badgeRadiusFactor, t),
      borderWidth: lerpDouble(borderWidth, other.borderWidth, t),
      cardShadow: BoxShadow.lerpList(cardShadow, other.cardShadow, t) ?? const [],
      displayFontFamily:
          past ? displayFontFamily : other.displayFontFamily,
      displayFontFallback:
          past ? displayFontFallback : other.displayFontFallback,
      ornament: past ? ornament : other.ornament,
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

/// Convenience accessor: `context.luma` -> active [LumaPalette].
extension LumaThemeX on BuildContext {
  LumaPalette get luma => Theme.of(this).extension<LumaPalette>()!;

  /// `context.lumaDecor` -> active [LumaDecor]. Falls back to
  /// [LumaDecor.standard] so a widget built under a bare [ThemeData] (as in
  /// some widget tests) still has shapes to read.
  LumaDecor get lumaDecor =>
      Theme.of(this).extension<LumaDecor>() ?? LumaDecor.standard;
}

class LumaTheme {
  const LumaTheme._();

  static ThemeData get dark =>
      _build(LumaPalette.dark, Brightness.dark, LumaDecor.standard);
  static ThemeData get light =>
      _build(LumaPalette.light, Brightness.light, LumaDecor.standard);

  /// Builds the theme for [brightness] in the given [style], optionally
  /// recoloring the accent with a chosen [accentSeed] (null keeps the style's
  /// own accent).
  ///
  /// A style that ships a complete palette — Coffee — ignores [accentSeed]:
  /// re-hueing espresso to teal would undo the very thing the user picked.
  /// The Settings picker says as much next to the accent swatches.
  static ThemeData from(
    Brightness brightness, [
    Color? accentSeed,
    LumaThemeStyle style = LumaThemeStyle.standard,
  ]) {
    final base = LumaPalette.forStyle(style, brightness);
    final palette = (accentSeed == null || style != LumaThemeStyle.standard)
        ? base
        : base.withAccent(accentSeed, brightness);
    return _build(palette, brightness, LumaDecor.forStyle(style));
  }

  /// The accent this combination resolves to, without building a whole
  /// [ThemeData] for it. The splash screen paints before the MaterialApp's
  /// theme is in scope, so it needs the color on its own.
  static Color accentFor(
    Brightness brightness,
    Color? accentSeed, [
    LumaThemeStyle style = LumaThemeStyle.standard,
  ]) {
    final base = LumaPalette.forStyle(style, brightness);
    if (accentSeed == null || style != LumaThemeStyle.standard) {
      return base.accent;
    }
    return base.withAccent(accentSeed, brightness).accent;
  }

  static ThemeData _build(
    LumaPalette p,
    Brightness brightness,
    LumaDecor decor,
  ) {
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

    final applied =
        base.textTheme.apply(bodyColor: p.textPrimary, displayColor: p.textPrimary);
    final textTheme = applied.copyWith(
      // Only the display tiers take the style's typeface — body copy keeps
      // the platform font so long text stays as legible as it was.
      displayLarge: decor.applyDisplayFont(applied.displayLarge),
      displayMedium: decor.applyDisplayFont(applied.displayMedium),
      displaySmall: decor.applyDisplayFont(applied.displaySmall),
      headlineLarge: decor.applyDisplayFont(applied.headlineLarge),
      headlineMedium: decor.applyDisplayFont(applied.headlineMedium),
      headlineSmall: decor.applyDisplayFont(applied.headlineSmall),
      titleLarge: decor.applyDisplayFont(
        applied.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: p.textPrimary,
          letterSpacing: -0.2,
        ),
      ),
      titleMedium: applied.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: p.textPrimary,
      ),
    );

    return base.copyWith(
      extensions: [p, decor],
      colorScheme: colorScheme,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      dividerColor: p.border,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: p.textSecondary),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.surfaceHover,
          // Half a card's radius: 8 on the default theme, rounder on Coffee.
          borderRadius: BorderRadius.circular(decor.cardRadius / 2),
          border: Border.all(color: p.border, width: decor.borderWidth),
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
