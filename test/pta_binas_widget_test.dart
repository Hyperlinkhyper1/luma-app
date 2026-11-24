import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/school/ui/pta/pta_binas_sheet.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/theme/luma_theme.dart';

void main() {
  for (final (label, size) in [
    ('desktop', const Size(1200, 900)),
    ('phone', const Size(360, 740)),
  ]) {
    testWidgets('Binas navigation and formula search on $label', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: LumaTheme.dark,
          locale: const Locale('nl'),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showPtaBinas(context),
                child: const Text('Open Binas'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open Binas'));
      await tester.pumpAndSettle();

      if (label == 'phone') {
        final horizontal = find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.right,
        );
        final position = tester.state<ScrollableState>(horizontal).position;
        await tester.drag(find.text('OH⁻'), const Offset(-180, 0));
        await tester.pumpAndSettle();
        expect(position.pixels, greaterThan(0));
      }

      final search = find.byType(TextField);
      await tester.enterText(search, 'SO4');
      await tester.pumpAndSettle();
      expect(find.text('SO₄²⁻'), findsOneWidget);
      expect(find.text('Cl⁻'), findsNothing);
      expect(find.text('Ba²⁺'), findsOneWidget);
      await tester.enterText(search, 'Ca2+ SO42-');
      await tester.pumpAndSettle();
      expect(find.text('Ca²⁺'), findsOneWidget);
      expect(find.text('SO₄²⁻'), findsOneWidget);
      expect(find.text('Ba²⁺'), findsNothing);

      if (label == 'phone') {
        await tester.tap(find.text('45A · Oplosbaarheid'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('65A · Vlamkleuren').last);
      } else {
        await tester.tap(find.text('65A'));
      }
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller!.text, isEmpty);
      expect(find.text('K⁺'), findsOneWidget);

      await tester.enterText(search, 'Na+');
      await tester.pumpAndSettle();
      expect(find.text('Na⁺'), findsOneWidget);
      expect(find.text('K⁺'), findsNothing);
      await tester.enterText(search, 'geen treffers');
      await tester.pumpAndSettle();
      expect(find.text('Geen resultaten'), findsOneWidget);
      await tester.tap(find.byTooltip('Wissen'));
      await tester.pumpAndSettle();
      expect(find.text('K⁺'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
