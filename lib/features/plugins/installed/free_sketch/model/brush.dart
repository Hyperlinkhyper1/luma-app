/// The brush model: what a brush *is*, independent of how it is drawn.
///
/// A brush is a stamp ("tip") laid down repeatedly along the stroke, the way
/// every raster painting app works. Everything that makes a pencil feel
/// different from an airbrush — spacing, how pressure maps onto size and
/// flow, jitter, taper, paper grain — is a number on [BrushPreset]. The
/// stroke engine turns input into dabs using these numbers; the renderer
/// draws the dabs. Neither knows any brush by name.
library;

enum BrushCategory {
  sketching('Sketching'),
  inking('Inking'),
  painting('Painting'),
  watercolor('Watercolor'),
  markers('Markers'),
  airbrush('Airbrush'),
  texture('Texture & effects'),
  blending('Blending');

  const BrushCategory(this.label);
  final String label;
}

/// What a dab does to the pixels under it.
enum BrushEngine {
  /// Lays colour down.
  paint,

  /// Picks up the colour under the tip and drags it along.
  smudge,

  /// Softens what is under the tip.
  blur,
}

/// The stamp each dab is drawn with. [round] is drawn as a vector circle so
/// its edge stays crisp at any size; the others are generated textures.
enum BrushTip {
  round,
  pencil,
  charcoal,
  chalk,
  crayon,
  ink,
  bristle,
  spray,
  watercolor,
  splatter,
  sparkle,
  leaf;

  static BrushTip parse(String? name) =>
      values.firstWhere((tip) => tip.name == name, orElse: () => round);
}

/// How a dab's rotation is chosen.
enum BrushAngleMode {
  fixed,

  /// Follows the direction of travel, so a flat bristle tip drags like one.
  direction,
  random,
}

/// Paper texture pressed through the stroke. Grain lives in canvas space, not
/// in the tip, so going back over the same patch fills the same pits — which
/// is what makes a pencil read as graphite on paper.
enum BrushGrain { none, paper, canvas, rough }

/// How a finished stroke combines with the layer it lands on.
enum StrokeBlend {
  normal,

  /// Overlapping strokes darken each other, like marker or watercolour glazes.
  multiply,

  /// Light adds up, for glows and sparkles.
  glow,
}

/// One adjustable number on a brush — the settings panel is generated from
/// this list, and saved per-brush overrides are keyed by [name].
enum BrushParam {
  size('Size', 1, 500, unit: 'px'),
  opacity('Opacity', 0.01, 1, percent: true),
  flow('Flow', 0.01, 1, percent: true),
  hardness('Hardness', 0, 1, percent: true),
  spacing('Spacing', 0.01, 2, percent: true),
  streamline('StreamLine', 0, 1, percent: true),
  sizePressure('Pressure → size', 0, 1, percent: true),
  flowPressure('Pressure → opacity', 0, 1, percent: true),
  taperStart('Taper start', 0, 3),
  taperEnd('Taper end', 0, 3),
  sizeJitter('Size jitter', 0, 1, percent: true),
  angleJitter('Rotation jitter', 0, 1, percent: true),
  scatter('Scatter', 0, 4, percent: true),
  roundness('Roundness', 0.05, 1, percent: true),
  angle('Angle', 0, 180, unit: '°'),
  grainStrength('Grain', 0, 1, percent: true),
  wetEdges('Wet edges', 0, 1, percent: true),
  colorJitter('Colour jitter', 0, 1, percent: true),
  strength('Strength', 0.05, 1, percent: true);

  const BrushParam(
    this.label,
    this.min,
    this.max, {
    this.percent = false,
    this.unit = '',
  });

  final String label;
  final double min;
  final double max;
  final bool percent;
  final String unit;

  String format(double value) {
    if (percent) return '${(value * 100).round()}%';
    if (this == taperStart || this == taperEnd) {
      return value == 0 ? 'Off' : value.toStringAsFixed(1);
    }
    if (this == size) {
      return value < 10 ? '${value.toStringAsFixed(1)} $unit' : '${value.round()} $unit';
    }
    return '${value.round()}$unit';
  }
}

class BrushPreset {
  const BrushPreset({
    required this.id,
    required this.name,
    required this.category,
    this.engine = BrushEngine.paint,
    this.tip = BrushTip.round,
    this.size = 12,
    this.maxSize = 300,
    this.opacity = 1,
    this.flow = 1,
    this.hardness = 0.9,
    this.spacing = 0.1,
    this.roundness = 1,
    this.angle = 0,
    this.angleMode = BrushAngleMode.fixed,
    this.sizePressure = 0.5,
    this.flowPressure = 0.3,
    this.taperStart = 0,
    this.taperEnd = 0,
    this.sizeJitter = 0,
    this.angleJitter = 0,
    this.scatter = 0,
    this.count = 1,
    this.colorJitter = 0,
    this.grain = BrushGrain.none,
    this.grainStrength = 0,
    this.strokeBlend = StrokeBlend.normal,
    this.streamline = 0.2,
    this.strength = 0.7,
    this.airbrush = false,
    this.wetEdges = 0,
  });

  final String id;
  final String name;
  final BrushCategory category;
  final BrushEngine engine;
  final BrushTip tip;

  /// Diameter in canvas pixels.
  final double size;

  /// Upper end of the size slider for this brush.
  final double maxSize;

  /// The most a single stroke can cover, however many dabs overlap.
  final double opacity;

  /// Alpha of one dab. Low flow builds up within a stroke; [opacity] caps it.
  final double flow;

  /// Edge falloff of the [BrushTip.round] tip: 1 is a crisp disc, 0 an
  /// airbrush-soft glow.
  final double hardness;

  /// Distance between dabs as a fraction of the diameter.
  final double spacing;

  /// Height of the tip relative to its width — below 1 gives a chisel nib.
  final double roundness;

  /// Tip rotation in degrees, used as-is for [BrushAngleMode.fixed] and as an
  /// offset otherwise.
  final double angle;
  final BrushAngleMode angleMode;

  /// How much of the diameter light pressure takes away (0 ignores pressure).
  final double sizePressure;

  /// How much of the flow light pressure takes away.
  final double flowPressure;

  /// Taper lengths, in multiples of the brush diameter.
  final double taperStart;
  final double taperEnd;

  final double sizeJitter;
  final double angleJitter;

  /// Random offset of each dab, in multiples of the diameter.
  final double scatter;

  /// Dabs stamped at each step; more than one reads as a spray.
  final int count;

  /// Per-dab hue/value wobble, for foliage and natural media.
  final double colorJitter;

  final BrushGrain grain;
  final double grainStrength;
  final StrokeBlend strokeBlend;

  /// Default stroke smoothing for this brush.
  final double streamline;

  /// Smudge pickup or blur amount, for the non-paint engines.
  final double strength;

  /// Keeps depositing while the pen rests in one place.
  final bool airbrush;

  /// Pigment pooling along the stroke's outline, the way watercolour dries
  /// darker at its edges.
  final double wetEdges;

  double get(BrushParam param) => switch (param) {
        BrushParam.size => size,
        BrushParam.opacity => opacity,
        BrushParam.flow => flow,
        BrushParam.hardness => hardness,
        BrushParam.spacing => spacing,
        BrushParam.streamline => streamline,
        BrushParam.sizePressure => sizePressure,
        BrushParam.flowPressure => flowPressure,
        BrushParam.taperStart => taperStart,
        BrushParam.taperEnd => taperEnd,
        BrushParam.sizeJitter => sizeJitter,
        BrushParam.angleJitter => angleJitter,
        BrushParam.scatter => scatter,
        BrushParam.roundness => roundness,
        BrushParam.angle => angle,
        BrushParam.grainStrength => grainStrength,
        BrushParam.wetEdges => wetEdges,
        BrushParam.colorJitter => colorJitter,
        BrushParam.strength => strength,
      };

  /// The parameters worth showing for this brush. Hardness means nothing to
  /// a textured tip, grain nothing to a brush without one.
  List<BrushParam> get adjustable => [
        BrushParam.size,
        BrushParam.opacity,
        if (engine == BrushEngine.paint) BrushParam.flow,
        if (engine != BrushEngine.paint) BrushParam.strength,
        if (tip == BrushTip.round) BrushParam.hardness,
        BrushParam.spacing,
        BrushParam.streamline,
        BrushParam.sizePressure,
        if (engine == BrushEngine.paint) BrushParam.flowPressure,
        BrushParam.taperStart,
        BrushParam.taperEnd,
        BrushParam.roundness,
        BrushParam.angle,
        BrushParam.sizeJitter,
        BrushParam.angleJitter,
        BrushParam.scatter,
        if (engine == BrushEngine.paint) BrushParam.colorJitter,
        if (grain != BrushGrain.none) BrushParam.grainStrength,
        if (engine == BrushEngine.paint) BrushParam.wetEdges,
      ];

  BrushPreset copyWithParam(BrushParam param, double value) {
    final v = value.clamp(param.min, param == BrushParam.size ? maxSize : param.max).toDouble();
    return BrushPreset(
      id: id,
      name: name,
      category: category,
      engine: engine,
      tip: tip,
      size: param == BrushParam.size ? v : size,
      maxSize: maxSize,
      opacity: param == BrushParam.opacity ? v : opacity,
      flow: param == BrushParam.flow ? v : flow,
      hardness: param == BrushParam.hardness ? v : hardness,
      spacing: param == BrushParam.spacing ? v : spacing,
      roundness: param == BrushParam.roundness ? v : roundness,
      angle: param == BrushParam.angle ? v : angle,
      angleMode: angleMode,
      sizePressure: param == BrushParam.sizePressure ? v : sizePressure,
      flowPressure: param == BrushParam.flowPressure ? v : flowPressure,
      taperStart: param == BrushParam.taperStart ? v : taperStart,
      taperEnd: param == BrushParam.taperEnd ? v : taperEnd,
      sizeJitter: param == BrushParam.sizeJitter ? v : sizeJitter,
      angleJitter: param == BrushParam.angleJitter ? v : angleJitter,
      scatter: param == BrushParam.scatter ? v : scatter,
      count: count,
      colorJitter: param == BrushParam.colorJitter ? v : colorJitter,
      grain: grain,
      grainStrength: param == BrushParam.grainStrength ? v : grainStrength,
      strokeBlend: strokeBlend,
      streamline: param == BrushParam.streamline ? v : streamline,
      strength: param == BrushParam.strength ? v : strength,
      airbrush: airbrush,
      wetEdges: param == BrushParam.wetEdges ? v : wetEdges,
    );
  }

  /// This preset with the user's saved tweaks applied. Unknown keys are
  /// skipped so settings saved by a newer version never break an older one.
  BrushPreset withOverrides(Map<String, double>? overrides) {
    if (overrides == null || overrides.isEmpty) return this;
    var brush = this;
    for (final entry in overrides.entries) {
      final param = BrushParam.values.where((p) => p.name == entry.key).firstOrNull;
      if (param != null) brush = brush.copyWithParam(param, entry.value);
    }
    return brush;
  }
}

/// The built-in brush library, grouped by [BrushCategory] in display order.
class BrushLibrary {
  const BrushLibrary._();

  static final Map<String, BrushPreset> _byId = {
    for (final brush in all) brush.id: brush,
  };

  static BrushPreset byId(String? id) => _byId[id] ?? all.first;

  static bool contains(String? id) => _byId.containsKey(id);

  static List<BrushPreset> inCategory(BrushCategory category) =>
      all.where((brush) => brush.category == category).toList(growable: false);

  static const defaultBrush = 'pencil_hb';
  static const defaultEraser = 'round_hard';
  static const defaultSmudge = 'blend_soft';

  static const all = <BrushPreset>[
    // ------------------------------------------------------------ sketching
    BrushPreset(
      id: 'pencil_hb',
      name: 'HB Pencil',
      category: BrushCategory.sketching,
      tip: BrushTip.pencil,
      size: 5,
      maxSize: 40,
      opacity: 0.9,
      flow: 0.55,
      spacing: 0.1,
      angleMode: BrushAngleMode.random,
      sizePressure: 0.45,
      flowPressure: 0.85,
      taperStart: 0.6,
      taperEnd: 0.6,
      grain: BrushGrain.paper,
      grainStrength: 0.55,
      streamline: 0.15,
    ),
    BrushPreset(
      id: 'pencil_6b',
      name: '6B Pencil',
      category: BrushCategory.sketching,
      tip: BrushTip.pencil,
      size: 10,
      maxSize: 60,
      flow: 0.75,
      spacing: 0.08,
      angleMode: BrushAngleMode.random,
      sizePressure: 0.35,
      flowPressure: 0.8,
      grain: BrushGrain.paper,
      grainStrength: 0.45,
      streamline: 0.1,
    ),
    BrushPreset(
      id: 'mechanical',
      name: 'Mechanical pencil',
      category: BrushCategory.sketching,
      size: 2.5,
      maxSize: 16,
      hardness: 0.8,
      opacity: 0.9,
      flow: 0.85,
      spacing: 0.08,
      sizePressure: 0.2,
      flowPressure: 0.75,
      grain: BrushGrain.paper,
      grainStrength: 0.3,
      streamline: 0.2,
    ),
    BrushPreset(
      id: 'charcoal',
      name: 'Charcoal',
      category: BrushCategory.sketching,
      tip: BrushTip.charcoal,
      size: 24,
      maxSize: 160,
      flow: 0.5,
      spacing: 0.07,
      angleMode: BrushAngleMode.random,
      sizePressure: 0.3,
      flowPressure: 0.9,
      sizeJitter: 0.12,
      grain: BrushGrain.rough,
      grainStrength: 0.6,
      streamline: 0.05,
    ),
    BrushPreset(
      id: 'pastel',
      name: 'Soft pastel',
      category: BrushCategory.sketching,
      tip: BrushTip.chalk,
      size: 32,
      maxSize: 200,
      flow: 0.45,
      spacing: 0.08,
      angleMode: BrushAngleMode.random,
      sizePressure: 0.25,
      flowPressure: 0.85,
      grain: BrushGrain.canvas,
      grainStrength: 0.55,
      streamline: 0.05,
    ),
    BrushPreset(
      id: 'crayon',
      name: 'Wax crayon',
      category: BrushCategory.sketching,
      tip: BrushTip.crayon,
      size: 14,
      maxSize: 80,
      flow: 0.85,
      spacing: 0.08,
      angleMode: BrushAngleMode.random,
      sizePressure: 0.3,
      flowPressure: 0.7,
      grain: BrushGrain.paper,
      grainStrength: 0.75,
      streamline: 0.05,
    ),

    // --------------------------------------------------------------- inking
    BrushPreset(
      id: 'studio_pen',
      name: 'Studio pen',
      category: BrushCategory.inking,
      size: 9,
      maxSize: 100,
      hardness: 1,
      spacing: 0.04,
      sizePressure: 0.85,
      flowPressure: 0,
      taperStart: 0.8,
      taperEnd: 0.8,
      streamline: 0.35,
    ),
    BrushPreset(
      id: 'fineliner',
      name: 'Fineliner',
      category: BrushCategory.inking,
      size: 3,
      maxSize: 30,
      hardness: 1,
      spacing: 0.05,
      sizePressure: 0.08,
      flowPressure: 0,
      streamline: 0.3,
    ),
    BrushPreset(
      id: 'brush_pen',
      name: 'Brush pen',
      category: BrushCategory.inking,
      size: 16,
      maxSize: 120,
      hardness: 0.97,
      spacing: 0.04,
      sizePressure: 0.95,
      flowPressure: 0,
      taperStart: 1.4,
      taperEnd: 1.8,
      streamline: 0.4,
    ),
    BrushPreset(
      id: 'calligraphy',
      name: 'Calligraphy nib',
      category: BrushCategory.inking,
      size: 20,
      maxSize: 120,
      hardness: 1,
      spacing: 0.025,
      roundness: 0.18,
      angle: 40,
      sizePressure: 0.3,
      flowPressure: 0,
      streamline: 0.3,
    ),
    BrushPreset(
      id: 'technical',
      name: 'Technical pen',
      category: BrushCategory.inking,
      size: 2,
      maxSize: 24,
      hardness: 1,
      spacing: 0.05,
      sizePressure: 0,
      flowPressure: 0,
      streamline: 0.5,
    ),
    BrushPreset(
      id: 'dry_ink',
      name: 'Dry ink',
      category: BrushCategory.inking,
      tip: BrushTip.ink,
      size: 12,
      maxSize: 100,
      spacing: 0.05,
      angleMode: BrushAngleMode.random,
      sizePressure: 0.75,
      flowPressure: 0.1,
      taperStart: 0.5,
      taperEnd: 0.8,
      grain: BrushGrain.paper,
      grainStrength: 0.35,
      streamline: 0.25,
    ),

    // ------------------------------------------------------------- painting
    BrushPreset(
      id: 'round_hard',
      name: 'Hard round',
      category: BrushCategory.painting,
      size: 26,
      maxSize: 500,
      hardness: 0.92,
      spacing: 0.06,
      sizePressure: 0.5,
      flowPressure: 0.2,
      streamline: 0.1,
    ),
    BrushPreset(
      id: 'round_soft',
      name: 'Soft round',
      category: BrushCategory.painting,
      size: 90,
      maxSize: 500,
      hardness: 0.05,
      flow: 0.25,
      spacing: 0.06,
      sizePressure: 0.2,
      flowPressure: 0.8,
      streamline: 0.05,
    ),
    BrushPreset(
      id: 'oil',
      name: 'Oil paint',
      category: BrushCategory.painting,
      tip: BrushTip.bristle,
      size: 40,
      maxSize: 300,
      flow: 0.85,
      spacing: 0.035,
      angleMode: BrushAngleMode.direction,
      sizePressure: 0.35,
      flowPressure: 0.5,
      colorJitter: 0.03,
      grain: BrushGrain.canvas,
      grainStrength: 0.28,
      streamline: 0.15,
    ),
    BrushPreset(
      id: 'gouache',
      name: 'Gouache',
      category: BrushCategory.painting,
      size: 34,
      maxSize: 300,
      hardness: 0.7,
      flow: 0.7,
      opacity: 0.95,
      spacing: 0.05,
      sizePressure: 0.4,
      flowPressure: 0.6,
      grain: BrushGrain.canvas,
      grainStrength: 0.22,
      streamline: 0.1,
    ),
    BrushPreset(
      id: 'flat_acrylic',
      name: 'Flat acrylic',
      category: BrushCategory.painting,
      tip: BrushTip.bristle,
      size: 56,
      maxSize: 300,
      flow: 0.95,
      spacing: 0.03,
      roundness: 1,
      angleMode: BrushAngleMode.direction,
      sizePressure: 0.15,
      flowPressure: 0.4,
      grain: BrushGrain.canvas,
      grainStrength: 0.32,
      streamline: 0.2,
    ),
    BrushPreset(
      id: 'palette_knife',
      name: 'Palette knife',
      category: BrushCategory.painting,
      size: 60,
      maxSize: 300,
      hardness: 1,
      roundness: 0.12,
      angle: 90,
      angleMode: BrushAngleMode.direction,
      spacing: 0.02,
      sizePressure: 0.1,
      flowPressure: 0.3,
      streamline: 0.3,
    ),

    // ----------------------------------------------------------- watercolor
    BrushPreset(
      id: 'wc_wash',
      name: 'Watercolor wash',
      category: BrushCategory.watercolor,
      tip: BrushTip.watercolor,
      size: 80,
      maxSize: 400,
      opacity: 0.6,
      flow: 0.3,
      spacing: 0.06,
      angleMode: BrushAngleMode.random,
      sizeJitter: 0.15,
      sizePressure: 0.3,
      flowPressure: 0.6,
      grain: BrushGrain.paper,
      grainStrength: 0.4,
      strokeBlend: StrokeBlend.multiply,
      wetEdges: 0.85,
      streamline: 0.1,
    ),
    BrushPreset(
      id: 'wc_round',
      name: 'Round watercolor',
      category: BrushCategory.watercolor,
      tip: BrushTip.watercolor,
      size: 28,
      maxSize: 200,
      opacity: 0.8,
      flow: 0.35,
      spacing: 0.05,
      angleMode: BrushAngleMode.random,
      sizePressure: 0.7,
      flowPressure: 0.5,
      taperStart: 0.6,
      taperEnd: 1,
      grain: BrushGrain.paper,
      grainStrength: 0.5,
      strokeBlend: StrokeBlend.multiply,
      wetEdges: 0.6,
      streamline: 0.2,
    ),
    BrushPreset(
      id: 'wc_bleed',
      name: 'Wet bleed',
      category: BrushCategory.watercolor,
      tip: BrushTip.watercolor,
      size: 60,
      maxSize: 400,
      opacity: 0.5,
      flow: 0.2,
      spacing: 0.07,
      angleMode: BrushAngleMode.random,
      sizeJitter: 0.2,
      sizePressure: 0.2,
      flowPressure: 0.7,
      grain: BrushGrain.paper,
      grainStrength: 0.3,
      strokeBlend: StrokeBlend.multiply,
      wetEdges: 1,
      streamline: 0.1,
    ),
    BrushPreset(
      id: 'wc_spatter',
      name: 'Spatter',
      category: BrushCategory.watercolor,
      tip: BrushTip.splatter,
      size: 70,
      maxSize: 300,
      opacity: 0.85,
      flow: 0.6,
      spacing: 0.8,
      angleJitter: 1,
      sizeJitter: 0.5,
      scatter: 0.6,
      sizePressure: 0.2,
      flowPressure: 0.3,
      strokeBlend: StrokeBlend.multiply,
      streamline: 0,
    ),

    // -------------------------------------------------------------- markers
    BrushPreset(
      id: 'marker',
      name: 'Alcohol marker',
      category: BrushCategory.markers,
      size: 20,
      maxSize: 120,
      hardness: 0.85,
      opacity: 0.55,
      spacing: 0.04,
      wetEdges: 0.3,
      roundness: 0.7,
      angle: 45,
      sizePressure: 0.1,
      flowPressure: 0,
      strokeBlend: StrokeBlend.multiply,
      streamline: 0.2,
    ),
    BrushPreset(
      id: 'highlighter',
      name: 'Highlighter',
      category: BrushCategory.markers,
      size: 26,
      maxSize: 120,
      hardness: 0.95,
      opacity: 0.45,
      spacing: 0.03,
      roundness: 0.3,
      angle: 90,
      sizePressure: 0,
      flowPressure: 0,
      strokeBlend: StrokeBlend.multiply,
      streamline: 0.4,
    ),
    BrushPreset(
      id: 'felt_tip',
      name: 'Felt tip',
      category: BrushCategory.markers,
      size: 7,
      maxSize: 60,
      hardness: 0.6,
      flow: 0.9,
      spacing: 0.05,
      sizePressure: 0.2,
      flowPressure: 0.2,
      grain: BrushGrain.paper,
      grainStrength: 0.15,
      streamline: 0.25,
    ),

    // ------------------------------------------------------------- airbrush
    BrushPreset(
      id: 'airbrush',
      name: 'Airbrush',
      category: BrushCategory.airbrush,
      size: 140,
      maxSize: 500,
      hardness: 0,
      flow: 0.06,
      spacing: 0.08,
      sizePressure: 0,
      flowPressure: 1,
      airbrush: true,
      streamline: 0.05,
    ),
    BrushPreset(
      id: 'fine_airbrush',
      name: 'Fine airbrush',
      category: BrushCategory.airbrush,
      size: 24,
      maxSize: 200,
      hardness: 0.25,
      flow: 0.12,
      spacing: 0.06,
      sizePressure: 0.4,
      flowPressure: 0.9,
      airbrush: true,
      streamline: 0.2,
    ),
    BrushPreset(
      id: 'spray',
      name: 'Spray paint',
      category: BrushCategory.airbrush,
      tip: BrushTip.spray,
      size: 90,
      maxSize: 400,
      flow: 0.5,
      spacing: 0.25,
      angleMode: BrushAngleMode.random,
      sizePressure: 0.2,
      flowPressure: 0.6,
      airbrush: true,
      streamline: 0,
    ),

    // -------------------------------------------------------------- texture
    BrushPreset(
      id: 'splatter',
      name: 'Splatter',
      category: BrushCategory.texture,
      tip: BrushTip.splatter,
      size: 60,
      maxSize: 300,
      spacing: 1.1,
      angleJitter: 1,
      sizeJitter: 0.6,
      scatter: 0.9,
      sizePressure: 0.3,
      flowPressure: 0,
      streamline: 0,
    ),
    BrushPreset(
      id: 'sparkle',
      name: 'Sparkle',
      category: BrushCategory.texture,
      tip: BrushTip.sparkle,
      size: 36,
      maxSize: 200,
      spacing: 1.8,
      angleJitter: 0.15,
      sizeJitter: 0.7,
      scatter: 1.4,
      colorJitter: 0.15,
      sizePressure: 0.4,
      flowPressure: 0.2,
      strokeBlend: StrokeBlend.glow,
      streamline: 0,
    ),
    BrushPreset(
      id: 'glow',
      name: 'Glow',
      category: BrushCategory.texture,
      size: 50,
      maxSize: 400,
      hardness: 0,
      flow: 0.2,
      spacing: 0.06,
      sizePressure: 0.4,
      flowPressure: 0.6,
      strokeBlend: StrokeBlend.glow,
      streamline: 0.2,
    ),
    BrushPreset(
      id: 'foliage',
      name: 'Foliage',
      category: BrushCategory.texture,
      tip: BrushTip.leaf,
      size: 36,
      maxSize: 200,
      spacing: 0.6,
      angleJitter: 1,
      sizeJitter: 0.5,
      scatter: 0.9,
      colorJitter: 0.35,
      sizePressure: 0.3,
      flowPressure: 0,
      streamline: 0,
    ),
    BrushPreset(
      id: 'stipple',
      name: 'Stipple',
      category: BrushCategory.texture,
      size: 5,
      maxSize: 40,
      hardness: 0.9,
      spacing: 1.6,
      sizeJitter: 0.5,
      scatter: 3,
      count: 2,
      sizePressure: 0.3,
      flowPressure: 0.3,
      streamline: 0,
    ),

    // ------------------------------------------------------------- blending
    BrushPreset(
      id: 'blend_soft',
      name: 'Soft blender',
      category: BrushCategory.blending,
      engine: BrushEngine.smudge,
      size: 50,
      maxSize: 400,
      hardness: 0.2,
      spacing: 0.08,
      sizePressure: 0.2,
      strength: 0.75,
      streamline: 0.15,
    ),
    BrushPreset(
      id: 'smudge',
      name: 'Smudge',
      category: BrushCategory.blending,
      engine: BrushEngine.smudge,
      size: 30,
      maxSize: 300,
      hardness: 0.7,
      spacing: 0.06,
      sizePressure: 0.3,
      strength: 0.9,
      streamline: 0.15,
    ),
    BrushPreset(
      id: 'blend_bristle',
      name: 'Bristle blender',
      category: BrushCategory.blending,
      engine: BrushEngine.smudge,
      tip: BrushTip.bristle,
      size: 44,
      maxSize: 300,
      spacing: 0.05,
      angleMode: BrushAngleMode.direction,
      sizePressure: 0.2,
      strength: 0.8,
      streamline: 0.15,
    ),
    BrushPreset(
      id: 'blur',
      name: 'Blur',
      category: BrushCategory.blending,
      engine: BrushEngine.blur,
      size: 70,
      maxSize: 400,
      hardness: 0.1,
      spacing: 0.15,
      sizePressure: 0.2,
      strength: 0.6,
      streamline: 0.1,
    ),
  ];
}
