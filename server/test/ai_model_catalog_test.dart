import 'dart:io';

import 'package:luma_sync_server/ai_model_catalog.dart';
import 'package:luma_sync_server/ai_model_sources.dart';
import 'package:test/test.dart';

/// One entry shaped exactly like OpenRouter's `/api/v1/models` payload, so a
/// change in how the mapping reads it shows up here rather than as a blank
/// column in the app.
Map<String, dynamic> _openRouterEntry({
  String id = 'anthropic/claude-opus-5',
  Object? huggingFaceId,
  Object? designArena,
}) =>
    {
      'id': id,
      'name': 'Anthropic: Claude Opus 5',
      'created': 1787086655,
      'description': 'A  model   with\n messy whitespace.',
      'context_length': 1000000,
      'hugging_face_id': huggingFaceId,
      'architecture': {
        'input_modalities': ['text', 'image'],
        'output_modalities': ['text'],
      },
      'pricing': {
        'prompt': '0.000005',
        'completion': '0.000025',
        'input_cache_read': '0.0000005',
        'image': '-1',
      },
      'top_provider': {'max_completion_tokens': 64000},
      'benchmarks': {
        'artificial_analysis': {
          'intelligence_index': 63.1,
          'coding_index': 78.0,
          'agentic_index': 59.2,
        },
        'design_arena': designArena ?? const [],
      },
      'reasoning': {
        'supported_efforts': ['low', 'high', 'none'],
        'default_effort': 'high',
      },
    };

void main() {
  group('parseOpenRouterModel', () {
    test('maps prices per token onto USD per million', () {
      final model = parseOpenRouterModel(_openRouterEntry(), nowMs: 1)!;
      expect(model.inputPricePerM, closeTo(5.0, 1e-9));
      expect(model.outputPricePerM, closeTo(25.0, 1e-9));
      expect(model.cacheReadPerM, closeTo(0.5, 1e-9));
      expect(model.avgPricePerM, closeTo(15.0, 1e-9));
      // 8:1 input:output, so the cheaper input side dominates.
      expect(model.blendedPricePerM, closeTo((5 * 8 + 25) / 9, 1e-9));
    });

    test('a price of -1 means "not priced here", not a negative price', () {
      final entry = _openRouterEntry();
      (entry['pricing'] as Map<String, dynamic>)['completion'] = '-1';
      final model = parseOpenRouterModel(entry, nowMs: 1)!;
      expect(model.outputPricePerM, isNull);
      // Half a price is not a price: averaging against a missing side would
      // report this model as cheaper than it is.
      expect(model.avgPricePerM, isNull);
      expect(model.blendedPricePerM, isNull);
    });

    test('an empty hugging_face_id is treated as absent', () {
      // Regression: closed models carry `""` here. Left as a real value, the
      // lookup URL collapses to Hugging Face's list endpoint, which answers
      // 200 with a JSON array of every model on the hub.
      expect(parseOpenRouterModel(_openRouterEntry(huggingFaceId: ''), nowMs: 1)!
          .huggingFaceId, isNull);
      expect(parseOpenRouterModel(_openRouterEntry(huggingFaceId: '   '),
              nowMs: 1)!
          .huggingFaceId, isNull);
      expect(
          parseOpenRouterModel(_openRouterEntry(huggingFaceId: 'org/Repo'),
                  nowMs: 1)!
              .huggingFaceId,
          'org/Repo');
    });

    test('strips the vendor prefix and tidies the description', () {
      final model = parseOpenRouterModel(_openRouterEntry(), nowMs: 1)!;
      expect(model.name, 'Claude Opus 5');
      expect(model.vendor, 'anthropic');
      expect(model.vendorName, 'Anthropic');
      expect(model.description, 'A model with messy whitespace.');
    });

    test('drops the "none" effort but keeps the real tiers', () {
      final model = parseOpenRouterModel(_openRouterEntry(), nowMs: 1)!;
      expect(model.supportedEfforts, ['low', 'high']);
      expect(model.defaultEffort, 'high');
    });

    test('skips alias and routing-variant rows', () {
      for (final id in [
        '~anthropic/claude-latest',
        'anthropic/claude-opus-5:free',
        'anthropic/claude-opus-5:thinking',
        'no-slash-id',
      ]) {
        expect(parseOpenRouterModel(_openRouterEntry(id: id), nowMs: 1), isNull,
            reason: '$id should not become a leaderboard row');
      }
    });

    test('survives fields that arrive as the wrong JSON type', () {
      final entry = _openRouterEntry()
        ..['pricing'] = ['not', 'an', 'object']
        ..['architecture'] = 'text->text'
        ..['benchmarks'] = 42;
      final model = parseOpenRouterModel(entry, nowMs: 1);
      expect(model, isNotNull);
      expect(model!.inputPricePerM, isNull);
      expect(model.inputModalities, isEmpty);
      expect(model.llmStatsIndex, isNull);
    });

    test('code arena prefers the code category over the mean', () {
      final model = parseOpenRouterModel(
        _openRouterEntry(designArena: const [
          {'arena': 'agents', 'category': 'androidnative', 'elo': 9999},
          {'arena': 'models', 'category': 'website', 'elo': 1300},
          {'arena': 'models', 'category': 'codecategories', 'elo': 1333, 'rank': 4},
        ]),
        nowMs: 1,
      )!;
      expect(model.codeArena, 1333);
      expect(model.codeArenaRank, 4);
    });

    test('code arena falls back to the mean of the model arena only', () {
      final model = parseOpenRouterModel(
        _openRouterEntry(designArena: const [
          {'arena': 'agents', 'category': 'androidnative', 'elo': 9999},
          {'arena': 'models', 'category': 'website', 'elo': 1300},
          {'arena': 'models', 'category': 'gamedev', 'elo': 1400},
        ]),
        nowMs: 1,
      )!;
      expect(model.codeArena, 1350);
      expect(model.codeArenaRank, isNull);
    });
  });

  group('AiModel.mergedWith', () {
    test('a later source refines earlier values but never blanks them', () {
      final base = parseOpenRouterModel(_openRouterEntry(), nowMs: 1)!;
      final overlay = AiModel(
        id: base.id,
        slug: base.slug,
        name: base.name,
        vendor: base.vendor,
        vendorName: base.vendorName,
        updatedAtMs: 2,
        reasoningIndex: 71.4,
        speedTokensPerSec: 50,
        sources: const ['artificial-analysis'],
      );
      final merged = base.mergedWith(overlay);

      expect(merged.reasoningIndex, 71.4);
      expect(merged.speedTokensPerSec, 50);
      // Everything the overlay said nothing about survives.
      expect(merged.inputPricePerM, closeTo(5.0, 1e-9));
      expect(merged.codingIndex, 78.0);
      expect(merged.contextTokens, 1000000);
      expect(merged.sources, containsAll(['openrouter', 'artificial-analysis']));
    });

    test('open weights latch on once any source confirms a repo', () {
      final closed = parseOpenRouterModel(_openRouterEntry(), nowMs: 1)!;
      final open = AiModel(
        id: closed.id,
        slug: closed.slug,
        name: closed.name,
        vendor: closed.vendor,
        vendorName: closed.vendorName,
        updatedAtMs: 2,
        openWeights: true,
        licenseId: 'apache-2.0',
      );
      expect(closed.mergedWith(open).openWeights, isTrue);
      // And a later overlay that says nothing about it doesn't reclose it.
      expect(closed.mergedWith(open).mergedWith(closed).openWeights, isTrue);
    });
  });

  group('parseFeed', () {
    test('reads RSS 2.0 items, CDATA and RFC-822 dates', () {
      final items = parseFeed('''
<rss><channel>
<item>
  <title><![CDATA[Claude Opus 5 is here]]></title>
  <link>https://example.com/a</link>
  <pubDate>Tue, 12 Aug 2026 10:00:00 GMT</pubDate>
  <description>&lt;p&gt;A &amp;amp; B&lt;/p&gt;</description>
</item>
</channel></rss>
''', 'Example');
      expect(items, hasLength(1));
      expect(items.single.title, 'Claude Opus 5 is here');
      expect(items.single.url, 'https://example.com/a');
      expect(items.single.summary, 'A & B');
      expect(
        DateTime.fromMillisecondsSinceEpoch(items.single.publishedAtMs,
            isUtc: true),
        DateTime.utc(2026, 8, 12, 10),
      );
    });

    test('reads Atom entries, whose link is an attribute', () {
      final items = parseFeed('''
<feed>
<entry>
  <title>Qwen3.8 released</title>
  <link rel="alternate" href="https://example.com/b"/>
  <published>2026-08-12T10:00:00Z</published>
  <summary>Weights on the hub.</summary>
</entry>
</feed>
''', 'Example');
      expect(items.single.url, 'https://example.com/b');
      expect(items.single.title, 'Qwen3.8 released');
    });

    test('unescapes Markdown-escaped titles', () {
      final items = parseFeed(
        '<feed><entry><title>LFM2.5 Q4\\_0 Checkpoints</title>'
        '<link href="https://example.com/c"/></entry></feed>',
        'Example',
      );
      expect(items.single.title, 'LFM2.5 Q4_0 Checkpoints');
    });

    test('a page that is not a feed yields nothing rather than throwing', () {
      // A docs site answering 200 with its HTML 404 page is the real case
      // this guards; the refresh reports it as a failed source.
      expect(parseFeed('<!doctype html><html><body>Not a feed</body></html>',
              'Example'),
          isEmpty);
    });

    test('gives the same item the same id across polls', () {
      String idOf() => parseFeed(
            '<feed><entry><title>T</title>'
            '<link href="https://example.com/same"/></entry></feed>',
            'Example',
          ).single.id;
      expect(idOf(), idOf());
    });
  });

  group('AiModelCatalogStore', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('luma_ai_catalog_test');
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    AiModel model(String id, {double? index}) => AiModel(
          id: id,
          slug: id.split('/').last,
          name: id.split('/').last,
          vendor: id.split('/').first,
          vendorName: 'Vendor',
          updatedAtMs: 1,
          llmStatsIndex: index,
        );

    test('reports which ids are new, and only the new ones', () async {
      final store = await AiModelCatalogStore.open(dir.path);
      expect(await store.upsertModels([model('a/one'), model('a/two')]),
          unorderedEquals(['a/one', 'a/two']));
      expect(await store.upsertModels([model('a/one'), model('a/three')]),
          ['a/three']);
      expect(store.modelCount, 3);
    });

    test('keeps a model an upstream stopped listing', () async {
      final store = await AiModelCatalogStore.open(dir.path);
      await store.upsertModels([model('a/one'), model('a/two')]);
      await store.upsertModels([model('a/one')]);
      // A provider dropping a model from one response must not erase it.
      expect(store.byId('a/two'), isNotNull);
    });

    test('pruneVendorsNotIn removes only disallowed vendors, permanently',
        () async {
      final store = await AiModelCatalogStore.open(dir.path);
      await store.upsertModels(
          [model('openai/gpt'), model('baidu/ernie'), model('qwen/max')]);

      final removed = await store.pruneVendorsNotIn({'openai', 'qwen'});
      expect(removed, ['baidu/ernie']);
      expect(store.byId('baidu/ernie'), isNull);
      expect(store.byId('openai/gpt'), isNotNull);
      expect(store.byId('qwen/max'), isNotNull);

      // A later upsertModels can't bring it back on its own — the vendor
      // filter runs upstream of the store, so nothing should be re-adding
      // pruned vendors in the first place.
      await store.upsertModels([model('a/one')]);
      expect(store.byId('baidu/ernie'), isNull);
    });

    test('sorts rated models first and leaves unrated ones at the end',
        () async {
      final store = await AiModelCatalogStore.open(dir.path);
      await store.upsertModels([
        model('a/unrated'),
        model('a/low', index: 10),
        model('a/high', index: 90),
      ]);
      expect([for (final m in store.models) m.id],
          ['a/high', 'a/low', 'a/unrated']);
    });

    test('round-trips through disk', () async {
      final store = await AiModelCatalogStore.open(dir.path);
      await store.upsertModels([model('a/one', index: 42)]);
      await store.upsertNews([
        const AiNewsItem(
          id: 'n1',
          title: 'T',
          url: 'https://example.com',
          source: 'Example',
          publishedAtMs: 5,
        ),
      ]);

      final reopened = await AiModelCatalogStore.open(dir.path);
      expect(reopened.modelCount, 1);
      expect(reopened.byId('a/one')?.llmStatsIndex, 42);
      expect(reopened.news.single.title, 'T');
      expect(reopened.etag, store.etag);
    });

    test('the etag moves when the catalogue does', () async {
      final store = await AiModelCatalogStore.open(dir.path);
      final before = store.etag;
      await store.upsertModels([model('a/one')]);
      expect(store.etag, isNot(before));
    });

    test('news is kept newest-first and capped', () async {
      final store = await AiModelCatalogStore.open(dir.path);
      await store.upsertNews([
        for (var i = 0; i < kAiNewsRetained + 10; i++)
          AiNewsItem(
            id: 'n$i',
            title: 'T$i',
            url: 'https://example.com/$i',
            source: 'Example',
            publishedAtMs: i,
          ),
      ]);
      expect(store.news, hasLength(kAiNewsRetained));
      expect(store.news.first.publishedAtMs,
          greaterThan(store.news.last.publishedAtMs));
    });

    test('a corrupt catalogue file starts empty rather than refusing to boot',
        () async {
      await File('${dir.path}${Platform.pathSeparator}ai_models.json')
          .writeAsString('{not json');
      final store = await AiModelCatalogStore.open(dir.path);
      expect(store.modelCount, 0);
    });
  });

  group('display names', () {
    test('known vendors and licences read as names', () {
      expect(vendorDisplayName('moonshotai'), 'Moonshot AI');
      expect(vendorDisplayName('x-ai'), 'xAI');
      expect(licenseDisplayName('apache-2.0'), 'Apache 2.0');
      expect(licenseDisplayName('mit'), 'MIT');
    });

    test('an unknown vendor or licence still reads as a name, not a slug', () {
      expect(vendorDisplayName('brand-new-lab'), 'Brand New Lab');
      expect(licenseDisplayName('some-new-license'), 'Some New License');
    });
  });
}
