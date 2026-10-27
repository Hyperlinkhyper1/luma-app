import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/chat/assistant_compose_mode.dart';
import 'package:luma/features/chat/assistant_file_policy.dart';
import 'package:luma/features/chat/widgets/compose_mode_menu.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/theme/luma_theme.dart';

Widget _host({
  bool filesAllowed = true,
  bool picture = false,
  int? picturePercent,
  String? artifactType,
  Alignment alignment = Alignment.topLeft,
  AssistantComposeMode mode = AssistantComposeMode.chat,
  ValueChanged<AssistantComposeMode>? onChanged,
  ValueChanged<String?>? onArtifactTypeChanged,
}) => MaterialApp(
  theme: LumaTheme.dark,
  localizationsDelegates: L.localizationsDelegates,
  supportedLocales: L.supportedLocales,
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: alignment,
        child: ComposeModeButton(
          mode: mode,
          onChanged: onChanged ?? (_) {},
          availability: () async => ComposeModeAvailability(
            research: false,
            picture: picture,
            picturePercent: picturePercent,
          ),
          filesAllowed: filesAllowed,
          modesAllowed: false,
          artifactType: artifactType,
          onArtifactTypeChanged: onArtifactTypeChanged,
          onUpload: () {},
        ),
      ),
    ),
  ),
);

Finder _menuItem(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(MenuItemButton));

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.add_rounded));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'hover shows every artifact beside its parent and allows selection',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final modes = <AssistantComposeMode>[];
      final artifacts = <String?>[];
      await tester.pumpWidget(
        _host(
          mode: AssistantComposeMode.plan,
          onChanged: modes.add,
          onArtifactTypeChanged: artifacts.add,
        ),
      );
      await _openMenu(tester);
      expect(find.text('CSV spreadsheet (.csv)'), findsNothing);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(1200, 700));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Artifact generation')));
      await tester.pumpAndSettle();

      for (final type in assistantArtifactTypes.entries) {
        expect(find.text('${type.value} (.${type.key})'), findsOneWidget);
      }
      expect(find.text('Picture unavailable'), findsOneWidget);
      expect(find.text('Upload files'), findsOneWidget);
      final parent = tester.getRect(find.byType(SubmenuButton));
      expect(
        tester.getTopLeft(_menuItem('Plain text (.txt)')).dx,
        greaterThanOrEqualTo(parent.right),
      );
      final csv = _menuItem('CSV spreadsheet (.csv)');
      await mouse.moveTo(Offset(parent.right + 2, parent.center.dy));
      await tester.pump();
      await mouse.moveTo(tester.getCenter(csv));
      await tester.pumpAndSettle();
      expect(find.text('Artifact generation'), findsOneWidget);
      expect(csv, findsOneWidget);
      await tester.tap(csv);
      await tester.pumpAndSettle();
      expect(modes, [AssistantComposeMode.chat]);
      expect(artifacts, ['csv']);
      expect(find.text('Artifact generation'), findsNothing);
      expect(find.text('CSV spreadsheet (.csv)'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Free sees only the picture choice under artifacts', (
    tester,
  ) async {
    final modes = <AssistantComposeMode>[];
    final artifacts = <String?>[];
    await tester.pumpWidget(
      _host(
        filesAllowed: false,
        picture: true,
        picturePercent: 10,
        onChanged: modes.add,
        onArtifactTypeChanged: artifacts.add,
      ),
    );
    await _openMenu(tester);
    expect(find.text('Requires Orbit or Nova'), findsOneWidget);
    expect(find.text('Pictures only · files need Orbit or Nova'), findsOneWidget);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(700, 500));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('Artifact generation')));
    await tester.pumpAndSettle();
    for (final type in assistantArtifactTypes.entries) {
      expect(find.text('${type.value} (.${type.key})'), findsNothing);
    }
    await tester.tap(find.text('Picture · 10% weekly usage'));
    await tester.pumpAndSettle();
    expect(modes, [AssistantComposeMode.picture]);
    expect(artifacts, [null]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('available Picture selects picture mode and clears artifact', (
    tester,
  ) async {
    final modes = <AssistantComposeMode>[];
    final artifacts = <String?>[];
    await tester.pumpWidget(
      _host(
        picture: true,
        picturePercent: 5,
        artifactType: 'csv',
        onChanged: modes.add,
        onArtifactTypeChanged: artifacts.add,
      ),
    );
    await _openMenu(tester);
    await tester.tap(find.text('Artifact generation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Picture · 5% weekly usage'));
    await tester.pumpAndSettle();
    expect(modes, [AssistantComposeMode.picture]);
    expect(artifacts, [null]);
    expect(find.text('Artifact generation'), findsNothing);
    expect(find.text('Picture · 5% weekly usage'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final available in [
    const ComposeModeAvailability(
      research: false,
      picture: false,
      picturePercent: 5,
    ),
    const ComposeModeAvailability(research: false, picture: true),
  ]) {
    testWidgets(
      'Picture is disabled with picture=${available.picture} and cost=${available.picturePercent}',
      (tester) async {
        final modes = <AssistantComposeMode>[];
        final artifacts = <String?>[];
        await tester.pumpWidget(
          _host(
            picture: available.picture,
            picturePercent: available.picturePercent,
            onChanged: modes.add,
            onArtifactTypeChanged: artifacts.add,
          ),
        );
        await _openMenu(tester);
        await tester.tap(find.text('Artifact generation'));
        await tester.pumpAndSettle();
        final label = available.picturePercent == null
            ? 'Picture unavailable'
            : 'Picture · ${available.picturePercent}% weekly usage';
        expect(
          tester.widget<MenuItemButton>(_menuItem(label)).onPressed,
          isNull,
        );
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(modes, isEmpty);
        expect(artifacts, isEmpty);
        expect(find.text('Artifact generation'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('outside tap and Escape dismiss menus and allow reopening', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await _openMenu(tester);
    await tester.tap(find.text('Artifact generation'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(780, 580));
    await tester.pumpAndSettle();
    expect(find.text('Artifact generation'), findsNothing);
    expect(find.text('CSV spreadsheet (.csv)'), findsNothing);

    await _openMenu(tester);
    await tester.tap(find.text('Artifact generation'));
    await tester.pumpAndSettle();
    expect(find.text('CSV spreadsheet (.csv)'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('CSV spreadsheet (.csv)'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Artifact generation'), findsNothing);

    await _openMenu(tester);
    expect(find.text('Artifact generation'), findsOneWidget);
    await tester.tap(find.text('Artifact generation'));
    await tester.pumpAndSettle();
    expect(find.text('CSV spreadsheet (.csv)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320px bottom composer supports touch artifact selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final artifacts = <String?>[];
    await tester.pumpWidget(
      _host(
        alignment: Alignment.bottomLeft,
        onArtifactTypeChanged: artifacts.add,
      ),
    );
    final plus = tester.getRect(find.byIcon(Icons.add_rounded));
    await _openMenu(tester);
    final artifact = find.text('Artifact generation');
    expect(artifact.hitTestable(), findsOneWidget);
    expect(tester.getCenter(artifact).dy, lessThan(plus.top));
    await tester.tap(artifact);
    await tester.pumpAndSettle();
    final csv = find.text('CSV spreadsheet (.csv)');
    expect(csv.hitTestable(), findsOneWidget);
    for (final type in assistantArtifactTypes.entries) {
      final label = find.text('${type.value} (.${type.key})');
      expect(label.hitTestable(), findsOneWidget);
      final labelRect = tester.getRect(label);
      expect(labelRect.left, greaterThanOrEqualTo(0));
      expect(labelRect.right, lessThanOrEqualTo(320));
    }
    final rect = tester.getRect(_menuItem('CSV spreadsheet (.csv)'));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(320));
    await tester.tap(csv);
    await tester.pumpAndSettle();
    expect(artifacts, ['csv']);
    expect(find.text('Artifact generation'), findsNothing);
    expect(csv, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
