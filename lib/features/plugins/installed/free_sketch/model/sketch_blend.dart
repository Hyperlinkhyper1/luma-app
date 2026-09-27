import 'dart:ui';

/// A layer's blend mode.
///
/// Every mode maps onto one of the engine's own [BlendMode]s, so compositing
/// is a single draw per layer. The PSD and OpenRaster keys are what the two
/// layered export formats call the same mode; keeping them here means the
/// exporters and the painter cannot disagree about what "Overlay" is.
enum SketchBlend {
  normal('Normal', BlendMode.srcOver, 'norm', 'svg:src-over'),
  multiply('Multiply', BlendMode.multiply, 'mul ', 'svg:multiply'),
  colorBurn('Color burn', BlendMode.colorBurn, 'idiv', 'svg:color-burn'),
  darken('Darken', BlendMode.darken, 'dark', 'svg:darken'),
  screen('Screen', BlendMode.screen, 'scrn', 'svg:screen'),
  colorDodge('Color dodge', BlendMode.colorDodge, 'div ', 'svg:color-dodge'),
  lighten('Lighten', BlendMode.lighten, 'lite', 'svg:lighten'),
  add('Add', BlendMode.plus, 'lddg', 'svg:plus'),
  overlay('Overlay', BlendMode.overlay, 'over', 'svg:overlay'),
  softLight('Soft light', BlendMode.softLight, 'sLit', 'svg:soft-light'),
  hardLight('Hard light', BlendMode.hardLight, 'hLit', 'svg:hard-light'),
  difference('Difference', BlendMode.difference, 'diff', 'svg:difference'),
  exclusion('Exclusion', BlendMode.exclusion, 'smud', 'svg:exclusion'),
  hue('Hue', BlendMode.hue, 'hue ', 'svg:hue'),
  saturation('Saturation', BlendMode.saturation, 'sat ', 'svg:saturation'),
  color('Color', BlendMode.color, 'colr', 'svg:color'),
  luminosity('Luminosity', BlendMode.luminosity, 'lum ', 'svg:luminosity');

  const SketchBlend(this.label, this.mode, this.psdKey, this.oraOp);

  final String label;
  final BlendMode mode;

  /// The four-character key Photoshop stores in a layer record.
  final String psdKey;

  /// The `composite-op` attribute OpenRaster writes in `stack.xml`.
  final String oraOp;

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
