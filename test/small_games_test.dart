import 'dart:math';

import 'package:image/image.dart' as img;

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/small_games/bingo_card.dart';
import 'package:luma/features/plugins/installed/small_games/bingo_card_export.dart';

void main() {
  test('draw calls every ball once and reset starts a fresh game', () {
    final draw = BingoDraw(Random(1));
    final called = List.generate(75, (_) => draw.draw());
    expect(called.toSet(), hasLength(75));
    expect(called.every((number) => number! >= 1 && number <= 75), isTrue);
    expect(draw.draw(), isNull);
    expect(draw.remaining, 0);
    draw.reset();
    expect(draw.called, isEmpty);
    expect(draw.remaining, 75);
  });

  test('cards use column ranges, a free center, and unique layouts', () {
    final cards = BingoCard.generateMany(200, Random(42));
    expect(cards.map((card) => card.signature).toSet(), hasLength(200));
    for (final card in cards) {
      for (var column = 0; column < 5; column++) {
        final values = card.columns[column].whereType<int>().toList();
        expect(values.toSet(), hasLength(column == 2 ? 4 : 5));
        expect(
          values.every(
            (value) => value >= column * 15 + 1 && value <= (column + 1) * 15,
          ),
          isTrue,
        );
      }
      expect(card.columns[2][2], isNull);
    }
  });

  test('card count has a practical export bound', () {
    expect(() => BingoCard.generateMany(0, Random(1)), throwsRangeError);
    expect(() => BingoCard.generateMany(501, Random(1)), throwsRangeError);
  });

  test('card renderer produces a full-size PNG', () async {
    final card = BingoCard.generate(Random(7));
    final bytes = await BingoCardExport.render(card, 1);
    final png = img.decodePng(bytes);
    expect(png, isNotNull);
    expect(png!.width, 900);
    expect(png.height, 1060);
  });
}
