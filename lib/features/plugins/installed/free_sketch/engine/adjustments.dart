import 'dart:math' as math;
import 'dart:ui';

/// Layer adjustments. Each is a colour matrix or an image filter, so a live
/// preview is a single filtered draw of the layer and applying it is the same
/// draw rasterised once.
enum AdjustmentKind {
  hueSaturation('Hue / saturation', [
    AdjustmentParam('hue', 'Hue', -180, 180, 0, unit: '°'),
    AdjustmentParam('saturation', 'Saturation', -100, 100, 0, unit: '%'),
    AdjustmentParam('lightness', 'Lightness', -100, 100, 0, unit: '%'),
  ]),
  brightnessContrast('Brightness / contrast', [
    AdjustmentParam('brightness', 'Brightness', -100, 100, 0, unit: '%'),
    AdjustmentParam('contrast', 'Contrast', -100, 100, 0, unit: '%'),
  ]),
  colorBalance('Color balance', [
    AdjustmentParam('red', 'Cyan ↔ Red', -100, 100, 0),
    AdjustmentParam('green', 'Magenta ↔ Green', -100, 100, 0),
    AdjustmentParam('blue', 'Yellow ↔ Blue', -100, 100, 0),
  ]),
  blur('Gaussian blur', [
    AdjustmentParam('radius', 'Radius', 0, 60, 4, unit: ' px'),
  ]),
  invert('Invert', []),
  desaturate('Black & white', []);

  const AdjustmentKind(this.label, this.params);

  final String label;
  final List<AdjustmentParam> params;

  Map<String, double> get defaults => {for (final p in params) p.key: p.initial};

  /// The paint that draws a layer adjusted — used both for the preview and
  /// when the adjustment is applied.
  Paint paint(Map<String, double> values) {
    double v(String key) => values[key] ?? 0;
    final paint = Paint();
    switch (this) {
      case AdjustmentKind.hueSaturation:
        var m = _hue(v('hue'));
        m = _mul(_saturation(1 + v('saturation') / 100), m);
        final l = v('lightness') / 100;
        if (l > 0) {
          m = _mul(_scaleOffset(1 - l, 255 * l), m);
        } else if (l < 0) {
          m = _mul(_scaleOffset(1 + l, 0), m);
        }
        paint.colorFilter = ColorFilter.matrix(m);
      case AdjustmentKind.brightnessContrast:
        final b = v('brightness') / 100;
        final c = v('contrast') / 100;
        final factor = c >= 0 ? 1 / (1 - c * 0.9) : 1 + c;
        paint.colorFilter = ColorFilter.matrix(
          _scaleOffset(factor, 128 * (1 - factor) + b * 128),
        );
      case AdjustmentKind.colorBalance:
        paint.colorFilter = ColorFilter.matrix(<double>[
          1, 0, 0, 0, v('red') * 0.6, //
          0, 1, 0, 0, v('green') * 0.6, //
          0, 0, 1, 0, v('blue') * 0.6, //
          0, 0, 0, 1, 0, //
        ]);
      case AdjustmentKind.blur:
        final sigma = math.max(0.01, v('radius') / 2);
        paint.imageFilter = ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal);
      case AdjustmentKind.invert:
        paint.colorFilter = const ColorFilter.matrix(<double>[
          -1, 0, 0, 0, 255, //
          0, -1, 0, 0, 255, //
          0, 0, -1, 0, 255, //
          0, 0, 0, 1, 0, //
        ]);
      case AdjustmentKind.desaturate:
        paint.colorFilter = ColorFilter.matrix(_saturation(0));
    }
    return paint;
  }

  static List<double> _scaleOffset(double scale, double offset) => <double>[
        scale, 0, 0, 0, offset, //
        0, scale, 0, 0, offset, //
        0, 0, scale, 0, offset, //
        0, 0, 0, 1, 0, //
      ];

  static List<double> _saturation(double s) => <double>[
        0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s, 0, 0, //
        0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s, 0, 0, //
        0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s, 0, 0, //
        0, 0, 0, 1, 0, //
      ];

  static List<double> _hue(double degrees) {
    final r = degrees * math.pi / 180;
    final c = math.cos(r);
    final s = math.sin(r);
    return <double>[
      0.213 + c * 0.787 - s * 0.213, 0.715 - c * 0.715 - s * 0.715, 0.072 - c * 0.072 + s * 0.928, 0, 0, //
      0.213 - c * 0.213 + s * 0.143, 0.715 + c * 0.285 + s * 0.140, 0.072 - c * 0.072 - s * 0.283, 0, 0, //
      0.213 - c * 0.213 - s * 0.787, 0.715 - c * 0.715 + s * 0.715, 0.072 + c * 0.928 + s * 0.072, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }

  /// `a × b` for 4×5 colour matrices (b is applied first).
  static List<double> _mul(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0);
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 5; col++) {
        var sum = col == 4 ? a[row * 5 + 4] : 0.0;
        for (var k = 0; k < 4; k++) {
          sum += a[row * 5 + k] * b[k * 5 + col];
        }
        out[row * 5 + col] = sum;
      }
    }
    return out;
  }
}

class AdjustmentParam {
  const AdjustmentParam(this.key, this.label, this.min, this.max, this.initial, {this.unit = ''});

  final String key;
  final String label;
  final double min;
  final double max;
  final double initial;
  final String unit;
}
