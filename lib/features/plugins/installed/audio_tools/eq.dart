import 'dart:math' as math;
import 'dart:typed_data';

/// The filter shape of one equalizer band.
enum EqBandType { highPass, lowShelf, peak, highShelf, lowPass }

/// Lowest and highest frequency a band can be tuned to.
const double kEqMinHz = 20;
const double kEqMaxHz = 20000;

/// Gain range for a band and for the preamp, in dB.
const double kEqMaxGainDb = 24;
const double kEqMinQ = 0.3;
const double kEqMaxQ = 8;

/// One band of the parametric equalizer. Pass filters ignore [gainDb].
class EqBand {
  const EqBand({
    required this.type,
    required this.frequency,
    this.gainDb = 0,
    this.q = 1,
    this.enabled = true,
  });

  final EqBandType type;
  final double frequency;
  final double gainDb;
  final double q;
  final bool enabled;

  bool get usesGain =>
      type != EqBandType.highPass && type != EqBandType.lowPass;

  EqBand copyWith({
    EqBandType? type,
    double? frequency,
    double? gainDb,
    double? q,
    bool? enabled,
  }) => EqBand(
    type: type ?? this.type,
    frequency: (frequency ?? this.frequency).clamp(kEqMinHz, kEqMaxHz),
    gainDb: (gainDb ?? this.gainDb).clamp(-kEqMaxGainDb, kEqMaxGainDb),
    q: (q ?? this.q).clamp(kEqMinQ, kEqMaxQ),
    enabled: enabled ?? this.enabled,
  );

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'frequency': frequency,
    'gainDb': gainDb,
    'q': q,
    'enabled': enabled,
  };

  factory EqBand.fromJson(Map<String, dynamic> json) => EqBand(
    type: EqBandType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => EqBandType.peak,
    ),
    frequency: ((json['frequency'] as num?)?.toDouble() ?? 1000).clamp(
      kEqMinHz,
      kEqMaxHz,
    ),
    gainDb: ((json['gainDb'] as num?)?.toDouble() ?? 0).clamp(
      -kEqMaxGainDb,
      kEqMaxGainDb,
    ),
    q: ((json['q'] as num?)?.toDouble() ?? 1).clamp(kEqMinQ, kEqMaxQ),
    enabled: json['enabled'] as bool? ?? true,
  );

  @override
  bool operator ==(Object other) =>
      other is EqBand &&
      other.type == type &&
      other.frequency == frequency &&
      other.gainDb == gainDb &&
      other.q == q &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(type, frequency, gainDb, q, enabled);
}

/// A full equalizer curve: the bands plus an overall preamp.
class EqSettings {
  const EqSettings({required this.bands, this.preampDb = 0});

  final List<EqBand> bands;
  final double preampDb;

  EqSettings copyWith({List<EqBand>? bands, double? preampDb}) => EqSettings(
    bands: bands ?? this.bands,
    preampDb: (preampDb ?? this.preampDb).clamp(-kEqMaxGainDb, 12),
  );

  EqSettings withBand(int index, EqBand band) =>
      copyWith(bands: [...bands]..[index] = band);

  Map<String, dynamic> toJson() => {
    'preampDb': preampDb,
    'bands': [for (final b in bands) b.toJson()],
  };

  factory EqSettings.fromJson(Map<String, dynamic> json) {
    final raw = json['bands'];
    final bands = raw is List
        ? [
            for (final b in raw)
              if (b is Map) EqBand.fromJson(b.cast<String, dynamic>()),
          ]
        : const <EqBand>[];
    return EqSettings(
      bands: bands.isEmpty ? EqPreset.flat.settings.bands : bands,
      preampDb: ((json['preampDb'] as num?)?.toDouble() ?? 0).clamp(
        -kEqMaxGainDb,
        12,
      ),
    );
  }

  /// Combined response of every enabled band at [frequency], in dB,
  /// including the preamp.
  double responseDb(double frequency, double sampleRate) {
    var db = preampDb;
    for (final band in bands) {
      if (!band.enabled) continue;
      db += BiquadCoefficients.forBand(
        band,
        sampleRate,
      ).magnitudeDb(frequency, sampleRate);
    }
    return db;
  }

  @override
  bool operator ==(Object other) =>
      other is EqSettings &&
      other.preampDb == preampDb &&
      _listEquals(other.bands, bands);

  @override
  int get hashCode => Object.hash(preampDb, Object.hashAll(bands));
}

bool _listEquals(List<EqBand> a, List<EqBand> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Normalized biquad coefficients (a0 == 1), from the RBJ Audio EQ Cookbook.
class BiquadCoefficients {
  const BiquadCoefficients(this.b0, this.b1, this.b2, this.a1, this.a2);

  static const identity = BiquadCoefficients(1, 0, 0, 0, 0);

  final double b0;
  final double b1;
  final double b2;
  final double a1;
  final double a2;

  factory BiquadCoefficients.forBand(EqBand band, double sampleRate) {
    final f0 = band.frequency.clamp(kEqMinHz, sampleRate * 0.49);
    final w0 = 2 * math.pi * f0 / sampleRate;
    final cosW = math.cos(w0);
    final sinW = math.sin(w0);
    final alpha = sinW / (2 * band.q);
    final a = math.pow(10, band.gainDb / 40).toDouble();
    final sqrtA2Alpha = 2 * math.sqrt(a) * alpha;

    final double b0, b1, b2, a0, a1, a2;
    switch (band.type) {
      case EqBandType.peak:
        b0 = 1 + alpha * a;
        b1 = -2 * cosW;
        b2 = 1 - alpha * a;
        a0 = 1 + alpha / a;
        a1 = -2 * cosW;
        a2 = 1 - alpha / a;
      case EqBandType.lowShelf:
        b0 = a * ((a + 1) - (a - 1) * cosW + sqrtA2Alpha);
        b1 = 2 * a * ((a - 1) - (a + 1) * cosW);
        b2 = a * ((a + 1) - (a - 1) * cosW - sqrtA2Alpha);
        a0 = (a + 1) + (a - 1) * cosW + sqrtA2Alpha;
        a1 = -2 * ((a - 1) + (a + 1) * cosW);
        a2 = (a + 1) + (a - 1) * cosW - sqrtA2Alpha;
      case EqBandType.highShelf:
        b0 = a * ((a + 1) + (a - 1) * cosW + sqrtA2Alpha);
        b1 = -2 * a * ((a - 1) + (a + 1) * cosW);
        b2 = a * ((a + 1) + (a - 1) * cosW - sqrtA2Alpha);
        a0 = (a + 1) - (a - 1) * cosW + sqrtA2Alpha;
        a1 = 2 * ((a - 1) - (a + 1) * cosW);
        a2 = (a + 1) - (a - 1) * cosW - sqrtA2Alpha;
      case EqBandType.highPass:
        b0 = (1 + cosW) / 2;
        b1 = -(1 + cosW);
        b2 = (1 + cosW) / 2;
        a0 = 1 + alpha;
        a1 = -2 * cosW;
        a2 = 1 - alpha;
      case EqBandType.lowPass:
        b0 = (1 - cosW) / 2;
        b1 = 1 - cosW;
        b2 = (1 - cosW) / 2;
        a0 = 1 + alpha;
        a1 = -2 * cosW;
        a2 = 1 - alpha;
    }
    return BiquadCoefficients(b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0);
  }

  /// Magnitude of this filter's response at [frequency], in dB.
  double magnitudeDb(double frequency, double sampleRate) {
    final w = 2 * math.pi * frequency / sampleRate;
    final c1 = math.cos(w), s1 = math.sin(w);
    final c2 = math.cos(2 * w), s2 = math.sin(2 * w);
    final numRe = b0 + b1 * c1 + b2 * c2;
    final numIm = -(b1 * s1 + b2 * s2);
    final denRe = 1 + a1 * c1 + a2 * c2;
    final denIm = -(a1 * s1 + a2 * s2);
    final num = numRe * numRe + numIm * numIm;
    final den = denRe * denRe + denIm * denIm;
    if (den <= 0 || num <= 0) return -120;
    return 10 * math.log(num / den) / math.ln10;
  }
}

/// Runs an [EqSettings] curve over interleaved float PCM, in place.
///
/// Filter state survives [apply], so the curve can be dragged while audio is
/// flowing without clicks. The output passes through a soft limiter so a
/// big boost saturates gently instead of hard-clipping.
class EqProcessor {
  EqProcessor({
    required this.sampleRate,
    required this.channels,
    EqSettings? settings,
  }) {
    apply(settings ?? EqPreset.flat.settings);
  }

  final double sampleRate;
  final int channels;

  Float64List _coeffs = Float64List(0);
  Float64List _state = Float64List(0);
  int _bandCount = 0;
  double _preamp = 1;

  void apply(EqSettings settings) {
    final active = [
      for (final b in settings.bands)
        if (b.enabled) b,
    ];
    final coeffs = Float64List(active.length * 5);
    for (var i = 0; i < active.length; i++) {
      final c = BiquadCoefficients.forBand(active[i], sampleRate);
      coeffs
        ..[i * 5] = c.b0
        ..[i * 5 + 1] = c.b1
        ..[i * 5 + 2] = c.b2
        ..[i * 5 + 3] = c.a1
        ..[i * 5 + 4] = c.a2;
    }
    if (active.length != _bandCount) {
      _state = Float64List(active.length * channels * 2);
      _bandCount = active.length;
    }
    _coeffs = coeffs;
    _preamp = math.pow(10, settings.preampDb / 20).toDouble();
  }

  void reset() => _state.fillRange(0, _state.length, 0);

  void process(Float32List samples) {
    final coeffs = _coeffs;
    final state = _state;
    final bands = _bandCount;
    final frames = samples.length ~/ channels;
    for (var f = 0; f < frames; f++) {
      for (var ch = 0; ch < channels; ch++) {
        final idx = f * channels + ch;
        var x = samples[idx] * _preamp;
        for (var b = 0; b < bands; b++) {
          final c = b * 5;
          final s = (b * channels + ch) * 2;
          final y = coeffs[c] * x + state[s];
          state[s] = coeffs[c + 1] * x - coeffs[c + 3] * y + state[s + 1];
          state[s + 1] = coeffs[c + 2] * x - coeffs[c + 4] * y;
          x = y;
        }
        samples[idx] = softClip(x);
      }
    }
  }

  /// Linear below 0.8, then eases towards ±1 so peaks never hard-clip.
  static double softClip(double x) {
    final a = x.abs();
    if (a <= 0.8) return x;
    final shaped = 0.8 + 0.2 * _tanh((a - 0.8) / 0.2);
    return x < 0 ? -shaped : shaped;
  }

  static double _tanh(double x) {
    if (x > 20) return 1;
    final e = math.exp(2 * x);
    return (e - 1) / (e + 1);
  }

  static double peak(Float32List samples) {
    var p = 0.0;
    for (final s in samples) {
      final a = s.abs();
      if (a > p) p = a;
    }
    return p;
  }
}

/// Built-in voice curves. Every preset uses the same nine-band layout, so
/// switching between them only moves the handles.
enum EqPreset {
  flat,
  clear,
  deep,
  radio,
  telephone,
  megaphone,
  muffled,
  tiny;

  EqSettings get settings => switch (this) {
    EqPreset.flat => _layout(),
    EqPreset.clear => _layout(hp: 90, gains: const [-2, -3, -1, 0, 1, 4, 3]),
    EqPreset.deep => _layout(
      hp: 50,
      gains: const [6, 4, 1, -1, -3, -5, -8],
      lp: 7000,
    ),
    EqPreset.radio => _layout(
      hp: 250,
      gains: const [0, -2, 3, 6, 5, 0, -6],
      lp: 5000,
    ),
    EqPreset.telephone => _layout(
      hp: 500,
      hpQ: 1.2,
      gains: const [0, 0, 2, 4, 6, 0, 0],
      lp: 3000,
      lpQ: 1.2,
    ),
    EqPreset.megaphone => _layout(
      hp: 700,
      gains: const [0, 0, 2, 8, 10, -4, 0],
      lp: 4500,
      preamp: -6,
    ),
    EqPreset.muffled => _layout(
      gains: const [4, 3, 0, -6, -12, -18, -20],
      lp: 800,
    ),
    EqPreset.tiny => _layout(hp: 600, gains: const [-12, -8, -3, 2, 5, 6, 6]),
  };
}

const _layoutFrequencies = [
  120.0,
  250.0,
  500.0,
  1000.0,
  2000.0,
  4000.0,
  8000.0,
];

EqSettings _layout({
  double? hp,
  double hpQ = 0.707,
  List<double> gains = const [0, 0, 0, 0, 0, 0, 0],
  double? lp,
  double lpQ = 0.707,
  double preamp = 0,
}) {
  final middle = <EqBand>[
    for (var i = 0; i < _layoutFrequencies.length; i++)
      EqBand(
        type: i == 0
            ? EqBandType.lowShelf
            : i == _layoutFrequencies.length - 1
            ? EqBandType.highShelf
            : EqBandType.peak,
        frequency: _layoutFrequencies[i],
        gainDb: gains[i],
        q: i == 0 || i == _layoutFrequencies.length - 1 ? 0.707 : 1.0,
      ),
  ];
  return EqSettings(
    preampDb: preamp,
    bands: [
      EqBand(
        type: EqBandType.highPass,
        frequency: hp ?? 80,
        q: hpQ,
        enabled: hp != null,
      ),
      ...middle,
      EqBand(
        type: EqBandType.lowPass,
        frequency: lp ?? 12000,
        q: lpQ,
        enabled: lp != null,
      ),
    ],
  );
}
