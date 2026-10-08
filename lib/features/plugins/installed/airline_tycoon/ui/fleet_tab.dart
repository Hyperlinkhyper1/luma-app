import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import '../airline_game_state.dart';
import '../airline_tycoon_repository.dart';
import '../data/aircraft.dart';
import '../sim/economy.dart';
import '../sim/geo.dart';
import '../sim/hub.dart';
import 'money.dart';

class FleetTab extends StatelessWidget {
  const FleetTab({super.key, required this.repository});

  final AirlineTycoonRepository repository;

  @override
  Widget build(BuildContext context) {
    final state = repository.state;
    final t = L.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t.airlineFleetCount(state.fleet.length),
                  style: TextStyle(
                    color: context.luma.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              LumaPrimaryButton(
                label: t.airlineFleetAcquire,
                icon: Icons.add_rounded,
                onTap: () => _openMarket(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: state.fleet.isEmpty
              ? LumaEmptyState(
                  icon: Icons.flight_rounded,
                  title: t.airlineFleetEmptyTitle,
                  subtitle: t.airlineFleetEmptySubtitle,
                  action: LumaPrimaryButton(
                    label: t.airlineFleetBrowse,
                    onTap: () => _openMarket(context),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: state.fleet.length,
                  itemBuilder: (context, index) => _AircraftCard(
                    repository: repository,
                    aircraft: state.fleet[index],
                  ),
                ),
        ),
      ],
    );
  }

  void _openMarket(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MarketSheet(repository: repository),
    );
  }
}

class _AircraftCard extends StatelessWidget {
  const _AircraftCard({required this.repository, required this.aircraft});

  final AirlineTycoonRepository repository;
  final OwnedAircraft aircraft;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final state = repository.state;
    final model = aircraftModelById(aircraft.modelId);
    if (model == null) return const SizedBox.shrink();

    final route = state.routeById(aircraft.routeId);
    final grounded = aircraft.isGrounded(state.day);
    final t = L.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LumaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                LumaIconBadge(
                  icon: Icons.flight_rounded,
                  color: grounded ? luma.warning : luma.accent,
                  size: 38,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.name,
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        aircraft.leased
                            ? t.airlineFleetDetailLeased(
                                aircraft.registration, model.maker)
                            : t.airlineFleetDetail(
                                aircraft.registration, model.maker),
                        style:
                            TextStyle(color: luma.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (grounded)
                  _Chip(
                    // Says it in words, not only in colour.
                    label:
                        t.airlineFleetInCheck('${aircraft.groundedUntilDay - state.day}'),
                    colour: luma.warning,
                    icon: Icons.build_rounded,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _ConditionBar(condition: aircraft.condition),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _Fact(label: t.airlineLabelSeats, value: '${model.seats}'),
                _Fact(label: t.airlineLabelRange, value: fmtKm(model.rangeKm.toDouble())),
                _Fact(
                  label: t.airlineLabelHours,
                  value: aircraft.blockHours.toStringAsFixed(0),
                ),
                if (aircraft.leased)
                  _Fact(
                    label: t.airlineLabelLease,
                    value: t.airlineFactPerDay(fmtMoney(model.leasePerDayEur)),
                  )
                else
                  _Fact(
                    label: t.airlineLabelResale,
                    value: fmtMoney(model.resaleValueEur(aircraft.blockHours)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _RoutePicker(
                    repository: repository,
                    aircraft: aircraft,
                    currentRoute: route?.id,
                  ),
                ),
                const SizedBox(width: 8),
                LumaGhostButton(
                  label: aircraft.leased ? t.airlineFleetReturn : t.airlineFleetSell,
                  onTap: () => _confirmRelease(context, model),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRelease(BuildContext context, AircraftModel model) {
    final t = L.of(context);
    final leased = aircraft.leased;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          leased ? t.airlineFleetReturnTitle : t.airlineFleetSellTitle,
        ),
        content: Text(
          leased
              ? t.airlineFleetReturnBody(aircraft.registration)
              : t.airlineFleetSellBody(
                  aircraft.registration,
                  fmtExactMoney(model.resaleValueEur(aircraft.blockHours)),
                  fmtExactMoney(model.priceEur),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t.airlineFleetKeepIt),
          ),
          TextButton(
            onPressed: () {
              repository.releaseAircraft(aircraft.id);
              Navigator.of(dialogContext).pop();
            },
            child: Text(leased ? t.airlineFleetReturn : t.airlineFleetSell),
          ),
        ],
      ),
    );
  }
}

class _RoutePicker extends StatelessWidget {
  const _RoutePicker({
    required this.repository,
    required this.aircraft,
    required this.currentRoute,
  });

  final AirlineTycoonRepository repository;
  final OwnedAircraft aircraft;
  final String? currentRoute;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;
    final state = repository.state;
    final catalog = repository.catalog;
    final t = L.of(context);

    if (state.routes.isEmpty) {
      return Text(
        t.airlineFleetOpenRouteFirst,
        style: TextStyle(color: luma.textMuted, fontSize: 12),
      );
    }

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: luma.surfaceHover,
        borderRadius: decor.buttonBorderRadius,
        border: Border.all(color: luma.border, width: decor.borderWidth),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: currentRoute,
          isExpanded: true,
          hint: Text(
            t.airlineFleetUnassigned,
            style: TextStyle(color: luma.textMuted, fontSize: 13),
          ),
          dropdownColor: luma.surface,
          style: TextStyle(color: luma.textPrimary, fontSize: 13),
          items: [
            DropdownMenuItem<String?>(
              child: Text(t.airlineFleetUnassigned),
            ),
            for (final route in state.routes)
              DropdownMenuItem<String?>(
                value: route.id,
                child: Text(
                  catalog?.byIata(route.destIata)?.label ?? route.destIata,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) {
            final result = repository.assignAircraft(aircraft.id, value);
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
      ),
    );
  }
}

class _MarketSheet extends StatelessWidget {
  const _MarketSheet({required this.repository});

  final AirlineTycoonRepository repository;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final effects = repository.hubEffects;
    final t = L.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.94,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: luma.background,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: luma.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t.airlineMarketTitle,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    fmtExactMoney(repository.state.cashEur),
                    style: TextStyle(color: luma.accent, fontSize: 14),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: kAircraftCatalog.length,
                itemBuilder: (context, index) {
                  final model = kAircraftCatalog[index];
                  return _MarketRow(
                    repository: repository,
                    model: model,
                    runwayOk: model.canUseRunway(effects.maxRunwayM),
                    hubRunway: effects.maxRunwayM,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketRow extends StatelessWidget {
  const _MarketRow({
    required this.repository,
    required this.model,
    required this.runwayOk,
    required this.hubRunway,
  });

  final AirlineTycoonRepository repository;
  final AircraftModel model;
  final bool runwayOk;
  final int hubRunway;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final canBuy = repository.state.cashEur >= model.priceEur;
    final t = L.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LumaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${model.maker} ${model.name}',
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  fmtMoney(model.priceEur),
                  style: TextStyle(
                    color: canBuy ? luma.textPrimary : luma.textMuted,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _Fact(label: t.airlineLabelSeats, value: '${model.seats}'),
                _Fact(label: t.airlineLabelRange, value: fmtKm(model.rangeKm.toDouble())),
                _Fact(label: t.airlineLabelCruise, value: t.airlineFactKmh('${model.cruiseKmh.round()}')),
                _Fact(label: t.airlineLabelRunway, value: t.airlineFactMetres(fmtCount(model.minRunwayM))),
                _Fact(
                  label: t.airlineLabelLease,
                  value: t.airlineFactPerDay(fmtMoney(model.leasePerDayEur)),
                ),
              ],
            ),
            if (!runwayOk) ...[
              const SizedBox(height: 10),
              // The reason is stated rather than the option silently hidden.
              Row(
                children: [
                  Icon(Icons.block_rounded, size: 15, color: luma.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t.airlineMarketNeedsRunway(
                        t.airlineFactMetres(fmtCount(model.minRunwayM)),
                        hubRunway == 0
                            ? t.airlineRunwayNone
                            : t.airlineFactMetres(fmtCount(hubRunway)),
                      ),
                      style:
                          TextStyle(color: luma.warning, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: LumaGhostButton(
                    label: t.airlineMarketLease,
                    expand: true,
                    onTap: () => _acquire(context, lease: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LumaPrimaryButton(
                    label: t.airlineMarketBuy,
                    expand: true,
                    onTap: canBuy ? () => _acquire(context, lease: false) : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _acquire(BuildContext context, {required bool lease}) {
    final t = L.of(context);
    final result = repository.acquireAircraft(model, lease: lease);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? t.airlineMarketJoinedFleet(model.name)
              : result.message!,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _ConditionBar extends StatelessWidget {
  const _ConditionBar({required this.condition});

  final double condition;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final poor = condition < 0.6;
    final colour = poor ? luma.warning : luma.success;

    return Row(
      children: [
        Icon(
          poor ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
          size: 14,
          color: colour,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: condition.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: luma.surfaceHover,
              valueColor: AlwaysStoppedAnimation(colour),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(condition * 100).round()}%',
          style: TextStyle(
            color: luma.textSecondary,
            fontSize: 12,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
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

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.colour, required this.icon});

  final String label;
  final Color colour;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.16),
        borderRadius: context.lumaDecor.pillBorderRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colour),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: colour, fontSize: 11)),
        ],
      ),
    );
  }
}

/// What one aircraft would do on this sector today, shared with the routes
/// tab so the fare slider previews exactly what the day loop will compute.
({int rotations, FlightResult leg}) projectFlight({
  required AircraftModel model,
  required double distanceKm,
  required double fareEur,
  required double demand,
  required double fuelIndex,
  required HubEffects hubEffects,
}) {
  final blockHours = Geo.blockHours(distanceKm, model.cruiseKmh);
  return (
    rotations: Economy.rotationsPerDay(blockHours),
    leg: Economy.flight(
      model: model,
      distanceKm: distanceKm,
      fareEur: fareEur,
      availableDemand: demand,
      fuelPriceIndex: fuelIndex,
      hub: hubEffects,
    ),
  );
}
