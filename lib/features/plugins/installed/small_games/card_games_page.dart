import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import 'card_games_logic.dart';

const _felt = Color(0xFF0A6946);
const _feltDark = Color(0xFF06432F);
const _gold = Color(0xFFE7C478);
const _cream = Color(0xFFFFF9E9);

enum _TableGame { poker, blackjack, patience }

class CardGamesPage extends StatefulWidget {
  const CardGamesPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<CardGamesPage> createState() => _CardGamesPageState();
}

class _CardGamesPageState extends State<CardGamesPage> {
  _TableGame? _game;
  late final _poker = PokerGame();
  late final _blackjack = BlackjackGame();
  late final _patience = PatienceGame();

  L get t => L.of(context);

  void _open(_TableGame game) => setState(() => _game = game);

  void _newGame() => setState(() {
    switch (_game) {
      case _TableGame.poker:
        _poker.newRound();
      case _TableGame.blackjack:
        _blackjack.newRound();
      case _TableGame.patience:
        _patience.newGame();
      case null:
        break;
    }
  });

  @override
  Widget build(BuildContext context) {
    final title = switch (_game) {
      _TableGame.poker => t.cardGamesFiveCardDraw,
      _TableGame.blackjack => t.cardGamesBlackjack,
      _TableGame.patience => t.cardGamesPatience,
      null => t.cardGamesTableTitle,
    };
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF191D1B), Color(0xFF30251C), Color(0xFF121917)],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: _game == null
                          ? t.cardGamesAllGames
                          : t.cardGamesBackToTable,
                      onPressed: _game == null
                          ? widget.onBack
                          : () => setState(() => _game = null),
                      color: _cream,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.cardGamesHeader,
                            style: TextStyle(
                              color: _gold.withValues(alpha: .9),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.2,
                            ),
                          ),
                          Text(
                            title,
                            style: const TextStyle(
                              color: _cream,
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_game != null)
                      TextButton.icon(
                        onPressed: _newGame,
                        style: TextButton.styleFrom(foregroundColor: _gold),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(t.cardGamesNewGame),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(80),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF9E7040),
                        Color(0xFF53341E),
                        Color(0xFFB4864A),
                      ],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 28,
                        offset: Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(70),
                      color: _gold,
                    ),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 570),
                      padding: const EdgeInsets.fromLTRB(14, 22, 14, 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(65),
                        gradient: const RadialGradient(
                          center: Alignment(0, -.2),
                          radius: 1.25,
                          colors: [Color(0xFF168458), _felt, _feltDark],
                        ),
                      ),
                      child: Column(
                        children: [
                          _dealer(),
                          const SizedBox(height: 12),
                          if (_game == null) _lobby() else _activeGame(),
                          const SizedBox(height: 16),
                          const Divider(color: Color(0x669CD8B4), height: 1),
                          const SizedBox(height: 12),
                          _player(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dealer() => Column(
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF19362D),
          border: Border.all(color: _gold, width: 2),
        ),
        child: const Icon(Icons.person_rounded, color: _gold, size: 30),
      ),
      const SizedBox(height: 3),
      Text(
        t.cardGamesDealer,
        style: const TextStyle(
          color: _cream,
          fontSize: 10,
          letterSpacing: 2,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );

  Widget _player() => Column(
    children: [
      const SizedBox(
        width: 112,
        height: 86,
        child: CustomPaint(painter: _PlayerPainter()),
      ),
      Text(
        t.cardGamesYouSeat,
        style: const TextStyle(
          color: _cream,
          fontSize: 11,
          letterSpacing: 1.7,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );

  Widget _lobby() => Column(
    children: [
      const SizedBox(height: 18),
      Text(
        t.cardGamesPullUpChair,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _gold,
          fontSize: 11,
          letterSpacing: 3.5,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 7),
      Text(
        t.cardGamesWhatToPlay,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _cream,
          fontSize: 27,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 7),
      Text(
        t.cardGamesLobbyBlurb,
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFFD1E8DA), fontSize: 13),
      ),
      const SizedBox(height: 28),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 570 ? 1 : 3;
          final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
          return Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              _choice(
                width,
                _TableGame.poker,
                '♠',
                t.cardGamesPoker,
                t.cardGamesFiveCardDraw,
                t.cardGamesPokerBlurb,
              ),
              _choice(
                width,
                _TableGame.blackjack,
                '♥',
                t.cardGamesBlackjack,
                t.cardGamesBlackjackType,
                t.cardGamesBlackjackBlurb,
              ),
              _choice(
                width,
                _TableGame.patience,
                '♣',
                t.cardGamesPatience,
                t.cardGamesSolitaire,
                t.cardGamesPatienceBlurb,
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 24),
      _chipRow(),
    ],
  );

  Widget _choice(
    double width,
    _TableGame game,
    String suit,
    String name,
    String type,
    String description,
  ) => SizedBox(
    width: width,
    child: Material(
      color: const Color(0xDDFCF7E9),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: ValueKey('open_${game.name}'),
        borderRadius: BorderRadius.circular(18),
        onTap: () => _open(game),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    suit,
                    style: TextStyle(
                      fontSize: 33,
                      color: suit == '♥' ? const Color(0xFFA63232) : _feltDark,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.north_east_rounded,
                    color: _feltDark,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                name,
                style: const TextStyle(
                  color: Color(0xFF1A2D24),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                type.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF94703C),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(color: Color(0xFF53645A), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _chipRow() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (final color in [
        const Color(0xFFD6A349),
        const Color(0xFF9E3031),
        const Color(0xFF184D70),
      ]) ...[
        Container(
          width: 27,
          height: 27,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: _cream, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 4,
                offset: Offset(1, 3),
              ),
            ],
          ),
          child: const Icon(Icons.circle, size: 6, color: _cream),
        ),
      ],
    ],
  );

  Widget _activeGame() => switch (_game!) {
    _TableGame.poker => _pokerBoard(),
    _TableGame.blackjack => _blackjackBoard(),
    _TableGame.patience => _patienceBoard(),
  };

  Widget _blackjackBoard() => Column(
    children: [
      const SizedBox(height: 8),
      _sectionLabel(t.cardGamesDealerHand),
      const SizedBox(height: 8),
      _cardRow(_blackjack.dealer, hideFrom: _blackjack.finished ? null : 1),
      const SizedBox(height: 8),
      _status(
        _blackjack.finished
            ? t.cardGamesDealerTotal(_blackjack.dealerTotal)
            : t.cardGamesDealerShowing(
                blackjackTotal([_blackjack.dealer.first]),
              ),
      ),
      const SizedBox(height: 28),
      const _FeltRule(),
      const SizedBox(height: 22),
      _sectionLabel(t.cardGamesYourHand),
      const SizedBox(height: 8),
      _cardRow(_blackjack.player),
      const SizedBox(height: 8),
      _status(t.cardGamesYouTotal(_blackjack.playerTotal)),
      const SizedBox(height: 18),
      if (_blackjack.finished) _result(_blackjack.result),
      const SizedBox(height: 12),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          if (!_blackjack.finished) ...[
            _action(
              t.cardGamesHit,
              Icons.add_rounded,
              () => setState(_blackjack.hit),
            ),
            _action(
              t.cardGamesStand,
              Icons.pan_tool_alt_rounded,
              () => setState(_blackjack.stand),
            ),
          ] else
            _action(
              t.cardGamesDealAgain,
              Icons.refresh_rounded,
              () => setState(_blackjack.newRound),
            ),
        ],
      ),
      const SizedBox(height: 12),
      _hint(t.cardGamesBlackjackHint),
    ],
  );

  Widget _pokerBoard() => Column(
    children: [
      const SizedBox(height: 8),
      _sectionLabel(t.cardGamesDealerHand),
      const SizedBox(height: 8),
      _cardRow(_poker.dealer, hideFrom: _poker.finished ? null : 0),
      if (_poker.finished) ...[
        const SizedBox(height: 8),
        _status(evaluatePokerHand(_poker.dealer).label),
      ],
      const SizedBox(height: 25),
      const _FeltRule(),
      const SizedBox(height: 20),
      _sectionLabel(t.cardGamesYourHand),
      const SizedBox(height: 8),
      LayoutBuilder(
        builder: (context, constraints) {
          final width = min(62.0, (constraints.maxWidth - 35) / 5 - 5);
          return Wrap(
            alignment: WrapAlignment.center,
            spacing: 5,
            runSpacing: 8,
            children: [
              for (var i = 0; i < 5; i++)
                Column(
                  children: [
                    GestureDetector(
                      key: ValueKey('poker_card_$i'),
                      onTap: _poker.finished
                          ? null
                          : () => setState(() => _poker.toggleHeld(i)),
                      child: _PlayingCardView(
                        card: _poker.player[i],
                        width: width,
                        selected: _poker.held.contains(i) && !_poker.finished,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _poker.held.contains(i) && !_poker.finished
                          ? t.cardGamesHold
                          : ' ',
                      style: const TextStyle(
                        color: _gold,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
      if (_poker.finished) _status(evaluatePokerHand(_poker.player).label),
      const SizedBox(height: 13),
      if (_poker.finished) _result(_poker.result),
      const SizedBox(height: 12),
      _action(
        _poker.finished ? t.cardGamesDealAgain : t.cardGamesDrawCards,
        _poker.finished ? Icons.refresh_rounded : Icons.style_rounded,
        () => setState(_poker.finished ? _poker.newRound : _poker.draw),
      ),
      const SizedBox(height: 12),
      _hint(t.cardGamesPokerHint),
    ],
  );

  Widget _patienceBoard() => Column(
    children: [
      const SizedBox(height: 8),
      _sectionLabel(t.cardGamesPatienceSection),
      const SizedBox(height: 9),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _pileButton(
              'Stock',
              t.cardGamesStock,
              _patience.stock.isNotEmpty
                  ? const _PlayingCardView(faceDown: true, width: 54)
                  : const _EmptyCard(label: '↻'),
              () => setState(_patience.draw),
            ),
            const SizedBox(width: 6),
            _pileButton(
              'Waste',
              t.cardGamesWaste,
              _patience.waste.isEmpty
                  ? const _EmptyCard(label: '—')
                  : _PlayingCardView(
                      card: _patience.waste.last,
                      width: 54,
                      selected: _patience.selection?.area == PatienceArea.waste,
                    ),
              () => setState(_patience.selectWaste),
            ),
            const SizedBox(width: 12),
            for (var i = 0; i < 4; i++) ...[
              _pileButton(
                'F${i + 1}',
                t.cardGamesFoundation('${i + 1}'),
                _patience.foundations[i].isEmpty
                    ? const _EmptyCard(label: 'A')
                    : _PlayingCardView(
                        card: _patience.foundations[i].last,
                        width: 54,
                        selected:
                            _patience.selection?.area ==
                                PatienceArea.foundation &&
                            _patience.selection?.pile == i,
                      ),
                () => setState(() => _patience.selectFoundation(i)),
              ),
              if (i < 3) const SizedBox(width: 6),
            ],
          ],
        ),
      ),
      const SizedBox(height: 18),
      const _FeltRule(),
      const SizedBox(height: 16),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var col = 0; col < 7; col++) ...[
              _tableauColumn(col),
              if (col < 6) const SizedBox(width: 6),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      _status(_patience.message),
      const SizedBox(height: 8),
      _hint(t.cardGamesPatienceHint),
    ],
  );

  Widget _pileButton(
    String id,
    String label,
    Widget card,
    VoidCallback onTap,
  ) => Column(
    children: [
      InkWell(key: ValueKey('patience_$id'), onTap: onTap, child: card),
      const SizedBox(height: 4),
      Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: _cream,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  Widget _tableauColumn(int column) {
    final pile = _patience.tableau[column];
    return SizedBox(
      width: 54,
      height: max(92.0, 84 + pile.length * 23.0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (pile.isEmpty)
            Positioned(
              top: 0,
              child: InkWell(
                key: ValueKey('patience_column_$column'),
                onTap: () => setState(() => _patience.moveToTableau(column)),
                child: const _EmptyCard(label: 'K'),
              ),
            ),
          for (var index = 0; index < pile.length; index++)
            Positioned(
              top: index * 23.0,
              child: GestureDetector(
                key: ValueKey('patience_card_${column}_$index'),
                onTap: () =>
                    setState(() => _patience.selectTableau(column, index)),
                child: _PlayingCardView(
                  card: pile[index].card,
                  faceDown: !pile[index].faceUp,
                  width: 54,
                  selected:
                      _patience.selection?.area == PatienceArea.tableau &&
                      _patience.selection?.pile == column &&
                      _patience.selection?.index == index,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cardRow(List<PlayingCard> cards, {int? hideFrom}) => LayoutBuilder(
    builder: (context, constraints) {
      final width = min(
        60.0,
        (constraints.maxWidth - 30) / max(cards.length, 5) - 6,
      );
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var i = 0; i < cards.length; i++)
            _PlayingCardView(
              card: cards[i],
              faceDown: hideFrom != null && i >= hideFrom,
              width: width,
            ),
        ],
      );
    },
  );

  Widget _sectionLabel(String label) => Text(
    label,
    style: const TextStyle(
      color: _gold,
      fontSize: 10,
      letterSpacing: 2,
      fontWeight: FontWeight.w800,
    ),
  );

  Widget _status(String label) => Text(
    label,
    textAlign: TextAlign.center,
    style: const TextStyle(
      color: _cream,
      fontWeight: FontWeight.w700,
      fontSize: 13,
    ),
  );

  Widget _result(String result) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFF0C4B36),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _gold),
    ),
    child: Text(
      result,
      textAlign: TextAlign.center,
      style: const TextStyle(color: _cream, fontWeight: FontWeight.w700),
    ),
  );

  Widget _hint(String hint) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Text(
      hint,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Color(0xFFCCE5D6), fontSize: 11),
    ),
  );

  Widget _action(String label, IconData icon, VoidCallback onPressed) =>
      FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: const Color(0xFF263027),
          padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 12),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label),
      );
}

class _PlayingCardView extends StatelessWidget {
  const _PlayingCardView({
    this.card,
    this.faceDown = false,
    required this.width,
    this.selected = false,
  });

  final PlayingCard? card;
  final bool faceDown;
  final double width;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final height = width * 1.43;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: faceDown ? const Color(0xFF243D57) : _cream,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected ? _gold : const Color(0xFFCBBE9D),
          width: selected ? 3 : 1,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(1, 3)),
        ],
      ),
      child: faceDown
          ? Center(
              child: Container(
                margin: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  border: Border.all(color: _gold.withValues(alpha: .8)),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Center(
                  child: Text(
                    '✦',
                    style: TextStyle(color: _gold, fontSize: width * .38),
                  ),
                ),
              ),
            )
          : card == null
          ? null
          : Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${card!.rankLabel}${card!.suitLabel}',
                    style: TextStyle(
                      color: card!.isRed
                          ? const Color(0xFFB82D34)
                          : const Color(0xFF172A29),
                      fontSize: width * .27,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        child: Text(
                          card!.suitLabel,
                          style: TextStyle(
                            color: card!.isRed
                                ? const Color(0xFFB82D34)
                                : const Color(0xFF172A29),
                            fontSize: width * .53,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    width: 54,
    height: 77,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: _cream.withValues(alpha: .45)),
    ),
    child: Text(
      label,
      style: TextStyle(color: _cream.withValues(alpha: .72), fontSize: 20),
    ),
  );
}

class _FeltRule extends StatelessWidget {
  const _FeltRule();

  @override
  Widget build(BuildContext context) =>
      Container(width: 160, height: 1, color: _gold.withValues(alpha: .48));
}

class _PlayerPainter extends CustomPainter {
  const _PlayerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final jacket = Paint()..color = const Color(0xFF213C4A);
    final shirt = Paint()..color = _cream;
    final skin = Paint()..color = const Color(0xFFC98962);
    final hair = Paint()..color = const Color(0xFF302018);
    canvas.drawOval(Rect.fromLTWH(7, 50, 98, 70), jacket);
    canvas.drawPath(
      Path()
        ..moveTo(45, 56)
        ..lineTo(56, 79)
        ..lineTo(67, 56)
        ..close(),
      shirt,
    );
    canvas.drawOval(Rect.fromLTWH(38, 12, 36, 46), skin);
    canvas.drawArc(Rect.fromLTWH(36, 8, 40, 34), pi, pi, true, hair);
    canvas.drawCircle(const Offset(50, 36), 1.2, hair);
    canvas.drawCircle(const Offset(63, 36), 1.2, hair);
    final smile = Paint()
      ..color = const Color(0xFF302018)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawArc(Rect.fromLTWH(51, 40, 12, 7), 0, pi, false, smile);
  }

  @override
  bool shouldRepaint(covariant _PlayerPainter oldDelegate) => false;
}
