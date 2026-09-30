import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/audio_tools/audio_types.dart';
import 'package:luma/features/plugins/installed/audio_tools/eq.dart';

const _rate = 48000.0;

Float32List _sine(double freq, {double amp = 0.25, int frames = 48000}) =>
    Float32List.fromList([
      for (var i = 0; i < frames; i++)
        amp * math.sin(2 * math.pi * freq * i / _rate),
    ]);

/// Peak of the second half, once the filters have settled.
double _settledPeak(Float32List s) =>
    EqProcessor.peak(Float32List.sublistView(s, s.length ~/ 2));

double _db(double ratio) => 20 * math.log(ratio) / math.ln10;

void main() {
  test('flat curve leaves the signal untouched', () {
    final eq = EqProcessor(sampleRate: _rate, channels: 1);
    final input = _sine(440);
    final output = Float32List.fromList(input);
    eq.process(output);
    for (var i = 0; i < input.length; i++) {
      expect(output[i], closeTo(input[i], 1e-5));
    }
  });

  test('a peaking band boosts its centre frequency by its gain', () {
    const band = EqBand(type: EqBandType.peak, frequency: 1000, gainDb: 6);
    final c = BiquadCoefficients.forBand(band, _rate);
    expect(c.magnitudeDb(1000, _rate), closeTo(6, 0.01));
    expect(c.magnitudeDb(50, _rate), closeTo(0, 0.2));

    final eq = EqProcessor(
      sampleRate: _rate,
      channels: 1,
      settings: const EqSettings(bands: [band]),
    );
    final s = _sine(1000, amp: 0.1);
    eq.process(s);
    expect(_db(_settledPeak(s) / 0.1), closeTo(6, 0.1));
  });

  test('shelves and pass filters shape the right end of the spectrum', () {
    double at(EqBand b, double f) =>
        BiquadCoefficients.forBand(b, _rate).magnitudeDb(f, _rate);

    const low = EqBand(
      type: EqBandType.lowShelf,
      frequency: 200,
      gainDb: 9,
      q: 0.707,
    );
    expect(at(low, 30), closeTo(9, 0.3));
    expect(at(low, 8000), closeTo(0, 0.3));

    const high = EqBand(
      type: EqBandType.highShelf,
      frequency: 4000,
      gainDb: -9,
      q: 0.707,
    );
    expect(at(high, 18000), closeTo(-9, 0.5));
    expect(at(high, 100), closeTo(0, 0.3));

    const hp = EqBand(type: EqBandType.highPass, frequency: 500, q: 0.707);
    expect(at(hp, 500), closeTo(-3, 0.1));
    expect(at(hp, 50), lessThan(-35));

    const lp = EqBand(type: EqBandType.lowPass, frequency: 3000, q: 0.707);
    expect(at(lp, 3000), closeTo(-3, 0.1));
    expect(at(lp, 100), closeTo(0, 0.1));
  });

  test('disabled bands and the preamp are respected', () {
    final settings = EqSettings(
      preampDb: -6,
      bands: const [
        EqBand(
          type: EqBandType.peak,
          frequency: 1000,
          gainDb: 12,
          enabled: false,
        ),
      ],
    );
    expect(settings.responseDb(1000, _rate), closeTo(-6, 1e-9));
  });

  test('soft clip is linear when quiet and never exceeds full scale', () {
    expect(EqProcessor.softClip(0.5), 0.5);
    expect(EqProcessor.softClip(-0.8), -0.8);
    for (final x in [0.9, 1.5, 4.0, 100.0]) {
      expect(EqProcessor.softClip(x), lessThanOrEqualTo(1));
      expect(EqProcessor.softClip(-x), greaterThanOrEqualTo(-1));
      expect(EqProcessor.softClip(x), greaterThan(0.8));
    }
  });

  test('stereo channels keep independent filter state', () {
    final eq = EqProcessor(
      sampleRate: _rate,
      channels: 2,
      settings: const EqSettings(
        bands: [EqBand(type: EqBandType.peak, frequency: 1000, gainDb: 6)],
      ),
    );
    final mono = _sine(1000, amp: 0.1);
    final stereo = Float32List(mono.length * 2);
    for (var i = 0; i < mono.length; i++) {
      stereo[i * 2] = mono[i];
    }
    eq.process(stereo);
    var rightPeak = 0.0;
    for (var i = 0; i < mono.length; i++) {
      rightPeak = math.max(rightPeak, stereo[i * 2 + 1].abs());
    }
    expect(rightPeak, 0);
  });

  test('settings survive a JSON round trip and presets are distinct', () {
    for (final p in EqPreset.values) {
      final back = EqSettings.fromJson(p.settings.toJson());
      expect(back, p.settings);
    }
    final curves = EqPreset.values.map((p) => p.settings).toSet();
    expect(curves.length, EqPreset.values.length);
  });

  test('broken saved settings fall back to the flat layout', () {
    final s = EqSettings.fromJson({'bands': 'nope', 'preampDb': 99});
    expect(s.bands, EqPreset.flat.settings.bands);
    expect(s.preampDb, 12);
  });

  test('virtual cables are recognised by name', () {
    const cable = AudioDevice(
      id: 'a',
      name: 'CABLE Input (VB-Audio Virtual Cable)',
    );
    const speakers = AudioDevice(id: 'b', name: 'Speakers (Realtek(R) Audio)');
    expect(cable.isVirtualCable, isTrue);
    expect(speakers.isVirtualCable, isFalse);
    expect(
      const AudioDevices(outputs: [speakers, cable]).virtualCableOutput?.id,
      'a',
    );
  });
}
