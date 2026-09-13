import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/app/widgets.dart';
import 'package:luma/features/home/home_classic_tiles.dart';
import 'package:luma/features/home/home_editor.dart';
import 'package:luma/features/home/home_layout.dart';
import 'package:luma/features/home/home_page.dart';
import 'package:luma/features/home/home_repository.dart';
import 'package:luma/features/home/home_scope.dart';
import 'package:luma/theme/luma_theme.dart';
import 'package:luma/finance/data/database.dart';
import 'package:luma/finance/finance_repository.dart';
import 'package:luma/finance/finance_scope.dart';

class _PreviewFinance implements FinanceRepository {
  @override
  Stream<List<FinanceTransaction>> watchTransactions({int? limit}) =>
      Stream.value([]);
  @override
  Stream<List<Holding>> watchHoldings() => Stream.value([
    const Holding(
      id: 1,
      ticker: 'SAMPLE',
      name: 'Preview investment',
      shares: 1,
      avgCostCents: 18474,
    ),
  ]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _tile = HomeTile(
  id: 'first',
  kind: 'unavailable',
  x: 0,
  y: 0,
  w: 4,
  h: 5,
);

void main() {
  void viewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('original dashboard renders at phone and desktop sizes', (
    tester,
  ) async {
    viewport(tester, const Size(1040, 800));
    late Directory directory;
    var previewTheme = LumaTheme.dark;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('luma_home_preview_');
      final icons = FontLoader('MaterialIcons');
      icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      final font = File(
        '${Platform.environment['WINDIR'] ?? 'C:/Windows'}/Fonts/segoeui.ttf',
      );
      if (await font.exists()) {
        final loader = FontLoader('HomePreview');
        loader.addFont(
          font.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
        await loader.load();
        previewTheme = previewTheme.copyWith(
          textTheme: previewTheme.textTheme.apply(fontFamily: 'HomePreview'),
        );
      }
    });
    addTearDown(() => directory.delete(recursive: true));
    for (final phone in [false, true]) {
      tester.view.physicalSize = phone
          ? const Size(320, 820)
          : const Size(1040, 800);
      late HomeRepository repo;
      await tester.runAsync(() async {
        repo = HomeRepository(
          family: phone ? 'phone' : 'desktop',
          file: () async =>
              File('${directory.path}/${phone ? 'phone' : 'desktop'}.json'),
        );
        await repo.ready;
        await repo.save(HomeLayout.defaults(phone ? 'phone' : 'desktop'));
      });
      final capture = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: previewTheme,
          home: MediaQuery(
            data: MediaQueryData(
              size: tester.view.physicalSize,
              textScaler: TextScaler.noScaling,
            ),
            child: RepaintBoundary(
              key: capture,
              child: HomeScope(
                repository: repo,
                child: Scaffold(
                  body: FinanceScope(
                    repository: _PreviewFinance(),
                    child: HomePage(
                      key: ValueKey(phone),
                      onNavigate: (_) {},
                      startEditing: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await repo.ready;
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('How things look'), findsOneWidget);
      expect(find.text('Pick up where you left off'), findsOneWidget);
      expect(find.text("What you've been up to"), findsOneWidget);
      expect(find.text('Came in this month'), findsOneWidget);
      expect(find.text('Ask Assistant'), findsOneWidget);
      final ink = tester.getRect(
        find
            .descendant(
              of: find.byType(HomeClassicShortcut).first,
              matching: find.byType(InkWell),
            )
            .first,
      );
      final badge = tester.getRect(
        find
            .descendant(
              of: find.byType(HomeClassicShortcut).first,
              matching: find.byType(LumaIconBadge),
            )
            .first,
      );
      final columns = phone ? 4 : 12;
      final width = phone ? 280.0 : 1000.0;
      final step = (width + 16) / columns;
      expect(ink.width, closeTo((phone ? 4 : 3) * step - 16, 4));
      expect(badge.left - ink.left, closeTo(16, 1));
      expect(tester.takeException(), isNull);
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final target = Directory('.dart_tool/home-preview');
        await target.create(recursive: true);
        await File(
          '${target.path}/${phone ? 'phone' : 'desktop'}.png',
        ).writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
      repo.dispose();
    }
  });

  Future<void> grid(
    WidgetTester tester,
    HomeLayout initial,
    ValueChanged<HomeLayout> changed, {
    double textScale = 1,
  }) async {
    var layout = initial;
    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.light,
        home: MediaQuery(
          data: MediaQueryData(
            size: tester.view.physicalSize,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => HomeGrid(
                header: const SizedBox(height: 200),
                layout: layout,
                editing: true,
                onChanged: (value) {
                  setState(() => layout = value);
                  changed(value);
                },
                onAdd: () {},
                onNavigate: (_) {},
                onPlugin: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('dragging snaps to cells and moves overlapping tiles down', (
    tester,
  ) async {
    viewport(tester, const Size(1040, 800));
    var layout = HomeLayout(
      columns: 12,
      tiles: [
        _tile,
        _tile.copyWith(id: 'second', x: 4),
      ],
    );
    await grid(tester, layout, (value) => layout = value);
    final before = tester.getRect(find.byKey(const ValueKey('first')));
    final step = (before.width + 16) / 4;
    final handle = find.byIcon(Icons.drag_indicator_rounded).first;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await gesture.moveBy(Offset(step * 4 + 3, 3));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(layout.tiles.first.x, 4);
    expect(layout.tiles.first.y, 0);
    expect(layout.tiles[1].y, 5);
    final after = tester.getRect(find.byKey(const ValueKey('first')));
    expect(after.left, closeTo(before.left + step * 4, .01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('resize handle snaps both dimensions to the grid', (
    tester,
  ) async {
    viewport(tester, const Size(1040, 800));
    var layout = HomeLayout(columns: 12, tiles: [_tile]);
    await grid(tester, layout, (value) => layout = value);
    final before = tester.getRect(find.byKey(const ValueKey('first')));
    final step = (before.width + 16) / 4;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.south_east_rounded)),
    );
    await gesture.moveBy(const Offset(20, 20));
    await tester.pump();
    await gesture.moveBy(Offset(step + 3, 53));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(layout.tiles.single.w, 5);
    expect(layout.tiles.single.h, 6);
    final after = tester.getRect(find.byKey(const ValueKey('first')));
    expect(after.width, closeTo(before.width + step, .01));
    expect(after.height, before.height + 50);
    expect(tester.takeException(), isNull);
  });

  testWidgets('position dialog provides precise accessible placement', (
    tester,
  ) async {
    viewport(tester, const Size(1040, 800));
    var layout = HomeLayout(columns: 12, tiles: [_tile]);
    await grid(tester, layout, (value) => layout = value);
    await tester.tap(find.byTooltip('Edit unavailable'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Position & size'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.enterText(
        find.byType(TextField).at(i),
        ['4', '3', '5', '6'][i],
      );
    }
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(layout.tiles.single.x, 3);
    expect(layout.tiles.single.y, 2);
    expect(layout.tiles.single.w, 5);
    expect(layout.tiles.single.h, 6);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone and narrow desktop grids contain large text', (
    tester,
  ) async {
    viewport(tester, const Size(320, 720));
    for (final columns in [4, 12]) {
      await grid(
        tester,
        HomeLayout(columns: columns, tiles: [_tile]),
        (_) {},
        textScale: 1.5,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('cancel keeps saved tiles and save persists the edited layout', (
    tester,
  ) async {
    viewport(tester, const Size(1040, 800));
    late Directory directory;
    late HomeRepository repo;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('luma_home_editor_');
      repo = HomeRepository(
        family: 'desktop',
        file: () async => File('${directory.path}/home.json'),
      );
      await repo.ready;
      await repo.save(HomeLayout(columns: 12, tiles: [_tile]));
    });
    addTearDown(() async {
      repo.dispose();
      await directory.delete(recursive: true);
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.light,
        home: HomeScope(
          repository: repo,
          child: Scaffold(
            body: HomePage(onNavigate: (_) {}, startEditing: true),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await repo.ready;
    });
    await tester.pumpAndSettle();
    Future<void> removeTile() async {
      await tester.tap(find.byTooltip('Edit unavailable'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove tile'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Reset to original dashboard'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('income')), findsOneWidget);
    expect(repo.layout.tiles, hasLength(1));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('first')), findsOneWidget);
    await tester.tap(find.byTooltip('Edit home'));
    await tester.pumpAndSettle();
    await removeTile();
    expect(find.byKey(const ValueKey('first')), findsNothing);
    expect(find.byKey(const ValueKey('home-greeting')), findsOneWidget);
    expect(repo.layout.tiles, hasLength(1));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('first')), findsOneWidget);
    await tester.tap(find.byTooltip('Edit home'));
    await tester.pumpAndSettle();
    await removeTile();
    await tester.runAsync(() async {
      final saved = Completer<void>();
      void observeSave() {
        if (repo.layout.tiles.isEmpty && !saved.isCompleted) saved.complete();
      }

      repo.addListener(observeSave);
      await tester.tap(find.text('Save layout'));
      await saved.future;
      repo.removeListener(observeSave);
    });
    await tester.pumpAndSettle();
    expect(repo.layout.tiles, isEmpty);
    await tester.runAsync(() async {
      final restored = HomeRepository(
        family: 'desktop',
        file: () async => File('${directory.path}/home.json'),
      );
      await restored.ready;
      expect(restored.layout.tiles, isEmpty);
      restored.dispose();
    });
    expect(tester.takeException(), isNull);
  });
}
