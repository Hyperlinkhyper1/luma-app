import 'dart:math';

import '../../../../l10n/current_l.dart';

enum CardSuit { clubs, diamonds, hearts, spades }

class PlayingCard {
  const PlayingCard(this.suit, this.rank);

  final CardSuit suit;
  final int rank;

  bool get isRed => suit == CardSuit.diamonds || suit == CardSuit.hearts;

  String get rankLabel => switch (rank) {
    1 => 'A',
    11 => 'J',
    12 => 'Q',
    13 => 'K',
    _ => '$rank',
  };

  String get suitLabel => switch (suit) {
    CardSuit.clubs => '♣',
    CardSuit.diamonds => '♦',
    CardSuit.hearts => '♥',
    CardSuit.spades => '♠',
  };

  @override
  String toString() => '$rankLabel$suitLabel';
}

List<PlayingCard> shuffledDeck([Random? random]) {
  final cards = [
    for (final suit in CardSuit.values)
      for (var rank = 1; rank <= 13; rank++) PlayingCard(suit, rank),
  ];
  cards.shuffle(random ?? Random());
  return cards;
}

int blackjackTotal(Iterable<PlayingCard> cards) {
  var total = 0;
  var aces = 0;
  for (final card in cards) {
    if (card.rank == 1) aces++;
    total += card.rank == 1 ? 11 : min(card.rank, 10);
  }
  while (total > 21 && aces > 0) {
    total -= 10;
    aces--;
  }
  return total;
}

class BlackjackGame {
  BlackjackGame({Random? random}) : _random = random ?? Random() {
    newRound();
  }

  final Random _random;
  late List<PlayingCard> _deck;
  final player = <PlayingCard>[];
  final dealer = <PlayingCard>[];
  bool finished = false;
  String result = '';

  int get playerTotal => blackjackTotal(player);
  int get dealerTotal => blackjackTotal(dealer);

  void newRound() {
    _deck = shuffledDeck(_random);
    player.clear();
    dealer.clear();
    finished = false;
    result = '';
    player.add(_deck.removeLast());
    dealer.add(_deck.removeLast());
    player.add(_deck.removeLast());
    dealer.add(_deck.removeLast());
    if (playerTotal == 21 || dealerTotal == 21) {
      finished = true;
      final t = currentL;
      result = playerTotal == dealerTotal
          ? t.cardGamesBjPushBlackjack
          : playerTotal == 21
          ? t.cardGamesBjPlayerBlackjack
          : t.cardGamesBjDealerBlackjack;
    }
  }

  void hit() {
    if (finished) return;
    player.add(_deck.removeLast());
    if (playerTotal > 21) {
      finished = true;
      result = currentL.cardGamesBjBust;
    }
  }

  void stand() {
    if (finished) return;
    while (dealerTotal < 17) {
      dealer.add(_deck.removeLast());
    }
    finished = true;
    final t = currentL;
    result = dealerTotal > 21 || playerTotal > dealerTotal
        ? t.cardGamesBjPlayerWins
        : playerTotal == dealerTotal
        ? t.cardGamesBjPushTie
        : t.cardGamesBjDealerWins;
  }
}

class PokerHand implements Comparable<PokerHand> {
  const PokerHand(this.category, this.kickers);

  final int category;
  final List<int> kickers;

  String get label {
    final t = currentL;
    return [
      t.cardGamesHandHighCard,
      t.cardGamesHandOnePair,
      t.cardGamesHandTwoPair,
      t.cardGamesHandThreeOfKind,
      t.cardGamesHandStraight,
      t.cardGamesHandFlush,
      t.cardGamesHandFullHouse,
      t.cardGamesHandFourOfKind,
      t.cardGamesHandStraightFlush,
    ][category];
  }

  @override
  int compareTo(PokerHand other) {
    if (category != other.category) return category.compareTo(other.category);
    for (var i = 0; i < kickers.length; i++) {
      final difference = kickers[i].compareTo(other.kickers[i]);
      if (difference != 0) return difference;
    }
    return 0;
  }
}

PokerHand evaluatePokerHand(List<PlayingCard> cards) {
  assert(cards.length == 5);
  final ranks = cards.map((card) => card.rank == 1 ? 14 : card.rank).toList()
    ..sort((a, b) => b.compareTo(a));
  final counts = <int, int>{};
  for (final rank in ranks) {
    counts[rank] = (counts[rank] ?? 0) + 1;
  }
  final groups = counts.entries.toList()
    ..sort((a, b) {
      final count = b.value.compareTo(a.value);
      return count != 0 ? count : b.key.compareTo(a.key);
    });
  final flush = cards.every((card) => card.suit == cards.first.suit);
  final unique = ranks.toSet().toList()..sort((a, b) => b.compareTo(a));
  final straightHigh = unique.length == 5
      ? (unique.first - unique.last == 4
            ? unique.first
            : unique.join(',') == '14,5,4,3,2'
            ? 5
            : 0)
      : 0;
  if (flush && straightHigh > 0) return PokerHand(8, [straightHigh]);
  if (groups.first.value == 4) {
    return PokerHand(7, [groups.first.key, groups.last.key]);
  }
  if (groups.first.value == 3 && groups[1].value == 2) {
    return PokerHand(6, [groups.first.key, groups[1].key]);
  }
  if (flush) return PokerHand(5, ranks);
  if (straightHigh > 0) return PokerHand(4, [straightHigh]);
  if (groups.first.value == 3) {
    return PokerHand(3, [
      groups.first.key,
      ...groups.skip(1).map((g) => g.key),
    ]);
  }
  if (groups.first.value == 2 && groups[1].value == 2) {
    return PokerHand(2, [groups.first.key, groups[1].key, groups[2].key]);
  }
  if (groups.first.value == 2) {
    return PokerHand(1, [
      groups.first.key,
      ...groups.skip(1).map((g) => g.key),
    ]);
  }
  return PokerHand(0, ranks);
}

class PokerGame {
  PokerGame({Random? random}) : _random = random ?? Random() {
    newRound();
  }

  final Random _random;
  late List<PlayingCard> _deck;
  final player = <PlayingCard>[];
  final dealer = <PlayingCard>[];
  final held = <int>{};
  bool finished = false;
  String result = '';

  void newRound() {
    _deck = shuffledDeck(_random);
    player
      ..clear()
      ..addAll(List.generate(5, (_) => _deck.removeLast()));
    dealer
      ..clear()
      ..addAll(List.generate(5, (_) => _deck.removeLast()));
    held.clear();
    finished = false;
    result = '';
  }

  void toggleHeld(int index) {
    if (finished) return;
    if (!held.add(index)) held.remove(index);
  }

  void draw() {
    if (finished) return;
    for (var i = 0; i < 5; i++) {
      if (!held.contains(i)) player[i] = _deck.removeLast();
    }
    final dealerGroups = <int, int>{};
    for (final card in dealer) {
      dealerGroups[card.rank] = (dealerGroups[card.rank] ?? 0) + 1;
    }
    final dealerKeeps = <int>{};
    for (var i = 0; i < 5; i++) {
      if (dealerGroups[dealer[i].rank]! >= 2) dealerKeeps.add(i);
    }
    if (dealerKeeps.isEmpty) {
      final highest = dealer.indexWhere((c) => c.rank == 1);
      if (highest >= 0) dealerKeeps.add(highest);
    }
    for (var i = 0; i < 5; i++) {
      if (!dealerKeeps.contains(i)) dealer[i] = _deck.removeLast();
    }
    finished = true;
    final yours = evaluatePokerHand(player);
    final theirs = evaluatePokerHand(dealer);
    final comparison = yours.compareTo(theirs);
    final t = currentL;
    result = comparison > 0
        ? t.cardGamesPokerPlayerWins(yours.label, theirs.label)
        : comparison < 0
        ? t.cardGamesPokerDealerWins(yours.label, theirs.label)
        : t.cardGamesPokerPush(yours.label);
  }
}

class PatienceCard {
  PatienceCard(this.card, {this.faceUp = false});

  final PlayingCard card;
  bool faceUp;
}

enum PatienceArea { waste, tableau, foundation }

class PatienceSelection {
  const PatienceSelection(this.area, this.pile, this.index);

  final PatienceArea area;
  final int pile;
  final int index;
}

class PatienceGame {
  PatienceGame({Random? random}) : _random = random ?? Random() {
    newGame();
  }

  final Random _random;
  final stock = <PlayingCard>[];
  final waste = <PlayingCard>[];
  final tableau = List.generate(7, (_) => <PatienceCard>[]);
  final foundations = List.generate(4, (_) => <PlayingCard>[]);
  PatienceSelection? selection;
  String message = currentL.cardGamesPatienceStart;

  bool get won => foundations.every((pile) => pile.length == 13);

  void newGame() {
    final deck = shuffledDeck(_random);
    for (final pile in tableau) {
      pile.clear();
    }
    for (final pile in foundations) {
      pile.clear();
    }
    stock.clear();
    waste.clear();
    for (var column = 0; column < 7; column++) {
      for (var row = 0; row <= column; row++) {
        tableau[column].add(
          PatienceCard(deck.removeLast(), faceUp: row == column),
        );
      }
    }
    stock.addAll(deck);
    selection = null;
    message = currentL.cardGamesPatienceStart;
  }

  void draw() {
    selection = null;
    if (stock.isNotEmpty) {
      waste.add(stock.removeLast());
      message = currentL.cardGamesPatienceDrawn;
    } else if (waste.isNotEmpty) {
      stock.addAll(waste.reversed);
      waste.clear();
      message = currentL.cardGamesPatienceRecycled;
    }
  }

  void selectWaste() {
    if (waste.isEmpty) return;
    selection = const PatienceSelection(PatienceArea.waste, 0, 0);
    message = currentL.cardGamesPatienceChooseTarget;
  }

  void selectTableau(int column, int index) {
    final pile = tableau[column];
    if (index >= pile.length || !pile[index].faceUp) return;
    if (selection != null && moveToTableau(column)) return;
    selection = PatienceSelection(PatienceArea.tableau, column, index);
    message = currentL.cardGamesPatienceChooseAnother;
  }

  void selectFoundation(int column) {
    if (selection != null && moveToFoundation(column)) return;
    final pile = foundations[column];
    if (pile.isEmpty) return;
    selection = PatienceSelection(
      PatienceArea.foundation,
      column,
      pile.length - 1,
    );
    message = currentL.cardGamesPatienceChooseColumn;
  }

  PlayingCard? get selectedCard {
    final chosen = selection;
    if (chosen == null) return null;
    return switch (chosen.area) {
      PatienceArea.waste => waste.isEmpty ? null : waste.last,
      PatienceArea.tableau => tableau[chosen.pile][chosen.index].card,
      PatienceArea.foundation => foundations[chosen.pile].last,
    };
  }

  bool moveToTableau(int destination) {
    final chosen = selection;
    final card = selectedCard;
    if (chosen == null ||
        card == null ||
        (chosen.area == PatienceArea.tableau && chosen.pile == destination)) {
      return false;
    }
    final target = tableau[destination];
    final allowed = target.isEmpty
        ? card.rank == 13
        : target.last.card.isRed != card.isRed &&
              target.last.card.rank == card.rank + 1;
    if (!allowed) {
      message = target.isEmpty
          ? currentL.cardGamesPatienceOnlyKing
          : currentL.cardGamesPatienceBuildDown;
      return false;
    }
    switch (chosen.area) {
      case PatienceArea.waste:
        target.add(PatienceCard(waste.removeLast(), faceUp: true));
      case PatienceArea.foundation:
        target.add(
          PatienceCard(foundations[chosen.pile].removeLast(), faceUp: true),
        );
      case PatienceArea.tableau:
        final source = tableau[chosen.pile];
        target.addAll(source.sublist(chosen.index));
        source.removeRange(chosen.index, source.length);
        if (source.isNotEmpty) source.last.faceUp = true;
    }
    selection = null;
    message = currentL.cardGamesPatienceNiceMove;
    return true;
  }

  bool moveToFoundation(int destination) {
    final chosen = selection;
    final card = selectedCard;
    if (chosen == null ||
        card == null ||
        chosen.area == PatienceArea.foundation ||
        (chosen.area == PatienceArea.tableau &&
            chosen.index != tableau[chosen.pile].length - 1)) {
      return false;
    }
    final target = foundations[destination];
    final allowed = target.isEmpty
        ? card.rank == 1
        : target.last.suit == card.suit && card.rank == target.last.rank + 1;
    if (!allowed) {
      message = currentL.cardGamesPatienceFoundationRule;
      return false;
    }
    if (chosen.area == PatienceArea.waste) {
      target.add(waste.removeLast());
    } else {
      final source = tableau[chosen.pile];
      target.add(source.removeLast().card);
      if (source.isNotEmpty) source.last.faceUp = true;
    }
    selection = null;
    message = won ? currentL.cardGamesPatienceWon : currentL.cardGamesPatienceMoved;
    return true;
  }
}
