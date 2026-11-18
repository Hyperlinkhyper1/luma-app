import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/chat/assistant_greeting.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/l10n/app_localizations_en.dart';

void main() {
  test('greeting period follows the hour', () {
    GreetingPeriod at(int h) => greetingPeriodFor(DateTime(2026, 1, 1, h));
    expect(at(0), GreetingPeriod.night);
    expect(at(4), GreetingPeriod.night);
    expect(at(5), GreetingPeriod.morning);
    expect(at(11), GreetingPeriod.morning);
    expect(at(12), GreetingPeriod.afternoon);
    expect(at(17), GreetingPeriod.afternoon);
    expect(at(18), GreetingPeriod.evening);
    expect(at(23), GreetingPeriod.evening);
  });

  test('every line carries the name only when there is one', () {
    final t = LEn();
    for (final period in GreetingPeriod.values) {
      for (final line in assistantGreetings(t, period, 'Sam')) {
        expect(line, contains('Sam'));
      }
      for (final line in assistantGreetings(t, period, null)) {
        expect(line, isNot(contains('{name}')));
      }
    }
    expect(
      assistantGreetings(t, GreetingPeriod.evening, null),
      isNot(contains(t.assistantGreetingMorning)),
    );
  });

  testWidgets('a page left open moves on to the evening greeting', (
    tester,
  ) async {
    var now = DateTime(2026, 1, 1, 9);
    final t = LEn();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: AssistantGreeting(
          name: 'Sam',
          clock: () => now,
          random: math.Random(1),
        ),
      ),
    );
    final morning = assistantGreetings(t, GreetingPeriod.morning, 'Sam');
    expect(morning, contains(tester.widget<Text>(find.byType(Text)).data));

    now = DateTime(2026, 1, 1, 20);
    await tester.pump(const Duration(minutes: 1));
    final evening = assistantGreetings(t, GreetingPeriod.evening, 'Sam');
    expect(evening, contains(tester.widget<Text>(find.byType(Text)).data));
  });
}
