import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark_repository.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark_scope.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/server_rack_test_page.dart';
import 'package:luma/theme/luma_theme.dart';

const _scene = 'assets/ai_usage/server_rack_tests/opus_5_5_xhigh.html';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the Opus 5.5 XHigh rack scene has both viewing modes', () async {
    final html = await rootBundle.loadString(_scene);
    expect(html.toLowerCase(), contains('<!doctype html>'));
    for (final label in [
      'FULL RACK FRONT',
      'FULL RACK 3/4',
      'FULL RACK SIDE',
      'FULL RACK REAR',
      'INSPECT SLICE',
    ]) {
      expect(html, contains(label), reason: 'missing rack control: $label');
    }
    for (final label in [
      'WHOLE SLICE',
      'TOP DOWN',
      '3/4 ENGINEERING VIEW',
      'FRONT INTERNALS',
      'REAR INTERNALS',
      'CPU + MEMORY',
      'GPU AREA',
      'STORAGE AREA',
      'PREVIOUS SERVER',
      'NEXT SERVER',
      'RETURN TO RACK',
      'EXPLODED VIEW',
      'CHASSIS CUTAWAY',
      'SHOW AIRFLOW',
    ]) {
      expect(html, contains(label), reason: 'missing slice control: $label');
    }
  });

  test('all nine servers are in the scene, each with its own layout', () async {
    final html = await rootBundle.loadString(_scene);
    for (final name in [
      'WEB / EDGE NODE',
      'GENERAL PURPOSE',
      'IN-MEMORY CACHE',
      'VIRTUALIZATION HOST',
      'DATABASE SERVER',
      'BACKUP / ARCHIVE NODE',
      'INFERENCE NODE',
      'AI COMPUTE NODE',
      'STORAGE NODE',
    ]) {
      expect(html, contains("name: '$name'"), reason: 'missing server: $name');
    }
    // Every archetype carries its own build() rather than sharing one layout.
    expect(RegExp(r'build\(ctx\) \{').allMatches(html).length, 9);
  });

  test('the scene works offline from the shared three.js copy', () async {
    final html = await rootBundle.loadString(_scene);
    expect(
      html,
      contains('../../airline_tycoon/scene/vendor/three-0.160.1.min.js'),
    );
    expect(html, isNot(contains('<script src="http')));
    expect(html, isNot(contains('<link rel="stylesheet" href="http')));
    final three = await rootBundle.loadString(
      'assets/airline_tycoon/scene/vendor/three-0.160.1.min.js',
    );
    expect(three, contains('THREE'));
  });

  testWidgets('the Server Rack Test lists the Opus 5.5 XHigh entry', (
    tester,
  ) async {
    final repository = AiBenchmarkRepository.withManifest(
      AiBenchmarkManifest.empty,
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      AiBenchmarkScope(
        repository: repository,
        child: MaterialApp(
          theme: LumaTheme.dark,
          home: const ServerRackTestPage(),
        ),
      ),
    );
    expect(find.text('Opus 5.5 (XHigh)'), findsOneWidget);
  });
}
