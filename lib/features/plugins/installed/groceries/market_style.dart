import 'package:flutter/material.dart';

import '../../../../theme/luma_theme.dart';

/// Approximate per-market accent colors, used only to tell store sections
/// and badges apart at a glance — not official brand colors.
const marketColors = <String, Color>{
  'jumbo': Color(0xFFF6C500),
  'ah': Color(0xFF4FA8DE),
  'lidl': Color(0xFF3D6DC7),
};

Color colorForMarket(String slug, LumaPalette luma) =>
    marketColors[slug] ?? luma.accent;
