import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/app/top_bar.dart';
import 'package:luma/features/converter/converter_page.dart';
import 'package:luma/theme/luma_theme.dart';

void main() {
  testWidgets('converter hub lists the four tools in the dark lavender palette',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.light,
        darkTheme: LumaTheme.dark,
        themeMode: ThemeMode.dark,
        home: const Scaffold(body: ConverterPage()),
      ),
    );

    expect(find.text('Picture converter'), findsOneWidget);
    expect(find.text('Audio converter'), findsOneWidget);
    expect(find.text('Video converter'), findsOneWidget);
    expect(find.text('Image downscaler'), findsOneWidget);
    expect(find.text('Video downscaler'), findsOneWidget);

    final context = tester.element(find.byType(ConverterPage));
    expect(context.luma.background, LumaPalette.dark.background);
  });

  testWidgets('opening a tool from the hub shows its screen and back works',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.dark,
        home: const Scaffold(body: ConverterPage()),
      ),
    );

    await tester.tap(find.text('Picture converter'));
    await tester.pumpAndSettle();

    // The picture tool screen is now showing its upload prompt.
    expect(find.text('Click to choose an image'), findsOneWidget);

    // Back returns to the hub.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Pick a tool to get started.'), findsOneWidget);
  });

  testWidgets('top bar renders the active section title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.dark,
        home: const Scaffold(body: TopBar(title: 'File Converter')),
      ),
    );

    expect(find.text('File Converter'), findsOneWidget);
  });
}
