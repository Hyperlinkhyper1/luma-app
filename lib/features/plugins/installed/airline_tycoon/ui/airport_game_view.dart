import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import '../airline_tycoon_repository.dart';
import '../data/aircraft.dart';
import 'airport_scene_view.dart';
import 'fleet_tab.dart';
import 'money.dart';
import 'routes_tab.dart';

typedef AirportSceneBuilder =
    Widget Function(BuildContext context, AirportSceneBridge bridge);

/// Allows an alternate renderer to use the same authoritative bridge.
class AirportSceneBridge {
  const AirportSceneBridge({required this.receive, required this.messages});
  final void Function(Map<String, Object?> message) receive;
  final ValueNotifier<Map<String, Object?>?> messages;
}

/// Airport operations UI; all mutations pass through repository commands.
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
  final _scene = GlobalKey<AirportSceneViewState>();
  final _sceneMessages = ValueNotifier<Map<String, Object?>?>(null);
  late Map<String, Object?> _world;
  String? _panel;
  String? _selected;
  String? _tool;
  String? _moveId;
  int _rotation = 0;
  bool _cutaway = false;
  bool _grid = false;
  bool _highQuality = true;
  bool _compactLayout = false;
  String? _notice;
  bool _noticeError = false;
  String? _aircraft;
  String? _route;
  String _stand = '';
  int _departureDelay = 120;

  List<Map<String, Object?>> _list(String key) => ((_world[key] as List?) ?? [])
      .whereType<Map>()
      .map((e) => Map<String, Object?>.from(e))
      .toList();

  @override
  void initState() {
    super.initState();
    _world = widget.repository.airportSnapshot();
    widget.repository.addListener(_changed);
  }

  @override
  void didUpdateWidget(AirportGameView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      oldWidget.repository.removeListener(_changed);
      widget.repository.addListener(_changed);
      _world = widget.repository.airportSnapshot();
    }
  }

  void _changed() {
    if (!mounted) return;
    _world = widget.repository.airportSnapshot();
    _scene.currentState?.refresh();
    setState(() {});
  }

  ActionResult _command(String action, [Map<String, Object?> args = const {}]) {
    final result = widget.repository.airportCommand(action, args);
    if (mounted) {
      setState(() {
        _noticeError = !result.success;
        _notice =
            result.message ??
            (result.success
                ? 'Airport updated.'
                : 'Unable to complete that action.');
      });
    }
    return result;
  }

  void _bridge(Map<String, Object?> message) {
    if (message['type'] == 'ready') {
      _view('cutaway', _cutaway);
      _view('grid', _grid);
      _view('quality', _highQuality ? 'high' : 'low');
      _setTool(_tool, moveId: _moveId);
      return;
    }
    if (message['type'] != 'command') return;
    final action = message['action'];
    if (action == 'select') {
      setState(() {
        _selected = message['facilityId'] as String?;
        _panel = 'Build';
      });
      return;
    }
    if (action != 'place' && action != 'move') return;
    final result = _command(action as String, message);
    _send({
      'type': 'result',
      'id': message['id'],
      'ok': result.success,
      'message': result.message,
    });
    if (result.success && action == 'move') _setTool(null);
  }

  void _send(Map<String, Object?> message) {
    _scene.currentState?.send(message);
    _sceneMessages.value = message;
  }

  void _view(String action, [Object? value, String? id]) =>
      _send({'type': 'view', 'action': action, 'value': value, 'id': id});

  void _setTool(String? kind, {String? moveId}) {
    setState(() {
      _tool = kind;
      _moveId = moveId;
      if (_compactLayout && kind != null) _panel = null;
    });
    _send({
      'type': 'tool',
      'kind': kind,
      'rotation': _rotation,
      'moveId': moveId,
    });
  }

  @override
  void dispose() {
    _sceneMessages.dispose();
    widget.repository.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final world = _world;
    final paused = world['paused'] == true;
    final time = (world['time'] as num? ?? 0).toInt();
    final clock =
        '${((time ~/ 60) % 24).toString().padLeft(2, '0')}:${(time % 60).toString().padLeft(2, '0')}';
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 820;
        _compactLayout = narrow;
        return Column(
          children: [
            Container(
              color: context.luma.surface,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${widget.repository.state.hubIata} / ${widget.repository.state.airlineName}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    fmtMoney(
                      (world['cash'] as num? ?? widget.repository.state.cashEur)
                          .round(),
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  Text('DAY ${world['day'] ?? 1} · $clock'),
                  IconButton.filledTonal(
                    tooltip: paused ? 'Resume airport' : 'Pause airport',
                    onPressed: () => _command(paused ? 'resume' : 'pause'),
                    icon: Icon(
                      paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    ),
                  ),
                  for (final speed in [1, 4, 12])
                    ChoiceChip(
                      label: Text('$speed×'),
                      selected: world['speed'] == speed,
                      onSelected: (_) => _command('speed', {'speed': speed}),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child:
                        widget.sceneBuilder?.call(
                          context,
                          AirportSceneBridge(
                            receive: _bridge,
                            messages: _sceneMessages,
                          ),
                        ) ??
                        AirportSceneView(
                          key: _scene,
                          snapshot: () => _world,
                          onMessage: _bridge,
                        ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    right: narrow ? 10 : (_panel == null ? 10 : 410),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        color: context.luma.surface,
                        elevation: 2,
                        borderRadius: BorderRadius.circular(8),
                        child: Wrap(
                          children: [
                            _viewButton(
                              'Fit airport',
                              Icons.zoom_out_map,
                              () => _view('fit'),
                            ),
                            _viewButton(
                              'Reset camera',
                              Icons.restart_alt,
                              () => _view('reset'),
                            ),
                            _viewButton('Terminal cutaway', Icons.roofing, () {
                              setState(() => _cutaway = !_cutaway);
                              _view('cutaway', _cutaway);
                            }, selected: _cutaway),
                            _viewButton(
                              'Construction grid',
                              Icons.grid_4x4,
                              () {
                                setState(() => _grid = !_grid);
                                _view('grid', _grid);
                              },
                              selected: _grid,
                            ),
                            _viewButton(
                              _highQuality
                                  ? 'Quality: high'
                                  : 'Quality: performance',
                              Icons.speed,
                              () {
                                setState(() => _highQuality = !_highQuality);
                                _view('quality', _highQuality ? 'high' : 'low');
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_panel != null)
                    Positioned(
                      top: narrow ? null : 10,
                      right: narrow ? 0 : 10,
                      bottom: 0,
                      left: narrow ? 0 : null,
                      width: narrow ? null : 390,
                      height: narrow ? constraints.maxHeight * .48 : null,
                      child: Material(
                        elevation: 5,
                        color: context.luma.surface,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              dense: true,
                              title: Text(
                                _panel!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              trailing: IconButton(
                                tooltip: 'Close panel',
                                onPressed: () => setState(() => _panel = null),
                                icon: const Icon(Icons.close),
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(child: _panelContent()),
                          ],
                        ),
                      ),
                    ),
                  if (_panel == null &&
                      _tool == null &&
                      paused &&
                      _list('flights').isEmpty)
                    Positioned(
                      left: 12,
                      bottom: 12,
                      width: narrow ? 270 : 320,
                      child: Material(
                        color: context.luma.surface,
                        elevation: 3,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Your first departure',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '1. Sign a regional airline or open your own route.\n2. Check the flight schedule.\n3. Resume your airport and follow the turnaround.',
                              ),
                              const SizedBox(height: 10),
                              FilledButton(
                                onPressed: () =>
                                    setState(() => _panel = 'Contracts'),
                                child: const Text('Meet the airlines'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_tool != null)
                    Positioned(
                      left: 12,
                      right: narrow || _panel == null ? 12 : 410,
                      bottom: _panel != null && narrow
                          ? constraints.maxHeight * .48 + 8
                          : 12,
                      child: Material(
                        color: context.luma.surface,
                        elevation: 3,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  '${_moveId == null ? 'Place' : 'Move'} ${_facilityName(_tool)}${_toolCost()}',
                                ),
                              ),
                              IconButton(
                                tooltip: 'Rotate 90°',
                                onPressed: () {
                                  _rotation = (_rotation + 1) % 4;
                                  _setTool(_tool, moveId: _moveId);
                                },
                                icon: const Icon(Icons.rotate_right),
                              ),
                              IconButton(
                                tooltip: 'Cancel construction',
                                onPressed: () => _setTool(null),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (world['saveError'] != null)
              Material(
                color: context.luma.danger.withValues(alpha: .12),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.save_outlined),
                  title: Text('${world['saveError']}'),
                  trailing: TextButton(
                    onPressed: () =>
                        unawaited(widget.repository.flushAirport()),
                    child: const Text('Retry save'),
                  ),
                ),
              ),
            if (world['awayReport'] is Map)
              _awayBanner(
                Map<String, Object?>.from(world['awayReport'] as Map),
              ),
            if (_notice != null)
              Material(
                color: _noticeError
                    ? context.luma.danger.withValues(alpha: .12)
                    : context.luma.accentSubtle,
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    _noticeError
                        ? Icons.info_outline
                        : Icons.check_circle_outline,
                  ),
                  title: Text(_notice!),
                  trailing: IconButton(
                    tooltip: 'Dismiss message',
                    onPressed: () => setState(() => _notice = null),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    for (final item in const [
                      ('Build', Icons.construction),
                      ('Fleet', Icons.flight),
                      ('Routes', Icons.route),
                      ('Contracts', Icons.handshake_outlined),
                      ('Schedule', Icons.calendar_month),
                      ('Finances', Icons.account_balance_wallet_outlined),
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            backgroundColor: _panel == item.$1
                                ? context.luma.accentSubtle
                                : null,
                          ),
                          onPressed: () => setState(
                            () => _panel = _panel == item.$1 ? null : item.$1,
                          ),
                          icon: Icon(item.$2, size: 18),
                          label: Text(item.$1),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _awayBanner(Map<String, Object?> report) => Material(
    color: context.luma.accentSubtle,
    child: ListTile(
      dense: true,
      leading: const Icon(Icons.history),
      title: Text(
        'While you were away · ${fmtMoney((report['profit'] as num? ?? 0).round())} · ${report['passengers']} passengers',
      ),
      subtitle: Text('${report['minutes']}'),
      trailing: IconButton(
        tooltip: 'Dismiss away report',
        onPressed: () => _command('dismissAway'),
        icon: const Icon(Icons.close),
      ),
    ),
  );

  Widget _viewButton(
    String label,
    IconData icon,
    VoidCallback action, {
    bool selected = false,
  }) => IconButton(
    tooltip: label,
    isSelected: selected,
    onPressed: action,
    icon: Icon(icon),
  );

  Widget _panelContent() => switch (_panel) {
    'Fleet' => FleetTab(repository: widget.repository),
    'Routes' => Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Route estimates assume full-day aircraft use. Airport earnings come from the flights you schedule.',
          ),
        ),
        Expanded(child: RoutesTab(repository: widget.repository)),
      ],
    ),
    'Build' => _buildPanel(),
    'Contracts' => _contractsPanel(),
    'Schedule' => _schedulePanel(),
    'Finances' => _financesPanel(),
    _ => const SizedBox.shrink(),
  };

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
  );

  Widget _buildPanel() {
    final selected = _list(
      'facilities',
    ).where((f) => f['id'] == _selected).firstOrNull;
    return ListView(
      children: [
        if (selected != null) ...[
          _heading('Selected · ${_facilityName(selected['kind'])}'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${selected['width']} × ${selected['depth']} m · ${selected['connected'] == true ? 'Connected' : 'Disconnected — connect paths to operate'}',
            ),
          ),
          Wrap(
            children: [
              TextButton.icon(
                onPressed: () => _view('focus', null, _selected),
                icon: const Icon(Icons.center_focus_strong),
                label: const Text('Focus'),
              ),
              TextButton.icon(
                onPressed: () {
                  _rotation = (selected['rotation'] as num? ?? 0).toInt();
                  _setTool(selected['kind'] as String, moveId: _selected);
                },
                icon: const Icon(Icons.open_with),
                label: const Text('Move'),
              ),
              TextButton.icon(
                onPressed: () {
                  if (_command('demolish', {'facilityId': _selected}).success) {
                    setState(() => _selected = null);
                  }
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Demolish'),
              ),
            ],
          ),
          const Divider(),
        ],
        _heading('AIRFIELD & TERMINAL'),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Choose a facility, then tap the ground to build. Rotate before placing. Indoor furniture needs a terminal.',
          ),
        ),
        for (final item in _list('catalog'))
          ListTile(
            selected: _tool == item['kind'],
            dense: true,
            leading: Icon(
              item['interior'] == true
                  ? Icons.chair_outlined
                  : Icons.domain_outlined,
            ),
            title: Text('${item['name']}'),
            subtitle: Text(
              '${item['blurb'] ?? ''}\n${item['width']} × ${item['depth']} m · ${fmtMoney((item['cost'] as num? ?? 0).round())}',
            ),
            isThreeLine: true,
            onTap: () => _setTool(item['kind'] as String),
          ),
        _heading('GROUND SERVICE VEHICLES'),
        for (final kind in ['fuel', 'baggage', 'bus', 'pushback'])
          ListTile(
            title: Text(_vehicleName(kind)),
            trailing: OutlinedButton(
              onPressed: () => _command('buyVehicle', {'kind': kind}),
              child: Text(_vehiclePrice(kind)),
            ),
          ),
      ],
    );
  }

  List<Map<String, Object?>> get _activeContracts => _list('contracts')
      .where(
        (contract) =>
            contract['cancelled'] != true &&
            (contract['endDay'] as num? ?? 0) >= (_world['day'] as num? ?? 1),
      )
      .toList();

  Widget _contractsPanel() => ListView(
    children: [
      _heading('START YOUR AIRPORT'),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          '1. Accept a regional airline contract, or open a route for your fleet.\n2. Check the Schedule.\n3. Press Resume and follow your first turnaround.',
        ),
      ),
      _heading('AIRLINE OFFERS · SEVEN DAYS'),
      for (final offer in _list('offers'))
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${offer['carrier']}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              Text(
                '${_modelName(offer['modelId'])} · ${offer['flightsPerDay']} flights/day · ${fmtMoney((offer['fee'] as num? ?? 0).round())} / flight',
              ),
              Text(
                'Requires ${offer['runwayM']} m runway and ${(offer['requiredServices'] as List? ?? []).map(_facilityName).join(', ')}.',
              ),
              Text(
                'Cancellation penalty: ${fmtMoney((offer['penalty'] as num? ?? 0).round())}',
              ),
              if (offer['blockedReason'] != null)
                Text(
                  '${offer['blockedReason']}',
                  style: TextStyle(color: context.luma.danger),
                ),
              const SizedBox(height: 6),
              FilledButton(
                onPressed: offer['blockedReason'] != null
                    ? null
                    : () =>
                          _command('acceptContract', {'offerId': offer['id']}),
                child: const Text('Accept contract'),
              ),
              const Divider(),
            ],
          ),
        ),
      _heading('ACTIVE CONTRACTS'),
      if (_activeContracts.isEmpty)
        const ListTile(title: Text('No active airline contracts.')),
      for (final contract in _activeContracts)
        ListTile(
          title: Text('${contract['carrier']}'),
          subtitle: Text(
            'Days ${contract['startDay']}–${contract['endDay']} · Satisfaction ${((contract['satisfaction'] as num? ?? 0) * 100).round()}%\nCancel remaining flights: ${fmtExactMoney((contract['cancelCost'] as num? ?? 0).round())}',
          ),
          trailing: IconButton(
            tooltip:
                'Cancel contract · ${fmtExactMoney((contract['cancelCost'] as num? ?? 0).round())}',
            onPressed: () =>
                _command('cancelContract', {'contractId': contract['id']}),
            icon: const Icon(Icons.cancel_outlined),
          ),
        ),
    ],
  );

  Widget _schedulePanel() {
    final fleet = _list('fleet');
    final routes = _list('routes');
    final stands = _list(
      'facilities',
    ).where((e) => e['kind'] == 'stand').toList();
    if (!fleet.any((e) => e['id'] == _aircraft)) {
      _aircraft = fleet.firstOrNull?['id'] as String?;
    }
    if (!routes.any((e) => e['id'] == _route)) {
      _route = routes.firstOrNull?['id'] as String?;
    }
    if (!stands.any((e) => e['id'] == _stand)) _stand = '';
    return ListView(
      children: [
        _heading('SCHEDULE YOUR FLEET'),
        if (fleet.isEmpty || routes.isEmpty)
          const ListTile(
            title: Text('Acquire an aircraft and open a route first.'),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                _dropdown(
                  'Aircraft',
                  _aircraft,
                  fleet
                      .map(
                        (e) => (
                          e['id'] as String,
                          '${e['registration']} · ${_modelName(e['modelId'])}',
                        ),
                      )
                      .toList(),
                  (v) => setState(() => _aircraft = v),
                ),
                _dropdown(
                  'Route',
                  _route,
                  routes
                      .map((e) => (e['id'] as String, '${e['destIata']}'))
                      .toList(),
                  (v) => setState(() => _route = v),
                ),
                _dropdown('Stand', _stand, [
                  ('', 'Automatic assignment'),
                  ...stands.map(
                    (e) => (e['id'] as String, _standName(e['id'])),
                  ),
                ], (v) => setState(() => _stand = v ?? '')),
                _dropdown(
                  'Departure',
                  '$_departureDelay',
                  const [
                    ('120', 'In 2 game hours'),
                    ('240', 'In 4 game hours'),
                    ('480', 'In 8 game hours'),
                    ('1440', 'In 24 game hours'),
                  ],
                  (v) => setState(() => _departureDelay = int.parse(v!)),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => _command('schedule', {
                    'aircraftId': _aircraft,
                    'routeId': _route,
                    'standId': _stand,
                    'departure':
                        (_world['time'] as num? ?? 0) + _departureDelay,
                  }),
                  icon: const Icon(Icons.add),
                  label: const Text('Schedule flight'),
                ),
              ],
            ),
          ),
        _heading('FLIGHT BOARD'),
        if (_list('flights').isEmpty)
          const ListTile(
            title: Text(
              'No flights scheduled. Accept a contract or schedule your fleet.',
            ),
          ),
        for (final flight in _list('flights').reversed.take(100))
          ListTile(
            dense: true,
            title: Text(
              '${flight['carrier']} · ${_modelName(flight['modelId'])}',
            ),
            subtitle: Text(
              '${_stageName(flight['stage'])} · ${_standName(flight['standId'])} · ${_flightTime(flight['departure'])}\nBoarded ${flight['boarded']}/${flight['passengers']} · Delay ${flight['delay']} min',
            ),
            isThreeLine: true,
            trailing: ['completed', 'cancelled'].contains(flight['stage'])
                ? null
                : IconButton(
                    tooltip: 'Cancel flight',
                    onPressed: () =>
                        _command('cancelFlight', {'flightId': flight['id']}),
                    icon: const Icon(Icons.cancel_outlined),
                  ),
          ),
      ],
    );
  }

  Widget _dropdown(
    String label,
    String? value,
    List<(String, String)> items,
    ValueChanged<String?> changed,
  ) => DropdownButtonFormField<String>(
    key: ValueKey('$label:$value'),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: items
        .map(
          (item) => DropdownMenuItem(
            value: item.$1,
            child: Text(item.$2, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: changed,
  );

  String _friendly(Object? value) {
    final text = '${value ?? ''}'
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAll('_', ' ');
    return text.isEmpty
        ? 'Unknown'
        : '${text[0].toUpperCase()}${text.substring(1)}';
  }

  String _facilityName(Object? kind) =>
      _list('catalog').where((e) => e['kind'] == kind).firstOrNull?['name']
          as String? ??
      switch (kind) {
        'checkIn' => 'Check-in desks',
        'boardingGate' => 'Boarding gate',
        'fuel' => 'Fuel service',
        'baggage' => 'Baggage service',
        'bus' => 'Passenger bus',
        'pushback' => 'Pushback service',
        _ => _friendly(kind),
      };

  String _modelName(Object? id) =>
      kAircraftCatalog.where((e) => e.id == id).firstOrNull?.name ??
      _friendly(id);

  String _vehicleName(String kind) => switch (kind) {
    'fuel' => 'Fuel truck',
    'baggage' => 'Baggage tug',
    'bus' => 'Passenger bus',
    'pushback' => 'Pushback tug',
    _ => _friendly(kind),
  };

  String _stageName(Object? stage) => switch (stage) {
    'approach' => 'On approach',
    'taxiIn' => 'Taxiing to stand',
    'taxiOut' => 'Taxiing to runway',
    'unloading' => 'Unloading passengers',
    'servicing' => 'Ground services',
    'departing' => 'Taking off',
    'remote' || 'enRoute' => 'Flying the route',
    _ => _friendly(stage),
  };

  String _standName(Object? id) {
    final stands = _list(
      'facilities',
    ).where((e) => e['kind'] == 'stand').toList();
    final index = stands.indexWhere((e) => e['id'] == id);
    return index < 0 ? 'Unassigned stand' : 'Stand ${index + 1}';
  }

  String _toolCost() {
    if (_moveId != null) return '';
    final cost = _list(
      'catalog',
    ).where((e) => e['kind'] == _tool).firstOrNull?['cost'];
    return cost is num ? ' · ${fmtMoney(cost.round())}' : '';
  }

  String _vehiclePrice(String kind) {
    final costs = _world['vehicleCosts'];
    final amount = costs is Map ? costs[kind] : null;
    return amount is num ? 'Buy · ${fmtMoney(amount.round())}' : 'Buy';
  }

  String _flightTime(Object? value) {
    final minutes = value is num ? value.toInt() : 0;
    return 'D${minutes ~/ 1440 + 1} ${(minutes ~/ 60 % 24).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
  }

  Widget _financesPanel() => ListView(
    children: [
      _heading('AIRPORT ACCOUNTS'),
      ListTile(
        title: const Text('Available cash'),
        trailing: Text(
          fmtMoney((_world['cash'] as num? ?? 0).round()),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          'Flights settle once on completion. This ledger includes airline handling, owned flights, retail, service costs and upkeep.',
        ),
      ),
      _heading('TRANSACTIONS'),
      if (_list('ledger').isEmpty)
        const ListTile(title: Text('Your transactions will appear here.')),
      for (final entry in _list('ledger').reversed.take(150))
        ListTile(
          dense: true,
          title: Text('${entry['description']}'),
          subtitle: Text(
            '${_friendly(entry['category'])} · Day ${((entry['time'] as num? ?? 0) / 1440).floor() + 1}',
          ),
          trailing: Text(fmtMoney((entry['amount'] as num? ?? 0).round())),
        ),
    ],
  );
}

