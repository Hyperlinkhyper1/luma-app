import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import '../airline_tycoon_repository.dart';
import '../data/aircraft.dart';
import '../sim/airport_contracts.dart' show aircraftSizeClass;
import 'airport_scene_view.dart';
import 'fleet_tab.dart';
import 'routes_tab.dart';

typedef AirportSceneBuilder =
    Widget Function(BuildContext context, AirportSceneBridge bridge);

/// Allows an alternate renderer to use the same authoritative bridge.
class AirportSceneBridge {
  const AirportSceneBridge({
    required this.receive,
    required this.messages,
    required this.snapshot,
    required this.visible,
  });

  /// Hands a message from the page to the airport.
  final void Function(Map<String, Object?> message) receive;

  /// The latest message the airport sent back to the page.
  final ValueNotifier<Map<String, Object?>?> messages;
  final Map<String, Object?> Function() snapshot;
  final bool visible;
}

/// The airport game. Its controls live inside the scene page (see
/// `assets/airline_tycoon/scene/hud.js`); this widget validates the page's
/// commands against the repository and hosts the two panels that stay in
/// Flutter, Fleet and Routes, as full pages over the airport.
class AirportGameView extends StatefulWidget {
  const AirportGameView({
    super.key,
    required this.repository,
    this.sceneBuilder,
  });
  final AirlineTycoonRepository repository;
  final AirportSceneBuilder? sceneBuilder;

  @override
  State<AirportGameView> createState() => _AirportGameViewState();
}

class _AirportGameViewState extends State<AirportGameView> {
  /// Everything the page may ask the repository to do. Anything else is
  /// refused here, before the repository sees it.
  static const _repositoryCommands = {
    'place',
    'move',
    'demolish',
    'buyVehicle',
    'acceptContract',
    'cancelContract',
    'cancelFlight',
    'reassignFlight',
    'moveFlight',
    'unscheduleFlight',
    'placeContract',
    'schedule',
    'speed',
    'pause',
    'resume',
    'dismissAway',
  };
  static const _pages = {'Fleet', 'Routes'};

  final _scene = GlobalKey<AirportSceneViewState>();
  final _sceneMessages = ValueNotifier<Map<String, Object?>?>(null);
  late final Map<String, String> _modelNames = {
    for (final model in kAircraftCatalog) model.id: model.name,
  };
  late final Map<String, String> _modelClasses = {
    for (final model in kAircraftCatalog) model.id: aircraftSizeClass(model),
  };
  String? _page;

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_changed);
  }

  @override
  void didUpdateWidget(AirportGameView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      oldWidget.repository.removeListener(_changed);
      widget.repository.addListener(_changed);
      _changed();
    }
  }

  Map<String, Object?> _snapshot() => {
    ...widget.repository.airportSnapshot(),
    'modelNames': _modelNames,
    'modelClasses': _modelClasses,
  };

  void _changed() {
    if (!mounted) return;
    _scene.currentState?.refresh();
    if (_page != null) setState(() {});
  }

  void _bridge(Map<String, Object?> message) {
    if (message['type'] != 'command') return;
    final action = message['action'];
    final ActionResult result;
    if (action == 'openPage') {
      final page = message['page'];
      if (page is String && _pages.contains(page)) {
        setState(() => _page = page);
        result = const ActionResult.ok();
      } else {
        result = const ActionResult.failed('That panel does not exist.');
      }
    } else if (action == 'retrySave') {
      unawaited(widget.repository.flushAirport());
      result = const ActionResult.ok();
    } else if (action is String && _repositoryCommands.contains(action)) {
      result = widget.repository.airportCommand(action, message);
    } else {
      result = const ActionResult.failed('Unknown airport command.');
    }
    _send({
      'type': 'result',
      'id': message['id'],
      'ok': result.success,
      'message': result.message,
    });
  }

  void _send(Map<String, Object?> message) {
    _scene.currentState?.send(message);
    _sceneMessages.value = message;
  }

  Map<String, String> _palette(LumaPalette luma) {
    String hex(Color color) {
      final argb = color.toARGB32();
      final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
      final alpha = (argb >> 24).toRadixString(16).padLeft(2, '0');
      return '#$rgb$alpha';
    }

    return {
      'bg': hex(luma.background),
      'surface': hex(luma.surface),
      'hover': hex(luma.surfaceHover),
      'border': hex(luma.border),
      'accent': hex(luma.accent),
      'accent-subtle': hex(luma.accentSubtle),
      'on-accent': hex(luma.onAccent),
      'text': hex(luma.textPrimary),
      'text2': hex(luma.textSecondary),
      'muted': hex(luma.textMuted),
      'success': hex(luma.success),
      'danger': hex(luma.danger),
      'warning': hex(luma.warning),
    };
  }

  @override
  void dispose() {
    _sceneMessages.dispose();
    widget.repository.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showingScene = _page == null;
    return Stack(
      children: [
        Positioned.fill(
          child:
              widget.sceneBuilder?.call(
                context,
                AirportSceneBridge(
                  receive: _bridge,
                  messages: _sceneMessages,
                  snapshot: _snapshot,
                  visible: showingScene,
                ),
              ) ??
              AirportSceneView(
                key: _scene,
                snapshot: _snapshot,
                onMessage: _bridge,
                palette: _palette(context.luma),
                visible: showingScene,
              ),
        ),
        if (_page != null)
          Positioned.fill(
            child: Material(
              color: context.luma.background,
              child: Column(
                children: [
                  Material(
                    color: context.luma.surface,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => setState(() => _page = null),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Back to airport'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _page!,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _page == 'Fleet'
                        ? FleetTab(repository: widget.repository)
                        : Column(
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: Text(
                                  'Route estimates assume full-day aircraft use. Airport earnings come from the flights you schedule.',
                                ),
                              ),
                              Expanded(
                                child: RoutesTab(repository: widget.repository),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
