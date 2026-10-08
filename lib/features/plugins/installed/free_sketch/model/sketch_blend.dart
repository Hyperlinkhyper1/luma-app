import 'dart:ui';

import '../../../../../l10n/current_l.dart';

/// A layer's blend mode.
///
/// Every mode maps onto one of the engine's own [BlendMode]s, so compositing
/// is a single draw per layer. The PSD and OpenRaster keys are what the two
/// layered export formats call the same mode; keeping them here means the
/// exporters and the painter cannot disagree about what "Overlay" is.
enum SketchBlend {
  normal(BlendMode.srcOver, 'norm', 'svg:src-over'),
  multiply(BlendMode.multiply, 'mul ', 'svg:multiply'),
  colorBurn(BlendMode.colorBurn, 'idiv', 'svg:color-burn'),
  darken(BlendMode.darken, 'dark', 'svg:darken'),
  screen(BlendMode.screen, 'scrn', 'svg:screen'),
  colorDodge(BlendMode.colorDodge, 'div ', 'svg:color-dodge'),
  lighten(BlendMode.lighten, 'lite', 'svg:lighten'),
  add(BlendMode.plus, 'lddg', 'svg:plus'),
  overlay(BlendMode.overlay, 'over', 'svg:overlay'),
  softLight(BlendMode.softLight, 'sLit', 'svg:soft-light'),
  hardLight(BlendMode.hardLight, 'hLit', 'svg:hard-light'),
  difference(BlendMode.difference, 'diff', 'svg:difference'),
  exclusion(BlendMode.exclusion, 'smud', 'svg:exclusion'),
  hue(BlendMode.hue, 'hue ', 'svg:hue'),
  saturation(BlendMode.saturation, 'sat ', 'svg:saturation'),
  color(BlendMode.color, 'colr', 'svg:color'),
  luminosity(BlendMode.luminosity, 'lum ', 'svg:luminosity');

  const SketchBlend(this.mode, this.psdKey, this.oraOp);

  final BlendMode mode;

  /// The four-character key Photoshop stores in a layer record.
  final String psdKey;

  /// The `composite-op` attribute OpenRaster writes in `stack.xml`.
  final String oraOp;

  String get label => switch (this) {
        normal => currentL.freeSketchBlendNormal,
        multiply => currentL.freeSketchBlendMultiply,
        colorBurn => currentL.freeSketchBlendColorBurn,
        darken => currentL.freeSketchBlendDarken,
        screen => currentL.freeSketchBlendScreen,
        colorDodge => currentL.freeSketchBlendColorDodge,
        lighten => currentL.freeSketchBlendLighten,
        add => currentL.freeSketchBlendAdd,
        overlay => currentL.freeSketchBlendOverlay,
        softLight => currentL.freeSketchBlendSoftLight,
        hardLight => currentL.freeSketchBlendHardLight,
        difference => currentL.freeSketchBlendDifference,
        exclusion => currentL.freeSketchBlendExclusion,
        hue => currentL.freeSketchBlendHue,
        saturation => currentL.freeSketchBlendSaturation,
        color => currentL.freeSketchBlendColor,
        luminosity => currentL.freeSketchBlendLuminosity,
      };

  /// Unknown names fall back to [normal]: a document written by a newer
  /// version should still open, just with the one layer composited plainly.
  static SketchBlend parse(String? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return normal;
  }

  /// Menu groups, the way every painting app lays them out: darkening,
  /// lightening, contrast, inversion and component modes.
  static const groups = <List<SketchBlend>>[
    [normal],
    [multiply, colorBurn, darken],
    [screen, colorDodge, lighten, add],
    [overlay, softLight, hardLight],
    [difference, exclusion],
    [hue, saturation, color, luminosity],
  ];
}
