import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark_repository.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark_scope.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/tts_results.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/tts_test_page.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/theme/luma_theme.dart';

const _poem = 'The Lamplighter\'s Hour.';

TtsBoard _board() => TtsBoard.fromJson({
      'scripts': 'abcd1234',
      'tests': [
        {'id': 'station_announcement', 'voice': 'female', 'text': 'Platform four.'},
        {'id': 'poem_female', 'voice': 'female', 'text': _poem},
        {'id': 'poem_male', 'voice': 'male', 'text': _poem},
        {'id': 'speech_male', 'voice': 'male', 'text': 'Friends.'},
        {'no': 'text'},
      ],
      'models': [
        {
          'runId': 'r1',
          'model': 'elevenlabs/eleven-v3',
          'femaleVoice': 'sarah',
          'maleVoice': 'george',
          'costUsd': 0.0123,
          'totalMs': 8400,
          'clips': [
            {
              'test': 'station_announcement',
              'voice': 'sarah',
              'ok': true,
              'format': 'mp3',
              'ms': 2100,
              'seconds': 18.4,
              'costUsd': 0.004,
            },
            {'test': 'poem_male', 'voice': 'george', 'ok': false, 'ms': 300},
          ],
        },
        {'model': 'no-run-id'},
      ],
      'hidden': {'otherScripts': 2},
    });

Widget _app(Widget home) => AiBenchmarkScope(
      repository: AiBenchmarkRepository.withManifest(AiBenchmarkManifest.empty),
      child: MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        theme: LumaTheme.dark,
        home: home,
      ),
    );

void main() {
  test('parses the board and skips malformed entries', () {
    final board = _board();
    expect(board.scripts.map((s) => s.id), [
      'station_announcement',
      'poem_female',
      'poem_male',
      'speech_male',
    ]);
    expect(board.otherScripts, 2);
    final e = board.entries.single;
    expect(e.vendor, 'elevenlabs');
    expect(e.shortName, 'eleven-v3');
    expect(e.clip('station_announcement')!.ok, isTrue);
    expect(e.clip('poem_male')!.ok, isFalse);
    expect(e.clip('speech_male'), isNull);
  });

  test('money and seconds read like the dashboard', () {
    expect(ttsMoney(0), r'$0');
    expect(ttsMoney(0.0123), r'$0.012');
    expect(ttsMoney(0.0004), r'$0.00040');
    expect(ttsSeconds(8.42), '8.4 s');
  });

  testWidgets('the model page lists all four scripts with cost and time',
      (tester) async {
    final board = _board();
    await tester.pumpWidget(
        _app(TtsModelPage(board: board, entry: board.entries.single)));
    await tester.pumpAndSettle();

    expect(find.text('Train station announcement'), findsOneWidget);
    expect(find.text('Poem reading (woman)'), findsOneWidget);
    expect(find.text('Poem reading (man)'), findsOneWidget);
    expect(find.text('Speech (man)'), findsOneWidget);
    expect(
        find.text(r'Voice: sarah · $0.0040 · made in 2.1 s · plays 18.4 s'),
        findsOneWidget);
    expect(find.text('This model could not read this script.'),
        findsNWidgets(3));

    await tester.tap(find.text('Show text').first);
    await tester.pump();
    expect(find.text('Platform four.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
