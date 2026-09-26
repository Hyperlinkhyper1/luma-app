import 'dart:math';

/// A standard 75-ball BINGO card. Each column draws from its own 15 numbers.
class BingoCard {
  BingoCard(this.columns);

  final List<List<int?>> columns;

  String get signature => columns.expand((column) => column).join(',');

  static BingoCard generate(Random random) {
    return BingoCard(
      List.generate(5, (column) {
        final numbers = List.generate(15, (index) => column * 15 + index + 1)
          ..shuffle(random);
        return List.generate(
          5,
          (row) => column == 2 && row == 2 ? null : numbers[row],
        );
      }),
    );
  }

  static List<BingoCard> generateMany(int count, Random random) {
    if (count < 1 || count > 500) {
      throw RangeError.range(count, 1, 500, 'count');
    }
    final signatures = <String>{};
    final cards = <BingoCard>[];
    while (cards.length < count) {
      final card = generate(random);
      if (signatures.add(card.signature)) cards.add(card);
    }
    return cards;
  }
}

/// Draws all 75 balls without repeating one during the current game.
class BingoDraw {
  BingoDraw(this._random);

  final Random _random;
  final List<int> _called = [];
  final List<int> _remaining = List.generate(75, (index) => index + 1);

  List<int> get called => List.unmodifiable(_called);
  int get remaining => _remaining.length;
  int? get latest => _called.isEmpty ? null : _called.last;

  int? draw() {
    if (_remaining.isEmpty) return null;
    final ball = _remaining.removeAt(_random.nextInt(_remaining.length));
    _called.add(ball);
    return ball;
  }

  void reset() {
    _called.clear();
    _remaining
      ..clear()
      ..addAll(List.generate(75, (index) => index + 1));
  }
}
