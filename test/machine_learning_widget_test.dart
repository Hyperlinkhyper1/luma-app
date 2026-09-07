import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/machine_learning/machine_learning_page.dart';
import 'package:luma/theme/luma_theme.dart';

Widget _host() => MaterialApp(
      theme: LumaTheme.dark,
      home: const Scaffold(body: MachineLearningPage()),
    );

void main() {
  testWidgets('the lab opens on an empty board, with nothing running yet',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.text('Machine Learning'), findsOneWidget);
    expect(find.text('Draw your creature'), findsOneWidget);
    expect(find.text('Draw a body here'), findsOneWidget);
    expect(find.text('Nothing to walk yet'), findsOneWidget);
    expect(find.text('Every generation will leave a mark here.'), findsOneWidget);
  });

  testWidgets('the how it works tab explains the pipeline', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    await tester.tap(find.text('How it works'));
    await tester.pump();

    expect(find.text('Your drawing becomes a body'), findsOneWidget);
    expect(find.text('The bones get motors'), findsOneWidget);
  });
}
