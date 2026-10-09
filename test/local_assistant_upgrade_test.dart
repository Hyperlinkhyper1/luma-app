import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/chat/local_model_store.dart';
import 'package:luma/features/chat/web_search_client.dart';

void main() {
  group('looksLikeFactQuestion', () {
    test('searches for questions about the world', () {
      for (final question in [
        'hoe ver is gouda naar berlijn',
        'Wie won de Tour de France in 2025?',
        'What is the population of Tokyo',
        'how tall is the eiffel tower',
        'Où se trouve la tour Eiffel exactement',
        '¿Cuándo empezó la Segunda Guerra Mundial?',
        '东京有多少人口',
        'The capital of Australia is Sydney, right?',
      ]) {
        expect(
          WebSearchClient.looksLikeFactQuestion(question),
          isTrue,
          reason: question,
        );
      }
    });

    test('leaves small talk, commands and personal questions alone', () {
      for (final text in [
        'hoi',
        'hoe gaat het?',
        'how are you doing today?',
        'open finance',
        'maak een notitie over boodschappen',
        'how much did I spend on groceries this month?',
        'wat staat er in mijn agenda morgen',
        'how do I install a plugin in luma',
        'Install the calculator plugin please',
        '我今天花了多少钱',
        '',
      ]) {
        expect(
          WebSearchClient.looksLikeFactQuestion(text),
          isFalse,
          reason: text,
        );
      }
    });
  });

  group('resultsForPrompt', () {
    test('lists the results with their URLs', () {
      final text = WebSearchClient.resultsForPrompt({
        'status': 'ok',
        'results': [
          {
            'title': 'Gouda – Berlijn',
            'url': 'https://example.com/route',
            'snippet': 'De afstand is ongeveer 650 km.',
          },
          {'title': 'Empty', 'url': 'https://example.com/empty', 'snippet': ''},
        ],
      });
      expect(text, contains('[1] Gouda – Berlijn — https://example.com/route'));
      expect(text, contains('650 km'));
      expect(text, isNot(contains('example.com/empty')));
    });

    test('is null when the search failed or found nothing', () {
      expect(
        WebSearchClient.resultsForPrompt({
          'status': 'limit_reached',
          'message': 'x',
        }),
        isNull,
      );
      expect(
        WebSearchClient.resultsForPrompt({'status': 'ok', 'results': []}),
        isNull,
      );
    });
  });

  test('deleteOtherModels keeps only the current model', () async {
    final dir = await Directory.systemTemp.createTemp('luma_models_');
    addTearDown(() => dir.delete(recursive: true));
    for (final name in [
      'Qwen3.5-4B-Q4_K_M.gguf',
      'Qwen3.5-0.8B-Q8_0.gguf',
      'Qwen3.5-0.8B-Q4_0.gguf',
      'Qwen3.5-2B-Q4_K_M.gguf.download',
      'Qwen3.5-4B-Q4_K_M.gguf.verified',
      'Qwen3.5-0.8B-Q4_0.gguf.verified',
      'notes.txt',
    ]) {
      await File('${dir.path}${Platform.pathSeparator}$name').writeAsString('x');
    }

    await LocalModelStore.deleteOtherModels(dir, 'Qwen3.5-4B-Q4_K_M.gguf');

    final left = dir.listSync().map((e) => e.uri.pathSegments.last).toSet();
    expect(left, {
      'Qwen3.5-4B-Q4_K_M.gguf',
      'Qwen3.5-4B-Q4_K_M.gguf.verified',
      'notes.txt',
    });
  });

  group('verify', () {
    const wrongDigest =
        '0f6b1ee6f2ac4a0b9b4b5b1b2a5f2f7e0a1d4e5c3b2a19080706050403020100';
    late Directory dir;
    late File model;
    late String modelSha;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('luma_verify_');
      model = File('${dir.path}${Platform.pathSeparator}model.gguf');
      await model.writeAsString('model');
      modelSha = sha256.convert(await model.readAsBytes()).toString();
    });
    tearDown(() => dir.delete(recursive: true));

    test('hashes once, then trusts the stamp while the file is unchanged',
        () async {
      expect(
        await LocalModelStore.verify(model, bytes: 5, expectedSha256: modelSha),
        isTrue,
      );
      expect(await File('${model.path}.verified').exists(), isTrue);

      // Same size and modified time but different bytes: a second hash
      // would reject it, so passing proves the stamp was used.
      final modified = await model.lastModified();
      await model.writeAsString('MODEL');
      await model.setLastModified(modified);
      expect(
        await LocalModelStore.verify(model, bytes: 5, expectedSha256: modelSha),
        isTrue,
      );
    });

    test('re-hashes a file whose modified time changed', () async {
      await LocalModelStore.verify(model, bytes: 5, expectedSha256: modelSha);
      await model.writeAsString('MODEL');
      await model.setLastModified(DateTime(2020));
      expect(
        await LocalModelStore.verify(model, bytes: 5, expectedSha256: modelSha),
        isFalse,
      );
      expect(await File('${model.path}.verified').exists(), isFalse);
    });

    test('rejects a file with the wrong digest', () async {
      expect(
        await LocalModelStore.verify(model, bytes: 5, expectedSha256: wrongDigest),
        isFalse,
      );
      expect(await File('${model.path}.verified').exists(), isFalse);
    });
  });
}
