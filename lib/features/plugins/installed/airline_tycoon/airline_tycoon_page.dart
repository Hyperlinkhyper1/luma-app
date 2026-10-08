import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/luma_theme.dart';
import 'airline_game_state.dart';
import 'airline_tycoon_repository.dart';
import 'airline_tycoon_scope.dart';
import 'data/airport_catalog.dart';
import 'ui/away_report_sheet.dart';
import 'ui/airport_game_view.dart';
import 'ui/finances_tab.dart';
import 'ui/fleet_tab.dart';
import 'ui/hub_view.dart';
import 'ui/money.dart';
import 'ui/routes_tab.dart';

class AirlineTycoonPage extends StatefulWidget {
  const AirlineTycoonPage({super.key});

  @override
  State<AirlineTycoonPage> createState() => _AirlineTycoonPageState();
}

class _AirlineTycoonPageState extends State<AirlineTycoonPage> {
  int _tab = 0;
  bool _awayShown = false;
  AirlineTycoonRepository? _repository;
  ValueListenable<TickerModeData>? _visibility;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = AirlineTycoonScope.of(context);
    if (_repository != repository) {
      _repository?.setAirportPageVisible(this, false);
      _repository = repository;
    }
    final visibility = TickerMode.getValuesNotifier(context);
    if (_visibility != visibility) {
      _visibility?.removeListener(_updateVisibility);
      _visibility = visibility;
      visibility.addListener(_updateVisibility);
    }
    _updateVisibility();
  }

  void _updateVisibility() {
    _repository?.setAirportPageVisible(
      this,
      _visibility?.value.enabled ?? false,
    );
  }

  @override
  void dispose() {
    _visibility?.removeListener(_updateVisibility);
    _repository?.setAirportPageVisible(this, false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = AirlineTycoonScope.of(context);
    final t = L.of(context);

    if (!repo.isLoaded) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }

    if (!repo.hasGame) {
      return _SetupView(repository: repo);
    }

    if (repo.airportMode) {
      return AirportGameView(repository: repo);
    }

    _maybeShowAwayReport(repo);

    return Column(
      children: [
        _TopStrip(repository: repo),
        LumaSegmentedTabs(
          tabs: [
            t.airlineTabFleet,
            t.airlineTabRoutes,
            t.airlineTabHub,
            t.airlineTabFinances,
          ],
          selectedIndex: _tab,
          onSelect: (index) => setState(() => _tab = index),
        ),
        Expanded(
          child: IndexedStack(
            index: _tab,
            sizing: StackFit.expand,
            children: [
              FleetTab(repository: repo),
              RoutesTab(repository: repo),
              HubView(repository: repo),
              FinancesTab(repository: repo),
            ],
          ),
        ),
      ],
    );
  }

  void _maybeShowAwayReport(AirlineTycoonRepository repo) {
    final report = repo.lastAwayReport;
    if (report == null || _awayShown) return;
    _awayShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => AwayReportSheet(
          report: report,
          onDismiss: () {
            Navigator.of(sheetContext).pop();
            repo.clearAwayReport();
          },
        ),
      );
    });
  }
}

/// Cash, the day clock and the speed control, above every tab.
class _TopStrip extends StatelessWidget {
  const _TopStrip({required this.repository});

  final AirlineTycoonRepository repository;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final state = repository.state;
    final broke = state.cashEur < 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: BoxDecoration(
        color: luma.surface,
        border: Border(bottom: BorderSide(color: luma.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.airlineName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: luma.textMuted, fontSize: 11),
                ),
                Text(
                  fmtMoney(state.cashEur),
                  style: TextStyle(
                    color: broke ? luma.danger : luma.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          _DayDial(repository: repository),
          const SizedBox(width: 10),
          for (final speed in AirlineGameState.gameSpeeds)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: _SpeedButton(
                speed: speed,
                active: state.gameSpeed == speed && !repository.isPaused,
                onTap: () {
                  repository.setSpeed(speed);
                  if (repository.isPaused) repository.resume();
                },
              ),
            ),
          const SizedBox(width: 4),
          _SquareButton(
            icon: repository.isPaused
                ? Icons.play_arrow_rounded
                : Icons.pause_rounded,
            label: repository.isPaused ? t.airlineResume : t.airlinePause,
            active: repository.isPaused,
            onTap: () =>
                repository.isPaused ? repository.resume() : repository.pause(),
          ),
        ],
      ),
    );
  }
}

class _DayDial extends StatelessWidget {
  const _DayDial({required this.repository});

  final AirlineTycoonRepository repository;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return Semantics(
      label: t.airlineDaySemantics(repository.state.day),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                value: repository.dayProgress,
                strokeWidth: 3,
                backgroundColor: luma.surfaceHover,
                valueColor: AlwaysStoppedAnimation(luma.accent),
              ),
            ),
            Text(
              '${repository.state.day}',
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  const _SpeedButton({
    required this.speed,
    required this.active,
    required this.onTap,
  });

  final int speed;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;
    final t = L.of(context);
    return Semantics(
      button: true,
      selected: active,
      label: t.airlineSpeedSemantics(speed),
      child: InkWell(
        onTap: onTap,
        borderRadius: decor.buttonBorderRadius,
        child: Container(
          width: 36,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? luma.accent : luma.surfaceHover,
            borderRadius: decor.buttonBorderRadius,
            border: Border.all(color: luma.border, width: decor.borderWidth),
          ),
          child: Text(
            '${speed}x',
            style: TextStyle(
              color: active ? luma.onAccent : luma.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: decor.buttonBorderRadius,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? luma.accent : luma.surfaceHover,
              borderRadius: decor.buttonBorderRadius,
              border: Border.all(color: luma.border, width: decor.borderWidth),
            ),
            child: Icon(
              icon,
              size: 18,
              color: active ? luma.onAccent : luma.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// First run: name the airline and pick where it flies from.
class _SetupView extends StatefulWidget {
  const _SetupView({required this.repository});

  final AirlineTycoonRepository repository;

  @override
  State<_SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends State<_SetupView> {
  final _name = TextEditingController(text: 'luma air');
  String? _hub;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final hubs = widget.repository.starterHubs().take(8).toList();

    // The hub list can run past a phone screen, so the primary action is
    // pinned rather than left at the bottom of the scroll where it is easy
    // to never reach.
    return Column(
      children: [
        Expanded(child: _buildForm(context, hubs)),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: BoxDecoration(
            color: luma.surface,
            border: Border(top: BorderSide(color: luma.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LumaPrimaryButton(
                label: t.airlineTakeOff,
                icon: Icons.flight_takeoff_rounded,
                expand: true,
                onTap: _hub == null
                    ? null
                    : () => widget.repository.startGame(
                        airlineName: _name.text,
                        hubIata: _hub!,
                      ),
              ),
              if (_hub == null) ...[
                const SizedBox(height: 6),
                Text(
                  t.airlineChooseHubToContinue,
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context, List<Airport> hubs) {
    final luma = context.luma;
    final t = L.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          t.airlineStartAirlineTitle,
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          t.airlinePickHubBlurb,
          style: TextStyle(color: luma.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 20),
        Text(
          t.airlineNameLabel,
          style: TextStyle(color: luma.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _name,
          style: TextStyle(color: luma.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: luma.surfaceHover,
            border: OutlineInputBorder(
              borderRadius: context.lumaDecor.buttonBorderRadius,
              borderSide: BorderSide(color: luma.border),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          t.airlineHomeHubLabel,
          style: TextStyle(color: luma.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        for (final airport in hubs)
          _HubOption(
            airport: airport,
            selected: _hub == airport.iata,
            onTap: () => setState(() => _hub = airport.iata),
          ),
      ],
    );
  }
}

class _HubOption extends StatelessWidget {
  const _HubOption({
    required this.airport,
    required this.selected,
    required this.onTap,
  });

  final Airport airport;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;
    final t = L.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: onTap,
          borderRadius: decor.cardBorderRadius,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? luma.accentSubtle : luma.surface,
              borderRadius: decor.cardBorderRadius,
              border: Border.all(
                color: selected ? luma.accent : luma.border,
                width: decor.borderWidth,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: selected ? luma.accent : luma.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        airport.label,
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        t.airlineHubOptionDetail(
                          airport.name,
                          fmtCount(airport.runwayM),
                          airport.country,
                        ),
                        style: TextStyle(
                          color: luma.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
