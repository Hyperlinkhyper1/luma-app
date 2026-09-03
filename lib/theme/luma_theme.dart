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
    required this.warning,
  });

  /// The far-left vertical icon sidebar.
  final Color rail;

  /// Main content background.
  final Color background;

  /// Cards / panels sitting on top of [background].
  final Color surface;
  final Color surfaceHover;
  final Color border;

  /// Brand accent.
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

  /// Cautionary status — sits between [success] and [danger] (e.g. "3
  /// updates available", "battery health fading").
  final Color warning;

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
    warning: Color(0xFFFFC15E),
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
    warning: Color(0xFFC2760C),
  );

  /// Espresso — a layered cacao ground with a quiet crema highlight.
  static const coffeeDark = LumaPalette(
    rail: Color(0xFF100A06),
    background: Color(0xFF1A110B),
    surface: Color(0xFF25180F),
    surfaceHover: Color(0xFF322117),
    border: Color(0xFF493321),
    accent: Color(0xFFDFB77F),
    accentHover: Color(0xFFF0C995),
    accentSubtle: Color(0x3DDFB77F),
    onAccent: Color(0xFF25160B),
    textPrimary: Color(0xFFF6EBDD),
    textSecondary: Color(0xFFC9B399),
    textMuted: Color(0xFFA58D73),
    success: Color(0xFF8FBE70),
    danger: Color(0xFFE47B63),
    warning: Color(0xFFD9A441),
  );

  /// Latte — warm paper, oat shadows and a dark-roast editorial accent.
  static const coffeeLight = LumaPalette(
    rail: Color(0xFFD8C7B3),
    background: Color(0xFFF0E5D7),
    surface: Color(0xFFFFFAF3),
    surfaceHover: Color(0xFFF2E5D7),
    border: Color(0xFFC5B19A),
    accent: Color(0xFF623619),
    accentHover: Color(0xFF4D2914),
    accentSubtle: Color(0x1F6B3B1D),
    onAccent: Color(0xFFFFF8EE),
    textPrimary: Color(0xFF2A1B10),
    textSecondary: Color(0xFF59412F),
    textMuted: Color(0xFF6B523D),
    success: Color(0xFF3E6D40),
    danger: Color(0xFFA8442D),
    warning: Color(0xFF9C6B12),
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
    Color? warning,
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
      warning: warning ?? this.warning,
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
      warning: Color.lerp(warning, other.warning, t)!,
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

  /// Corner radius for segmented tabs and compact chips.
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

  /// A tailored coffee-house system: generous cards, stadium actions, compact
  /// tab corners, circular badges and a serif display face.
  static const coffee = LumaDecor(
    style: LumaThemeStyle.coffee,
    cardRadius: 24,
    buttonRadius: 999,
    pillRadius: 14,
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
      onError: p.onAccent,
      outline: p.border,
      outlineVariant: p.border,
    );

    final coffee = decor.style == LumaThemeStyle.coffee;
    final fieldRadius = coffee ? 16.0 : 12.0;
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(fieldRadius),
      borderSide: BorderSide(color: p.border, width: decor.borderWidth),
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
      cardTheme: coffee
          ? CardThemeData(
              color: p.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: decor.cardBorderRadius,
                side: BorderSide(color: p.border, width: decor.borderWidth),
              ),
            )
          : base.cardTheme,
      dialogTheme: coffee
          ? DialogThemeData(
              backgroundColor: p.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: decor.cardBorderRadius,
                side: BorderSide(color: p.border, width: decor.borderWidth),
              ),
            )
          : base.dialogTheme,
      inputDecorationTheme: coffee
          ? InputDecorationThemeData(
              filled: true,
              fillColor: p.surfaceHover.withValues(
                alpha: brightness == Brightness.dark ? 0.72 : 0.88,
              ),
              labelStyle: TextStyle(color: p.textSecondary),
              hintStyle: TextStyle(color: p.textMuted),
              prefixIconColor: p.textSecondary,
              suffixIconColor: p.textSecondary,
              border: fieldBorder,
              enabledBorder: fieldBorder,
              focusedBorder: fieldBorder.copyWith(
                borderSide: BorderSide(color: p.accent, width: 1.6),
              ),
              errorBorder: fieldBorder.copyWith(
                borderSide: BorderSide(color: p.danger),
              ),
              focusedErrorBorder: fieldBorder.copyWith(
                borderSide: BorderSide(color: p.danger, width: 1.6),
              ),
            )
          : base.inputDecorationTheme,
      filledButtonTheme: coffee
          ? FilledButtonThemeData(
              style: ButtonStyle(
                minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 20),
                ),
                foregroundColor: WidgetStatePropertyAll(p.onAccent),
                backgroundColor: WidgetStatePropertyAll(p.accent),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: decor.buttonBorderRadius,
                  ),
                ),
              ),
            )
          : base.filledButtonTheme,
      outlinedButtonTheme: coffee
          ? OutlinedButtonThemeData(
              style: ButtonStyle(
                minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 20),
                ),
                foregroundColor: WidgetStatePropertyAll(p.textPrimary),
                side: WidgetStatePropertyAll(
                  BorderSide(color: p.border, width: decor.borderWidth),
                ),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: decor.buttonBorderRadius,
                  ),
                ),
              ),
            )
          : base.outlinedButtonTheme,
      textButtonTheme: coffee
          ? TextButtonThemeData(
              style: ButtonStyle(
                foregroundColor: WidgetStatePropertyAll(p.accent),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: decor.buttonBorderRadius,
                  ),
                ),
              ),
            )
          : base.textButtonTheme,
      appBarTheme: coffee
          ? AppBarThemeData(
              backgroundColor: p.background,
              foregroundColor: p.textPrimary,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              titleTextStyle: decor.applyDisplayFont(
                TextStyle(
                  color: p.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : base.appBarTheme,
      bottomSheetTheme: coffee
          ? BottomSheetThemeData(
              backgroundColor: p.surface,
              modalBackgroundColor: p.surface,
              surfaceTintColor: Colors.transparent,
              showDragHandle: true,
              dragHandleColor: p.border,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(decor.cardRadius),
                ),
                side: BorderSide(color: p.border, width: decor.borderWidth),
              ),
            )
          : base.bottomSheetTheme,
      popupMenuTheme: coffee
          ? PopupMenuThemeData(
              color: p.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(decor.cardRadius / 1.5),
                side: BorderSide(color: p.border, width: decor.borderWidth),
              ),
              textStyle: TextStyle(color: p.textPrimary, fontSize: 14),
            )
          : base.popupMenuTheme,
      navigationBarTheme: coffee
          ? NavigationBarThemeData(
              backgroundColor: p.rail,
              surfaceTintColor: Colors.transparent,
              indicatorColor: p.accentSubtle,
              indicatorShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(decor.pillRadius),
                side: BorderSide(color: p.accent, width: decor.borderWidth),
              ),
              labelTextStyle: WidgetStatePropertyAll(
                TextStyle(color: p.textSecondary, fontWeight: FontWeight.w600),
              ),
              iconTheme: WidgetStateProperty.resolveWith(
                (states) => IconThemeData(
                  color: states.contains(WidgetState.selected)
                      ? p.accent
                      : p.textSecondary,
                ),
              ),
            )
          : base.navigationBarTheme,
      navigationRailTheme: coffee
          ? NavigationRailThemeData(
              backgroundColor: p.rail,
              indicatorColor: p.accentSubtle,
              selectedIconTheme: IconThemeData(color: p.accent),
              unselectedIconTheme: IconThemeData(color: p.textSecondary),
              selectedLabelTextStyle: TextStyle(
                color: p.accent,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelTextStyle: TextStyle(color: p.textSecondary),
            )
          : base.navigationRailTheme,
      progressIndicatorTheme: coffee
          ? ProgressIndicatorThemeData(
              color: p.accent,
              linearTrackColor: p.border,
              circularTrackColor: p.border,
            )
          : base.progressIndicatorTheme,
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
