/// A whole-app visual style.
///
/// This is a bigger lever than the accent color: an accent only re-hues the
/// existing palette, while a style also swaps the surface shapes, the border
/// weights, the display typeface and any background ornament (see
/// `LumaDecor` in `luma_theme.dart`).
enum LumaThemeStyle {
  /// luma's built-in look — lavender, 16px card corners, no ornament.
  standard,

  /// Espresso/latte browns, stadium buttons, cup-round cards and a drifting
  /// coffee-bean backdrop. Paid: Orbit and Nova only.
  coffee,
}

/// Describes a [LumaThemeStyle] for the Settings picker, including which plan
/// tier it needs.
class ThemeStyleOption {
  const ThemeStyleOption({
    required this.style,
    required this.name,
    required this.blurb,
    required this.minPlanId,
  });

  final LumaThemeStyle style;

  /// English fallback name. The Settings picker prefers the localized string.
  final String name;
  final String blurb;

  /// The lowest plan tier allowed to use this style, or null when it's free
  /// for everyone.
  final String? minPlanId;

  bool get isPaid => minPlanId != null;

  /// Stable id used in the settings JSON / sync payload.
  String get id => style.name;
}

/// Every selectable style, in picker order. The first entry is the default.
const List<ThemeStyleOption> kThemeStyles = [
  ThemeStyleOption(
    style: LumaThemeStyle.standard,
    name: 'Default',
    blurb: 'luma as it comes — clean surfaces and your chosen accent.',
    minPlanId: null,
  ),
  ThemeStyleOption(
    style: LumaThemeStyle.coffee,
    name: 'Coffee',
    blurb: 'Espresso and cream, softer shapes, and beans drifting behind '
        'everything.',
    minPlanId: 'orbit',
  ),
];

ThemeStyleOption themeStyleOption(LumaThemeStyle style) =>
    kThemeStyles.firstWhere(
      (o) => o.style == style,
      orElse: () => kThemeStyles.first,
    );

/// Parses a persisted style id, falling back to [LumaThemeStyle.standard] for
/// anything unknown (an older build, or a hand-edited settings file).
LumaThemeStyle themeStyleFromId(Object? id) {
  for (final option in kThemeStyles) {
    if (option.id == id) return option.style;
  }
  return LumaThemeStyle.standard;
}

/// Plan tiers, lowest first. Mirrors `SettingsController._tierIndex`.
int _tierIndex(String? id) => switch (id) {
      'nova' => 2,
      'orbit' => 1,
      _ => 0,
    };

/// Whether [planId] unlocks [style]. Free styles are always unlocked; paid
/// ones need the plan to be at or above [ThemeStyleOption.minPlanId], so Nova
/// gets everything Orbit does.
bool themeStyleUnlocked(LumaThemeStyle style, String planId) {
  final option = themeStyleOption(style);
  final min = option.minPlanId;
  if (min == null) return true;
  return _tierIndex(planId) >= _tierIndex(min);
}
