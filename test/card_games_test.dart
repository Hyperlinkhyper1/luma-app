import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/small_games/card_games_logic.dart';

void main() {
  PlayingCard card(CardSuit suit, int rank) => PlayingCard(suit, rank);

  test('blackjack scores soft aces and busts correctly', () {
    expect(
      blackjackTotal([card(CardSuit.spades, 1), card(CardSuit.hearts, 9)]),
      20,
    );
    expect(
      blackjackTotal([
        card(CardSuit.spades, 1),
        card(CardSuit.hearts, 9),
        card(CardSuit.clubs, 5),
      ]),
      15,
    );
    final game = BlackjackGame(random: Random(3));
    while (!game.finished) {
      game.hit();
    }
    expect(game.playerTotal > 21 || game.playerTotal == 21, isTrue);
    expect(game.result, isNotEmpty);
  });

  test('poker compares hand categories and wheel straights', () {
    final wheel = evaluatePokerHand([
      card(CardSuit.spades, 1),
      card(CardSuit.hearts, 2),
      card(CardSuit.clubs, 3),
      card(CardSuit.diamonds, 4),
      card(CardSuit.spades, 5),
    ]);
    final flush = evaluatePokerHand([
      card(CardSuit.hearts, 2),
      card(CardSuit.hearts, 4),
      card(CardSuit.hearts, 6),
      card(CardSuit.hearts, 8),
      card(CardSuit.hearts, 11),
    ]);
    expect(wheel.label, 'Straight');
    expect(flush.compareTo(wheel), greaterThan(0));
    final game = PokerGame(random: Random(4));
    game.toggleHeld(0);
    final heldCard = game.player[0];
    game.draw();
    expect(identical(game.player[0], heldCard), isTrue);
    expect(game.finished, isTrue);
    expect(game.result, isNotEmpty);
  });

  test('patience deals a full unique deck and moves aces to foundations', () {
    final game = PatienceGame(random: Random(5));
    expect(game.tableau.map((pile) => pile.length).toList(), [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
    ]);
    expect(game.stock.length, 24);
    final all = [
      ...game.stock,
      for (final pile in game.tableau) ...pile.map((entry) => entry.card),
    ];
    expect(all.map((card) => card.toString()).toSet().length, 52);

    game.waste.add(card(CardSuit.spades, 1));
    game.selectWaste();
    expect(game.moveToFoundation(0), isTrue);
    expect(game.foundations[0].single.toString(), 'A♠');
    expect(game.moveToFoundation(1), isFalse);
  });
}
