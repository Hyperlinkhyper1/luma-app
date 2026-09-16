import 'dart:math' as math;

import '../airline_game_state.dart';
import '../data/aircraft.dart';
import '../data/airport_catalog.dart';
import 'economy.dart';
import 'geo.dart';
import 'hub.dart';

typedef Json = Map<String, Object?>;

double _number(Json j, String key, [double fallback = 0]) =>
    (j[key] as num?)?.toDouble() ?? fallback;

List<Json> _objects(Object? value) => value is List
    ? value.whereType<Map>().map((m) => Map<String, Object?>.from(m)).toList()
    : [];

class AirportFacilityDef {
  const AirportFacilityDef(
    this.kind,
    this.name,
    this.width,
    this.depth,
    this.height,
    this.cost,
    this.blurb, {
    this.interior = false,
  });
  final String kind;
  final String name;
  final double width, depth, height;
  final int cost;
  final String blurb;
  final bool interior;
  Json toJson() => {
    'kind': kind,
    'name': name,
    'width': width,
    'depth': depth,
    'height': height,
    'cost': cost,
    'interior': interior,
    'blurb': blurb,
  };
}

const airportFacilities = <AirportFacilityDef>[
  AirportFacilityDef(
    'runway',
    'Runway · 1,800 m',
    45,
    1800,
    .15,
    6000000,
    'Regional runway. Connect it to stands with taxiways.',
  ),
  AirportFacilityDef(
    'runwayMedium',
    'Runway · 2,600 m',
    45,
    2600,
    .15,
    13000000,
    'Supports narrowbody aircraft.',
  ),
  AirportFacilityDef(
    'runwayLong',
    'Runway · 3,400 m',
    60,
    3400,
    .15,
    24000000,
    'Supports long-haul widebodies.',
  ),
  AirportFacilityDef(
    'taxiway',
    'Taxiway',
    20,
    100,
    .1,
    60000,
    'Connect touching taxiways between a runway and a stand.',
  ),
  AirportFacilityDef(
    'stand',
    'Aircraft stand',
    60,
    65,
    .12,
    1200000,
    'One aircraft at a time. Needs taxiway, service road and a nearby boarding gate.',
  ),
  AirportFacilityDef(
    'terminal',
    'Terminal section',
    120,
    60,
    12,
    4000000,
    'Furnish its interior with passenger services.',
  ),
  AirportFacilityDef(
    'serviceRoad',
    'Service road',
    10,
    100,
    .08,
    20000,
    'Connect vehicle depots and services to aircraft stands.',
  ),
  AirportFacilityDef(
    'hangar',
    'Maintenance hangar',
    60,
    60,
    22,
    3000000,
    'Connected hangars reduce aircraft maintenance costs.',
  ),
  AirportFacilityDef(
    'fuelDepot',
    'Fuel depot',
    30,
    30,
    10,
    2000000,
    'Fuel supply for ground-service trucks.',
  ),
  AirportFacilityDef(
    'baggage',
    'Baggage facility',
    30,
    20,
    8,
    800000,
    'Baggage handling for every departure.',
  ),
  AirportFacilityDef(
    'vehicleDepot',
    'Vehicle depot',
    30,
    30,
    9,
    500000,
    'Purchase service vehicles; connect this to a service road.',
  ),
  AirportFacilityDef(
    'tower',
    'Control tower',
    15,
    15,
    38,
    1500000,
    'Airport landmark and flight control centre.',
  ),
  AirportFacilityDef(
    'entrance',
    'Entrance',
    6,
    4,
    3,
    15000,
    'Passenger entry to connected terminal sections.',
    interior: true,
  ),
  AirportFacilityDef(
    'checkIn',
    'Check-in desks',
    8,
    4,
    2,
    45000,
    'Process 8 passengers per game minute.',
    interior: true,
  ),
  AirportFacilityDef(
    'security',
    'Security lane',
    8,
    6,
    3,
    90000,
    'Screen 6 passengers per game minute.',
    interior: true,
  ),
  AirportFacilityDef(
    'seating',
    'Seating',
    8,
    4,
    1,
    12000,
    'Comfort for waiting passengers.',
    interior: true,
  ),
  AirportFacilityDef(
    'toilets',
    'Toilets',
    10,
    8,
    3,
    50000,
    'Essential passenger amenity.',
    interior: true,
  ),
  AirportFacilityDef(
    'cafe',
    'Café',
    12,
    8,
    3,
    85000,
    'Passenger satisfaction and retail income.',
    interior: true,
  ),
  AirportFacilityDef(
    'boardingGate',
    'Boarding gate',
    8,
    4,
    3,
    120000,
    'Place within 25 m of an aircraft stand.',
    interior: true,
  ),
];

AirportFacilityDef facilityDef(String kind) =>
    airportFacilities.firstWhere((d) => d.kind == kind);

class AirportFacility {
  AirportFacility({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    this.rotation = 0,
    double? width,
    double? depth,
  }) : width =
           width ??
           (rotation.isOdd ? facilityDef(kind).depth : facilityDef(kind).width),
       depth =
           depth ??
           (rotation.isOdd ? facilityDef(kind).width : facilityDef(kind).depth);
  final String id, kind;
  double x, y, width, depth;
  int rotation;
  bool connected = false;
  double get cx => x + width / 2;
  double get cy => y + depth / 2;
  bool get runway => kind.startsWith('runway');
  bool get interior => facilityDef(kind).interior;
  bool contains(double px, double py) =>
      px >= x && px <= x + width && py >= y && py <= y + depth;
  bool overlaps(AirportFacility b) =>
      x < b.x + b.width - .01 &&
      x + width > b.x + .01 &&
      y < b.y + b.depth - .01 &&
      y + depth > b.y + .01;
  double gap(AirportFacility b) {
    final dx = math.max(0.0, math.max(x - b.x - b.width, b.x - x - width));
    final dy = math.max(0.0, math.max(y - b.y - b.depth, b.y - y - depth));
    return math.sqrt(dx * dx + dy * dy);
  }

  Json toJson() => {
    'id': id,
    'kind': kind,
    'x': x,
    'y': y,
    'width': width,
    'depth': depth,
    'height': facilityDef(kind).height,
    'rotation': rotation,
    'connected': connected,
  };
  factory AirportFacility.fromJson(Json j) => AirportFacility(
    id: j['id'] as String,
    kind: j['kind'] as String,
    x: _number(j, 'x'),
    y: _number(j, 'y'),
    rotation: (j['rotation'] as num?)?.toInt() ?? 0,
    width: _number(j, 'width'),
    depth: _number(j, 'depth'),
  );
}

class AirportOffer {
  const AirportOffer(
    this.id,
    this.carrier,
    this.modelId,
    this.flightsPerDay,
    this.fee,
    this.penalty,
    this.requiredServices,
  );
  final String id, carrier, modelId;
  final int flightsPerDay, fee, penalty;
  final List<String> requiredServices;
  Json toJson() => {
    'id': id,
    'carrier': carrier,
    'modelId': modelId,
    'flightsPerDay': flightsPerDay,
    'fee': fee,
    'penalty': penalty,
    'requiredServices': requiredServices,
    'runwayM': aircraftModelById(modelId)!.minRunwayM,
  };
}

const airportOffers = [
  AirportOffer('coastal', 'Coastal Connect', 'atr72', 2, 42000, 12000, [
    'fuelDepot',
    'baggage',
  ]),
  AirportOffer('meridian', 'Meridian Airways', 'a320neo', 3, 95000, 30000, [
    'fuelDepot',
    'baggage',
    'cafe',
  ]),
  AirportOffer('aurora', 'Aurora International', 'b787_9', 2, 160000, 55000, [
    'fuelDepot',
    'baggage',
    'cafe',
    'seating',
    'toilets',
  ]),
];

class AirportContract {
  AirportContract(
    this.id,
    this.offerId,
    this.startDay,
    this.endDay, {
    this.satisfaction = 1,
    this.cancelled = false,
  });
  final String id, offerId;
  final int startDay, endDay;
  double satisfaction;
  bool cancelled;
  AirportOffer get offer => airportOffers.firstWhere((o) => o.id == offerId);
  Json toJson() => {
    'id': id,
    'offerId': offerId,
    'carrier': offer.carrier,
    'startDay': startDay,
    'endDay': endDay,
    'satisfaction': satisfaction,
    'cancelled': cancelled,
  };
  factory AirportContract.fromJson(Json j) => AirportContract(
    j['id'] as String,
    j['offerId'] as String,
    (j['startDay'] as num).toInt(),
    (j['endDay'] as num).toInt(),
    satisfaction: _number(j, 'satisfaction', 1),
    cancelled: j['cancelled'] == true,
  );
}

class AirportFlight {
  AirportFlight({
    required this.id,
    required this.carrier,
    required this.modelId,
    required this.standId,
    required this.arrival,
    required this.departure,
    this.aircraftId,
    this.routeId,
    this.contractId,
    this.passengers = 0,
  });
  final String id, carrier, modelId, standId;
  final String? aircraftId, routeId, contractId;
  final double arrival, departure;
  String stage = 'scheduled';
  double stageStart = 0, nextEvent = 0, delay = 0;
  double x = 0, y = 0, z = 0, heading = 0;
  int passengers, boarded = 0;
  bool settled = false;
  bool returning = false, returnSettled = false;
  double returnAt = 0;
  String? issue;
  List<String> serviced = [];
  List<List<double>> path = [];
  bool get finished => stage == 'completed' || stage == 'cancelled';
  Json toJson() => {
    'id': id,
    'carrier': carrier,
    'modelId': modelId,
    'standId': standId,
    'arrival': arrival,
    'departure': departure,
    'aircraftId': aircraftId,
    'routeId': routeId,
    'contractId': contractId,
    'stage': stage,
    'stageStart': stageStart,
    'nextEvent': nextEvent,
    'delay': delay,
    'x': x,
    'y': y,
    'z': z,
    'heading': heading,
    'passengers': passengers,
    'boarded': boarded,
    'settled': settled,
    'returning': returning,
    'returnSettled': returnSettled,
    'returnAt': returnAt,
    'issue': issue,
    'serviced': serviced,
    'path': path,
  };
  factory AirportFlight.fromJson(Json j) {
    final f = AirportFlight(
      id: j['id'] as String,
      carrier: j['carrier'] as String,
      modelId: j['modelId'] as String,
      standId: j['standId'] as String,
      arrival: _number(j, 'arrival'),
      departure: _number(j, 'departure'),
      aircraftId: j['aircraftId'] as String?,
      routeId: j['routeId'] as String?,
      contractId: j['contractId'] as String?,
      passengers: (_number(j, 'passengers')).toInt(),
    );
    f.stage = j['stage'] as String? ?? 'scheduled';
    f.stageStart = _number(j, 'stageStart');
    f.nextEvent = _number(j, 'nextEvent');
    f.delay = _number(j, 'delay');
    f.x = _number(j, 'x');
    f.y = _number(j, 'y');
    f.z = _number(j, 'z');
    f.heading = _number(j, 'heading');
    f.boarded = _number(j, 'boarded').toInt();
    f.settled = j['settled'] == true;
    f.returning = j['returning'] == true;
    f.returnSettled = j['returnSettled'] == true;
    f.returnAt = _number(j, 'returnAt');
    f.issue = j['issue'] as String?;
    f.serviced = (j['serviced'] as List? ?? []).cast<String>().toList();
    f.path = (j['path'] as List? ?? [])
        .map((p) => (p as List).map((n) => (n as num).toDouble()).toList())
        .toList();
    return f;
  }
}

class AirportVehicle {
  AirportVehicle(this.id, this.kind, this.x, this.y);
  final String id, kind;
  double x, y, heading = 0, busyUntil = 0, started = 0;
  String? flightId;
  bool returning = false;
  List<List<double>> path = [];
  Json toJson() => {
    'id': id,
    'kind': kind,
    'x': x,
    'y': y,
    'heading': heading,
    'busyUntil': busyUntil,
    'started': started,
    'flightId': flightId,
    'returning': returning,
    'path': path,
  };
  factory AirportVehicle.fromJson(Json j) {
    final v = AirportVehicle(
      j['id'] as String,
      j['kind'] as String,
      _number(j, 'x'),
      _number(j, 'y'),
    );
    v.heading = _number(j, 'heading');
    v.busyUntil = _number(j, 'busyUntil');
    v.started = _number(j, 'started');
    v.flightId = j['flightId'] as String?;
    v.returning = j['returning'] == true;
    v.path = (j['path'] as List? ?? [])
        .map((p) => (p as List).map((n) => (n as num).toDouble()).toList())
        .toList();
    return v;
  }
}

class AirportPassengerGroup {
  AirportPassengerGroup(this.id, this.flightId, this.count, this.x, this.y);
  final String id, flightId;
  final int count;
  String stage = 'entrance';
  double x, y, satisfaction = 1, nextEvent = 0, started = 0;
  String? facilityId;
  List<List<double>> path = [];
  Json toJson() => {
    'id': id,
    'flightId': flightId,
    'count': count,
    'stage': stage,
    'x': x,
    'y': y,
    'satisfaction': satisfaction,
    'nextEvent': nextEvent,
    'started': started,
    'facilityId': facilityId,
    'path': path,
  };
  factory AirportPassengerGroup.fromJson(Json j) {
    final p = AirportPassengerGroup(
      j['id'] as String,
      j['flightId'] as String,
      _number(j, 'count').toInt(),
      _number(j, 'x'),
      _number(j, 'y'),
    );
    p.stage = j['stage'] as String? ?? 'entrance';
    p.satisfaction = _number(j, 'satisfaction', 1);
    p.nextEvent = _number(j, 'nextEvent');
    p.started = _number(j, 'started');
    p.facilityId = j['facilityId'] as String?;
    p.path = (j['path'] as List? ?? [])
        .map((q) => (q as List).map((n) => (n as num).toDouble()).toList())
        .toList();
    return p;
  }
}

/// Authoritative airport simulation. Time is measured in game minutes.
/// All mutations enter through repository commands; rendering only reads it.
class AirportWorld {
  double time = 360;
  bool paused = true;
  int speed = 1, nextId = 1;
  int lastSeenEpochMs = 0;
  final List<AirportFacility> facilities = [];
  final List<AirportFlight> flights = [];
  final List<AirportContract> contracts = [];
  final List<AirportVehicle> vehicles = [];
  final List<AirportPassengerGroup> passengers = [];
  final List<Json> ledger = [];
  final Map<String, String> reservations = {};
  final Map<String, double> queues = {};
  String? lastError;
  int get day => time ~/ 1440 + 1;
  String _id(String prefix) => '$prefix${nextId++}';
  AirportFacility? facility(String? id) {
    for (final f in facilities) {
      if (f.id == id) return f;
    }
    return null;
  }

  AirportContract? contract(String? id) {
    for (final c in contracts) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<AirportFacility> ofKind(String kind) =>
      facilities.where((f) => f.kind == kind).toList();
  List<AirportFacility> get stands => ofKind('stand');
  bool hasService(String kind) =>
      facilities.any((f) => f.kind == kind && f.connected);

  factory AirportWorld.starter() {
    final w = AirportWorld();
    void add(String kind, double x, double y, {double? width, double? depth}) =>
        w.facilities.add(
          AirportFacility(
            id: w._id('b'),
            kind: kind,
            x: x,
            y: y,
            width: width,
            depth: depth,
          ),
        );
    add('runway', -500, -900);
    add('taxiway', -370, -850, width: 20, depth: 1700);
    add('taxiway', -455, 0, width: 105, depth: 20);
    add('taxiway', -350, -65, width: 30, depth: 20);
    add('taxiway', -350, 5, width: 30, depth: 20);
    add('stand', -320, -90);
    add('stand', -320, -20);
    add('terminal', -250, -90);
    add('terminal', -250, -30);
    add('serviceRoad', -260, -100, width: 10, depth: 230);
    add('fuelDepot', -290, 100);
    add('baggage', -250, 100);
    add('vehicleDepot', -260, 130);
    add('hangar', -330, 140);
    add('tower', -210, 140);
    add('entrance', -142, -65);
    add('checkIn', -160, -62);
    add('security', -180, -62);
    add('seating', -205, -68);
    add('toilets', -148, -40);
    add('cafe', -200, -40);
    add('boardingGate', -247, -62);
    add('boardingGate', -247, 8);
    for (final kind in ['fuel', 'baggage', 'bus', 'pushback']) {
      w.vehicles.add(AirportVehicle(w._id('v'), kind, -255, 145));
    }
    w.resolveConnections();
    return w;
  }
  AirportWorld();

  /// Graph paths use orthogonal shared boundaries; diagonal contact isn't a road.
  bool _touch(AirportFacility a, AirportFacility b, [double tolerance = .1]) {
    final overlapX =
        math.min(a.x + a.width, b.x + b.width) - math.max(a.x, b.x);
    final overlapY =
        math.min(a.y + a.depth, b.y + b.depth) - math.max(a.y, b.y);
    return a.gap(b) <= tolerance && (overlapX > .1 || overlapY > .1);
  }

  List<AirportFacility> _network(
    AirportFacility start,
    AirportFacility end,
    String kind,
  ) {
    final allowed = facilities
        .where((f) => f.kind == kind || f.id == start.id || f.id == end.id)
        .toList();
    final pending = <List<AirportFacility>>[
      [start],
    ];
    final seen = <String>{start.id};
    for (var i = 0; i < pending.length; i++) {
      final path = pending[i];
      if (path.last.id == end.id) return path;
      for (final next in allowed) {
        if (!seen.contains(next.id) && _touch(path.last, next)) {
          seen.add(next.id);
          pending.add([...path, next]);
        }
      }
    }
    return [];
  }

  AirportFacility? _terminal(AirportFacility item) {
    for (final t in ofKind('terminal')) {
      if (t.contains(item.x, item.y) &&
          t.contains(item.x + item.width, item.y + item.depth)) {
        return t;
      }
    }
    return null;
  }

  AirportFacility? _gate(AirportFacility stand) {
    for (final gate in ofKind('boardingGate')) {
      if (gate.gap(stand) <= 25 && gate.connected) return gate;
    }
    return null;
  }

  void resolveConnections() {
    for (final f in facilities) {
      f.connected = false;
    }
    for (final t in ofKind('terminal')) {
      t.connected = ofKind('entrance').any((e) {
        final et = _terminal(e);
        return et != null && _network(et, t, 'terminal').isNotEmpty;
      });
    }
    for (final f in facilities.where((f) => f.interior)) {
      final t = _terminal(f);
      f.connected = t != null && t.connected;
    }
    for (final runway in facilities.where((f) => f.runway)) {
      runway.connected = true;
    }
    for (final f in ofKind('vehicleDepot')) {
      f.connected = ofKind('serviceRoad').any((r) => _touch(f, r));
    }
    for (final f in facilities.where(
      (f) => [
        'fuelDepot',
        'baggage',
        'hangar',
        'serviceRoad',
        'tower',
      ].contains(f.kind),
    )) {
      f.connected = ofKind(
        'vehicleDepot',
      ).any((d) => d.connected && _network(d, f, 'serviceRoad').isNotEmpty);
    }
    for (final f in ofKind('taxiway')) {
      f.connected = facilities
          .where((r) => r.runway)
          .any((r) => _network(r, f, 'taxiway').isNotEmpty);
    }
    for (final s in stands) {
      s.connected =
          _gate(s) != null &&
          facilities
              .where((r) => r.runway)
              .any((r) => _network(r, s, 'taxiway').isNotEmpty) &&
          ofKind(
            'vehicleDepot',
          ).any((d) => d.connected && _network(d, s, 'serviceRoad').isNotEmpty);
    }
  }

  HubEffects get effects => HubEffects(
    activeGates: stands.where((s) => s.connected).length,
    inactiveGates: stands.where((s) => !s.connected).length,
    maxRunwayM: facilities
        .where((f) => f.runway)
        .fold(0, (a, f) => math.max(a, math.max(f.width, f.depth).round())),
    maintenanceMultiplier: hasService('hangar') ? .85 : 1,
    fuelMultiplier: hasService('fuelDepot') ? .94 : 1,
    hasCargo: hasService('baggage'),
    premiumMultiplier: hasService('cafe') ? 1.04 : 1,
    upkeepPerDayEur: facilities.fold(
      0,
      (n, f) => n + (facilityDef(f.kind).cost * .0004).round(),
    ),
  );

  void _book(
    AirlineGameState airline,
    String category,
    int amount,
    String description,
  ) {
    airline.cashEur += amount;
    ledger.add({
      'time': time,
      'category': category,
      'amount': amount,
      'description': description,
    });
    if (ledger.length > 2000) ledger.removeRange(0, ledger.length - 2000);
  }

  void recordTransaction(
    AirlineGameState airline,
    String category,
    int amount,
    String description,
  ) {
    _book(airline, category, amount, description);
  }

  String? build(
    AirlineGameState airline,
    String kind,
    double x,
    double y,
    int rotation, {
    String? moving,
  }) {
    if (!airportFacilities.any((d) => d.kind == kind)) {
      return 'Unknown building.';
    }
    if (!x.isFinite || !y.isFinite || x.abs() > 4000 || y.abs() > 4000) {
      return 'Build inside the airport boundary (±4 km).';
    }
    final old = facility(moving);
    if (moving != null && old == null) return 'That building no longer exists.';
    if (old != null && protected(old)) {
      return 'This facility is in use or needed by an imminent flight.';
    }
    final def = facilityDef(kind),
        step = facilityDef(kind).interior ? 1.0 : 5.0;
    final candidate = AirportFacility(
      id: old?.id ?? 'preview',
      kind: kind,
      x: (x / step).round() * step,
      y: (y / step).round() * step,
      rotation: rotation % 4,
      width: old == null
          ? null
          : (old.rotation.isOdd == rotation.isOdd ? old.width : old.depth),
      depth: old == null
          ? null
          : (old.rotation.isOdd == rotation.isOdd ? old.depth : old.width),
    );
    if (candidate.x + candidate.width > 4000 ||
        candidate.y + candidate.depth > 4000) {
      return 'The building extends beyond airport land.';
    }
    if (def.interior && _terminal(candidate) == null) {
      return 'Place this completely inside a terminal section.';
    }
    for (final b in facilities) {
      if (b.id == old?.id) continue;
      if (candidate.overlaps(b) &&
          !(def.interior && b.kind == 'terminal') &&
          !(kind == 'terminal' && b.interior)) {
        return 'This overlaps ${facilityDef(b.kind).name}.';
      }
    }
    if (old != null &&
        old.kind == 'terminal' &&
        facilities.any((b) => b.interior && _terminal(b)?.id == old.id)) {
      return 'Move or remove the terminal furnishings first.';
    }
    final cost = old == null ? def.cost : 0;
    if (airline.cashEur < cost) return 'Not enough cash for this construction.';
    if (old != null) facilities.remove(old);
    facilities.add(
      AirportFacility(
        id: old?.id ?? _id('b'),
        kind: kind,
        x: candidate.x,
        y: candidate.y,
        rotation: candidate.rotation,
        width: candidate.width,
        depth: candidate.depth,
      ),
    );
    if (cost > 0) _book(airline, 'construction', -cost, def.name);
    resolveConnections();
    return null;
  }

  bool protected(AirportFacility f) =>
      reservations.containsKey(f.id) ||
      flights.any(
        (flight) =>
            !flight.finished &&
            ((flight.arrival <= time + 120 && flight.departure + 180 >= time) ||
                (flight.returnAt > 0 &&
                    flight.returnAt <= time + 120 &&
                    flight.returnAt + 180 >= time) ||
                !['scheduled', 'enRoute'].contains(flight.stage)),
      );

  String? demolish(AirlineGameState airline, String id) {
    final f = facility(id);
    if (f == null) return 'That building no longer exists.';
    if (protected(f)) {
      return 'Cancel imminent flights and finish active operations before changing airport infrastructure.';
    }
    if (f.kind == 'terminal' &&
        facilities.any((b) => b.interior && _terminal(b)?.id == f.id)) {
      return 'Remove the terminal furnishings first.';
    }
    facilities.remove(f);
    resolveConnections();
    _book(
      airline,
      'construction',
      (facilityDef(f.kind).cost * .5).round(),
      'Demolished ${facilityDef(f.kind).name}',
    );
    return null;
  }

  String? buyVehicle(AirlineGameState airline, String kind) {
    if (!['fuel', 'baggage', 'bus', 'pushback'].contains(kind)) {
      return 'Unknown vehicle.';
    }
    if (airline.cashEur < 120000) return 'A service vehicle costs €120,000.';
    final depots = ofKind('vehicleDepot').where((d) => d.connected).toList();
    if (depots.isEmpty) {
      return 'Connect a vehicle depot to a service road first.';
    }
    vehicles.add(
      AirportVehicle(_id('v'), kind, depots.first.cx, depots.first.cy),
    );
    _book(airline, 'vehicles', -120000, 'Purchased $kind vehicle');
    return null;
  }

  AirportFacility? _runway(AirportFacility stand, AircraftModel model) {
    for (final r in facilities.where((f) => f.runway)) {
      if (math.max(r.width, r.depth) >= model.minRunwayM &&
          _network(r, stand, 'taxiway').isNotEmpty) {
        return r;
      }
    }
    return null;
  }

  String? _requirements(AirportOffer offer) {
    for (final kind in [
      ...offer.requiredServices,
      'entrance',
      'checkIn',
      'security',
      'boardingGate',
    ]) {
      if (!hasService(kind)) {
        return 'Provide a connected ${facilityDef(kind).name.toLowerCase()} first.';
      }
    }
    if (!stands.any(
      (s) =>
          s.connected && _runway(s, aircraftModelById(offer.modelId)!) != null,
    )) {
      return 'No connected stand with a long enough runway.';
    }
    return null;
  }

  String? contractBlocker(String offerId) {
    final offer = airportOffers.firstWhere((o) => o.id == offerId);
    if (contracts.any(
      (c) => c.offerId == offerId && !c.cancelled && c.endDay >= day,
    )) {
      return 'Already contracted until day ${contracts.firstWhere((c) => c.offerId == offerId && !c.cancelled && c.endDay >= day).endDay}.';
    }
    final problem = _requirements(offer);
    if (problem != null) return problem;
    final planned = <AirportFlight>[];
    final first = _contractStart(offer);
    for (var d = 0; d < 7; d++) {
      for (var i = 0; i < offer.flightsPerDay; i++) {
        final arrival = first + d * 1440 + i * 210;
        final stand = _availableStand(
          arrival,
          arrival + 80,
          aircraftModelById(offer.modelId)!,
          extra: planned,
        );
        if (stand == null) {
          return 'The seven-day schedule needs more free stand slots.';
        }
        planned.add(
          AirportFlight(
            id: 'preview${planned.length}',
            carrier: offer.carrier,
            modelId: offer.modelId,
            standId: stand.id,
            arrival: arrival,
            departure: arrival + 80,
          ),
        );
      }
    }
    return null;
  }

  double _contractStart(AirportOffer offer) {
    final start = math.max(420.0, time % 1440 + 30);
    if (start + (offer.flightsPerDay - 1) * 210 + 80 > 1380) {
      return (day) * 1440.0 + 420;
    }
    return (day - 1) * 1440.0 + start;
  }

  AirportFacility? _availableStand(
    double arrival,
    double departure,
    AircraftModel model, {
    String? standId,
    double returnAt = 0,
    List<AirportFlight> extra = const [],
  }) {
    for (final stand in stands) {
      if (standId != null && standId.isNotEmpty && stand.id != standId) {
        continue;
      }
      if (!stand.connected || _runway(stand, model) == null) continue;
      if (model.mtowTonnes > 150 && math.min(stand.width, stand.depth) < 60) {
        continue;
      }
      if ([...flights, ...extra].any(
        (f) =>
            !f.finished &&
            f.standId == stand.id &&
            ((arrival < f.departure + 30 && departure + 30 > f.arrival) ||
                (f.returnAt > 0 &&
                    arrival < f.returnAt + 40 &&
                    departure + 30 > f.returnAt - 10) ||
                (returnAt > 0 &&
                    returnAt - 10 < f.departure + 30 &&
                    returnAt + 40 > f.arrival) ||
                (returnAt > 0 &&
                    f.returnAt > 0 &&
                    returnAt - 10 < f.returnAt + 40 &&
                    returnAt + 40 > f.returnAt - 10)),
      )) {
        continue;
      }
      return stand;
    }
    return null;
  }

  String? acceptContract(AirlineGameState airline, String offerId) {
    final offers = airportOffers.where((o) => o.id == offerId);
    if (offers.isEmpty) return 'Unknown airline offer.';
    final offer = offers.first;
    if (contracts.any(
      (c) => c.offerId == offerId && !c.cancelled && c.endDay >= day,
    )) {
      return 'This airline already has an active contract.';
    }
    final problem = contractBlocker(offerId);
    if (problem != null) return problem;
    final planned = <AirportFlight>[];
    final contractId = 'c$nextId';
    final first = _contractStart(offer);
    final firstDay = first ~/ 1440 + 1;
    for (var d = 0; d < 7; d++) {
      for (var i = 0; i < offer.flightsPerDay; i++) {
        final arrival = first + d * 1440 + i * 210;
        final stand = _availableStand(
          arrival,
          arrival + 80,
          aircraftModelById(offer.modelId)!,
          extra: planned,
        );
        if (stand == null) {
          return 'Not enough stand capacity for the seven-day schedule. Free slots or build another connected stand.';
        }
        planned.add(
          AirportFlight(
            id: 'pending${planned.length}',
            carrier: offer.carrier,
            modelId: offer.modelId,
            standId: stand.id,
            arrival: arrival,
            departure: arrival + 80,
            contractId: contractId,
            passengers: (aircraftModelById(offer.modelId)!.seats * .8).round(),
          ),
        );
      }
    }
    final c = AirportContract(_id('c'), offerId, firstDay, firstDay + 6);
    contracts.add(c);
    for (final p in planned) {
      flights.add(
        AirportFlight(
          id: _id('f'),
          carrier: p.carrier,
          modelId: p.modelId,
          standId: p.standId,
          arrival: p.arrival,
          departure: p.departure,
          contractId: c.id,
          passengers: p.passengers,
        ),
      );
    }
    return null;
  }

  String? schedule(
    AirlineGameState airline,
    AirportCatalog catalog, {
    required String aircraftId,
    required String routeId,
    required double departure,
    String? standId,
  }) {
    final a = airline.aircraftById(aircraftId), r = airline.routeById(routeId);
    if (a == null || r == null || !r.active) {
      return 'Choose an available aircraft and active route.';
    }
    if (!departure.isFinite ||
        departure < time + 90 ||
        departure > time + 7 * 1440) {
      return 'Choose a departure between 90 minutes and seven days from now.';
    }
    if (a.isGrounded(airline.day)) return 'This aircraft is in maintenance.';
    final model = aircraftModelById(a.modelId)!;
    final home = catalog.byIata(airline.hubIata),
        dest = catalog.byIata(r.destIata);
    if (home == null || dest == null) return 'Unknown destination.';
    final distance = home.distanceToKm(dest);
    if (distance > model.rangeKm) {
      return 'This destination is beyond the aircraft range.';
    }
    final roundTrip = Geo.blockHours(distance, model.cruiseKmh) * 120 + 60;
    if (flights.any(
      (f) =>
          !f.finished &&
          f.aircraftId == aircraftId &&
          departure - 80 <
              math.max(
                f.returnAt + 40,
                f.departure + _roundTrip(f, airline, catalog),
              ) &&
          departure + roundTrip > f.arrival,
    )) {
      return 'The aircraft is already scheduled or still returning from another flight.';
    }
    final stand = _availableStand(
      departure - 80,
      departure,
      model,
      standId: standId,
      returnAt: departure + roundTrip,
    );
    if (stand == null) {
      return 'No compatible connected stand is free in this time slot.';
    }
    for (final kind in [
      'entrance',
      'checkIn',
      'security',
      'fuelDepot',
      'baggage',
    ]) {
      if (!hasService(kind)) {
        return 'A connected ${facilityDef(kind).name} is required.';
      }
    }
    a.routeId = routeId;
    flights.add(
      AirportFlight(
        id: _id('f'),
        carrier: airline.airlineName,
        modelId: a.modelId,
        standId: stand.id,
        arrival: departure - 80,
        departure: departure,
        aircraftId: a.id,
        routeId: routeId,
        passengers:
            (model.seats *
                    Economy.loadFactor(
                      r.fareEur.toDouble(),
                      Economy.fairFareEur(distance),
                    ))
                .floor(),
      )..returnAt = departure + roundTrip,
    );
    return null;
  }

  double _roundTrip(
    AirportFlight f,
    AirlineGameState airline,
    AirportCatalog catalog,
  ) {
    final r = airline.routeById(f.routeId),
        model = aircraftModelById(f.modelId)!;
    final a = catalog.byIata(airline.hubIata), b = catalog.byIata(r?.destIata);
    return a == null || b == null
        ? 180
        : Geo.blockHours(a.distanceToKm(b), model.cruiseKmh) * 120 + 60;
  }

  String? cancelFlight(AirlineGameState airline, String id) {
    final found = flights.where((f) => f.id == id);
    if (found.isEmpty) return 'Unknown flight.';
    final f = found.first;
    if (f.finished) return 'That flight is already closed.';
    if (f.stage != 'scheduled') {
      return 'An active turnaround must finish before it can be removed.';
    }
    _cancel(f, airline, 'Cancelled by operator');
    return null;
  }

  String? cancelContract(AirlineGameState airline, String id) {
    final c = contract(id);
    if (c == null || c.cancelled) return 'No active contract.';
    c.cancelled = true;
    for (final f in flights.where(
      (f) => f.contractId == id && f.stage == 'scheduled',
    )) {
      _cancel(f, airline, 'Contract cancelled');
    }
    return null;
  }

  void _cancel(AirportFlight f, AirlineGameState airline, String why) {
    if (f.finished) return;
    f.stage = 'cancelled';
    f.issue = why;
    f.settled = true;
    final c = contract(f.contractId);
    if (c != null) {
      _book(airline, 'penalty', -c.offer.penalty, '${f.carrier}: $why');
      c.satisfaction = (c.satisfaction - .08).clamp(0, 1);
    }
    reservations.removeWhere((key, value) => value == f.id);
    passengers.removeWhere((p) => p.flightId == f.id);
    for (final v in vehicles.where((v) => v.flightId == f.id)) {
      v.flightId = null;
      v.path = [];
    }
  }

  /// Advances between event boundaries rather than rendering frames. Replaying
  /// this with one large delta or many small deltas produces the same books.
  void advance(
    double minutes,
    AirlineGameState airline,
    AirportCatalog catalog,
  ) {
    if (minutes <= 0 || !minutes.isFinite) return;
    final target = time + minutes;
    while (time < target - .000001) {
      var next = math.min(target, (time / 1440).floor() * 1440 + 1440.0);
      for (final f in flights.where((f) => !f.finished)) {
        final due = f.stage == 'scheduled' ? f.arrival : f.nextEvent;
        if (due > time + .000001) next = math.min(next, due);
      }
      for (final p in passengers.where((p) => p.stage != 'ready')) {
        if (p.nextEvent > time + .000001) next = math.min(next, p.nextEvent);
      }
      for (final v in vehicles.where((v) => v.flightId != null)) {
        if (v.busyUntil > time + .000001) next = math.min(next, v.busyUntil);
      }
      final oldDay = day;
      time = next;
      airline.day = day;
      _positions();
      _vehicles();
      for (final p in [...passengers]) {
        if (p.stage != 'ready' && p.nextEvent <= time + .000001) {
          _passengerEvent(p, airline);
        }
      }
      for (final f in flights.where((f) => !f.finished).toList()) {
        if ((f.stage == 'scheduled' ? f.arrival : f.nextEvent) <=
            time + .000001) {
          _flightEvent(f, airline, catalog);
        }
      }
      if (day != oldDay) _daily(airline, oldDay);
    }
    _positions();
    airline.day = day;
  }

  void _daily(AirlineGameState airline, int previousDay) {
    _book(
      airline,
      'upkeep',
      -effects.upkeepPerDayEur,
      'Airport infrastructure upkeep',
    );
    _book(
      airline,
      'service',
      -vehicles.length * 450,
      'Vehicle staffing and maintenance',
    );
    for (final a in airline.fleet.where((a) => a.leased)) {
      _book(
        airline,
        'lease',
        -aircraftModelById(a.modelId)!.leasePerDayEur,
        'Lease ${a.registration}',
      );
    }
    final entries = ledger.where(
      (e) =>
          _number(e, 'time') > (previousDay - 1) * 1440 &&
          _number(e, 'time') <= time,
    );
    var income = 0, cost = 0;
    for (final e in entries) {
      final amount = (e['amount'] as num).toInt();
      if (amount > 0) {
        income += amount;
      } else {
        cost -= amount;
      }
    }
    airline.recordDay(
      DayRecord(
        day: previousDay,
        revenueEur: income,
        costEur: cost,
        cashEur: airline.cashEur,
      ),
    );
    flights.removeWhere((f) => f.finished && f.departure < time - 2 * 1440);
    contracts.removeWhere((c) => c.endDay < day - 14);
    queues.removeWhere((key, value) => value < time);
  }

  List<List<double>> _path(List<AirportFacility> nodes) {
    if (nodes.isEmpty) return [];
    final points = <List<double>>[
      [nodes.first.cx, nodes.first.cy, 0],
    ];
    for (var i = 1; i < nodes.length; i++) {
      final a = nodes[i - 1], b = nodes[i];
      points.add([
        (math.max(a.x, b.x) + math.min(a.x + a.width, b.x + b.width)) / 2,
        (math.max(a.y, b.y) + math.min(a.y + a.depth, b.y + b.depth)) / 2,
        0,
      ]);
      points.add([b.cx, b.cy, 0]);
    }
    return points;
  }

  bool _reserve(AirportFlight f, List<AirportFacility> nodes) {
    if (nodes.any(
      (n) => reservations[n.id] != null && reservations[n.id] != f.id,
    )) {
      return false;
    }
    for (final n in nodes) {
      reservations[n.id] = f.id;
    }
    return true;
  }

  void _stage(
    AirportFlight f,
    String name,
    double duration, {
    List<List<double>>? path,
  }) {
    f.stage = name;
    f.stageStart = time;
    f.nextEvent = time + duration;
    f.issue = null;
    f.path = path ?? [];
  }

  void _wait(AirportFlight f, String issue, AirlineGameState airline) {
    f.issue = issue;
    f.nextEvent = time + 2;
    f.path = [];
    f.delay = math.max(0, time - f.departure);
    if (time > (f.returning ? f.returnAt : f.departure) + 180) {
      _cancel(f, airline, issue);
    }
  }

  void _flightEvent(
    AirportFlight f,
    AirlineGameState airline,
    AirportCatalog catalog,
  ) {
    final stand = facility(f.standId), model = aircraftModelById(f.modelId)!;
    if (stand == null) {
      _cancel(f, airline, 'Stand removed');
      return;
    }
    final runway = _runway(stand, model);
    if (!stand.connected || runway == null) {
      if (f.stage == 'scheduled') _stage(f, 'awaitingAirport', 2);
      _wait(f, 'Airport access is disconnected', airline);
      return;
    }
    if (f.stage == 'awaitingAirport') f.stage = 'scheduled';
    final taxi = _network(runway, stand, 'taxiway');
    switch (f.stage) {
      case 'enRoute':
        f.returning = true;
        final alongY = runway.depth > runway.width;
        _stage(
          f,
          'approach',
          3,
          path: [
            [
              runway.cx - (alongY ? 0 : 1600),
              runway.cy - (alongY ? 1600 : 0),
              180,
            ],
            [
              runway.cx - (alongY ? 0 : runway.width * .45),
              runway.cy - (alongY ? runway.depth * .45 : 0),
              10,
            ],
          ],
        );
      case 'scheduled':
      case 'awaitingStand':
        final owned = airline.aircraftById(f.aircraftId);
        if (f.aircraftId != null && (owned == null || owned.isGrounded(day))) {
          _cancel(f, airline, 'Aircraft unavailable');
          return;
        }
        if (f.aircraftId != null) {
          if (!_reserve(f, [stand])) {
            _stage(f, 'awaitingStand', 2);
            _wait(f, 'Waiting for stand', airline);
            return;
          }
          _spawnPassengers(f, stand);
          f.x = stand.cx;
          f.y = stand.cy;
          f.z = 0;
          f.heading = -math.pi / 2;
          _stage(f, 'unloading', 3);
          return;
        }
        _spawnPassengers(f, stand);
        final alongY = runway.depth > runway.width;
        _stage(
          f,
          'approach',
          3,
          path: [
            [
              runway.cx - (alongY ? 0 : 1600),
              runway.cy - (alongY ? 1600 : 0),
              180,
            ],
            [
              runway.cx - (alongY ? 0 : runway.width * .45),
              runway.cy - (alongY ? runway.depth * .45 : 0),
              10,
            ],
          ],
        );
      case 'approach':
        if (!_reserve(f, [runway])) {
          _wait(f, 'Waiting for runway clearance', airline);
          return;
        }
        _stage(
          f,
          'landing',
          2,
          path: [
            [
              runway.cx -
                  (runway.width > runway.depth ? runway.width * .45 : 0),
              runway.cy -
                  (runway.depth > runway.width ? runway.depth * .45 : 0),
              1,
            ],
            [runway.cx, runway.cy, 0],
          ],
        );
      case 'landing':
        if (!_reserve(f, taxi)) {
          _wait(f, 'Waiting for taxiway clearance', airline);
          return;
        }
        _stage(
          f,
          'taxiIn',
          math.max(2, _pathLength(_path(taxi)) / 300),
          path: _path(taxi),
        );
      case 'taxiIn':
        reservations.removeWhere(
          (key, value) => value == f.id && key != stand.id,
        );
        f.x = stand.cx;
        f.y = stand.cy;
        f.z = 0;
        if (f.returning) {
          _settle(f, airline, catalog, inbound: true);
          reservations.removeWhere((key, value) => value == f.id);
          f.stage = 'completed';
          f.path = [];
          return;
        }
        _stage(f, 'unloading', 5);
      case 'unloading':
        _stage(f, 'servicing', 1);
      case 'servicing':
        final terms = contract(f.contractId);
        if (terms != null &&
            terms.offer.requiredServices.any((kind) => !hasService(kind))) {
          _wait(f, 'A required contract facility is unavailable', airline);
          return;
        }
        final services = ['fuel', 'baggage', 'bus'];
        for (final kind in services) {
          if (!f.serviced.contains(kind)) _dispatch(f, kind, stand);
        }
        if (services.any((k) => !f.serviced.contains(k))) {
          _wait(f, 'Waiting for ground services', airline);
          return;
        }
        final ready = passengers
            .where((p) => p.flightId == f.id && p.stage == 'ready')
            .fold(0, (n, p) => n + p.count);
        if (ready < f.passengers && time < f.departure + 30) {
          _wait(f, 'Passengers are still in the terminal', airline);
          return;
        }
        f.boarded = ready;
        _stage(f, 'boarding', math.max(3, ready / 20));
      case 'boarding':
        if (time < f.departure) {
          f.nextEvent = f.departure;
          return;
        }
        if (!f.serviced.contains('pushback')) {
          _dispatch(f, 'pushback', stand);
          _wait(f, 'Waiting for pushback tug', airline);
          return;
        }
        if (!_reserve(f, taxi)) {
          _wait(f, 'Waiting for taxiway clearance', airline);
          return;
        }
        _stage(
          f,
          'pushback',
          2,
          path: [
            [stand.cx, stand.cy, 0],
            [stand.x, stand.cy, 0],
          ],
        );
      case 'pushback':
        _stage(
          f,
          'taxiOut',
          math.max(2, _pathLength(_path(taxi)) / 300),
          path: _path(taxi.reversed.toList()),
        );
      case 'taxiOut':
        final alongY = runway.depth > runway.width;
        _stage(
          f,
          'departing',
          3,
          path: [
            [runway.cx, runway.cy, 0],
            [
              runway.cx + (alongY ? 0 : 1800),
              runway.cy + (alongY ? 1800 : 0),
              220,
            ],
          ],
        );
        f.delay = math.max(0, time - f.departure);
      case 'departing':
        reservations.removeWhere((key, value) => value == f.id);
        _settle(f, airline, catalog);
        if (f.aircraftId != null) {
          f.returnAt = time + _roundTrip(f, airline, catalog);
          _stage(f, 'enRoute', _roundTrip(f, airline, catalog));
        } else {
          f.stage = 'completed';
        }
        passengers.removeWhere((p) => p.flightId == f.id);
      default:
        break;
    }
  }

  void _spawnPassengers(AirportFlight f, AirportFacility stand) {
    final gate = _gate(stand),
        entrances = ofKind('entrance').where((e) => e.connected).toList();
    if (gate == null || entrances.isEmpty) return;
    for (var n = 0; n < f.passengers; n += 10) {
      final p = AirportPassengerGroup(
        _id('p'),
        f.id,
        math.min(10, f.passengers - n),
        entrances.first.cx,
        entrances.first.cy,
      );
      p.nextEvent = time + 1 + (n / 10) * .5;
      passengers.add(p);
    }
  }

  /// Walkable terminal cells exclude furniture footprints. This makes furniture
  /// placement and blocked corridors affect real passenger travel.
  List<List<double>> _walk(double sx, double sy, AirportFacility target) {
    const cell = 2.0;
    final terminals = ofKind('terminal').where((t) => t.connected).toList();
    final sourceObstacles = facilities
        .where((f) => f.interior && f.contains(sx, sy))
        .map((f) => f.id)
        .toSet();
    bool walkable(int x, int y) {
      final px = x * cell + 1, py = y * cell + 1;
      return terminals.any((t) => t.contains(px, py)) &&
          !facilities.any(
            (f) =>
                f.interior &&
                f.id != target.id &&
                !sourceObstacles.contains(f.id) &&
                f.contains(px, py),
          );
    }

    final start = ((sx / cell).floor(), (sy / cell).floor());
    final goal = ((target.cx / cell).floor(), (target.cy / cell).floor());
    final queue = [start], parent = <(int, int), (int, int)?>{start: null};
    for (var i = 0; i < queue.length && i < 16000; i++) {
      final at = queue[i];
      if (at == goal) {
        final result = <List<double>>[];
        (int, int)? node = at;
        while (node != null) {
          result.add([node.$1 * cell + 1, node.$2 * cell + 1, 0]);
          node = parent[node];
        }
        return result.reversed.toList();
      }
      for (final offset in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final next = (at.$1 + offset.$1, at.$2 + offset.$2);
        if (parent.containsKey(next)) continue;
        if (!walkable(next.$1, next.$2)) continue;
        if (!terminals.any(
          (t) => t.contains(next.$1 * cell + 1, next.$2 * cell + 1),
        )) {
          continue;
        }
        parent[next] = at;
        queue.add(next);
      }
    }
    return [];
  }

  void _passengerEvent(AirportPassengerGroup p, AirlineGameState airline) {
    final fs = flights.where((f) => f.id == p.flightId && !f.finished);
    if (fs.isEmpty) {
      passengers.remove(p);
      return;
    }
    final f = fs.first, stand = facility(fs.first.standId)!;
    final nextKind = switch (p.stage) {
      'entrance' => 'checkIn',
      'checkIn' => 'security',
      'security' => 'toilets',
      'toilets' => 'cafe',
      'cafe' => 'seating',
      _ => 'boardingGate',
    };
    AirportFacility? target;
    if (nextKind == 'boardingGate') {
      target = _gate(stand);
    } else {
      final candidates = ofKind(nextKind).where((b) => b.connected).toList()
        ..sort(
          (a, b) => (queues[a.id] ?? time).compareTo(queues[b.id] ?? time),
        );
      if (candidates.isNotEmpty) target = candidates.first;
    }
    if (target == null && ['cafe', 'toilets', 'seating'].contains(nextKind)) {
      p.satisfaction = (p.satisfaction - .12).clamp(0, 1);
      p.stage = nextKind;
      p.nextEvent = time + 1;
      return;
    }
    if (target == null) {
      p.satisfaction = (p.satisfaction - .01).clamp(0, 1);
      p.nextEvent = time + 2;
      return;
    }
    final path = _walk(p.x, p.y, target);
    if (path.isEmpty) {
      p.satisfaction = (p.satisfaction - .01).clamp(0, 1);
      p.nextEvent = time + 2;
      return;
    }
    final travel = _pathLength(path) / 65;
    final start = math.max(time + travel, queues[target.id] ?? time);
    final wait = start - time - travel;
    p.satisfaction = (p.satisfaction - wait * .005).clamp(0, 1);
    final duration = nextKind == 'checkIn'
        ? p.count / 8
        : nextKind == 'security'
        ? p.count / 6
        : nextKind == 'cafe'
        ? 3.0
        : 1.0;
    p.started = time;
    p.path = path;
    p.facilityId = target.id;
    p.nextEvent = start + duration;
    queues[target.id] = p.nextEvent;
    p.stage = nextKind == 'boardingGate' ? 'walkingToGate' : nextKind;
    if (nextKind == 'cafe') {
      _book(airline, 'retail', p.count * 8, 'Terminal café');
    }
    if (p.stage == 'walkingToGate') {
      // The next event finishes the walk; boarding cannot count these early.
      p.stage = 'gateWalk';
    }
    if (time > f.departure + 30) {
      p.satisfaction = (p.satisfaction - .1).clamp(0, 1);
    }
  }

  void _dispatch(AirportFlight f, String kind, AirportFacility stand) {
    if (vehicles.any((v) => v.flightId == f.id && v.kind == kind)) return;
    final supplyKind = kind == 'fuel'
        ? 'fuelDepot'
        : kind == 'baggage'
        ? 'baggage'
        : 'vehicleDepot';
    final sources = ofKind(supplyKind).where((d) => d.connected).toList();
    if (sources.isEmpty) return;
    final route = _network(sources.first, stand, 'serviceRoad');
    if (route.isEmpty) return;
    final free = vehicles.where((v) => v.kind == kind && v.flightId == null);
    if (free.isEmpty) return;
    final v = free.first;
    final origins = facilities
        .where(
          (b) => !b.interior && b.kind != 'terminal' && b.contains(v.x, v.y),
        )
        .toList();
    if (origins.isEmpty) return;
    final toSupply = _network(origins.first, sources.first, 'serviceRoad');
    if (toSupply.isEmpty) return;
    v.path = [
      [v.x, v.y, 0],
      ..._path(toSupply),
      ..._path(route).skip(1),
    ];
    v.returning = false;
    v.started = time;
    v.flightId = f.id;
    v.busyUntil =
        time +
        _pathLength(v.path) / 250 +
        (kind == 'fuel'
            ? 8
            : kind == 'baggage'
            ? 6
            : 3);
  }

  void _vehicles() {
    for (final v in vehicles.where((v) => v.flightId != null).toList()) {
      if (v.busyUntil > time + .000001) continue;
      if (v.returning) {
        if (v.path.isNotEmpty) {
          v.x = v.path.last[0];
          v.y = v.path.last[1];
        }
        v.flightId = null;
        v.path = [];
        v.returning = false;
        continue;
      }
      final fs = flights.where((f) => f.id == v.flightId && !f.finished);
      if (fs.isNotEmpty && !fs.first.serviced.contains(v.kind)) {
        fs.first.serviced.add(v.kind);
      }
      if (v.path.isNotEmpty) {
        v.x = v.path.last[0];
        v.y = v.path.last[1];
      }
      v.path = v.path.reversed.toList();
      v.returning = true;
      v.started = time;
      v.busyUntil = time + math.max(1, _pathLength(v.path) / 250);
    }
    for (final p in passengers.where(
      (p) => p.stage == 'gateWalk' && p.nextEvent <= time + .000001,
    )) {
      if (p.path.isNotEmpty) {
        p.x = p.path.last[0];
        p.y = p.path.last[1];
      }
      p.stage = 'ready';
      p.path = [];
    }
  }

  void _settle(
    AirportFlight f,
    AirlineGameState airline,
    AirportCatalog catalog, {
    bool inbound = false,
  }) {
    if (inbound ? f.returnSettled : f.settled) return;
    if (inbound) {
      f.returnSettled = true;
    } else {
      f.settled = true;
    }
    var carried = f.boarded;
    final groups = passengers.where((p) => p.flightId == f.id).toList();
    final satisfaction = groups.isEmpty
        ? 0.0
        : groups.fold(0.0, (n, p) => n + p.satisfaction * p.count) /
              math.max(1, f.passengers);
    final c = contract(f.contractId);
    if (c != null) {
      final reliability = (1 - f.delay / 180).clamp(0.0, 1.0);
      final fulfilled = f.boarded / math.max(1, f.passengers);
      final fee =
          (c.offer.fee * reliability * fulfilled * (.5 + .5 * satisfaction))
              .round();
      _book(airline, 'handling', fee, '${c.offer.carrier} ${f.id}');
      if (f.delay > 30 || fulfilled < .8) {
        _book(
          airline,
          'penalty',
          -c.offer.penalty,
          'Late or incomplete service ${f.id}',
        );
      }
      _book(
        airline,
        'service',
        -(c.offer.fee * .2).round(),
        'Ground services ${f.id}',
      );
      c.satisfaction =
          (c.satisfaction * .8 + satisfaction * reliability * fulfilled * .2)
              .clamp(0, 1);
    } else {
      final aircraft = airline.aircraftById(f.aircraftId),
          route = airline.routeById(f.routeId);
      final home = catalog.byIata(airline.hubIata),
          dest = catalog.byIata(route?.destIata);
      if (aircraft != null && route != null && home != null && dest != null) {
        final model = aircraftModelById(f.modelId)!;
        final distance = home.distanceToKm(dest);
        final demand = Economy.demandPerDay(
          catchmentA: home.catchment,
          catchmentB: dest.catchment,
          distanceKm: distance,
        );
        final today = flights
            .where(
              (other) =>
                  other.id != f.id &&
                  other.routeId == f.routeId &&
                  other.settled &&
                  other.departure ~/ 1440 == f.departure ~/ 1440,
            )
            .fold(0, (n, other) => n + other.boarded);
        final result = Economy.flight(
          model: model,
          distanceKm: distance,
          fareEur: route.fareEur.toDouble(),
          availableDemand: math.min(
            inbound ? model.seats.toDouble() : f.boarded.toDouble(),
            math.max(0, demand - today),
          ),
          fuelPriceIndex: airline.fuelPriceIndex,
          hub: effects,
        );
        _book(
          airline,
          'tickets',
          result.revenueEur,
          '${route.destIata} ${f.id}${inbound ? ' return' : ''}',
        );
        _book(airline, 'cargo', result.cargoEur, 'Cargo ${f.id}');
        carried = result.passengers;
        _book(airline, 'fuel', -result.fuelEur, 'Flight fuel ${f.id}');
        _book(airline, 'crew', -result.crewEur, 'Flight crew ${f.id}');
        _book(airline, 'landing', -result.landingEur, 'Landing ${f.id}');
        _book(
          airline,
          'maintenance',
          -result.maintenanceEur,
          'Flight maintenance ${f.id}',
        );
        final before = aircraft.blockHours;
        aircraft.blockHours += result.blockHours;
        aircraft.condition = (aircraft.condition - result.blockHours * .000025)
            .clamp(0, 1);
        if (before ~/ 3000 < aircraft.blockHours ~/ 3000) {
          aircraft.groundedUntilDay = day + 3;
          aircraft.condition = math.min(1, aircraft.condition + .35);
          _book(
            airline,
            'maintenance',
            -model.maintPerHourEur * 260,
            'Heavy check ${aircraft.registration}',
          );
        }
        route.recordProfit(
          result.revenueEur +
              result.cargoEur -
              result.fuelEur -
              result.crewEur -
              result.landingEur -
              result.maintenanceEur,
        );
      }
    }
    airline.flightsFlownEver++;
    airline.passengersCarriedEver += carried;
  }

  static double _pathLength(List<List<double>> path) {
    var length = 0.0;
    for (var i = 1; i < path.length; i++) {
      length += math.sqrt(
        math.pow(path[i][0] - path[i - 1][0], 2) +
            math.pow(path[i][1] - path[i - 1][1], 2),
      );
    }
    return length;
  }

  static List<double> _position(List<List<double>> path, double fraction) {
    if (path.isEmpty) return [0, 0, 0, 0];
    var remaining = _pathLength(path) * fraction.clamp(0, 1);
    for (var i = 1; i < path.length; i++) {
      final a = path[i - 1], b = path[i], dx = b[0] - a[0], dy = b[1] - a[1];
      final length = math.sqrt(dx * dx + dy * dy);
      if (remaining <= length || i == path.length - 1) {
        final t = length == 0 ? 1.0 : (remaining / length).clamp(0.0, 1.0);
        return [
          a[0] + dx * t,
          a[1] + dy * t,
          a[2] + (b[2] - a[2]) * t,
          math.atan2(-dx, -dy),
        ];
      }
      remaining -= length;
    }
    return [...path.last, 0];
  }

  void _positions() {
    for (final f in flights.where((f) => f.path.isNotEmpty && !f.finished)) {
      final p = _position(
        f.path,
        (time - f.stageStart) / math.max(.001, f.nextEvent - f.stageStart),
      );
      f.x = p[0];
      f.y = p[1];
      f.z = p[2];
      f.heading = p[3];
    }
    for (final v in vehicles.where((v) => v.path.isNotEmpty)) {
      final p = _position(
        v.path,
        (time - v.started) / math.max(.001, v.busyUntil - v.started),
      );
      v.x = p[0];
      v.y = p[1];
      v.heading = p[3];
    }
    for (final group in passengers.where((p) => p.path.isNotEmpty)) {
      final p = _position(
        group.path,
        (time - group.started) /
            math.max(.001, group.nextEvent - group.started),
      );
      group.x = p[0];
      group.y = p[1];
    }
  }

  Json toJson() => {
    'version': 2,
    'time': time,
    'paused': paused,
    'speed': speed,
    'nextId': nextId,
    'lastSeenEpochMs': lastSeenEpochMs,
    'facilities': facilities.map((f) => f.toJson()).toList(),
    'flights': flights.map((f) => f.toJson()).toList(),
    'contracts': contracts.map((c) => c.toJson()).toList(),
    'vehicles': vehicles.map((v) => v.toJson()).toList(),
    'passengers': passengers.map((p) => p.toJson()).toList(),
    'ledger': ledger,
    'reservations': reservations,
    'queues': queues,
  };

  factory AirportWorld.fromJson(Json j) {
    if (j['version'] != 2) {
      throw const FormatException('Unsupported airport save version');
    }
    final w = AirportWorld();
    w.time = _number(j, 'time', 360);
    w.paused = j['paused'] != false;
    w.speed = [1, 4, 12].contains(j['speed']) ? (j['speed'] as num).toInt() : 1;
    w.nextId = _number(j, 'nextId', 1).toInt();
    w.lastSeenEpochMs = _number(j, 'lastSeenEpochMs').toInt();
    w.facilities.addAll(
      _objects(j['facilities']).map(AirportFacility.fromJson),
    );
    w.flights.addAll(_objects(j['flights']).map(AirportFlight.fromJson));
    w.contracts.addAll(_objects(j['contracts']).map(AirportContract.fromJson));
    w.vehicles.addAll(_objects(j['vehicles']).map(AirportVehicle.fromJson));
    w.passengers.addAll(
      _objects(j['passengers']).map(AirportPassengerGroup.fromJson),
    );
    w.ledger.addAll(_objects(j['ledger']));
    w.reservations.addAll(
      Map<String, String>.from(j['reservations'] as Map? ?? {}),
    );
    for (final e in (j['queues'] as Map? ?? {}).entries) {
      w.queues[e.key as String] = (e.value as num).toDouble();
    }
    w.resolveConnections();
    return w;
  }
}
