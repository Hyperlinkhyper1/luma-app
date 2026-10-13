import 'package:luma_sync_server/benchmark_cost.dart';
import 'package:luma_sync_server/benchmark_prompts.dart';
import 'package:test/test.dart';

/// Keeps the "Add benchmark" cost estimate close to what real pagoda runs
/// were billed, at OpenRouter's per-million prices for those models.
void main() {
  final pagodaIn = benchmarkPromptTokens(benchmarkPromptFor('pagoda').length);
  // The median pagoda page on the roster is about 38 KB.
  final pagodaPage = benchmarkMedianPageTokens([38240]);

  double run(String effort,
      {required double inPerM, required double outPerM, bool reasons = true}) {
    final out = estimateBenchmarkOutputTokens(
        pageTokens: pagodaPage, effort: effort, reasons: reasons);
    return benchmarkCostUsd(pagodaIn, out, inputPerM: inPerM, outputPerM: outPerM);
  }

  void near(double estimate, double billed) => expect(
      estimate,
      inInclusiveRange(billed / 2, billed * 2),
      reason: 'estimated \$$estimate against \$$billed billed');

  test('the pagoda prompt reads as the 1.3-1.4k tokens it was billed as', () {
    expect(pagodaIn, inInclusiveRange(1300, 1400));
  });

  test('reasoning runs land within half to double of the bill', () {
    near(run('low', inPerM: 2, outPerM: 10), 0.247); // Gemini 4 Argon
    near(run('xhigh', inPerM: 2, outPerM: 10), 0.395);
    near(run('xhigh', inPerM: 4, outPerM: 20), 0.658); // Muse Wonder
    near(run('xhigh', inPerM: 0.09, outPerM: 0.36), 0.0164); // Solar Pro 4
    near(run('xhigh', inPerM: 0.14, outPerM: 0.28), 0.0136); // MiMo V2.5
  });

  test('xhigh lands near the 33-48k output tokens those runs used', () {
    final out =
        estimateBenchmarkOutputTokens(pageTokens: pagodaPage, effort: 'xhigh');
    expect(out, inInclusiveRange(36000, 46000));
  });

  test('a model that does not reason ignores the effort', () {
    int out(String e) => estimateBenchmarkOutputTokens(
        pageTokens: pagodaPage, effort: e, reasons: false);
    expect(out('xhigh'), out('low'));
    expect(out('low'), lessThan(8000));
  });

  test('effort only ever raises the estimate', () {
    var last = 0;
    for (final e in ['none', 'minimal', 'low', 'medium', 'high', 'xhigh']) {
      final out =
          estimateBenchmarkOutputTokens(pageTokens: pagodaPage, effort: e);
      expect(out, greaterThan(last), reason: e);
      last = out;
    }
  });

  test("the model's default effort falls back to medium", () {
    expect(
        estimateBenchmarkOutputTokens(pageTokens: pagodaPage, effort: ''),
        estimateBenchmarkOutputTokens(pageTokens: pagodaPage, effort: 'medium'));
    expect(
        estimateBenchmarkOutputTokens(
            pageTokens: pagodaPage, effort: '', defaultEffort: 'high'),
        estimateBenchmarkOutputTokens(pageTokens: pagodaPage, effort: 'high'));
  });

  test('the output cap bounds the estimate', () {
    expect(
        estimateBenchmarkOutputTokens(
            pageTokens: 30000, effort: 'xhigh', maxTokens: 64000),
        64000);
  });

  test('a test with no scenes yet gets the default page', () {
    expect(benchmarkMedianPageTokens(const []), kBenchmarkDefaultPageTokens);
    expect(benchmarkMedianPageTokens([3400, 6800]), 1500);
  });
}
