import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/ai_usage/ai_usage_page.dart';
import 'package:luma/features/plugins/installed/ai_usage/ai_usage_repository.dart';
import 'package:luma/features/plugins/installed/ai_usage/ai_usage_scope.dart';
import 'package:luma/features/plugins/installed/ai_usage/antigravity_scanner.dart';
import 'package:luma/features/plugins/installed/ai_usage/claude_code_scanner.dart';
import 'package:luma/features/plugins/installed/ai_usage/codex_cli_scanner.dart';
import 'package:luma/features/plugins/installed/ai_usage/data/ai_usage_database.dart';
import 'package:luma/features/plugins/installed/ai_usage/freebuff_scanner.dart';
import 'package:luma/features/plugins/installed/ai_usage/opencode_scanner.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/storage/storage_guard.dart';
import 'package:luma/theme/luma_theme.dart';
import 'package:luma/theme/theme_style.dart';

const _out = r'C:\Users\ayden\AppData\Local\Temp\claude\f55c479e66811e21\e07c06d6-3ca8-4c41-a3ad-73de652fdb88\scratchpad';

class _NoScheduleStorageGuard extends StorageGuardService {
  @override
  void scheduleRefresh() {}
}

class _Found extends ClaudeCodeScanner {
  const _Found();
  @override
  Future<ClaudeCodeScanResult> scan(AiUsageDatabase db) async =>
      const ClaudeCodeScanResult(projectsDirFound: true, filesScanned: 0, filesNew: 0, turnsAdded: 0);
}

class _NoCodex extends CodexCliScanner {
  const _NoCodex();
  @override
  Future<CodexCliScanResult> scan(AiUsageDatabase db) async => CodexCliScanResult.unavailable;
}

class _NoAg extends AntigravityScanner {
  const _NoAg();
  @override
  Future<AntigravityScanResult> scan(AiUsageDatabase db) async => AntigravityScanResult.unavailable;
}

class _NoOc extends OpencodeScanner {
  const _NoOc();
  @override
  Future<OpencodeScanResult> scan(AiUsageDatabase db) async => OpencodeScanResult.unavailable;
}

class _NoFb extends FreebuffScanner {
  const _NoFb();
  @override
  Future<FreebuffScanResult> scan(AiUsageDatabase db) async => FreebuffScanResult.unavailable;
}

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File(f).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  setUpAll(() => StorageGuardService.instance = _NoScheduleStorageGuard());

  testWidgets('render usage chart', (tester) async {
    const fonts = r'C:\Users\ayden\flutter\bin\cache\artifacts\material_fonts';
    await tester.runAsync(() async {
      await _font('Roboto', ['$fonts\\roboto-regular.ttf', '$fonts\\roboto-medium.ttf', '$fonts\\roboto-bold.ttf']);
      await _font('MaterialIcons', ['$fonts\\materialicons-regular.otf']);
    });
    tester.view.physicalSize = const Size(1150, 1300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final db = AiUsageDatabase(NativeDatabase.createInBackground(File('$_out\\usage_copy.sqlite')));
    final repo = AiUsageRepository(db,
        claudeScanner: const _Found(),
        codexScanner: const _NoCodex(),
        antigravityScanner: const _NoAg(),
        opencodeScanner: const _NoOc(),
        freebuffScanner: const _NoFb());
    final key = GlobalKey();
    final base = LumaTheme.from(Brightness.dark, null, LumaThemeStyle.standard);
    await tester.pumpWidget(MaterialApp(
      theme: base.copyWith(textTheme: base.textTheme.apply(fontFamily: 'Roboto')),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      home: RepaintBoundary(
        key: key,
        child: Scaffold(
          body: DefaultTextStyle.merge(
            style: const TextStyle(fontFamily: 'Roboto'),
            child: AiUsageScope(repository: repo, child: const AiUsageDashboardTab()),
          ),
        ),
      ),
    ));

    Future<void> settle() async {
      for (var i = 0; i < 14; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 700)));
        await tester.pump(const Duration(milliseconds: 500));
      }
    }

    Future<void> shot(String name) async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$_out\\$name.png').writeAsBytesSync(data!.buffer.asUint8List());
      });
    }

    await settle();
    await tester.tap(find.text('All').first);
    await settle();
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -220));
    await tester.pump(const Duration(milliseconds: 500));
    await shot('chart_all');

    final chart = find.byType(BarChart).first;
    final rect = tester.getRect(chart);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: rect.center);
    await mouse.moveTo(Offset(rect.left + rect.width * 0.62, rect.bottom - 60));
    await tester.pump(const Duration(milliseconds: 500));
    await shot('chart_all_hover');
    await mouse.moveTo(const Offset(5, 5));
    await mouse.removePointer();

    await tester.tap(find.descendant(of: find.byTooltip('Click to show or hide'), matching: find.text('Cache reads')));
    await tester.pump(const Duration(milliseconds: 500));
    await shot('chart_all_cachereads');
    await tester.tap(find.descendant(of: find.byTooltip('Click to show or hide'), matching: find.text('Cache reads')));

    await tester.tap(find.text('30d').first);
    await settle();
    await shot('chart_30d');

    await tester.tap(find.text('Cost').first);
    await tester.pump(const Duration(milliseconds: 500));
    await shot('chart_30d_cost');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      repo.dispose();
      await db.close();
    });
  }, timeout: const Timeout(Duration(minutes: 3)));
}
