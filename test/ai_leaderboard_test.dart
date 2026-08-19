import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/ai_usage/leaderboard/ai_leaderboard_format.dart';
import 'package:luma/features/plugins/installed/ai_usage/leaderboard/ai_leaderboard_sort.dart';
import 'package:luma/features/plugins/installed/ai_usage/leaderboard/ai_model.dart';
import 'package:luma/features/plugins/installed/ai_usage/open_source/vram_estimate.dart';

AiModel _model(
  String name, {
  String vendor = 'anthropic',
  String vendorName = 'Anthropic',
  double? index,
  double? price,
  int? context,
  bool open = false,
  double? params,
}) =>
    AiModel(
      id: '$vendor/${name.toLowerCase().replaceAll(' ', '-')}',
      slug: name.toLowerCase().replaceAll(' ', '-'),
      name: name,
      vendor: vendor,
      vendorName: vendorName,
      llmStatsIndex: index,
      inputPricePerM: price,
      outputPricePerM: price,
      contextTokens: context,
      openWeights: open,
      parametersB: params,
    );

void main() {
  group('filterAndSortModels', () {
    final models = [
      _model('Beta', index: 50, price: 2),
      _model('Alpha', index: 80, price: 10),
      _model('Gamma', index: 20, price: 1),
      _model('Unrated'),
    ];

    test('sorts by rating, best first, with unrated last', () {
      final rows = filterAndSortModels(models);
      expect([for (final m in rows) m.name],
          ['Alpha', 'Beta', 'Gamma', 'Unrated']);
    });

    test('unrated models stay last when the direction flips', () {
      // The regression this guards: folding "missing" into the comparison
      // makes nulls float to the top the moment a column is reversed.
      final rows = filterAndSortModels(models, descending: false);
      expect(rows.last.name, 'Unrated');
      expect([for (final m in rows.take(3)) m.name],
          ['Gamma', 'Beta', 'Alpha']);
    });

    test('unpriced models never look like the cheapest', () {
      final rows = filterAndSortModels(
        models,
        sortBy: AiLeaderboardColumn.price,
        descending: false,
      );
      expect(rows.first.name, 'Gamma');
      expect(rows.last.name, 'Unrated');
    });

    test('sorts names A–Z ascending and Z–A descending', () {
      expect(
        [
          for (final m in filterAndSortModels(models,
              sortBy: AiLeaderboardColumn.name, descending: false))
            m.name,
        ],
        ['Alpha', 'Beta', 'Gamma', 'Unrated'],
      );
      expect(
        filterAndSortModels(models,
                sortBy: AiLeaderboardColumn.name, descending: true)
            .first
            .name,
        'Unrated',
      );
    });

    test('ties fall back to name so the order is stable', () {
      final tied = [
        _model('Zeta', index: 50),
        _model('Alpha', index: 50),
      ];
      expect([for (final m in filterAndSortModels(tied)) m.name],
          ['Alpha', 'Zeta']);
    });

    test('the license column groups open weights first', () {
      final mixed = [
        _model('Closed'),
        _model('Open', open: true),
      ];
      expect(
        filterAndSortModels(mixed,
                sortBy: AiLeaderboardColumn.license, descending: true)
            .first
            .name,
        'Open',
      );
    });

    test('search matches name, provider and id', () {
      expect(filterAndSortModels(models, query: 'alph'), hasLength(1));
      expect(filterAndSortModels(models, query: 'ANTHROPIC'), hasLength(4));
      expect(filterAndSortModels(models, query: 'nothing here'), isEmpty);
    });

    test('the provider and open-weights filters compose', () {
      final mixed = [
        _model('A', open: true),
        _model('B'),
        _model('C', vendor: 'qwen', vendorName: 'Qwen', open: true),
      ];
      expect(
        [
          for (final m in filterAndSortModels(mixed,
              vendor: 'anthropic', openWeightsOnly: true))
            m.name,
        ],
        ['A'],
      );
    });
  });

  group('vendorsOf', () {
    test('lists each provider once, alphabetically by display name', () {
      final vendors = vendorsOf([
        _model('A', vendor: 'qwen', vendorName: 'Qwen'),
        _model('B'),
        _model('C', vendor: 'qwen', vendorName: 'Qwen'),
      ]);
      expect([for (final v in vendors) v.name], ['Anthropic', 'Qwen']);
    });
  });

  group('formatting', () {
    test('context windows read the way people say them', () {
      expect(formatTokens(1048576), '1.0M');
      expect(formatTokens(2000000), '2M');
      expect(formatTokens(128000), '128K');
      expect(formatTokens(null), isNull);
      expect(formatTokens(0), isNull);
    });

    test('sub-dollar prices keep enough decimals to stay distinct', () {
      // At two decimals a third of the board would read "$0.00".
      expect(formatPrice(0.05), r'$0.050');
      expect(formatPrice(0.002), r'$0.002');
      expect(formatPrice(7.22), r'$7.22');
      // Cents still matter past $10 — $7.22 vs $7.78 is the whole argument
      // for one model over another.
      expect(formatPrice(15), r'$15.00');
      expect(formatPrice(250), r'$250');
      expect(formatPrice(0), r'$0');
      expect(formatPrice(null), isNull);
    });

    test('exact token counts are grouped', () {
      expect(formatExactTokens(1048576), '1,048,576');
      expect(formatExactTokens(999), '999');
    });
  });

  group('AiModel pricing', () {
    test('averages input and output, and refuses to average half a price', () {
      const both = AiModel(
        id: 'a/b',
        slug: 'b',
        name: 'B',
        vendor: 'a',
        vendorName: 'A',
        inputPricePerM: 5,
        outputPricePerM: 25,
      );
      expect(both.avgPricePerM, 15);
      expect(both.blendedPricePerM, closeTo((5 * 8 + 25) / 9, 1e-9));

      const half = AiModel(
        id: 'a/b',
        slug: 'b',
        name: 'B',
        vendor: 'a',
        vendorName: 'A',
        inputPricePerM: 5,
      );
      expect(half.avgPricePerM, isNull);
      expect(half.blendedPricePerM, isNull);
    });
  });

  group('AiCatalog.fromJson', () {
    test('reads the payload the server publishes', () {
      final catalog = AiCatalog.fromJson(
          jsonDecode(jsonEncode({
            'refreshedAtMs': 1700000000000,
            'models': [
              {
                'id': 'anthropic/claude-opus-5',
                'slug': 'claude-opus-5',
                'name': 'Claude Opus 5',
                'vendor': 'anthropic',
                'vendorName': 'Anthropic',
                'llmStatsIndex': 63.1,
                'contextTokens': 1000000,
                'openWeights': false,
                'supportedEfforts': ['low', 'high'],
                'effortProfiles': [
                  {'effort': 'low', 'intelligenceIndex': 55.0,
                   'medianOutputTokens': 1200},
                  {'effort': 'high', 'intelligenceIndex': 63.1,
                   'medianOutputTokens': 9000},
                ],
              },
            ],
            'news': [
              {
                'id': 'n1',
                'title': 'T',
                'url': 'https://example.com',
                'source': 'OpenAI',
                'publishedAtMs': 1700000000000,
              },
            ],
          })) as Map<String, dynamic>);

      expect(catalog.models, hasLength(1));
      final model = catalog.models.single;
      expect(model.name, 'Claude Opus 5');
      expect(model.hasEffortLevels, isTrue);
      expect(model.hasEffortGraph, isTrue);
      expect(catalog.news.single.source, 'OpenAI');
      expect(catalog.refreshedAt, isNotNull);
    });

    test('a model with one measured tier gets no effort graph', () {
      const single = AiModel(
        id: 'a/b',
        slug: 'b',
        name: 'B',
        vendor: 'a',
        vendorName: 'A',
        supportedEfforts: ['low', 'high'],
        effortProfiles: [
          AiEffortProfile(effort: 'high', intelligenceIndex: 60),
        ],
      );
      // One point is a dot, not a trend.
      expect(single.hasEffortGraph, isFalse);
    });

    test('missing fields decode to nulls rather than throwing', () {
      final catalog = AiCatalog.fromJson({
        'models': [
          {'id': 'a/b'},
        ],
      });
      expect(catalog.models.single.llmStatsIndex, isNull);
      expect(catalog.models.single.contextTokens, isNull);
      expect(catalog.refreshedAt, isNull);
    });
  });

  group('estimateVram', () {
    test('weight memory is parameters times bits over eight', () {
      final estimate = estimateVram(
        parametersB: 70,
        quantization: Quantization.q4,
        contextTokens: 0,
      );
      expect(estimate.weightsGb, closeTo(70 * 4.8 / 8, 1e-9));
      expect(estimate.kvCacheGb, 0);
      expect(estimate.overheadGb, kRuntimeOverheadGb);
    });

    test('the context estimate matches known grouped-query layouts', () {
      // An 8B model with 8 KV heads at 128 head dim needs ~0.125 GB per 1K
      // tokens, and a 70B of the same shape ~0.33. The curve is calibrated
      // against those two points, so drift shows up here.
      final small = estimateVram(
        parametersB: 8,
        quantization: Quantization.fp16,
        contextTokens: 1000,
      );
      expect(small.kvCacheGb, closeTo(0.125, 0.02));

      final large = estimateVram(
        parametersB: 70,
        quantization: Quantization.fp16,
        contextTokens: 1000,
      );
      expect(large.kvCacheGb, closeTo(0.33, 0.04));
    });

    test('context cost scales linearly and halves at 8-bit', () {
      final base = estimateVram(
        parametersB: 8,
        quantization: Quantization.q4,
        contextTokens: 8192,
      );
      final doubled = estimateVram(
        parametersB: 8,
        quantization: Quantization.q4,
        contextTokens: 16384,
      );
      expect(doubled.kvCacheGb, closeTo(base.kvCacheGb * 2, 1e-9));

      final packed = estimateVram(
        parametersB: 8,
        quantization: Quantization.q4,
        contextTokens: 8192,
        kvCacheBits: 8,
      );
      expect(packed.kvCacheGb, closeTo(base.kvCacheGb / 2, 1e-9));
    });
  });

  group('fitIn', () {
    const estimate =
        VramEstimate(weightsGb: 20, kvCacheGb: 1, overheadGb: 1); // 22 GB

    test('leaves headroom rather than filling the card exactly', () {
      // 22 GB into a 24 GB card is 92% — real, but not comfortable.
      expect(fitIn(estimate, 24), FitVerdict.tight);
      expect(fitIn(estimate, 32), FitVerdict.comfortable);
    });

    test('distinguishes spilling to RAM from not running at all', () {
      expect(fitIn(estimate, 16), FitVerdict.spills);
      expect(fitIn(estimate, 8), FitVerdict.wontRun);
    });
  });
}
