import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../airline_game_state.dart';
import '../airline_tycoon_repository.dart';
import 'money.dart';

class FinancesTab extends StatelessWidget {
  const FinancesTab({super.key, required this.repository});

  final AirlineTycoonRepository repository;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final state = repository.state;
    final report = repository.lastDayReport;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        LumaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cash',
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
              Text(
                fmtExactMoney(state.cashEur),
                style: TextStyle(
                  color: state.cashEur >= 0 ? luma.textPrimary : luma.danger,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 12),
              if (state.history.length > 1)
                SizedBox(
                  height: 70,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _HistoryPainter(
                      history: state.history,
                      line: luma.accent,
                      fill: luma.accentSubtle,
                      grid: luma.border,
                    ),
                  ),
                )
              else
                Text(
                  'Trade a few days and the balance chart appears here.',
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (report != null) _DayBooks(report: report),
        const SizedBox(height: 12),
        LumaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The airline so far',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  _Stat(label: 'Day', value: '${state.day}'),
                  _Stat(
                    label: 'Flights flown',
                    value: fmtCount(state.flightsFlownEver),
                  ),
                  _Stat(
                    label: 'Passengers carried',
                    value: fmtCount(state.passengersCarriedEver),
                  ),
                  _Stat(label: 'Aircraft', value: '${state.fleet.length}'),
                  _Stat(label: 'Routes', value: '${state.routes.length}'),
                  _Stat(
                    label: 'Fuel price',
                    value: '${(state.fuelPriceIndex * 100).round()}%',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ExpansionCard(repository: repository),
      ],
    );
  }
}

class _DayBooks extends StatelessWidget {
  const _DayBooks({required this.report});

  final DayReport report;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Day ${report.day}',
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                fmtSignedMoney(report.profitEur),
                style: TextStyle(
                  color: report.profitEur >= 0 ? luma.success : luma.danger,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Line(label: 'Tickets', value: report.revenueEur, income: true),
          if (report.cargoEur > 0)
            _Line(label: 'Cargo', value: report.cargoEur, income: true),
          const SizedBox(height: 6),
          _Line(label: 'Fuel', value: -report.fuelEur),
          _Line(label: 'Crew', value: -report.crewEur),
          _Line(label: 'Airport fees', value: -report.landingEur),
          _Line(label: 'Maintenance', value: -report.maintenanceEur),
          _Line(label: 'Hub upkeep', value: -report.upkeepEur),
          if (report.leaseEur > 0)
            _Line(label: 'Lease payments', value: -report.leaseEur),
          const SizedBox(height: 10),
          Text(
            '${fmtCount(report.flights)} flights · '
            '${fmtCount(report.passengers)} passengers',
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
          for (final event in report.events) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 13, color: luma.warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    event,
                    style: TextStyle(color: luma.warning, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.income = false});

  final String label;
  final int value;
  final bool income;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: luma.textSecondary, fontSize: 13),
            ),
          ),
          Text(
            fmtSignedMoney(value),
            style: TextStyle(
              color: income ? luma.success : luma.textPrimary,
              fontSize: 13,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpansionCard extends StatelessWidget {
  const _ExpansionCard({required this.repository});

  final AirlineTycoonRepository repository;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final state = repository.state;
    final atLimit = state.gridSize >= AirlineGameState.maxGridSize;
    final cost = repository.expansionCostEur;

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The field',
            style: TextStyle(
              color: luma.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            atLimit
                ? 'Your land is ${state.gridSize} by ${state.gridSize} — '
                    'the largest the airport authority will sell you.'
                : 'Your land is ${state.gridSize} by ${state.gridSize}. Buying '
                    'more gives you room for another terminal and the gates '
                    'that go with it.',
            style: TextStyle(color: luma.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          LumaPrimaryButton(
            label: atLimit
                ? 'At the limit'
                : 'Buy land · ${fmtMoney(cost)}',
            icon: Icons.open_in_full_rounded,
            expand: true,
            onTap: atLimit
                ? null
                : () {
                    final result = repository.expandField();
                    if (!result.success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(result.message!),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: luma.textMuted)),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: luma.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _HistoryPainter extends CustomPainter {
  _HistoryPainter({
    required this.history,
    required this.line,
    required this.fill,
    required this.grid,
  });

  final List<DayRecord> history;
  final Color line;
  final Color fill;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2 || size.isEmpty) return;

    final values = [for (final record in history) record.cashEur.toDouble()];
    final maxValue = values.reduce(math.max);
    final minValue = values.reduce(math.min);
    final span = math.max(1.0, maxValue - minValue);
    final step = size.width / (values.length - 1);

    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()
        ..strokeWidth = 1
        ..color = grid,
    );

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * step;
      final y = size.height - ((values[i] - minValue) / span) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = line,
    );
  }

  @override
  bool shouldRepaint(_HistoryPainter old) =>
      old.history.length != history.length ||
      (old.history.isNotEmpty && old.history.last.cashEur != history.last.cashEur);
}
