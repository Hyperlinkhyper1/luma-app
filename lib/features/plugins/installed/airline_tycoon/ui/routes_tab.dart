import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../airline_game_state.dart';
import '../airline_tycoon_repository.dart';
import '../data/aircraft.dart';
import '../data/airport_catalog.dart';
import '../sim/economy.dart';
import '../sim/geo.dart';
import 'money.dart';
import 'route_map.dart';

class RoutesTab extends StatefulWidget {
  const RoutesTab({super.key, required this.repository});

  final AirlineTycoonRepository repository;

  @override
  State<RoutesTab> createState() => _RoutesTabState();
}

class _RoutesTabState extends State<RoutesTab> {
  Airport? _selected;

  @override
  Widget build(BuildContext context) {
    final map = RouteMap(
      repository: widget.repository,
      selected: _selected,
      onSelect: _onSelectAirport,
    );

    if (context.isPhoneWidth) {
      return Column(
        children: [
          SizedBox(height: 240, child: map),
          Expanded(child: _buildList()),
        ],
      );
    }
    return Row(
      children: [
        SizedBox(width: 360, child: _buildList()),
        Expanded(child: map),
      ],
    );
  }

  Widget _buildList() {
    final repo = widget.repository;
    final routes = repo.state.routes;
    final luma = context.luma;

    if (routes.isEmpty) {
      return LumaEmptyState(
        icon: Icons.route_rounded,
        title: 'No routes yet',
        subtitle: 'Tap an airport on the map to open your first route.',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${routes.length} route${routes.length == 1 ? '' : 's'} · '
                  '${repo.hubEffects.activeGates} gate(s)',
                  style: TextStyle(color: luma.textSecondary, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: routes.length,
            itemBuilder: (context, index) => _RouteCard(
              repository: repo,
              route: routes[index],
              onTap: () => _openRouteSheet(routes[index]),
            ),
          ),
        ),
      ],
    );
  }

  void _onSelectAirport(Airport airport) {
    setState(() => _selected = airport);
    final repo = widget.repository;
    final existing = repo.state.routes
        .where((r) => r.destIata == airport.iata)
        .toList();
    if (existing.isNotEmpty) {
      _openRouteSheet(existing.first);
      return;
    }
    _openNewRouteSheet(airport);
  }

  void _openNewRouteSheet(Airport airport) {
    final repo = widget.repository;
    final hub = repo.hubAirport;
    if (hub == null) return;

    final distance = hub.distanceToKm(airport);
    final demand = Economy.demandPerDay(
      catchmentA: hub.catchment,
      catchmentB: airport.catchment,
      distanceKm: distance,
    );
    final effects = repo.hubEffects;
    final usable = kAircraftCatalog
        .where((m) => m.rangeKm >= distance && m.canUseRunway(effects.maxRunwayM))
        .toList();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final luma = sheetContext.luma;
        return _SheetShell(
          title: '${hub.iata} → ${airport.iata}',
          subtitle: airport.name,
          children: [
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                _Fact(label: 'Distance', value: fmtKm(distance)),
                _Fact(label: 'Daily demand', value: '${demand.round()} pax'),
                _Fact(
                  label: 'Fair fare',
                  value: fmtExactMoney(Economy.fairFareEur(distance).round()),
                ),
                _Fact(
                  label: 'Runway there',
                  value: '${fmtCount(airport.runwayM)} m',
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (usable.isEmpty)
              _Notice(
                icon: Icons.warning_amber_rounded,
                colour: luma.warning,
                text: 'Nothing in the catalogue can fly this from your hub '
                    'yet — you need a longer runway, or this sector is beyond '
                    'every aircraft you could buy.',
              )
            else
              Text(
                'Can be flown by: ${usable.take(4).map((m) => m.name).join(', ')}'
                '${usable.length > 4 ? ' and ${usable.length - 4} more' : ''}.',
                style: TextStyle(color: luma.textSecondary, fontSize: 12),
              ),
            const SizedBox(height: 16),
            LumaPrimaryButton(
              label: 'Open route · '
                  '${fmtMoney((45000 + 12 * distance).round())}',
              expand: true,
              onTap: () {
                final result = repo.openRoute(airport.iata);
                Navigator.of(sheetContext).pop();
                if (!mounted) return;
                if (!result.success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result.message!),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
                setState(() {});
              },
            ),
          ],
        );
      },
    );
  }

  void _openRouteSheet(AirlineRoute route) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RouteDetailSheet(
        repository: widget.repository,
        routeId: route.id,
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.repository,
    required this.route,
    required this.onTap,
  });

  final AirlineTycoonRepository repository;
  final AirlineRoute route;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final dest = repository.catalog?.byIata(route.destIata);
    final assigned = repository.state.aircraftOnRoute(route.id).length;
    final recent = route.profitHistory.isEmpty ? 0 : route.profitHistory.last;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: context.lumaDecor.cardBorderRadius,
        child: LumaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      dest?.label ?? route.destIata,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Text(
                    fmtSignedMoney(recent),
                    style: TextStyle(
                      color: recent >= 0 ? luma.success : luma.danger,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.sell_rounded, size: 13, color: luma.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    fmtExactMoney(route.fareEur),
                    style: TextStyle(color: luma.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.flight_rounded, size: 13, color: luma.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    assigned == 0 ? 'no aircraft' : '$assigned assigned',
                    style: TextStyle(
                      color: assigned == 0 ? luma.warning : luma.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (route.profitHistory.length > 1) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 28,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _SparkPainter(
                      values: route.profitHistory,
                      positive: luma.success,
                      negative: luma.danger,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteDetailSheet extends StatefulWidget {
  const _RouteDetailSheet({required this.repository, required this.routeId});

  final AirlineTycoonRepository repository;
  final String routeId;

  @override
  State<_RouteDetailSheet> createState() => _RouteDetailSheetState();
}

class _RouteDetailSheetState extends State<_RouteDetailSheet> {
  late int _fare;

  @override
  void initState() {
    super.initState();
    _fare = widget.repository.state.routeById(widget.routeId)?.fareEur ?? 100;
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repo = widget.repository;
    final route = repo.state.routeById(widget.routeId);
    final hub = repo.hubAirport;
    final dest = repo.catalog?.byIata(route?.destIata);
    if (route == null || hub == null || dest == null) {
      return const SizedBox.shrink();
    }

    final distance = hub.distanceToKm(dest);
    final fair = Economy.fairFareEur(distance);
    final effects = repo.hubEffects;
    final demand = Economy.demandPerDay(
      catchmentA: hub.catchment,
      catchmentB: dest.catchment,
      distanceKm: distance,
    );

    final assigned = repo.state.aircraftOnRoute(route.id);
    final model = assigned.isEmpty
        ? null
        : aircraftModelById(assigned.first.modelId);

    // Preview with exactly the maths the day loop will run, so the number on
    // the slider is the number the player gets.
    var projectedProfit = 0;
    var loadFactor = 0.0;
    var dailyPax = 0;
    if (model != null) {
      final blockHours = Geo.blockHours(distance, model.cruiseKmh);
      final rotations = Economy.rotationsPerDay(blockHours);
      var remaining = demand;
      for (var i = 0; i < rotations * 2 * assigned.length; i++) {
        final leg = Economy.flight(
          model: model,
          distanceKm: distance,
          fareEur: _fare.toDouble(),
          availableDemand: remaining,
          fuelPriceIndex: repo.state.fuelPriceIndex,
          hub: effects,
        );
        remaining = math.max(0, remaining - leg.passengers);
        projectedProfit += leg.profitEur;
        dailyPax += leg.passengers;
        loadFactor = leg.loadFactor;
      }
    } else {
      loadFactor = Economy.loadFactor(_fare.toDouble(), fair);
    }

    final maxFare = (fair * 2).round();

    return _SheetShell(
      scrollable: true,
      title: '${hub.iata} → ${dest.iata}',
      subtitle: '${dest.name} · ${fmtKm(distance)}',
      children: [
        Wrap(
          spacing: 20,
          runSpacing: 10,
          children: [
            _Fact(label: 'Daily demand', value: '${demand.round()} pax'),
            _Fact(label: 'Fair fare', value: fmtExactMoney(fair.round())),
            _Fact(label: 'Aircraft', value: '${assigned.length}'),
            if (model != null) _Fact(label: 'Type', value: model.name),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text(
              'Fare',
              style: TextStyle(
                color: luma.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              fmtExactMoney(_fare),
              style: TextStyle(
                color: luma.accent,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        Slider(
          value: _fare.toDouble().clamp(10, maxFare.toDouble()),
          min: 10,
          max: maxFare.toDouble(),
          onChanged: (value) => setState(() => _fare = value.round()),
          onChangeEnd: (value) =>
              widget.repository.setFare(route.id, value.round()),
        ),
        Row(
          children: [
            Expanded(
              child: _Meter(
                label: 'Cabin filled',
                value: '${(loadFactor * 100).round()}%',
                fraction: loadFactor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model == null ? 'No aircraft assigned' : 'Projected today',
                    style: TextStyle(fontSize: 11, color: luma.textMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    model == null
                        ? 'Assign one in Fleet'
                        : '${fmtSignedMoney(projectedProfit)} · '
                            '${fmtCount(dailyPax)} pax',
                    style: TextStyle(
                      color: model == null
                          ? luma.warning
                          : projectedProfit >= 0
                              ? luma.success
                              : luma.danger,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        LumaGhostButton(
          label: 'Close this route',
          icon: Icons.close_rounded,
          expand: true,
          onTap: () {
            widget.repository.closeRoute(route.id);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({
    required this.title,
    required this.subtitle,
    required this.children,
    this.scrollable = false,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(subtitle, style: TextStyle(color: luma.textSecondary, fontSize: 13)),
        const SizedBox(height: 16),
        ...children,
      ],
    );

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: luma.surface,
          borderRadius: context.lumaDecor.cardBorderRadius,
          border: Border.all(color: luma.border),
        ),
        child: scrollable
            ? SingleChildScrollView(child: body)
            : body,
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({
    required this.label,
    required this.value,
    required this.fraction,
  });

  final String label;
  final String value;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final healthy = fraction >= 0.55;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: luma.textMuted)),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(
              value,
              style: TextStyle(
                color: healthy ? luma.success : luma.warning,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: fraction.clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: luma.surfaceHover,
                  valueColor: AlwaysStoppedAnimation(
                    healthy ? luma.success : luma.warning,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.colour,
    required this.text,
  });

  final IconData icon;
  final Color colour;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: colour),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: colour, fontSize: 12)),
          ),
        ],
      );
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: luma.textMuted)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: luma.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.values,
    required this.positive,
    required this.negative,
  });

  final List<int> values;
  final Color positive;
  final Color negative;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.isEmpty) return;

    final maxValue = values.reduce(math.max).toDouble();
    final minValue = values.reduce(math.min).toDouble();
    final span = math.max(1.0, maxValue - minValue);
    final step = size.width / (values.length - 1);

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

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = values.last >= 0 ? positive : negative,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.values.length != values.length ||
      (old.values.isNotEmpty && old.values.last != values.last);
}
