import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/decider_results.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/decider_test_page.dart';

DeciderBoard _board() => DeciderBoard.fromJson({
      'cases': 57,
      'chance': 17.7,
      'models': [
        {
          'model': 'perplexity/pplx-decider-flash-v1.2',
          'provider': 'openrouter',
          'accuracy': 35.9,
          'meanPTrue': 31.0,
          'costUsd': 0.0007,
          'costPer1k': 0.012,
          'bySkill': {
            'dates': {'n': 16, 'score': 25.0},
          },
        },
        {
          'model': 'perplexity/pplx-decider-v1.2',
          'provider': 'openrouter',
          'accuracy': 47.4,
          'meanPTrue': 40.0,
          'costPer1k': 0.024,
        },
        {
          'model': 'cloudflare/clef-omni',
          'provider': 'openrouter',
          'accuracy': 30.0,
          'costPer1k': 0.18,
        },
        {
          'model': 'inception/mercury-decide:free',
          'provider': 'openrouter',
          'accuracy': 20.0,
          'costPer1k': 0,
        },
        {
          'model': 'pplx-decider-flash-v1.2',
          'provider': 'perplexity',
          'accuracy': 36.0,
          'costPer1k': 0.012,
        },
        {'no': 'model'},
      ],
    });

void main() {
  test('parses the board best first and skips malformed entries', () {
    final board = _board();
    expect(board.cases, 57);
    expect(board.chance, 17.7);
    expect(board.entries.map((e) => e.accuracy),
        [47.4, 36.0, 35.9, 30.0, 20.0]);
    final flash = board.entries
        .firstWhere((e) => e.model == 'perplexity/pplx-decider-flash-v1.2');
    expect(flash.bySkill, {'dates': 25.0});
    expect(flash.vendor, 'perplexity');
    expect(flash.shortName, 'pplx-decider-flash-v1.2');
  });

  test('a direct Perplexity run counts as Perplexity', () {
    final direct = _board().entries.firstWhere((e) => e.direct);
    expect(direct.vendor, 'perplexity');
    expect(direct.shortName, 'pplx-decider-flash-v1.2');
  });

  test('the frontier keeps only models nothing beats on cost and accuracy',
      () {
    expect(_board().frontier.map((e) => e.accuracy), [20.0, 36.0, 47.4]);
  });

  test('companies get their logo colour, others a steady one', () {
    expect(deciderVendorColor('cloudflare'), const Color(0xFFF38020));
    expect(deciderVendorColor('typesafe'), deciderVendorColor('typesafe'));
    expect(deciderVendorColor('typesafe'),
        isNot(deciderVendorColor('respan')));
  });

  test('money reads like the dashboard', () {
    expect(deciderMoney(0), r'$0');
    expect(deciderMoney(1.5), r'$1.50');
    expect(deciderMoney(0.024), r'$0.024');
    expect(deciderMoney(0.0012), r'$0.0012');
  });

  testWidgets('the chart paints a board without throwing', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 700,
          height: 340,
          child: CustomPaint(
            painter: DeciderChartPainter(
              board: _board(),
              text: Colors.grey,
              label: Colors.white,
              grid: Colors.black26,
              accent: Colors.purple,
              danger: Colors.red,
              warning: Colors.amber,
              axisLabel: 'Cost per 1,000 cases',
              guessingLabel: 'guessing 17.7%',
              ceilingLabel: '50% ceiling',
              freeLabel: 'free',
            ),
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
  });
}
