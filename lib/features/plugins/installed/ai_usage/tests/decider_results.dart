import 'package:flutter/painting.dart';

/// One decision model's latest run on the Decider test's moderation suite,
/// as `/api/v1/ai-benchmarks/decider` reports it.
class DeciderEntry {
  const DeciderEntry({
    required this.model,
    required this.provider,
    required this.accuracy,
    required this.meanPTrue,
    required this.costUsd,
    required this.costPer1k,
    this.bySkill = const {},
  });

  /// The model id, `vendor/name` (bare for runs straight on Perplexity).
  final String model;

  /// `openrouter` or `perplexity`.
  final String provider;

  /// Share of cases it got right, 0 to 100.
  final double accuracy;

  /// The average probability it put on the right answer, 0 to 100.
  final double meanPTrue;
  final double costUsd;

  /// What 1,000 cases cost at this run's rate, in US dollars.
  final double costPer1k;

  /// Accuracy per skill the suite tests (dates, counting…), 0 to 100.
  final Map<String, double> bySkill;

  bool get direct => provider == 'perplexity';

  /// The company behind the model: the id's vendor prefix.
  String get vendor =>
      model.contains('/') ? model.split('/').first.replaceAll('~', '') : 'perplexity';

  /// The model's name without its vendor prefix.
  String get shortName =>
      model.contains('/') ? model.substring(model.indexOf('/') + 1) : model;

  static DeciderEntry? fromJson(Object? raw) {
    if (raw is! Map || raw['model'] is! String) return null;
    double n(Object? v) => v is num ? v.toDouble() : 0;
    final skills = raw['bySkill'];
    return DeciderEntry(
      model: raw['model'] as String,
      provider: raw['provider'] is String ? raw['provider'] as String : '',
      accuracy: n(raw['accuracy']),
      meanPTrue: n(raw['meanPTrue']),
      costUsd: n(raw['costUsd']),
      costPer1k: n(raw['costPer1k']),
      bySkill: {
        if (skills is Map)
          for (final e in skills.entries)
            if (e.value is Map) '${e.key}': n((e.value as Map)['score']),
      },
    );
  }
}

/// Everything the Decider test page shows.
class DeciderBoard {
  const DeciderBoard({
    required this.cases,
    required this.chance,
    required this.entries,
    this.otherSuite = 0,
    this.unfinished = 0,
  });

  final int cases;

  /// Models whose finished runs used an older suite, so they are left out.
  final int otherSuite;

  /// Models with no finished run (failed, stopped, interrupted), left out.
  final int unfinished;

  /// What guessing scores on the suite, 0 to 100.
  final double chance;

  /// Best first.
  final List<DeciderEntry> entries;

  static DeciderBoard fromJson(Map<String, dynamic> json) {
    final raw = json['models'];
    final entries = [
      if (raw is List)
        for (final m in raw) ?DeciderEntry.fromJson(m),
    ]..sort((a, b) => b.accuracy.compareTo(a.accuracy));
    final hidden = json['hidden'];
    int count(String key) =>
        hidden is Map && hidden[key] is num ? (hidden[key] as num).toInt() : 0;
    return DeciderBoard(
      cases: (json['cases'] as num?)?.toInt() ?? 0,
      chance: (json['chance'] as num?)?.toDouble() ?? 0,
      entries: entries,
      otherSuite: count('otherSuite'),
      unfinished: count('unfinished'),
    );
  }

  /// The models no other model beats on both cost and accuracy, cheapest
  /// first: the line the chart draws.
  List<DeciderEntry> get frontier {
    final sorted = [...entries]..sort((a, b) {
        final byCost = a.costPer1k.compareTo(b.costPer1k);
        return byCost != 0 ? byCost : b.accuracy.compareTo(a.accuracy);
      });
    final out = <DeciderEntry>[];
    for (final e in sorted) {
      if (out.isEmpty || e.accuracy > out.last.accuracy) out.add(e);
    }
    return out;
  }
}

/// Logo colours of the companies behind decision models, matching the admin
/// dashboard's chart. Companies not listed get a steady colour of their own.
const _brandColors = <String, Color>{
  'perplexity': Color(0xFF20B8CD),
  'openai': Color(0xFF10A37F),
  'cloudflare': Color(0xFFF38020),
  'microsoft': Color(0xFF00A4EF),
  'google': Color(0xFF4285F4),
  'anthropic': Color(0xFFD97757),
  'mistralai': Color(0xFFFA520F),
  'meta-llama': Color(0xFF0668E1),
  'meta': Color(0xFF0668E1),
  'nvidia': Color(0xFF76B900),
  'amazon': Color(0xFFFF9900),
  'ibm': Color(0xFF0F62FE),
  'upstage': Color(0xFF805CFB),
  'togethercomputer': Color(0xFF0F6FFF),
  'x-ai': Color(0xFFE7E7E7),
  'deepseek': Color(0xFF4D6BFE),
  'qwen': Color(0xFF615CED),
};

Color deciderVendorColor(String vendor) {
  final known = _brandColors[vendor];
  if (known != null) return known;
  var h = 0;
  for (final unit in vendor.codeUnits) {
    h = (h * 31 + unit) & 0xffffffff;
  }
  return HSLColor.fromAHSL(1, (h % 360).toDouble(), 0.62, 0.64).toColor();
}

/// Dollars the way the chart labels them: two decimals from a dollar up,
/// three from a cent, two significant digits below that.
String deciderMoney(double v) {
  if (v <= 0) return r'$0';
  if (v >= 1) return '\$${v.toStringAsFixed(2)}';
  if (v >= 0.01) return '\$${v.toStringAsFixed(3)}';
  return '\$${v.toStringAsPrecision(2)}';
}
