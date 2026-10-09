import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import '../../../../../theme/theme_style.dart';
import 'mc_tool_catalog.dart';

/// One set of tool screenshots per background luma can paint, so a banner
/// never shows a dark tool on a light page or espresso on lavender.
///
/// The images are rendered by `test/mc_tool_screenshots_test.dart`.
enum McShotVariant {
  light('light'),
  dark('dark'),
  coffeeLight('coffee_light'),
  coffeeDark('coffee_dark');

  const McShotVariant(this.dir);

  /// The folder under [kMcShotsRoot].
  final String dir;

  /// The set that matches the theme around [context].
  static McShotVariant of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final coffee = context.lumaDecor.style == LumaThemeStyle.coffee;
    return switch ((coffee, dark)) {
      (true, true) => McShotVariant.coffeeDark,
      (true, false) => McShotVariant.coffeeLight,
      (false, true) => McShotVariant.dark,
      (false, false) => McShotVariant.light,
    };
  }
}

const kMcShotsRoot = 'assets/mc_tools/shots';

/// The banner for [tool] in [variant].
String mcShotAsset(McTool tool, McShotVariant variant) =>
    '$kMcShotsRoot/${variant.dir}/${tool.name}.jpg';
