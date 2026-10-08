import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/luma_theme.dart';
import 'bingo_card.dart';
import 'bingo_card_export.dart';
import 'card_games_page.dart';

class SmallGamesPage extends StatefulWidget {
  const SmallGamesPage({super.key});

  @override
  State<SmallGamesPage> createState() => _SmallGamesPageState();
}

class _SmallGamesPageState extends State<SmallGamesPage> {
  bool _showBingo = false;
  bool _showCardGames = false;

  @override
  Widget build(BuildContext context) {
    if (_showBingo) {
      return BingoPage(onBack: () => setState(() => _showBingo = false));
    }
    if (_showCardGames) {
      return CardGamesPage(
        onBack: () => setState(() => _showCardGames = false),
      );
    }
    final t = L.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.smallGamesTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                t.smallGamesChooseGame,
                style: TextStyle(color: context.luma.textSecondary),
              ),
              const SizedBox(height: 24),
              LumaCard(
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: context.luma.accentSubtle,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.casino_rounded,
                        color: context.luma.accent,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.smallGamesBingoName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t.smallGamesBingoDescription,
                            style: TextStyle(
                              color: context.luma.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: t.smallGamesOpenBingo,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      onPressed: () => setState(() => _showBingo = true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              LumaCard(
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: context.luma.accentSubtle,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.style_rounded,
                        color: context.luma.accent,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.smallGamesCardGamesName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t.smallGamesCardGamesDescription,
                            style: TextStyle(
                              color: context.luma.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: t.smallGamesOpenCardGames,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      onPressed: () => setState(() => _showCardGames = true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BingoPage extends StatefulWidget {
  const BingoPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<BingoPage> createState() => _BingoPageState();
}

class _BingoPageState extends State<BingoPage> {
  final _draw = BingoDraw(Random.secure());
  final _quantity = TextEditingController(text: '10');
  bool _exporting = false;
  String? _message;

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final count = int.tryParse(_quantity.text.trim());
    if (count == null || count < 1 || count > 500) {
      setState(() => _message = L.of(context).smallGamesEnterQuantity);
      return;
    }
    setState(() {
      _exporting = true;
      _message = null;
    });
    try {
      final path = await BingoCardExport.save(count);
      if (!mounted) return;
      setState(
        () => _message = path == null
            ? null
            : L.of(context).smallGamesSavedCards(count, path),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = L.of(context).smallGamesExportFailed('$error'),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.luma;
    final t = L.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: t.smallGamesAllGames,
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.smallGamesBingoName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  Text(
                    t.smallGamesCalledCount(_draw.called.length),
                    style: TextStyle(color: palette.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 700;
                  final cage = _cageCard(palette);
                  final board = _numberBoard(palette);
                  return narrow
                      ? Column(
                          children: [cage, const SizedBox(height: 16), board],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: cage),
                            const SizedBox(width: 16),
                            Expanded(flex: 6, child: board),
                          ],
                        );
                },
              ),
              const SizedBox(height: 16),
              _exportCard(palette),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cageCard(LumaPalette palette) {
    final t = L.of(context);
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.smallGamesCageTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            t.smallGamesCageSubtitle,
            style: TextStyle(color: palette.textSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: _draw.called.length * 0.8),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeInOutCubic,
              builder: (context, angle, _) => CustomPaint(
                painter: _BingoCagePainter(
                  metal: palette.textSecondary,
                  ball: palette.accent,
                  ground: palette.surface,
                  angle: angle,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Column(
              children: [
                Text(
                  _draw.latest == null ? t.smallGamesReady : _letter(_draw.latest!),
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 106,
                  height: 106,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _draw.latest == null
                        ? palette.surfaceHover
                        : palette.accent,
                    boxShadow: [
                      BoxShadow(
                        color: palette.accent.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Text(
                    _draw.latest?.toString() ?? '—',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: _draw.latest == null
                          ? palette.textSecondary
                          : palette.onAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          LumaPrimaryButton(
            label: _draw.remaining == 0
                ? t.smallGamesAllBallsDrawn
                : t.smallGamesDrawNextBall,
            icon: Icons.play_arrow_rounded,
            expand: true,
            onTap: _draw.remaining == 0 ? null : () => setState(_draw.draw),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _draw.called.isEmpty ? null : () => setState(_draw.reset),
            icon: const Icon(Icons.restart_alt_rounded),
            label: Text(t.smallGamesNewGame),
          ),
        ],
      ),
    );
  }

  Widget _numberBoard(LumaPalette palette) {
    final t = L.of(context);
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.smallGamesCalledNumbers,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            t.smallGamesCalledNumbersHint,
            style: TextStyle(color: palette.textSecondary),
          ),
          const SizedBox(height: 20),
          for (var row = 0; row < 5; row++) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final gap = constraints.maxWidth < 410 ? 3.0 : 6.0;
                return Row(
                  children: [
                    for (var col = 0; col < 15; col++) ...[
                      if (col > 0) SizedBox(width: gap),
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _draw.called.contains(row * 15 + col + 1)
                                  ? palette.accent
                                  : palette.surfaceHover,
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${row * 15 + col + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: _draw.called.contains(row * 15 + col + 1)
                                      ? palette.onAccent
                                      : palette.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 7),
          ],
          const SizedBox(height: 14),
          Text(
            t.smallGamesRecentDraws,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (_draw.called.isEmpty)
            Text(
              t.smallGamesNoNumbersYet,
              style: TextStyle(color: palette.textMuted),
            )
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final number in _draw.called.reversed.take(12))
                  Chip(label: Text('${_letter(number)} $number')),
              ],
            ),
        ],
      ),
    );
  }

  Widget _exportCard(LumaPalette palette) {
    final t = L.of(context);
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.smallGamesExportTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            t.smallGamesExportDescription,
            style: TextStyle(color: palette.textSecondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _quantity,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: t.smallGamesNumberOfCards,
                    border: const OutlineInputBorder(),
                    helperText: '1–500',
                  ),
                ),
              ),
              LumaPrimaryButton(
                label: t.smallGamesExportPdf,
                icon: Icons.picture_as_pdf_rounded,
                loading: _exporting,
                onTap: _exporting ? null : _export,
              ),
            ],
          ),
          if (_message != null) ...[
            const SizedBox(height: 10),
            SelectableText(
              _message!,
              style: TextStyle(color: palette.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  String _letter(int number) => 'BINGO'[(number - 1) ~/ 15];
}

class _BingoCagePainter extends CustomPainter {
  _BingoCagePainter({
    required this.metal,
    required this.ball,
    required this.ground,
    required this.angle,
  });

  final Color metal;
  final Color ball;
  final Color ground;
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.47);
    final radius = min(size.width * 0.32, size.height * 0.38);
    final pen = Paint()
      ..color = metal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final support = Paint()
      ..color = metal
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx - radius * 0.75, size.height * 0.94),
      Offset(center.dx - radius * 0.65, center.dy),
      support,
    );
    canvas.drawLine(
      Offset(center.dx + radius * 0.75, size.height * 0.94),
      Offset(center.dx + radius * 0.65, center.dy),
      support,
    );
    canvas.drawLine(
      Offset(center.dx - radius * 1.1, size.height * 0.94),
      Offset(center.dx + radius * 1.1, size.height * 0.94),
      support,
    );
    final drum = Rect.fromCircle(center: center, radius: radius);
    canvas.drawOval(drum, Paint()..color = ground);
    for (var i = 0; i < 12; i++) {
      final position = 2 * pi * i / 12 + angle;
      final x = center.dx + cos(position) * radius * 0.55;
      final y = center.dy + sin(position) * radius * 0.55;
      canvas.drawCircle(
        Offset(x, y),
        radius * 0.14,
        Paint()..color = ball.withValues(alpha: 0.62),
      );
    }
    for (var i = 1; i <= 7; i++) {
      final scale = i / 8;
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: radius * 2 * scale,
          height: radius * 2,
        ),
        pen,
      );
    }
    for (var i = 0; i < 8; i++) {
      final angle = pi * i / 8;
      canvas.drawLine(
        Offset(
          center.dx - cos(angle) * radius,
          center.dy - sin(angle) * radius,
        ),
        Offset(
          center.dx + cos(angle) * radius,
          center.dy + sin(angle) * radius,
        ),
        pen,
      );
    }
    canvas.drawCircle(center, radius, pen);
    canvas.drawCircle(center, 9, Paint()..color = metal);
    canvas.drawLine(
      Offset(center.dx + radius, center.dy),
      Offset(center.dx + radius + 20, center.dy),
      support,
    );
  }

  @override
  bool shouldRepaint(covariant _BingoCagePainter oldDelegate) =>
      oldDelegate.metal != metal ||
      oldDelegate.ball != ball ||
      oldDelegate.ground != ground ||
      oldDelegate.angle != angle;
}
