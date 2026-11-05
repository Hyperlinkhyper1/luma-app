import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/map_maker/city_map_editor_view.dart';
import 'package:luma/features/plugins/installed/map_maker/city_map_models.dart';
import 'package:luma/features/plugins/installed/map_maker/city_map_overlays.dart';
import 'package:luma/features/plugins/installed/map_maker/city_map_painter.dart';
import 'package:luma/features/plugins/installed/map_maker/map_maker_models.dart';
import 'package:luma/features/plugins/installed/map_maker/map_maker_page.dart';
import 'package:luma/features/plugins/installed/map_maker/map_maker_store.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/theme/luma_theme.dart';

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
  theme: LumaTheme.dark,
  locale: locale,
  localizationsDelegates: L.localizationsDelegates,
  supportedLocales: L.supportedLocales,
  home: home,
);

CityMapPainter _mapPaint(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(find.byKey(const ValueKey('city-canvas')))
            .painter!
        as CityMapPainter;

Offset _worldToScreen(WidgetTester tester, Offset world) {
  final canvas = tester.renderObject<RenderBox>(
    find.byKey(const ValueKey('city-canvas')),
  );
  return canvas.localToGlobal(
    MatrixUtils.transformPoint(_mapPaint(tester).worldTransform!, world),
  );
}

void main() {
  testWidgets(
    'compact landscape menus expose scrollable layers and properties',
    (tester) async {
      tester.view.physicalSize = const Size(640, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = MapMakerStore.memory();
      final save = await store.createCity();
      await tester.pumpWidget(
        _app(CityMapEditorView(save: save, store: store, onBack: () {})),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('city-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('city-more-layers')));
      await tester.pumpAndSettle();
      final grid = find.byKey(const ValueKey('city-layer-grid'));
      await tester.ensureVisible(grid);
      await tester.tap(grid);
      await tester.pump();
      expect(_mapPaint(tester).showGrid, isFalse);
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('city-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('city-more-properties')));
      await tester.pumpAndSettle();
      expect(find.text('Plan overview'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await store.flush();
      store.dispose();
    },
  );

  testWidgets(
    'canvas fills the viewport and supports building after distant panning',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = MapMakerStore.memory();
      final save = await store.createCity();
      await tester.pumpWidget(
        _app(CityMapEditorView(save: save, store: store, onBack: () {})),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('city-pan')));
      await tester.dragFrom(const Offset(600, 400), const Offset(8000, 6000));
      await tester.pump();
      expect(_mapPaint(tester).visibleWorldBounds!.right, lessThan(-3200));
      expect(_mapPaint(tester).visibleWorldBounds!.bottom, lessThan(-2400));
      final canvasSize = tester.getSize(
        find.byKey(const ValueKey('city-canvas')),
      );
      expect(
        canvasSize,
        tester.getSize(find.byKey(const ValueKey('city-viewport'))),
      );
      expect(canvasSize.width, 880);
      await tester.tap(find.byKey(const ValueKey('city-frontage')));
      await tester.tap(find.byKey(const ValueKey('city-building-house')));
      await tester.tapAt(const Offset(600, 400));
      await tester.pump();
      expect(save.city.buildings.single.x, lessThan(-3200));
      expect(save.city.buildings.single.y, lessThan(-2400));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await store.flush();
      store.dispose();
    },
  );

  testWidgets(
    'wheel zoom stays anchored and the city can fit distant features',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = MapMakerStore.memory();
      final save = await store.createCity();
      save.city.buildings.addAll([
        CityBuilding(
          id: 'west',
          kind: CityBuildingKind.house,
          x: -1000000,
          y: -500000,
        ),
        CityBuilding(
          id: 'east',
          kind: CityBuildingKind.house,
          x: 1000000,
          y: 500000,
        ),
      ]);
      await tester.pumpWidget(
        _app(CityMapEditorView(save: save, store: store, onBack: () {})),
      );
      await tester.pumpAndSettle();
      final initial = _mapPaint(tester);
      expect(
        initial.visibleWorldBounds!.contains(const Offset(-1000000, -500000)),
        isTrue,
      );
      expect(
        initial.visibleWorldBounds!.contains(const Offset(1000000, 500000)),
        isTrue,
      );
      expect(find.byKey(const ValueKey('city-navigator')), findsOneWidget);
      final canvas = tester.renderObject<RenderBox>(
        find.byKey(const ValueKey('city-canvas')),
      );
      const local = Offset(280, 260);
      final anchor = MatrixUtils.transformPoint(
        Matrix4.inverted(initial.worldTransform!),
        local,
      );
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: canvas.localToGlobal(local),
          scrollDelta: const Offset(0, -120),
        ),
      );
      await tester.pump();
      final zoomed = _mapPaint(tester);
      expect(zoomed.viewScale, greaterThan(initial.viewScale));
      expect(
        (MatrixUtils.transformPoint(
                  Matrix4.inverted(zoomed.worldTransform!),
                  local,
                ) -
                anchor)
            .distance,
        lessThan(.00001),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await store.flush();
      store.dispose();
    },
  );

  testWidgets(
    'duplicate shortcut and measurement preserve undo and map geometry',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = MapMakerStore.memory();
      final save = await store.createCity();
      save.city.buildings.add(
        CityBuilding(
          id: 'source',
          kind: CityBuildingKind.house,
          x: -6000,
          y: -8000,
        ),
      );
      await tester.pumpWidget(
        _app(CityMapEditorView(save: save, store: store, onBack: () {})),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(_worldToScreen(tester, const Offset(-6000, -8000)));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(save.city.buildings, hasLength(2));
      await tester.tap(find.byKey(const ValueKey('city-undo')));
      await tester.pump();
      expect(save.city.buildings.single.id, 'source');
      await tester.tapAt(const Offset(600, 400));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.pump();
      await tester.tapAt(const Offset(500, 420));
      await tester.tapAt(const Offset(700, 420));
      await tester.pump();
      final paint = tester.widget<CustomPaint>(
        find.byKey(const ValueKey('city-canvas')),
      );
      final measure = paint.foregroundPainter! as CityMeasurePainter;
      expect((measure.start - measure.end).distance, greaterThan(100));
      expect(measure.label, endsWith(' m'));
      expect(save.city.buildings, hasLength(1));
      expect(save.city.roads, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(
        tester
            .widget<CustomPaint>(find.byKey(const ValueKey('city-canvas')))
            .foregroundPainter,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await store.flush();
      store.dispose();
    },
  );

  testWidgets('pinch zoom and space panning leave features intact', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MapMakerStore.memory();
    final save = await store.createCity();
    save.city.buildings.add(
      CityBuilding(id: 'source', kind: CityBuildingKind.house, x: 0, y: 0),
    );
    await tester.pumpWidget(
      _app(CityMapEditorView(save: save, store: store, onBack: () {})),
    );
    await tester.pumpAndSettle();
    final originalScale = _mapPaint(tester).viewScale;
    final first = await tester.startGesture(const Offset(500, 350), pointer: 1);
    final second = await tester.startGesture(
      const Offset(700, 350),
      pointer: 2,
    );
    await first.moveBy(const Offset(-60, 0));
    await second.moveBy(const Offset(60, 0));
    await tester.pump();
    await first.up();
    await second.up();
    expect(_mapPaint(tester).viewScale, greaterThan(originalScale));
    final originalBounds = _mapPaint(tester).visibleWorldBounds!;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.dragFrom(const Offset(600, 400), const Offset(160, 80));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(
      _mapPaint(tester).visibleWorldBounds!.left,
      lessThan(originalBounds.left),
    );
    expect(save.city.buildings.single.position, Offset.zero);
    final beforeMiddle = _mapPaint(tester).visibleWorldBounds!;
    final mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kMiddleMouseButton,
    );
    await mouse.down(const Offset(600, 400));
    await mouse.moveBy(const Offset(100, 50));
    await mouse.up();
    await tester.pump();
    expect(
      _mapPaint(tester).visibleWorldBounds!.left,
      lessThan(beforeMiddle.left),
    );
    expect(save.city.buildings.single.position, Offset.zero);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await store.flush();
    store.dispose();
  });

  testWidgets(
    'fit below full scale keeps zoom, snapping and scale feedback synchronized',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = MapMakerStore.memory();
      final save = await store.createCity();
      save.city.roads.add(
        CityRoad(
          id: 'wide',
          points: [const Offset(300, 1200), const Offset(2900, 1200)],
        ),
      );
      await tester.pumpWidget(
        _app(CityMapEditorView(save: save, store: store, onBack: () {})),
      );
      await tester.pumpAndSettle();
      final actualScale = _mapPaint(tester).worldTransform!.getMaxScaleOnAxis();
      final paint =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('city-canvas')),
                  )
                  .painter!
              as CityMapPainter;
      expect(actualScale, lessThan(1));
      expect(paint.viewScale, closeTo(actualScale, .0001));
      expect(find.text('${(actualScale * 100).round()}%'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('city-zoom-out')));
      await tester.pump();
      expect(
        _mapPaint(tester).worldTransform!.getMaxScaleOnAxis(),
        lessThan(actualScale),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await store.flush();
      store.dispose();
    },
  );

  testWidgets(
    'curves, snapped junctions, road access and properties work together',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = MapMakerStore.memory();
      final save = await store.createCity(title: 'Precision plan');
      await tester.pumpWidget(
        _app(CityMapEditorView(save: save, store: store, onBack: () {})),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('city-road-street')));
      await tester.tap(find.byKey(const ValueKey('city-curve')));
      await tester.pump();
      await tester.tapAt(const Offset(380, 420));
      await tester.tapAt(const Offset(620, 280));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('city-finish-road')),
            )
            .onPressed,
        isNull,
      );
      await tester.tapAt(const Offset(920, 420));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('city-finish-road')));
      await tester.pump();
      final curve = save.city.roads.single;
      expect(curve.curved, isTrue);
      expect(curve.centerline.length, greaterThan(3));
      await tester.tap(find.byKey(const ValueKey('city-building-house')));
      await tester.tapAt(const Offset(620, 380));
      await tester.pump();
      expect(save.city.buildings.single.roadId, curve.id);
      expect(save.city.buildings.single.roadAnchor, isNotNull);

      final endpoint = _worldToScreen(tester, curve.points.first);
      await tester.tap(find.byKey(const ValueKey('city-road-avenue')));
      await tester.tap(find.byKey(const ValueKey('city-straight')));
      await tester.tapAt(endpoint + const Offset(5, 2));
      await tester.tapAt(const Offset(380, 650));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('city-finish-road')));
      await tester.pump();
      expect(save.city.roads.last.points.first, curve.points.first);
      expect(
        save.city.junctions.any(
          (junction) => junction.roadIds.toSet().containsAll(
            save.city.roads.map((road) => road.id),
          ),
        ),
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('city-select')));
      await tester.tapAt(_worldToScreen(tester, curve.points[1]));
      await tester.pump();
      final name = find.byKey(ValueKey('city-feature-name-${curve.id}'));
      await tester.enterText(name, 'River Road');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(save.city.roads.first.name, 'River Road');
      await tester.enterText(name, 'Canal Road');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(save.city.roads.first.name, 'Canal Road');
      await tester.tap(find.byKey(const ValueKey('city-layer-roads')));
      await tester.pump();
      final paint =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('city-canvas')),
                  )
                  .painter!
              as CityMapPainter;
      expect(paint.showRoads, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await store.flush();
      store.dispose();
    },
  );

  testWidgets('unsubmitted feature names survive closing the editor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MapMakerStore.memory();
    final save = await store.createCity();
    final road = CityRoad(
      id: 'named',
      points: [const Offset(1400, 1200), const Offset(1800, 1200)],
    );
    save.city.roads.add(road);
    await tester.pumpWidget(
      _app(CityMapEditorView(save: save, store: store, onBack: () {})),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(_worldToScreen(tester, const Offset(1600, 1200)));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('city-feature-name-named')),
      'Saved on close',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(save.city.roads.single.name, 'Saved on close');
    expect(tester.takeException(), isNull);
    await store.flush();
    store.dispose();
  });

  testWidgets('city tile opens editor, edits survive leaving and reopening', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MapMakerStore.memory();
    await tester.pumpWidget(_app(MapMakerPage(store: store)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('City Planner'));
    await tester.pumpAndSettle();
    expect(find.byType(CityMapEditorView), findsOneWidget);
    expect(store.saves.single.kind, MapMakerKind.city);

    await tester.tap(find.byKey(const ValueKey('city-road-avenue')));
    await tester.tapAt(const Offset(480, 500));
    await tester.tapAt(const Offset(750, 500));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('city-finish-road')));
    await tester.pump();
    expect(store.saves.single.city.roads.single.kind, CityRoadKind.avenue);

    await tester.tap(find.byKey(const ValueKey('city-building-house')));
    await tester.tapAt(const Offset(550, 360));
    await tester.pump();
    expect(
      store.saves.single.city.buildings.single.kind,
      CityBuildingKind.house,
    );
    expect(
      store.saves.single.city.buildings.single.roadId,
      store.saves.single.city.roads.single.id,
    );

    await tester.tap(find.byKey(const ValueKey('city-back')));
    await tester.pumpAndSettle();
    expect(find.byType(CityMapEditorView), findsNothing);
    expect(find.textContaining('Transit Map •'), findsNothing);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(CityMapEditorView), findsOneWidget);
    expect(store.saves.single.city.buildings, hasLength(1));
    expect(store.saves.single.city.roads, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await store.flush();
    store.dispose();
  });

  testWidgets('compact Dutch editor places rotated pieces and finishes roads', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MapMakerStore.memory();
    final save = await store.createCity(title: 'Mijn stad');
    await tester.pumpWidget(
      _app(
        CityMapEditorView(save: save, store: store, onBack: () {}),
        locale: const Locale('nl'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Street'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('city-road-street')));
    await tester.pump();
    await tester.tapAt(const Offset(70, 350));
    await tester.tapAt(const Offset(270, 350));
    await tester.pump();
    final finish = find.byKey(const ValueKey('city-finish-road'));
    expect(finish.hitTestable(), findsOneWidget);
    await tester.tap(finish);
    await tester.pump();
    expect(save.city.roads, hasLength(1));
    final house = find.byKey(const ValueKey('city-building-house'));
    await tester.ensureVisible(house);
    await tester.tap(house);
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('city-frontage')));
    await tester.tap(find.byKey(const ValueKey('city-frontage')));
    await tester.ensureVisible(find.byKey(const ValueKey('city-rotate')));
    await tester.tap(find.byKey(const ValueKey('city-rotate')));
    await tester.tapAt(const Offset(180, 450));
    await tester.pump();
    expect(save.city.buildings.single.quarterTurns, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await store.flush();
    store.dispose();
  });

  testWidgets('zoomed buildings drag correctly and save commits a road draft', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MapMakerStore.memory();
    final save = await store.createCity();
    await tester.pumpWidget(
      _app(CityMapEditorView(save: save, store: store, onBack: () {})),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('city-frontage')));
    await tester.tap(find.byKey(const ValueKey('city-building-house')));
    await tester.tapAt(const Offset(550, 380));
    await tester.pump();
    final original = save.city.buildings.single.position;
    await tester.tap(find.byKey(const ValueKey('city-zoom-in')));
    await tester.tap(find.byKey(const ValueKey('city-select')));
    await tester.pump();
    await tester.dragFrom(
      _worldToScreen(tester, original),
      const Offset(96, 48),
    );
    await tester.pump();
    expect(save.city.buildings.single.position, isNot(original));
    await tester.tap(find.byKey(const ValueKey('city-undo')));
    await tester.pump();
    expect(save.city.buildings.single.position, original);
    await tester.tap(find.byKey(const ValueKey('city-redo')));
    await tester.pump();
    expect(save.city.buildings.single.position, isNot(original));
    await tester.tap(find.byKey(const ValueKey('city-road-highway')));
    await tester.tapAt(const Offset(450, 540));
    await tester.tapAt(const Offset(760, 540));
    await tester.pump();
    expect(save.city.roads, isEmpty);
    await tester.tap(find.byKey(const ValueKey('city-save')));
    await tester.pumpAndSettle();
    expect(save.city.roads.single.kind, CityRoadKind.highway);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await store.flush();
    store.dispose();
  });
}
