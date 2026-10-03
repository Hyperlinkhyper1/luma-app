import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark_repository.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark_scope.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/server_rack_test_page.dart';
import 'package:luma/theme/luma_theme.dart';

const _scene = 'assets/ai_usage/server_rack_tests/sonnet_5_5_xhigh.html';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the Sonnet 5.5 Xhigh rack scene is bundled with both viewing modes',
    () async {
      final html = await rootBundle.loadString(_scene);
      expect(html.toLowerCase(), contains('<!doctype html>'));
      // Full rack: camera presets, selection and the way into a slice.
      for (final label in [
        'FULL RACK FRONT',
        'FULL RACK 3/4',
        'FULL RACK SIDE',
        'FULL RACK REAR',
        'INSPECT SLICE',
      ]) {
        expect(html, contains(label), reason: 'missing rack control: $label');
      }
      // Single slice: presets, per-server switching and the inspection modes.
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
    },
  );

  test(
    'every inspectable server archetype is described in the scene',
    () async {
      final html = await rootBundle.loadString(_scene);
      for (final name in [
        'GENERAL PURPOSE',
        'VIRTUALIZATION HOST',
        'AI COMPUTE NODE',
        'STORAGE NODE',
        'DATABASE SERVER',
      ]) {
        expect(html, contains(name), reason: 'missing server: $name');
      }
    },
  );

  test(
    'three.js is read from the vendored copy that ships with the app',
    () async {
      final html = await rootBundle.loadString(_scene);
      const vendor = 'assets/airline_tycoon/scene/vendor/three-0.160.1.min.js';
      // The scene sits at assets/ai_usage/server_rack_tests/, so it climbs two
      // levels to reach the shared copy rather than carrying its own.
      expect(
        html,
        contains('../../airline_tycoon/scene/vendor/three-0.160.1.min.js'),
      );
      final three = await rootBundle.loadString(vendor);
      expect(three, contains('THREE'));
    },
  );

  testWidgets('the Server Rack Test lists the Sonnet 5.5 Xhigh entry', (
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
    expect(find.text('Sonnet 5.5 (Xhigh)'), findsOneWidget);
  });
}
