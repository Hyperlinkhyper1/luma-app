import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark_repository.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark_scope.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/benchmark_webview.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/hero_tile.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/pagoda_test_page.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/tests_tab.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/theme/luma_theme.dart';

class _MobileWebviewPlatform extends InAppWebViewPlatform {
  final views = <_MobileWebview>[];
  dynamic messageOnLoad;
  bool _sentReadiness = false;

  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) {
    final view = _MobileWebview(params, this);
    views.add(view);
    return view;
  }
}

class _MobileController extends PlatformInAppWebViewController {
  _MobileController()
    : super.implementation(
        const PlatformInAppWebViewControllerCreationParams(id: 'phone-test'),
      );

  final handlers = <String, JavaScriptHandlerCallback>{};

  @override
  void addJavaScriptHandler({
    required String handlerName,
    required JavaScriptHandlerCallback callback,
  }) {
    handlers[handlerName] = callback;
  }

  @override
  void dispose({bool isKeepAlive = false}) {}
}

class _MobileWebview extends PlatformInAppWebViewWidget {
  _MobileWebview(super.params, this.platform) : super.implementation();

  final _MobileWebviewPlatform platform;
  final controller = _MobileController();
  bool _created = false;

  dynamic get callbackController => params.controllerFromPlatform!(controller);

  @override
  Widget build(BuildContext context) {
    if (!_created) {
      _created = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final converted = callbackController;
        params.onWebViewCreated?.call(converted);
        params.onLoadStart?.call(converted, params.initialUrlRequest?.url);
        params.onLoadStop?.call(converted, params.initialUrlRequest?.url);
        if (platform.messageOnLoad != null && !platform._sentReadiness) {
          platform._sentReadiness = true;
          controller.handlers['lumaBenchmark']?.call([platform.messageOnLoad]);
        }
      });
    }
    return const SizedBox.expand(key: ValueKey('mobile-benchmark-surface'));
  }

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      params.controllerFromPlatform!(controller) as T;

  @override
  void dispose() {}
}

Widget _app(AiBenchmarkRepository repository, {Widget? home}) =>
    AiBenchmarkScope(
      repository: repository,
      child: MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        theme: LumaTheme.dark,
        home: Scaffold(body: home ?? const TestsTab()),
      ),
    );

void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _selectModel(
  WidgetTester tester, {
  required String title,
  required String model,
}) async {
  final tile = find.widgetWithText(LumaHeroTile, title);
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pumpAndSettle();
  final button = find.widgetWithText(ModelButton, model);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

Future<void> _finishLoading(
  WidgetTester tester,
  _MobileWebviewPlatform platform,
) async {
  for (var attempt = 0; attempt < 30 && platform.views.isEmpty; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump();
  }
  expect(platform.views, isNotEmpty);
  await tester.pumpAndSettle();
}

void main() {
  late _MobileWebviewPlatform platform;
  final t = lookupL(const Locale('en'));

  setUp(() {
    platform = _MobileWebviewPlatform();
    InAppWebViewPlatform.instance = platform;
  });

  final bundled = [
    (
      title: t.aiTestPagodaTitle,
      model: 'Step 5',
      asset: 'assets/tests/pagoda_step5.html',
    ),
    (
      title: t.aiTestEngineTitle,
      model: 'GPT 6.1 Sol (Low)',
      asset: 'assets/ai_usage/engine_tests/gpt_6_1_sol_low.html',
    ),
    (
      title: t.aiTestPcTitle,
      model: 'GPT 6.1 Sol (Xhigh)',
      asset: 'assets/ai_usage/pc_tests/gpt61_sol_xhigh/index.html',
    ),
    (
      title: t.aiTestServerRackTitle,
      model: 'Sonnet 5.5 (Low)',
      asset: 'assets/ai_usage/server_rack_tests/sonnet_5_5_low.html',
    ),
    (
      title: t.aiTestCruiseShipTitle,
      model: 'Opus 5.5 (Ultracode)',
      asset: 'assets/ai_usage/cruise_ship_tests/opus_5_5_ultracode.html',
    ),
  ];

  for (final benchmark in bundled) {
    testWidgets('${benchmark.title} opens a bundled contestant at 320px', (
      tester,
    ) async {
      _phoneSize(tester);
      platform.messageOnLoad = {'type': 'cruise-ready'};
      final repository = AiBenchmarkRepository.withManifest(
        AiBenchmarkManifest.empty,
      );
      addTearDown(repository.dispose);
      await tester.pumpWidget(_app(repository));
      await _selectModel(
        tester,
        title: benchmark.title,
        model: benchmark.model,
      );
      await _finishLoading(tester, platform);

      expect(find.byType(InAppWebView), findsOneWidget);
      expect(platform.views.last.params.initialFile, benchmark.asset);
      expect(platform.views.last.params.initialUrlRequest, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  final cached = [
    (kind: 'pagoda', title: t.aiTestPagodaTitle),
    (kind: 'engine', title: t.aiTestEngineTitle),
    (kind: 'pc', title: t.aiTestPcTitle),
    (kind: 'keyboard', title: t.aiTestKeyboardTitle),
    (kind: 'cathedral', title: t.aiTestCathedralTitle),
    (kind: 'server_rack', title: t.aiTestServerRackTitle),
    (kind: 'cruise_ship', title: t.aiTestCruiseShipTitle),
    (kind: 'website_landing_page', title: t.aiTestWebsiteLandingTitle),
  ];

  for (final benchmark in cached) {
    testWidgets('${benchmark.title} opens its cached contestant on a phone', (
      tester,
    ) async {
      _phoneSize(tester);
      platform.messageOnLoad = {'type': 'cruise-ready'};
      final directory = Directory.systemTemp.createTempSync('luma_phone_tests');
      addTearDown(() => directory.deleteSync(recursive: true));
      final id = '${benchmark.kind}_phone';
      final extension = benchmark.kind == 'cathedral' ? 'glb' : 'html';
      final scene = File(
        '${directory.path}/$kAiBenchmarkCacheDir/scenes/$id.$extension',
      );
      final bytes = utf8.encode('<!doctype html><title>Phone fixture</title>');
      scene.parent.createSync(recursive: true);
      scene.writeAsBytesSync(bytes);
      final repository = AiBenchmarkRepository.withManifest(
        AiBenchmarkManifest.fromJson({
          'benchmarks': [
            {
              'id': id,
              'kind': benchmark.kind,
              'model': 'Phone contestant',
              'sizeBytes': bytes.length,
              'sha256': sha256.convert(bytes).toString(),
            },
          ],
        }),
        cacheDir: directory,
      );
      addTearDown(repository.dispose);
      await tester.runAsync(
        () => repository.sceneFile(id, extension: extension),
      );
      await tester.pumpWidget(_app(repository));
      await _selectModel(
        tester,
        title: benchmark.title,
        model: 'Phone contestant',
      );
      await _finishLoading(tester, platform);

      expect(find.byType(InAppWebView), findsOneWidget);
      expect(
        platform.views.last.params.initialUrlRequest?.url.toString(),
        Uri.file(
          benchmark.kind == 'cathedral'
              ? '${scene.path}.viewer.html'
              : scene.path,
        ).toString(),
      );
      expect(platform.views.last.params.initialFile, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final target in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$target keeps cached paths and existing messages usable',
      (tester) async {
        final received = <dynamic>[];
        final repository = AiBenchmarkRepository.withManifest(
          AiBenchmarkManifest.empty,
        );
        addTearDown(repository.dispose);
        final path = '${Directory.systemTemp.path}/phone cache/scene.html';
        await tester.pumpWidget(
          _app(
            repository,
            home: BenchmarkWebview(path: path, onMessage: received.add),
          ),
        );
        await tester.pumpAndSettle();
        final view = platform.views.last;
        expect(BenchmarkWebview.supported, isTrue);
        expect(
          view.params.initialUrlRequest?.url.toString(),
          Uri.file(path).toString(),
        );
        expect(view.params.initialSettings?.javaScriptEnabled, isTrue);
        expect(
          view.params.initialSettings?.allowFileAccessFromFileURLs,
          isTrue,
        );
        expect(
          view.params.initialSettings?.allowUniversalAccessFromFileURLs,
          isTrue,
        );
        expect(
          view.params.initialSettings?.allowingReadAccessTo.toString(),
          Uri.directory(File(path).parent.path).toString(),
        );
        expect(
          view.params.initialUserScripts!.single.injectionTime,
          UserScriptInjectionTime.AT_DOCUMENT_START,
        );
        expect(
          view.params.initialUserScripts!.single.source,
          contains('window.chrome.webview.postMessage'),
        );
        final message = {'type': 'cruise-ready'};
        view.controller.handlers['lumaBenchmark']!([message]);
        expect(received, [message]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant({target}),
    );
  }
}
