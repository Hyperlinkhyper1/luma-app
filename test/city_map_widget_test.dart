import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/map_maker/city_map_editor_view.dart';
import 'package:luma/features/plugins/installed/map_maker/city_map_models.dart';
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

void main() {
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

    await tester.tap(find.byKey(const ValueKey('city-building-house')));
    await tester.tapAt(const Offset(550, 360));
    await tester.pump();
    expect(
      store.saves.single.city.buildings.single.kind,
      CityBuildingKind.house,
    );

    await tester.tap(find.byKey(const ValueKey('city-road-avenue')));
    await tester.tapAt(const Offset(480, 500));
    await tester.tapAt(const Offset(750, 500));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('city-finish-road')));
    await tester.pump();
    expect(store.saves.single.city.roads.single.kind, CityRoadKind.avenue);

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
    await tester.tap(find.byKey(const ValueKey('city-building-house')));
    await tester.tapAt(const Offset(550, 380));
    await tester.pump();
    final original = save.city.buildings.single.position;
    await tester.tap(find.byKey(const ValueKey('city-zoom-in')));
    await tester.tap(find.byKey(const ValueKey('city-select')));
    await tester.pump();
    final canvas = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('city-canvas')),
    );
    await tester.dragFrom(canvas.localToGlobal(original), const Offset(96, 48));
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
