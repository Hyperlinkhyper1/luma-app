import 'dart:math' as math;

import '../airline_game_state.dart';
import '../data/aircraft.dart';
import '../data/airport_catalog.dart';
import 'airport_contracts.dart';
import 'economy.dart';
import 'geo.dart';
import 'hub.dart';

export 'airport_contracts.dart';

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
    required this.category,
    this.maxMtowTonnes,
  });
  final String kind;
  final String name;
  final double width, depth, height;
  final int cost;
  final String blurb;
  final bool interior;

  /// Build-menu group: airfield, apron, services, terminal, interior, shops
  /// or decor.
  final String category;

  /// Heaviest aircraft a stand accepts; null means any.
  final int? maxMtowTonnes;

  Json toJson() {
    final upgrade = facilityUpgrade(kind);
    return {
      'upgrades': [
        for (final u in facilityUpgrades(kind))
          {'id': u.id, 'attribute': u.attribute, 'effect': u.effect},
      ],
      'kind': kind,
      'name': name,
      'width': width,
      'depth': depth,
      'height': height,
      'cost': cost,
      'interior': interior,
      'blurb': blurb,
      'category': category,
      'maxMtow': maxMtowTonnes,
      'upgrade': upgrade == null
          ? null
          : {'attribute': upgrade.attribute, 'effect': upgrade.effect},
    };
  }
}

/// The passenger flow no airport works without: in through check-in and
/// security, out through customs and check-out.
const terminalEssentials = [
  'entrance',
  'checkIn',
  'security',
  'boardingGate',
  'customs',
  'checkOut',
];

/// Every kind an aircraft can park on.
const standKinds = {'stand', 'standRegional', 'standContact'};

/// Interior pieces that only lift passenger mood.
const decorKinds = {'plant', 'fountain', 'infoBoard', 'infoPanel'};

/// Arriving passengers a single baggage carousel serves at once.
const carouselCapacity = 100;

/// Highest level a facility can be upgraded to; everything is built at 1.
const maxFacilityLevel = 5;

const _retailKinds = {
  'shop',
  'kiosk',
  'foodShop',
  'perfumeShop',
  'flowerShop',
  'clothingShop',
  'luxuryBoutique',
  'cafe',
  'restaurant',
  'vendingMachine',
  'coffeeToGo',
  'foodCart',
};
const _waitingKinds = {'seating', 'lounge', 'vipLounge', 'arcade'};
const _staffedKinds = {
  'customs',
  'checkOut',
  'checkIn',
  'checkInCounter',
  'ticketMachine',
  'security',
  'toilets',
  'infoDesk',
};

typedef FacilityUpgrade = ({String id, String attribute, String effect});

/// Everything upgrading [kind] can improve, each levelled on its own, first
/// the main one. Empty means the kind cannot be upgraded.
List<FacilityUpgrade> facilityUpgrades(String kind) {
  if (kind == 'boardingGate') {
    return const [
      (
        id: 'lanes',
        attribute: 'Boarding lanes',
        effect: 'One more lane of passengers boards at the same time.',
      ),
      (
        id: 'speed',
        attribute: 'Boarding speed',
        effect: 'Each lane boards 1.5 more passengers per minute.',
      ),
    ];
  }
  final single = _singleUpgrade(kind);
  return single == null
      ? const []
      : [(id: 'main', attribute: single.attribute, effect: single.effect)];
}

/// The main upgrade of [kind], or null when it has none.
FacilityUpgrade? facilityUpgrade(String kind) =>
    facilityUpgrades(kind).firstOrNull;

({String attribute, String effect})? _singleUpgrade(String kind) {
  if (kind.startsWith('runway')) {
    return (
      attribute: 'Surface & lighting',
      effect: 'Landings and take-offs clear the runway 15% faster per level.',
    );
  }
  if (standKinds.contains(kind)) {
    return (
      attribute: 'Asphalt',
      effect: 'Ground handling and boarding are 15% faster per level.',
    );
  }
  if (decorKinds.contains(kind)) {
    return (
      attribute: 'Quality',
      effect: 'Counts as one more decoration per level.',
    );
  }
  if (_retailKinds.contains(kind)) {
    return (
      attribute: 'Stock & staff',
      effect: '15% more sales and 25% quicker service per level.',
    );
  }
  if (_waitingKinds.contains(kind)) {
    return (
      attribute: 'Comfort',
      effect: '+1% satisfaction and 15% more income per level.',
    );
  }
  if (_staffedKinds.contains(kind)) {
    return (
      attribute: 'Staff',
      effect: kind == 'infoDesk'
          ? 'Each level counts as another staffed desk.'
          : 'Passengers are processed 25% faster per level.',
    );
  }
  return switch (kind) {
    'taxiway' => (
      attribute: 'Asphalt',
      effect: 'Aircraft taxi 10% faster per level.',
    ),
    'terminal' => (
      attribute: 'Comfort',
      effect: 'Passengers are 1% happier per level, averaged over sections.',
    ),
    'fuelDepot' || 'baggage' || 'vehicleDepot' => (
      attribute: 'Equipment',
      effect: 'Ground services dispatched from here are 20% faster per level.',
    ),
    'tower' => (
      attribute: 'Radar',
      effect: 'Approaches take 10% less time per level.',
    ),
    'bins' => (
      attribute: 'Service',
      effect: 'Each level counts as another set of bins.',
    ),
    'baggageCarousel' => (
      attribute: 'Belt speed',
      effect: 'Passengers collect their bags 25% faster per level.',
    ),
    _ => null,
  };
}

/// Size of the airframe the scene draws for [model], so passengers walk to
/// the door that is actually there.
({double length, double radius, double doorHeight}) airframe(
  AircraftModel model,
) {
  const known = {
    'atr72': (27.0, 1.35, false),
    'e175': (31.7, 1.5, false),
    'e195e2': (41.5, 1.55, false),
    'a220_300': (38.7, 1.75, false),
    'a320neo': (37.6, 2.0, false),
    'b737max8': (39.5, 1.9, false),
    'a321neo': (44.5, 2.0, false),
    'a330_900': (63.7, 2.8, true),
    'b787_9': (62.8, 2.9, true),
    'a350_1000': (73.8, 3.0, true),
    'b777_300er': (73.9, 3.1, true),
    'b747_8i': (76.3, 3.2, true),
    'a380_800': (72.7, 3.6, true),
  };
  final (length, radius, wide) =
      known[model.id] ??
      (model.seats <= 80
          ? (27.0, 1.35, false)
          : model.mtowTonnes > 150
          ? (62.8, 2.9, true)
          : (37.6, 2.0, false));
  return (
    length: length,
    radius: radius,
    doorHeight: radius + (wide ? 2.4 : 1.6) - radius * .35,
  );
}

/// Price of taking a [def] facility from [level] to the next one.
int upgradeCostAt(AirportFacilityDef def, int level) =>
    math.max(1000, (def.cost * .4 * level / 1000).round() * 1000);

const airportFacilities = <AirportFacilityDef>[
  AirportFacilityDef(
    'runway',
    'Runway · 1,800 m',
    45,
    1800,
    .15,
    6000000,
    'Regional runway. Connect it to stands with taxiways.',
    category: 'airfield',
  ),
  AirportFacilityDef(
    'runwayMedium',
    'Runway · 2,600 m',
    45,
    2600,
    .15,
    13000000,
    'Supports narrowbody aircraft.',
    category: 'airfield',
  ),
  AirportFacilityDef(
    'runwayLong',
    'Runway · 3,400 m',
    60,
    3400,
    .15,
    24000000,
    'Supports long-haul widebodies.',
    category: 'airfield',
  ),
  AirportFacilityDef(
    'taxiway',
    'Taxiway',
    20,
    100,
    .1,
    60000,
    'Connect touching taxiways between a runway and a stand.',
    category: 'airfield',
  ),
  AirportFacilityDef(
    'standRegional',
    'Regional stand',
    40,
    45,
    .12,
    550000,
    'Turboprops and regional jets up to 45 t. Needs taxiway, service road and a nearby boarding gate.',
    category: 'apron',
    maxMtowTonnes: 45,
  ),
  AirportFacilityDef(
    'stand',
    'Remote stand',
    60,
    65,
    .12,
    1200000,
    'Any aircraft. Passengers ride a bus. Needs taxiway, service road and a nearby boarding gate.',
    category: 'apron',
  ),
  AirportFacilityDef(
    'standContact',
    'Contact stand · jet bridge',
    60,
    65,
    .12,
    2600000,
    'Build against a terminal. Passengers walk on board: no bus, faster boarding, happier travellers.',
    category: 'apron',
  ),
  AirportFacilityDef(
    'serviceRoad',
    'Service road',
    10,
    100,
    .08,
    20000,
    'Connect vehicle depots and services to aircraft stands.',
    category: 'apron',
  ),
  AirportFacilityDef(
    'terminal',
    'Terminal section',
    120,
    60,
    12,
    4000000,
    'Furnish its interior with passenger services.',
    category: 'terminal',
  ),
  AirportFacilityDef(
    'hangar',
    'Maintenance hangar',
    60,
    60,
    22,
    3000000,
    'Connected hangars reduce aircraft maintenance costs.',
    category: 'services',
  ),
  AirportFacilityDef(
    'fuelDepot',
    'Fuel depot',
    30,
    30,
    10,
    2000000,
    'Fuel supply for ground-service trucks.',
    category: 'services',
  ),
  AirportFacilityDef(
    'baggage',
    'Baggage facility',
    30,
    20,
    8,
    800000,
    'Baggage handling for every departure.',
    category: 'services',
  ),
  AirportFacilityDef(
    'vehicleDepot',
    'Vehicle depot',
    30,
    30,
    9,
    500000,
    'Select this depot to buy service vehicles; connect it to a service road.',
    category: 'services',
  ),
  AirportFacilityDef(
    'tower',
    'Control tower',
    15,
    15,
    38,
    1500000,
    'Airport landmark and flight control centre.',
    category: 'services',
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
    category: 'interior',
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
    category: 'interior',
  ),
  AirportFacilityDef(
    'infoDesk',
    'Information desk',
    5,
    4,
    3,
    90000,
    'Staff who answer questions and point the way: every connected desk '
        'lifts passenger satisfaction across the terminal.',
    interior: true,
    category: 'interior',
  ),
  AirportFacilityDef(
    'checkInCounter',
    'Staffed check-in counter',
    6,
    5,
    3,
    70000,
    'Two agents with a bag drop: 10 passengers per game minute. Counts as '
        'check-in desks.',
    interior: true,
    category: 'interior',
  ),
  AirportFacilityDef(
    'ticketMachine',
    'Ticket machine',
    1,
    1,
    2,
    12000,
    'Self check-in beside the desks: 4 passengers per game minute.',
    interior: true,
    category: 'interior',
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
    category: 'interior',
  ),
  AirportFacilityDef(
    'customs',
    'Customs',
    8,
    6,
    3,
    70000,
    'Arriving passengers clear customs here, 6 per game minute. Required.',
    interior: true,
    category: 'interior',
  ),
  AirportFacilityDef(
    'checkOut',
    'Arrivals check-out',
    8,
    4,
    2,
    40000,
    'Arriving passengers check out here on their way to the exit, 10 per game minute. Required.',
    interior: true,
    category: 'interior',
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
    category: 'interior',
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
    category: 'interior',
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
    category: 'interior',
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
    category: 'shops',
  ),
  AirportFacilityDef(
    'vendingMachine',
    'Vending machine',
    1,
    1,
    2,
    9000,
    'Quick snacks instead of the café: €3 per passenger, one minute each.',
    interior: true,
    category: 'shops',
  ),
  AirportFacilityDef(
    'perfumeShop',
    'Perfume boutique',
    8,
    7,
    3,
    260000,
    'Few buyers, large baskets: one passenger in four spends €90 here.',
    interior: true,
    category: 'shops',
  ),
  AirportFacilityDef(
    'flowerShop',
    'Flower shop',
    6,
    5,
    3,
    150000,
    'Fresh bouquets after security: €16 per passenger, two minutes each.',
    interior: true,
    category: 'shops',
  ),
  AirportFacilityDef(
    'foodShop',
    'Duty-free food & drink',
    10,
    8,
    3,
    230000,
    'Snacks, sweets and a chilled drinks wall after security: €20 per '
        'passenger, two and a half minutes each.',
    interior: true,
    category: 'shops',
  ),
  AirportFacilityDef(
    'kiosk',
    'Newsstand kiosk',
    5,
    4,
    3,
    55000,
    'A staffed till for papers and snacks after security: €9 per passenger, '
        'ninety seconds each.',
    interior: true,
    category: 'shops',
  ),
  AirportFacilityDef(
    'restaurant',
    'Restaurant',
    14,
    10,
    3,
    380000,
    'Sit-down dining instead of the café: €26 per passenger, five minutes, '
        'and a happier wait.',
    interior: true,
    category: 'shops',
  ),
  AirportFacilityDef(
    'coffeeToGo',
    'Coffee to-go',
    4,
    3,
    3,
    75000,
    'A quick espresso stop after security: €6 per passenger, ninety seconds '
        'each.',
    interior: true,
    category: 'shops',
  ),
  AirportFacilityDef(
    'foodCart',
    'Food cart',
    3,
    2,
    3,
    40000,
    'A cheap grab-and-go stall for tight corners: €4 per passenger, one '
        'minute each.',
    interior: true,
    category: 'shops',
  ),
  AirportFacilityDef(
    'shop',
    'Duty-free shop',
    12,
    8,
    3,
    160000,
    'Passengers browse after security: €14 retail income each.',
    interior: true,
    category: 'shops',
  ),
  AirportFacilityDef(
    'clothingShop',
    'Fashion boutique',
    8,
    6,
    3,
    190000,
    'Duty-free clothing after security: €18 per passenger, three minutes each.',
    interior: true,
    category: 'shops',
  ),
  AirportFacilityDef(
    'luxuryBoutique',
    'Luxury boutique',
    8,
    6,
    3,
    320000,
    'Premium knitwear after security: €26 per passenger, four minutes each, '
        'and a calmer wait.',
    interior: true,
    category: 'shops',
  ),
  AirportFacilityDef(
    'lounge',
    'Premium lounge',
    14,
    10,
    3,
    240000,
    'Waiting area that earns €20 per passenger and lifts their mood.',
    interior: true,
    category: 'shops',
  ),
  AirportFacilityDef(
    'baggageCarousel',
    'Baggage carousel',
    10,
    5,
    3,
    65000,
    'Arrivals of medium and long-haul contracts collect their bags here. '
        'Up to $carouselCapacity people at once.',
    interior: true,
    category: 'interior',
  ),
  AirportFacilityDef(
    'vipLounge',
    'VIP lounge & bar',
    8,
    6,
    3,
    420000,
    'First-class waiting area: €35 per passenger and a much happier wait.',
    interior: true,
    category: 'shops',
  ),
  AirportFacilityDef(
    'bins',
    'Recycling bins',
    2,
    1,
    2,
    2500,
    'Waste, paper and bottles. A clean terminal keeps passengers happy: each '
        'set adds 4% cleanliness, from 60% up to 100%.',
    interior: true,
    category: 'decor',
  ),
  AirportFacilityDef(
    'arcade',
    'Arcade',
    10,
    8,
    3,
    340000,
    'Cabinets, air hockey and a claw machine: €12 per passenger, and a big '
        'mood boost for the wait.',
    interior: true,
    category: 'shops',
  ),
  AirportFacilityDef(
    'plant',
    'Palm planter',
    2,
    2,
    3,
    3000,
    'Decor. Every piece in a terminal lifts passenger mood a little.',
    interior: true,
    category: 'decor',
  ),
  AirportFacilityDef(
    'fountain',
    'Fountain',
    6,
    6,
    2,
    40000,
    'Decor centrepiece. Lifts passenger mood.',
    interior: true,
    category: 'decor',
  ),
  AirportFacilityDef(
    'infoBoard',
    'Flight information board',
    4,
    2,
    3,
    18000,
    'Decor. Passengers find their gate with less stress.',
    interior: true,
    category: 'decor',
  ),
  AirportFacilityDef(
    'infoPanel',
    'Flight info screen',
    1,
    1,
    3,
    6000,
    'A small pedestal departures screen. Cheaper decor with the same '
        'stress-easing effect as a full board.',
    interior: true,
    category: 'decor',
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

  /// Upgrade levels by [facilityUpgrades] id, 1 to [maxFacilityLevel].
  final Map<String, int> levels = {};
  int levelOf(String attribute) => levels[attribute] ?? 1;

  /// Level of the main upgrade.
  int get level => levelOf(facilityUpgrade(kind)?.id ?? 'main');
  set level(int value) => levels[facilityUpgrade(kind)?.id ?? 'main'] = value;
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
    'level': level,
    'levels': levels,
  };
  factory AirportFacility.fromJson(Json j) => AirportFacility(
    id: j['id'] as String,
    kind: j['kind'] as String,
    x: _number(j, 'x'),
    y: _number(j, 'y'),
    rotation: (j['rotation'] as num?)?.toInt() ?? 0,
    width: _number(j, 'width'),
    depth: _number(j, 'depth'),
  ).._loadLevels(j);

  void _loadLevels(Json j) {
    final saved = j['levels'];
    if (saved is Map && saved.isNotEmpty) {
      for (final e in saved.entries) {
        if (e.value is num) {
          levels['${e.key}'] = (e.value as num).toInt().clamp(
            1,
            maxFacilityLevel,
          );
        }
      }
    } else if (j['level'] is num) {
      level = (j['level'] as num).toInt().clamp(1, maxFacilityLevel);
    }
  }
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

  /// How the aircraft moves along [path] this stage, for the renderer:
  /// position = ease·u + (1 − ease)·u² of the path at time fraction u, so 1 is
  /// steady, 0 accelerates from rest and 2 slows to a stop. A negative value
  /// is a smoothstep: pull away gently and brake gently.
  double ease = 1;
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
    'ease': ease,
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
    f.ease = _number(j, 'ease', 1);
    return f;
  }
}

class AirportVehicle {
  AirportVehicle(this.id, this.kind, this.x, this.y);
  final String id, kind;
  double x, y, heading = 0, busyUntil = 0, started = 0;

  /// When the vehicle reaches the end of [path]; it works there until
  /// [busyUntil].
  double arriveAt = 0;
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
    'arriveAt': arriveAt,
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
    v.arriveAt = _number(j, 'arriveAt', v.busyUntil);
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

  /// Arriving passengers walk from the gate to a baggage carousel and out.
  bool arriving = false;
  String stage = 'entrance';
  double x, y, satisfaction = 1, nextEvent = 0, started = 0;
  String? facilityId;
  List<List<double>> path = [];

  /// Minutes between one passenger of the group and the next setting off,
  /// when they board or leave an aircraft in single file. Zero walks together.
  double interval = 0;
  Json toJson() => {
    'id': id,
    'flightId': flightId,
    'count': count,
    'interval': interval,
    'arriving': arriving,
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
    p.arriving = j['arriving'] as bool? ?? false;
    p.stage = j['stage'] as String? ?? 'entrance';
    p.satisfaction = _number(j, 'satisfaction', 1);
    p.nextEvent = _number(j, 'nextEvent');
    p.started = _number(j, 'started');
    p.facilityId = j['facilityId'] as String?;
    p.interval = _number(j, 'interval');
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

  /// Generated offers already signed; they leave the market for good.
  final Set<String> signedOffers = {};
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
  List<AirportFacility> get stands =>
      facilities.where((f) => standKinds.contains(f.kind)).toList();

  /// How clean the terminal is, from .6 with no bins to 1 with ten sets.
  double get cleanliness => .6 + math.min(.4, _levels('bins') * .04);

  /// Satisfaction added by staffed information desks, up to three of them.
  double get infoDeskBonus => math.min(.06, _levels('infoDesk') * .02);

  /// Connected facilities of [kind], each counted once per upgrade level.
  int _levels(String kind) => facilities
      .where((f) => f.kind == kind && f.connected)
      .fold(0, (n, f) => n + f.level);

  /// Speed or income multiplier of an upgraded facility: 1 at level 1.
  static double _boost(AirportFacility? f, double perLevel) =>
      1 + perLevel * ((f?.level ?? 1) - 1);

  /// Approach speed from the best control tower's radar level.
  double get _radar =>
      ofKind('tower').fold(1.0, (best, t) => math.max(best, _boost(t, .1)));

  /// Taxi speed over [path], from the taxiways' average asphalt level.
  double _taxiBoost(List<AirportFacility> path) {
    final taxiways = path.where((n) => n.kind == 'taxiway').toList();
    if (taxiways.isEmpty) return 1;
    return taxiways.fold(0.0, (n, t) => n + _boost(t, .1)) / taxiways.length;
  }

  /// Satisfaction the terminal's average comfort level adds.
  double get terminalComfort {
    final sections = ofKind('terminal');
    if (sections.isEmpty) return 0;
    return sections.fold(0, (n, t) => n + t.level - 1) / sections.length * .01;
  }

  /// What the next level of [f]'s [attribute] (its main one by default)
  /// costs, or null when it cannot go higher.
  int? upgradeCost(AirportFacility f, [String? attribute]) {
    final u = attribute == null
        ? facilityUpgrade(f.kind)
        : facilityUpgrades(f.kind).where((u) => u.id == attribute).firstOrNull;
    if (u == null || f.levelOf(u.id) >= maxFacilityLevel) return null;
    return upgradeCostAt(facilityDef(f.kind), f.levelOf(u.id));
  }

  String? upgrade(AirlineGameState airline, String id, {String? attribute}) {
    final f = facility(id);
    if (f == null) return 'That building no longer exists.';
    final u = attribute == null || attribute.isEmpty
        ? facilityUpgrade(f.kind)
        : facilityUpgrades(f.kind).where((u) => u.id == attribute).firstOrNull;
    if (u == null) return '${facilityDef(f.kind).name} has no such upgrade.';
    final cost = upgradeCost(f, u.id);
    if (cost == null) return 'Already at the highest level.';
    if (airline.cashEur < cost) return 'Not enough cash for this upgrade.';
    f.levels[u.id] = f.levelOf(u.id) + 1;
    _book(
      airline,
      'construction',
      -cost,
      '${facilityDef(f.kind).name}: ${u.attribute.toLowerCase()} level ${f.levelOf(u.id)}',
    );
    return null;
  }

  bool hasService(String kind) => facilities.any(
    (f) =>
        f.connected &&
        (f.kind == kind || (kind == 'checkIn' && f.kind == 'checkInCounter')),
  );

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
    add('customs', -140, 18);
    add('checkOut', -140, 10);
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

  // ── Stand and pavement geometry ─────────────────────────────────────────
  // Distances are metres, speeds metres per game minute. One game minute is
  // one real second at 1×, so these are picked to read well on screen rather
  // than to match a stopwatch: walking crowds, trucks and taxiing aircraft
  // all move at a watchable pace.

  /// Walking pace of passengers.
  static const walkSpeed = 15.0;

  /// Driving pace of ground service vehicles.
  static const vehicleSpeed = 40.0;

  /// Taxi pace of aircraft, before taxiway upgrades.
  static const taxiSpeed = 60.0;

  static const _sideVectors = {
    '+x': (1.0, 0.0),
    '-x': (-1.0, 0.0),
    '+z': (0.0, 1.0),
    '-z': (0.0, -1.0),
  };
  static const _oppositeSide = {'+x': '-x', '-x': '+x', '+z': '-z', '-z': '+z'};

  /// The side of [a] that [b] touches along a shared edge.
  static String? _touchingSide(AirportFacility a, AirportFacility b) {
    final overlapX =
        math.min(a.x + a.width, b.x + b.width) - math.max(a.x, b.x);
    final overlapZ =
        math.min(a.y + a.depth, b.y + b.depth) - math.max(a.y, b.y);
    if (overlapZ > 1 && (b.x - (a.x + a.width)).abs() < 1.2) return '+x';
    if (overlapZ > 1 && (b.x + b.width - a.x).abs() < 1.2) return '-x';
    if (overlapX > 1 && (b.y - (a.y + a.depth)).abs() < 1.2) return '+z';
    if (overlapX > 1 && (b.y + b.depth - a.y).abs() < 1.2) return '-z';
    return null;
  }

  /// Which way aircraft on [stand] point: nose-in to the terminal it serves,
  /// or along its own +x when there is no terminal yet.
  String standNose(AirportFacility stand) {
    String? side;
    var best = double.infinity;
    for (final t in ofKind('terminal')) {
      final touching = _touchingSide(stand, t);
      final dx = t.cx - stand.cx, dz = t.cy - stand.cy;
      final gapX = math.max(0.0, dx.abs() - (t.width + stand.width) / 2);
      final gapZ = math.max(0.0, dz.abs() - (t.depth + stand.depth) / 2);
      final distance = touching != null
          ? -1.0
          : math.sqrt(gapX * gapX + gapZ * gapZ);
      if (distance < best) {
        best = distance;
        side =
            touching ??
            (gapX >= gapZ ? (dx > 0 ? '+x' : '-x') : (dz > 0 ? '+z' : '-z'));
      }
    }
    return side ?? const ['+x', '-z', '-x', '+z'][stand.rotation % 4];
  }

  /// Where the stand's lead-in line runs across it: in line with a taxiway
  /// that meets the entry edge end-on, so the yellow line carries straight on
  /// instead of kinking. Otherwise down the middle.
  double standLane(AirportFacility stand) {
    final entry = _oppositeSide[standNose(stand)]!;
    final acrossX = entry.endsWith('z');
    final lo = acrossX ? stand.x : stand.y;
    final hi = lo + (acrossX ? stand.width : stand.depth);
    final centre = (lo + hi) / 2;
    double? best;
    for (final t in ofKind('taxiway')) {
      if (_touchingSide(stand, t) != entry) continue;
      if ((t.depth >= t.width) != acrossX) continue;
      final lateral = acrossX ? t.cx : t.cy;
      if (best == null || (lateral - centre).abs() < (best - centre).abs()) {
        best = lateral;
      }
    }
    return best == null ? centre : best.clamp(lo + 8, hi - 8).toDouble();
  }

  /// A point on [stand], [back] metres from its nose edge towards the entry
  /// and [left] metres to the parked aircraft's left of the lead-in line.
  List<double> standPoint(
    AirportFacility stand,
    double back, [
    double left = 0,
    double z = 0,
  ]) {
    final (nx, ny) = _sideVectors[standNose(stand)]!;
    final lane = standLane(stand);
    final noseEdge = nx > 0
        ? stand.x + stand.width
        : nx < 0
        ? stand.x
        : ny > 0
        ? stand.y + stand.depth
        : stand.y;
    final lx = ny, ly = -nx;
    final baseX = nx != 0 ? noseEdge - nx * back : lane;
    final baseY = ny != 0 ? noseEdge - ny * back : lane;
    return [baseX + lx * left, baseY + ly * left, z];
  }

  /// Length of [stand] along its nose axis.
  double _standLength(AirportFacility stand) =>
      standNose(stand).endsWith('x') ? stand.width : stand.depth;

  /// Heading of an aircraft nosed in on [stand], in the renderer's convention.
  double _noseHeading(AirportFacility stand) {
    final (nx, ny) = _sideVectors[standNose(stand)]!;
    return math.atan2(-nx, -ny);
  }

  /// Distance from the nose edge to where the nose stops.
  static double _stopBack(AirportFacility stand) =>
      stand.kind == 'standRegional' ? 7.5 : 12.5;

  /// Where the middle of a parked [model] sits on [stand].
  List<double> parkingSpot(AirportFacility stand, AircraftModel model) =>
      standPoint(stand, _stopBack(stand) + airframe(model).length / 2);

  /// The front left door of a [model] parked on [stand], at sill height.
  List<double> aircraftDoor(AirportFacility stand, AircraftModel model) {
    final a = airframe(model);
    return standPoint(
      stand,
      _stopBack(stand) + a.length * .14 + 1,
      a.radius,
      a.doorHeight,
    );
  }

  /// Where a jet bridge on a contact stand meets the terminal (its rotunda)
  /// and where its cab stops by the aircraft. The scene draws the same bridge.
  static const bridgeRotunda = (back: 4.5, left: 12.0);
  static const bridgeCab = (back: 18.8, left: 5.2);
  static const bridgeFloor = 4.2;

  /// The walk between a gate and the aircraft door: through the jet bridge on
  /// a contact stand, out of the terminal and up the stairs on the others.
  List<List<double>> _gateToDoor(
    AirportFacility gate,
    AirportFacility stand,
    AircraftModel model,
    List<double> from,
  ) {
    final door = aircraftDoor(stand, model);
    if (stand.kind == 'standContact') {
      return [
        [from[0], from[1], 0],
        standPoint(stand, -2, bridgeRotunda.left),
        standPoint(stand, bridgeRotunda.back, bridgeRotunda.left, bridgeFloor),
        standPoint(stand, bridgeCab.back, bridgeCab.left, bridgeFloor),
        door,
      ];
    }
    final a = airframe(model);
    final foot = standPoint(
      stand,
      _stopBack(stand) + a.length * .14 + 1,
      a.radius + 4.5,
    );
    final hall = _terminal(gate);
    final exit = hall == null
        ? foot
        : [
            foot[0].clamp(hall.x, hall.x + hall.width).toDouble(),
            foot[1].clamp(hall.y, hall.y + hall.depth).toDouble(),
            0.0,
          ];
    return [
      [from[0], from[1], 0],
      exit,
      foot,
      door,
    ];
  }

  /// Passengers per game minute through the gate serving [stand]: the gate's
  /// boarding lanes times its speed, faster over a jet bridge.
  double boardingRate(AirportFacility stand) {
    final gate = _gate(stand);
    final lanes = gate?.levelOf('lanes') ?? 1;
    final speed = gate?.levelOf('speed') ?? 1;
    return lanes *
        (3 + (speed - 1) * 1.5) *
        (stand.kind == 'standContact' ? 1.6 : 1) *
        _boost(stand, .15);
  }

  static bool _linear(AirportFacility f) =>
      f.kind == 'taxiway' || f.kind == 'serviceRoad' || f.runway;

  /// The closest point to [p] on [f]'s centreline.
  static List<double> _onCentreline(AirportFacility f, List<double> p) =>
      f.depth >= f.width
      ? [f.cx, p[1].clamp(f.y, f.y + f.depth).toDouble(), 0]
      : [p[0].clamp(f.x, f.x + f.width).toDouble(), f.cy, 0];

  /// Where a route crosses from [a] into [b]: on their shared edge, in line
  /// with whichever of them meets that edge end-on.
  List<double> _portal(AirportFacility a, AirportFacility b) {
    final x0 = math.max(a.x, b.x), x1 = math.min(a.x + a.width, b.x + b.width);
    final y0 = math.max(a.y, b.y), y1 = math.min(a.y + a.depth, b.y + b.depth);
    final edgeAlongY = (x1 - x0) < (y1 - y0);
    bool endOn(AirportFacility f) =>
        _linear(f) && (f.depth >= f.width) != edgeAlongY;
    double lateral(AirportFacility f) => edgeAlongY ? f.cy : f.cx;
    bool entryOf(AirportFacility stand, AirportFacility other) =>
        standKinds.contains(stand.kind) &&
        _touchingSide(stand, other) == _oppositeSide[standNose(stand)];
    double at;
    if (entryOf(b, a)) {
      at = standLane(b);
    } else if (entryOf(a, b)) {
      at = standLane(a);
    } else if (endOn(b)) {
      at = lateral(b);
    } else if (endOn(a)) {
      at = lateral(a);
    } else {
      at = edgeAlongY ? (y0 + y1) / 2 : (x0 + x1) / 2;
    }
    final lo = edgeAlongY ? y0 : x0, hi = edgeAlongY ? y1 : x1;
    at = hi - lo > 2 ? at.clamp(lo + 1, hi - 1).toDouble() : (lo + hi) / 2;
    return edgeAlongY ? [(x0 + x1) / 2, at, 0] : [at, (y0 + y1) / 2, 0];
  }

  /// A drivable line through touching [nodes] from [from] to [to]: down the
  /// middle of each runway, taxiway or road, turning where two of them meet.
  /// The renderer rounds the corners.
  List<List<double>> _route(
    List<AirportFacility> nodes,
    List<double> from,
    List<double> to,
  ) {
    final points = <List<double>>[
      [from[0], from[1], 0],
    ];
    void add(List<double> p) {
      final last = points.last;
      if ((last[0] - p[0]).abs() + (last[1] - p[1]).abs() > .05) {
        points.add([p[0], p[1], 0]);
      }
    }

    for (var i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      final entry = i == 0 ? from : _portal(nodes[i - 1], n);
      final exit = i == nodes.length - 1 ? to : _portal(n, nodes[i + 1]);
      if (i > 0) add(entry);
      if (_linear(n)) {
        add(_onCentreline(n, entry));
        add(_onCentreline(n, exit));
      } else if (standKinds.contains(n.kind) && i == nodes.length - 1) {
        // Line up on the lead-in before rolling to the stop.
        add(standPoint(n, _standLength(n) - 6));
      }
      if (i < nodes.length - 1) add(exit);
    }
    add(to);
    return points;
  }

  /// The runway's side of the taxi route: where aircraft leave it after
  /// landing and join it for take-off.
  List<double> _runwayGate(
    AirportFacility runway,
    List<AirportFacility> taxi,
  ) => taxi.length < 2
      ? [runway.cx, runway.cy, 0]
      : _onCentreline(runway, _portal(runway, taxi[1]));

  /// Unit vector along [runway] from [from] towards its farther end, the
  /// distance to that end, and the far threshold.
  ({double dx, double dy, double room}) _runwayRun(
    AirportFacility runway,
    List<double> from,
  ) {
    final alongY = runway.depth >= runway.width;
    final start = (alongY ? runway.y : runway.x) + 30;
    final end =
        (alongY ? runway.y + runway.depth : runway.x + runway.width) - 30;
    final at = alongY ? from[1] : from[0];
    final forward = (end - at) >= (at - start);
    final sign = forward ? 1.0 : -1.0;
    final room = sign > 0 ? end - at : at - start;
    return (dx: alongY ? 0.0 : sign, dy: alongY ? sign : 0.0, room: room);
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
    // Anything can be moved, even while it is in use: aircraft, vehicles and
    // passengers carry on from wherever it now stands.
    final old = facility(moving);
    if (moving != null && old == null) return 'That building no longer exists.';
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
    if (kind == 'standContact' &&
        !ofKind('terminal').any((t) => t.gap(candidate) <= 1)) {
      return 'A jet bridge needs this stand to touch a terminal section.';
    }
    for (final b in facilities) {
      if (b.id == old?.id) continue;
      if (candidate.overlaps(b) &&
          !(def.interior && b.kind == 'terminal') &&
          !(kind == 'terminal' && b.interior)) {
        return 'This overlaps ${facilityDef(b.kind).name}.';
      }
    }
    final furnishings = old?.kind == 'terminal'
        ? facilities
              .where((b) => b.interior && _terminal(b)?.id == old!.id)
              .toList()
        : const <AirportFacility>[];
    final cost = old == null ? def.cost : 0;
    if (airline.cashEur < cost) return 'Not enough cash for this construction.';
    if (old != null) facilities.remove(old);
    // A terminal section takes its furnishings along, turned with it.
    for (final b in furnishings) {
      _carry(b, old!, candidate);
    }
    facilities.add(
      AirportFacility(
        id: old?.id ?? _id('b'),
        kind: kind,
        x: candidate.x,
        y: candidate.y,
        rotation: candidate.rotation,
        width: candidate.width,
        depth: candidate.depth,
      )..levels.addAll(old?.levels ?? const {}),
    );
    if (cost > 0) _book(airline, 'construction', -cost, def.name);
    resolveConnections();
    return null;
  }

  /// Moves [item] from [from]'s interior to the same place inside [to].
  static void _carry(
    AirportFacility item,
    AirportFacility from,
    AirportFacility to,
  ) {
    final local = [
      _toLocal(from, item.x, item.y),
      _toLocal(from, item.x + item.width, item.y + item.depth),
    ];
    final a = _fromLocal(to, local[0][0], local[0][1]);
    final b = _fromLocal(to, local[1][0], local[1][1]);
    double tidy(double v) => (v * 1e6).round() / 1e6;
    item.x = tidy(math.min(a[0], b[0]));
    item.y = tidy(math.min(a[1], b[1]));
    item.width = tidy((a[0] - b[0]).abs());
    item.depth = tidy((a[1] - b[1]).abs());
    item.rotation = (item.rotation + to.rotation - from.rotation) % 4;
  }

  /// The corner a facility's model frame starts from, and its turn angle —
  /// the same transform the scene applies when it draws the facility.
  static (double, double, double, double) _frame(AirportFacility f) {
    final turn = f.rotation % 4;
    final lw = turn.isOdd ? f.depth : f.width;
    final ld = turn.isOdd ? f.width : f.depth;
    final px =
        f.x +
        (turn == 2
            ? lw
            : turn == 3
            ? ld
            : 0);
    final pz =
        f.y +
        (turn == 1
            ? lw
            : turn == 2
            ? ld
            : 0);
    final theta = turn * math.pi / 2;
    return (px, pz, math.cos(theta), math.sin(theta));
  }

  static List<double> _toLocal(AirportFacility f, double wx, double wz) {
    final (px, pz, c, s) = _frame(f);
    final dx = wx - px, dz = wz - pz;
    return [dx * c - dz * s, dx * s + dz * c];
  }

  static List<double> _fromLocal(AirportFacility f, double lx, double lz) {
    final (px, pz, c, s) = _frame(f);
    return [px + lx * c + lz * s, pz - lx * s + lz * c];
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
    final def = facilityDef(f.kind);
    var invested = def.cost;
    for (final u in facilityUpgrades(f.kind)) {
      for (var level = 1; level < f.levelOf(u.id); level++) {
        invested += upgradeCostAt(def, level);
      }
    }
    _book(
      airline,
      'construction',
      (invested * .5).round(),
      'Demolished ${def.name}',
    );
    return null;
  }

  String? buyVehicle(AirlineGameState airline, String kind, {String? depotId}) {
    if (!['fuel', 'baggage', 'bus', 'pushback'].contains(kind)) {
      return 'Unknown vehicle.';
    }
    if (airline.cashEur < 120000) return 'A service vehicle costs €120,000.';
    AirportFacility? home;
    if (depotId != null && depotId.isNotEmpty) {
      home = facility(depotId);
      if (home == null || home.kind != 'vehicleDepot') {
        return 'Select a vehicle depot to buy service vehicles.';
      }
      if (!home.connected) {
        return 'Connect that vehicle depot to a service road first.';
      }
    } else {
      final depots = ofKind('vehicleDepot').where((d) => d.connected).toList();
      if (depots.isEmpty) {
        return 'Select a connected vehicle depot to buy service vehicles.';
      }
      home = depots.first;
    }
    vehicles.add(AirportVehicle(_id('v'), kind, home.cx, home.cy));
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
    for (final kind in [...offer.requiredServices, ...terminalEssentials]) {
      if (!hasService(kind)) {
        return 'Provide a connected ${facilityDef(kind).name.toLowerCase()} first.';
      }
    }
    if (!stands.any(
      (s) =>
          s.connected &&
          standAccepts(s, offer.model) &&
          _runway(s, offer.model) != null,
    )) {
      return 'No connected ${offer.haul} stand with a long enough runway.';
    }
    return null;
  }

  /// Offers open for signing today: the permanent starter offers plus what
  /// airlines published in the last two days.
  List<AirportOffer> get offers => [
    ...airportOffers,
    for (var d = math.max(1, day - 2); d <= day; d++)
      ...offersPublishedOn(
        d,
      ).where((o) => o.expiresDay! >= day && !signedOffers.contains(o.id)),
  ];

  AirportOffer? offer(String id) {
    for (final o in offers) {
      if (o.id == id) return o;
    }
    return null;
  }

  bool _contractOpen(AirportContract c) =>
      !c.cancelled &&
      (c.remaining > 0 ||
          flights.any((f) => f.contractId == c.id && !f.finished));

  String? contractBlocker(String offerId) {
    final o = offer(offerId);
    if (o == null) return 'This offer is no longer available.';
    if (contracts.any((c) => c.offerId == offerId && _contractOpen(c))) {
      return 'This airline is still flying its current contract.';
    }
    return _requirements(o);
  }

  AirportFacility? _availableStand(
    double arrival,
    double departure,
    AircraftModel model, {
    String? standId,
    double returnAt = 0,
    List<AirportFlight> extra = const [],
    String? ignoreFlightId,
  }) {
    for (final stand in stands) {
      if (standId != null && standId.isNotEmpty && stand.id != standId) {
        continue;
      }
      if (!stand.connected || _runway(stand, model) == null) continue;
      if (!standAccepts(stand, model)) continue;
      if ([...flights, ...extra].any(
        (f) =>
            !f.finished &&
            f.id != ignoreFlightId &&
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

  /// Whether [stand] can take [model] at all, ignoring the timetable.
  bool standAccepts(AirportFacility stand, AircraftModel model) {
    final limit = facilityDef(stand.kind).maxMtowTonnes;
    if (limit != null && model.mtowTonnes > limit) return false;
    return !(model.mtowTonnes > 150 && math.min(stand.width, stand.depth) < 60);
  }

  String _clock(double minutes) {
    final m = minutes.round();
    return 'day ${m ~/ 1440 + 1} ${(m ~/ 60 % 24).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }

  String? _placementProblem(
    AirportFacility? stand,
    AircraftModel model,
    double arrival,
  ) {
    if (stand == null || !standKinds.contains(stand.kind)) {
      return 'Choose an aircraft stand.';
    }
    if (!standAccepts(stand, model)) {
      return '${facilityDef(stand.kind).name} cannot take the ${model.name}.';
    }
    if (!stand.connected || _runway(stand, model) == null) {
      return 'That stand is not connected to a long enough runway.';
    }
    if (!arrival.isFinite || arrival < time + 30) {
      return 'Plan at least 30 minutes ahead.';
    }
    if (arrival > time + planningHorizonDays * 1440) {
      return 'The timetable only reaches $planningHorizonDays days ahead.';
    }
    return null;
  }

  /// Moves a flight that has not arrived yet to another stand or time.
  String? moveFlight(String flightId, String standId, double arrival) {
    final found = flights.where((f) => f.id == flightId);
    if (found.isEmpty) return 'Unknown flight.';
    final f = found.first;
    if (f.stage != 'scheduled') {
      return 'Only flights that have not arrived yet can be moved.';
    }
    arrival = (arrival / 5).round() * 5.0;
    final stand = facility(standId), model = aircraftModelById(f.modelId)!;
    if (stand?.id == f.standId && arrival == f.arrival) return null;
    final problem = _placementProblem(stand, model, arrival);
    if (problem != null) return problem;
    final c = contract(f.contractId);
    if (c != null && !slotAllows(c.offer.slot, arrival)) {
      return '${c.carrier} wants this flight to start in ${slotLabel(c.offer.slot)}.';
    }
    final shift = arrival - f.arrival;
    final departure = f.departure + shift;
    final returnAt = f.returnAt > 0 ? f.returnAt + shift : 0.0;
    if (f.aircraftId != null &&
        flights.any(
          (o) =>
              o.id != f.id &&
              !o.finished &&
              o.aircraftId == f.aircraftId &&
              arrival < math.max(o.returnAt + 40, o.departure + 60) &&
              math.max(returnAt + 40, departure + 60) > o.arrival,
        )) {
      return 'The aircraft is busy with another flight at that time.';
    }
    if (_availableStand(
          arrival,
          departure,
          model,
          standId: stand!.id,
          returnAt: returnAt,
          ignoreFlightId: f.id,
        ) ==
        null) {
      return 'That stand is busy at ${_clock(arrival)}.';
    }
    final moved = AirportFlight(
      id: f.id,
      carrier: f.carrier,
      modelId: f.modelId,
      standId: stand.id,
      arrival: arrival,
      departure: departure,
      aircraftId: f.aircraftId,
      routeId: f.routeId,
      contractId: f.contractId,
      passengers: f.passengers,
    )..returnAt = returnAt;
    flights[flights.indexOf(f)] = moved;
    if (c != null) _contractSpan(c);
    return null;
  }

  String? reassignFlight(String flightId, String standId) {
    final found = flights.where((f) => f.id == flightId);
    if (found.isEmpty) return 'Unknown flight.';
    return moveFlight(flightId, standId, found.first.arrival);
  }

  /// Takes a flight off the timetable. A contract flight returns to the
  /// holding bar to be placed again; the player's own flight is dropped.
  String? unscheduleFlight(String flightId) {
    final found = flights.where((f) => f.id == flightId);
    if (found.isEmpty) return 'Unknown flight.';
    final f = found.first;
    if (f.stage != 'scheduled') {
      return 'Only flights that have not arrived yet can be unscheduled.';
    }
    flights.remove(f);
    final c = contract(f.contractId);
    if (c != null) {
      c.placed = math.max(0, c.placed - 1);
      c.deadlineDay = math.max(c.deadlineDay, day + 2);
      _contractSpan(c);
    }
    return null;
  }

  void _contractSpan(AirportContract c) {
    final own = flights.where((f) => f.contractId == c.id);
    if (own.isEmpty) return;
    c.startDay = own.map((f) => f.arrival ~/ 1440 + 1).reduce(math.min);
    c.endDay = own.map((f) => f.departure ~/ 1440 + 1).reduce(math.max);
  }

  /// Puts a signed contract on the timetable: a regular contract places all
  /// its remaining daily flights at [arrival], a charter places one.
  String? placeContract(String contractId, String standId, double arrival) {
    final c = contract(contractId);
    if (c == null || c.cancelled) return 'No active contract.';
    if (c.remaining <= 0) return 'Every flight of this contract is planned.';
    arrival = (arrival / 5).round() * 5.0;
    final stand = facility(standId), model = c.offer.model;
    final problem = _placementProblem(stand, model, arrival);
    if (problem != null) return problem;
    if (!slotAllows(c.offer.slot, arrival)) {
      return '${c.carrier} wants its flights to start in ${slotLabel(c.offer.slot)}.';
    }
    final count = c.offer.isRegular ? c.remaining : 1;
    final firstDay = arrival ~/ 1440 + 1;
    if (c.offer.isRegular && firstDay > c.deadlineDay) {
      return 'This series has to start by day ${c.deadlineDay}.';
    }
    if (!c.offer.isRegular && firstDay > c.signedDay + c.offer.placementDays) {
      return 'Charter flights have to fly by day ${c.signedDay + c.offer.placementDays}.';
    }
    final requirement = _requirements(c.offer);
    if (requirement != null) return requirement;
    final planned = <AirportFlight>[];
    for (var d = 0; d < count; d++) {
      final a = arrival + d * 1440;
      final dep = a + c.offer.standMinutes - slotExitMinutes;
      if (_availableStand(a, dep, model, standId: stand!.id, extra: planned) ==
          null) {
        return 'That stand is busy at ${_clock(a)}.';
      }
      planned.add(
        AirportFlight(
          id: 'pending${planned.length}',
          carrier: c.carrier,
          modelId: model.id,
          standId: stand.id,
          arrival: a,
          departure: dep,
          contractId: c.id,
          passengers: c.offer.passengers,
        ),
      );
    }
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
    c.placed += count;
    _contractSpan(c);
    return null;
  }

  /// Signs an offer. Its flights wait in the holding bar until placed.
  String? acceptContract(AirlineGameState airline, String offerId) {
    final o = offer(offerId);
    if (o == null) return 'This offer is no longer available.';
    final problem = contractBlocker(offerId);
    if (problem != null) return problem;
    if (o.expiresDay != null) signedOffers.add(o.id);
    contracts.add(AirportContract(id: _id('c'), offer: o, signedDay: day));
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
    for (final kind in [...terminalEssentials, 'fuelDepot', 'baggage']) {
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
    if (c == null || !_contractOpen(c)) return 'No active contract.';
    final unplaced = c.remaining;
    c.cancelled = true;
    for (final f in flights.where(
      (f) => f.contractId == id && f.stage == 'scheduled',
    )) {
      _cancel(f, airline, 'Contract cancelled');
    }
    if (unplaced > 0) {
      _book(
        airline,
        'penalty',
        -unplaced * c.offer.penalty,
        '${c.carrier}: $unplaced unplanned flights',
      );
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
    for (final c in contracts.where((c) => c.remaining > 0)) {
      if (day <= c.deadlineDay) continue;
      final missed = c.remaining;
      c.lapsed += missed;
      c.satisfaction = (c.satisfaction - .1 * missed).clamp(0, 1);
      _book(
        airline,
        'penalty',
        -missed * c.offer.penalty,
        '${c.carrier}: $missed flights never planned',
      );
    }
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
    contracts.removeWhere(
      (c) => !_contractOpen(c) && (c.endDay ?? c.deadlineDay) < day - 14,
    );
    queues.removeWhere((key, value) => value < time);
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
    double ease = 1,
  }) {
    f.ease = ease;
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
    // Where aircraft leave the runway after landing and join it to take off.
    final gate = _runwayGate(runway, taxi);
    final run = _runwayRun(runway, gate);
    switch (f.stage) {
      case 'enRoute':
        f.returning = true;
        _approach(f, runway, gate, run);
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
          final hangar = ofKind('hangar').firstOrNull;
          final spot = parkingSpot(stand, model);
          if (hangar != null) {
            // Based aircraft are towed from the hangar apron to the stand.
            final from = [hangar.x - 5, hangar.y - 25, 0.0];
            final path = [
              from,
              standPoint(stand, _standLength(stand) - 6),
              spot,
            ];
            _stage(
              f,
              'positioning',
              math.max(3, _pathLength(path) / (taxiSpeed * .6)),
              path: path,
              ease: -1,
            );
            return;
          }
          _park(f, stand, model);
          _stage(f, 'unloading', 3);
          return;
        }
        _spawnPassengers(f, stand);
        _approach(f, runway, gate, run);
      case 'positioning':
        _park(f, stand, model);
        _stage(f, 'unloading', 3);
      case 'approach':
        if (!_reserve(f, [runway])) {
          _wait(f, 'Waiting for runway clearance', airline);
          return;
        }
        // Touch down past the far threshold and roll out to the taxi exit,
        // braking from approach speed to taxi speed.
        final touchdown = [
          gate[0] + run.dx * math.max(0, run.room - 300),
          gate[1] + run.dy * math.max(0, run.room - 300),
          0.0,
        ];
        final roll = _pathLength([touchdown, gate]);
        const landingSpeed = 250.0;
        final minutes = math.max(
          1.5,
          2 * roll / (landingSpeed + taxiSpeed) / _boost(runway, .15),
        );
        _stage(
          f,
          'landing',
          minutes,
          path: [touchdown, gate],
          ease: roll > 1
              ? (landingSpeed * minutes / roll).clamp(1, 2).toDouble()
              : 1,
        );
      case 'landing':
        if (!_reserve(f, taxi)) {
          _wait(f, 'Waiting for taxiway clearance', airline);
          return;
        }
        final path = _route(taxi, gate, parkingSpot(stand, model));
        _stage(
          f,
          'taxiIn',
          math.max(2, _pathLength(path) / (taxiSpeed * _taxiBoost(taxi))),
          path: path,
          ease: -1,
        );
      case 'taxiIn':
        reservations.removeWhere(
          (key, value) => value == f.id && key != stand.id,
        );
        _park(f, stand, model);
        final arriving = _spawnArrivals(f, stand, model);
        _stage(f, 'unloading', math.max(2, arriving));
      case 'unloading':
        if (f.returning) {
          // Home again: settle the return leg and tow back to the hangar.
          _settle(f, airline, catalog, inbound: true);
          final hangar = ofKind('hangar').firstOrNull;
          if (hangar != null) {
            final path = [
              parkingSpot(stand, model),
              standPoint(stand, _standLength(stand) - 6),
              [hangar.x - 5, hangar.y - 25, 0.0],
            ];
            _stage(
              f,
              'toHangar',
              math.max(3, _pathLength(path) / (taxiSpeed * .6)),
              path: path,
              ease: -1,
            );
            reservations.removeWhere((key, value) => value == f.id);
            return;
          }
          reservations.removeWhere((key, value) => value == f.id);
          f.stage = 'completed';
          f.path = [];
          return;
        }
        _stage(f, 'servicing', 1);
      case 'toHangar':
        f.stage = 'completed';
        f.path = [];
      case 'servicing':
        final terms = contract(f.contractId);
        if (terms != null &&
            terms.offer.requiredServices.any((kind) => !hasService(kind))) {
          _wait(f, 'A required contract facility is unavailable', airline);
          return;
        }
        final missing = terminalEssentials.where((k) => !hasService(k));
        if (missing.isNotEmpty) {
          _wait(
            f,
            'The terminal needs ${facilityDef(missing.first).name.toLowerCase()}',
            airline,
          );
          return;
        }
        final contact = stand.kind == 'standContact';
        final services = ['fuel', 'baggage', if (!contact) 'bus'];
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
        if (contact) {
          for (final p in passengers.where((p) => p.flightId == f.id)) {
            p.satisfaction = (p.satisfaction + .05).clamp(0, 1);
          }
        }
        // The tug drives over while passengers board, ready to push back.
        _dispatch(f, 'pushback', stand);
        _stage(f, 'boarding', math.max(1, _board(f, stand, model)));
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
        f.delay = math.max(0, time - f.departure);
        final spot = parkingSpot(stand, model);
        final back = standPoint(stand, _standLength(stand) - 8);
        _stage(
          f,
          'pushback',
          math.max(2, _pathLength([spot, back]) / 12),
          path: [spot, back],
          ease: -1,
        );
      case 'pushback':
        final path = _route(
          taxi.reversed.toList(),
          standPoint(stand, _standLength(stand) - 8),
          gate,
        );
        _stage(
          f,
          'taxiOut',
          math.max(2, _pathLength(path) / (taxiSpeed * _taxiBoost(taxi))),
          path: path,
          ease: -1,
        );
      case 'taxiOut':
        // Roll down the longer side of the runway, lift off and climb out
        // until the aircraft is lost in the haze.
        final liftoff = math.min(run.room * .75, 1400.0);
        final climb = run.room + 11000;
        _stage(
          f,
          'departing',
          20 / _boost(runway, .15),
          path: [
            gate,
            [gate[0] + run.dx * liftoff, gate[1] + run.dy * liftoff, 0],
            [gate[0] + run.dx * climb, gate[1] + run.dy * climb, 1300],
          ],
          ease: 0,
        );
      case 'departing':
        reservations.removeWhere((key, value) => value == f.id);
        _settle(f, airline, catalog);
        if (f.aircraftId != null) {
          f.returnAt = time + _roundTrip(f, airline, catalog);
          _stage(f, 'enRoute', _roundTrip(f, airline, catalog));
        } else {
          f.stage = 'completed';
        }
        passengers.removeWhere((p) => p.flightId == f.id && !p.arriving);
      default:
        break;
    }
  }

  /// A long straight-in approach from beyond the far end of [runway], out of
  /// the haze, slowing down towards the threshold.
  void _approach(
    AirportFlight f,
    AirportFacility runway,
    List<double> gate,
    ({double dx, double dy, double room}) run,
  ) {
    final threshold = [
      gate[0] + run.dx * math.max(0, run.room - 300),
      gate[1] + run.dy * math.max(0, run.room - 300),
      0.0,
    ];
    const reach = 12000.0, minutes = 16.0, touchdownSpeed = 250.0;
    final t = minutes / _radar;
    _stage(
      f,
      'approach',
      t,
      path: [
        [threshold[0] + run.dx * reach, threshold[1] + run.dy * reach, 900],
        threshold,
      ],
      ease: (2 - touchdownSpeed * t / reach).clamp(1, 2).toDouble(),
    );
  }

  /// Puts [f] on its stand, nose in.
  void _park(AirportFlight f, AirportFacility stand, AircraftModel model) {
    final spot = parkingSpot(stand, model);
    f.x = spot[0];
    f.y = spot[1];
    f.z = 0;
    f.heading = _noseHeading(stand);
  }

  /// How far outside the doors passengers are dropped off.
  static const kerbDistance = 9.0;

  /// Where passengers cross the facade for [entrance]: the doorway on the
  /// nearest outside wall of its terminal section, and the kerb outside it.
  /// A wall shared with another section is inside the hall, never a door.
  ({List<double> door, List<double> kerb})? entranceDoor(
    AirportFacility entrance,
  ) {
    final t = _terminal(entrance);
    if (t == null) return null;
    ({List<double> door, List<double> kerb})? best;
    var bestDistance = double.infinity;
    for (final (nx, ny) in const [
      (1.0, 0.0),
      (-1.0, 0.0),
      (0.0, 1.0),
      (0.0, -1.0),
    ]) {
      final door = [
        nx == 0
            ? entrance.cx.clamp(t.x + 4, t.x + t.width - 4).toDouble()
            : (nx > 0 ? t.x + t.width : t.x),
        ny == 0
            ? entrance.cy.clamp(t.y + 4, t.y + t.depth - 4).toDouble()
            : (ny > 0 ? t.y + t.depth : t.y),
        0.0,
      ];
      final outX = door[0] + nx * 2, outY = door[1] + ny * 2;
      if (ofKind(
        'terminal',
      ).any((o) => o.id != t.id && o.contains(outX, outY))) {
        continue;
      }
      final distance =
          (door[0] - entrance.cx).abs() + (door[1] - entrance.cy).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = (
          door: door,
          kerb: [door[0] + nx * kerbDistance, door[1] + ny * kerbDistance, 0.0],
        );
      }
    }
    return best;
  }

  /// Kerb → doors → [entrance], walking around the furniture once inside.
  List<List<double>> _entranceRoute(AirportFacility entrance) {
    final door = entranceDoor(entrance);
    if (door == null) return [];
    final kerb = door.kerb, at = door.door;
    final nx = (kerb[0] - at[0]).sign, ny = (kerb[1] - at[1]).sign;
    final walk = _walk(at[0] - nx * 1.5, at[1] - ny * 1.5, entrance);
    return [
      kerb,
      at,
      if (walk.isEmpty) [entrance.cx, entrance.cy, 0.0] else ...walk,
    ];
  }

  void _spawnPassengers(AirportFlight f, AirportFacility stand) {
    final gate = _gate(stand),
        entrances = ofKind('entrance').where((e) => e.connected).toList();
    if (gate == null || entrances.isEmpty) return;
    final route = _entranceRoute(entrances.first);
    for (var n = 0; n < f.passengers; n += 10) {
      final p = AirportPassengerGroup(
        _id('p'),
        f.id,
        math.min(10, f.passengers - n),
        entrances.first.cx,
        entrances.first.cy,
      );
      if (route.isEmpty) {
        p.nextEvent = time + 1 + (n / 10) * .5;
      } else {
        // Groups arrive at the kerb one after another and walk in.
        p.path = route;
        p.started = time + (n / 10) * .5;
        p.nextEvent = p.started + math.max(1, _pathLength(route) / walkSpeed);
      }
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

  /// Arrivals for contracts that need baggage reclaim, one group per ten.
  /// Boarding in single file: groups leave the gate one after another, each
  /// passenger [interval] behind the last, through the jet bridge or up the
  /// stairs, at the gate's lane-and-speed rate. Returns the minutes until the
  /// last one is on board.
  double _board(AirportFlight f, AirportFacility stand, AircraftModel model) {
    final gate = _gate(stand);
    final groups = passengers
        .where((p) => p.flightId == f.id && !p.arriving && p.stage == 'ready')
        .toList();
    if (gate == null || groups.isEmpty) return 1;
    final interval = 1 / boardingRate(stand);
    var released = 0, finish = 0.0;
    for (final p in groups) {
      final path = _gateToDoor(gate, stand, model, [p.x, p.y]);
      final walk = _pathLength(path) / walkSpeed;
      p.path = path;
      p.interval = interval;
      p.started = time + released * interval;
      p.nextEvent = p.started + (p.count - 1) * interval + walk;
      p.stage = 'walkingOnBoard';
      p.x = path.last[0];
      p.y = path.last[1];
      released += p.count;
      finish = math.max(finish, p.nextEvent - time);
    }
    return finish;
  }

  /// Every arriving flight lets its passengers off in single file at the
  /// gate's rate: down the jet bridge or the stairs, into the terminal to
  /// the gate, then bags if the contract has checked luggage, customs,
  /// check-out and out to the kerb. Returns how long the doors stay busy.
  double _spawnArrivals(
    AirportFlight f,
    AirportFacility stand,
    AircraftModel model,
  ) {
    if (passengers.any((p) => p.flightId == f.id && p.arriving)) return 0;
    final gate = _gate(stand);
    if (gate == null || f.passengers <= 0) return 0;
    final interval = 1 / boardingRate(stand);
    final path = _gateToDoor(gate, stand, model, [
      gate.cx,
      gate.cy,
    ]).reversed.toList();
    final walk = _pathLength(path) / walkSpeed;
    for (var n = 0; n < f.passengers; n += 10) {
      final count = math.min(10, f.passengers - n);
      final p = AirportPassengerGroup(_id('p'), f.id, count, gate.cx, gate.cy)
        ..arriving = true;
      p.stage = 'deplaning';
      p.path = path;
      p.interval = interval;
      p.started = time + n * interval;
      p.nextEvent = p.started + (count - 1) * interval + walk;
      passengers.add(p);
    }
    return f.passengers * interval;
  }

  /// Sends an arriving group to the least busy connected [kinds] desk.
  /// False when there is none, or no way to walk there.
  bool _queueArrival(
    AirportPassengerGroup p,
    Set<String> kinds,
    String stage,
    double perMinute,
  ) {
    final desks =
        facilities.where((b) => kinds.contains(b.kind) && b.connected).toList()
          ..sort(
            (a, b) => (queues[a.id] ?? time).compareTo(queues[b.id] ?? time),
          );
    if (desks.isEmpty) return false;
    final desk = desks.first, path = _walk(p.x, p.y, desk);
    if (path.isEmpty) return false;
    final travel = _pathLength(path) / walkSpeed;
    final start = math.max(time + travel, queues[desk.id] ?? time);
    p.satisfaction = (p.satisfaction - (start - time - travel) * .005).clamp(
      0,
      1,
    );
    p.path = path;
    p.started = time;
    p.facilityId = desk.id;
    p.stage = stage;
    p.nextEvent = start + p.count / perMinute / _boost(desk, .25);
    queues[desk.id] = p.nextEvent;
    p.x = path.last[0];
    p.y = path.last[1];
    return true;
  }

  /// People waiting at or collecting from [carousel].
  int carouselLoad(String carouselId) => passengers
      .where(
        (p) =>
            p.arriving &&
            p.facilityId == carouselId &&
            const {'toReclaim', 'reclaim', 'collecting'}.contains(p.stage),
      )
      .fold(0, (n, p) => n + p.count);

  void _arrivalEvent(AirportPassengerGroup p) {
    final flight = flights.where((f) => f.id == p.flightId).firstOrNull;
    void walkTo(AirportFacility target, String stage) {
      final path = _walk(p.x, p.y, target);
      p.path = path;
      p.started = time;
      p.stage = stage;
      p.nextEvent =
          time +
          (path.isEmpty ? 1 : math.max(.5, _pathLength(path) / walkSpeed));
      if (path.isNotEmpty) {
        p.x = path.last[0];
        p.y = path.last[1];
      }
    }

    void hold() {
      p.satisfaction = (p.satisfaction - .01).clamp(0, 1);
      p.nextEvent = time + 2;
    }

    switch (p.stage) {
      case 'deplaning':
        if (p.path.isNotEmpty) {
          p.x = p.path.last[0];
          p.y = p.path.last[1];
        }
        p.path = [];
        final terms = contract(flight?.contractId);
        if (terms != null &&
            terms.offer.requiredServices.contains('baggageCarousel')) {
          p.stage = 'arrived';
          p.nextEvent = time + .1;
        } else if (!_queueArrival(p, const {'customs'}, 'customs', 6)) {
          hold();
        }
      case 'arrived':
        final carousels =
            ofKind('baggageCarousel')
                .where(
                  (c) =>
                      c.connected &&
                      carouselLoad(c.id) + p.count <= carouselCapacity,
                )
                .toList()
              ..sort(
                (a, b) => carouselLoad(a.id).compareTo(carouselLoad(b.id)),
              );
        if (carousels.isEmpty) {
          p.satisfaction = (p.satisfaction - .02).clamp(0, 1);
          p.nextEvent = time + 1;
          return;
        }
        p.facilityId = carousels.first.id;
        walkTo(carousels.first, 'toReclaim');
      case 'toReclaim':
        p.stage = 'reclaim';
        p.started = time;
        p.path = [];
        p.nextEvent = time + .5;
      case 'reclaim':
        final delivered =
            flight == null ||
            flight.finished ||
            flight.serviced.contains('baggage');
        if (!delivered) {
          p.satisfaction = (p.satisfaction - .004).clamp(0, 1);
          p.nextEvent = time + 1;
          return;
        }
        p.stage = 'collecting';
        p.started = time;
        p.nextEvent =
            time + (1.5 + p.count * .15) / _boost(facility(p.facilityId), .25);
      case 'collecting':
        p.facilityId = null;
        if (!_queueArrival(p, const {'customs'}, 'customs', 6)) hold();
      case 'customs':
        if (!_queueArrival(p, const {'checkOut'}, 'checkOut', 10)) hold();
      case 'checkOut':
        p.facilityId = null;
        final exits = ofKind('entrance').where((e) => e.connected).toList();
        if (exits.isEmpty) {
          passengers.remove(p);
          return;
        }
        walkTo(exits.first, 'leaving');
        final out = _entranceRoute(exits.first).reversed.toList();
        if (out.isNotEmpty && p.path.isNotEmpty) {
          p.path = [...p.path, ...out];
          p.x = out.last[0];
          p.y = out.last[1];
          p.nextEvent = time + math.max(.5, _pathLength(p.path) / walkSpeed);
        }
      default:
        final terms = contract(flight?.contractId);
        if (terms != null) {
          terms.satisfaction = (terms.satisfaction * .97 + p.satisfaction * .03)
              .clamp(0, 1);
        }
        passengers.remove(p);
    }
  }

  void _passengerEvent(AirportPassengerGroup p, AirlineGameState airline) {
    if (p.arriving) {
      _arrivalEvent(p);
      return;
    }
    final fs = flights.where((f) => f.id == p.flightId && !f.finished);
    if (fs.isEmpty) {
      passengers.remove(p);
      return;
    }
    final f = fs.first, stand = facility(fs.first.standId)!;
    if (p.stage == 'walkingOnBoard') {
      // On board: hidden until the aircraft leaves and takes the group along.
      p.stage = 'boarded';
      p.path = [];
      p.nextEvent = 1e12;
      return;
    }
    if (p.stage == 'boarded') return;
    if (p.stage == 'entrance' && p.path.isNotEmpty) {
      p.x = p.path.last[0];
      p.y = p.path.last[1];
    }
    final nextKind = switch (p.stage) {
      'entrance' => 'checkIn',
      'checkIn' => 'security',
      'security' => 'shop',
      'shop' => 'toilets',
      'toilets' => 'cafe',
      'cafe' => 'seating',
      _ => 'boardingGate',
    };
    AirportFacility? target;
    if (nextKind == 'boardingGate') {
      target = _gate(stand);
    } else {
      final kinds = switch (nextKind) {
        'seating' => {'seating', 'lounge', 'vipLounge', 'arcade'},
        'checkIn' => {'checkIn', 'checkInCounter', 'ticketMachine'},
        'cafe' => {
          'cafe',
          'restaurant',
          'vendingMachine',
          'coffeeToGo',
          'foodCart',
        },
        'shop' => {
          'shop',
          'kiosk',
          'foodShop',
          'perfumeShop',
          'flowerShop',
          'clothingShop',
          'luxuryBoutique',
        },
        _ => {nextKind},
      };
      final candidates =
          facilities
              .where((b) => kinds.contains(b.kind) && b.connected)
              .toList()
            ..sort(
              (a, b) => (queues[a.id] ?? time).compareTo(queues[b.id] ?? time),
            );
      if (candidates.isNotEmpty) target = candidates.first;
    }
    if (target == null && nextKind == 'shop') {
      p.stage = nextKind;
      p.nextEvent = time + .05;
      return;
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
    final travel = _pathLength(path) / walkSpeed;
    final start = math.max(time + travel, queues[target.id] ?? time);
    final wait = start - time - travel;
    p.satisfaction = (p.satisfaction - wait * .005).clamp(0, 1);
    final duration =
        (target.kind == 'ticketMachine'
            ? p.count / 4
            : target.kind == 'checkInCounter'
            ? p.count / 10
            : nextKind == 'checkIn'
            ? p.count / 8
            : nextKind == 'security'
            ? p.count / 6
            : target.kind == 'restaurant'
            ? 5.0
            : target.kind == 'coffeeToGo'
            ? 1.5
            : target.kind == 'foodCart'
            ? 1.0
            : target.kind == 'cafe'
            ? 3.0
            : target.kind == 'kiosk'
            ? 1.5
            : target.kind == 'foodShop'
            ? 2.5
            : target.kind == 'perfumeShop'
            ? 2.0
            : target.kind == 'flowerShop'
            ? 2.0
            : target.kind == 'luxuryBoutique'
            ? 4.0
            : target.kind == 'clothingShop'
            ? 3.0
            : nextKind == 'shop'
            ? 2.0
            : 1.0) /
        (_waitingKinds.contains(target.kind) ? 1 : _boost(target, .25));
    final sales = _boost(target, .15);
    void sell(int amount, String description) =>
        _book(airline, 'retail', (amount * sales).round(), description);
    if (nextKind == 'seating' || nextKind == 'boardingGate') {
      final decor = facilities
          .where((d) => decorKinds.contains(d.kind) && d.connected)
          .fold(0, (n, d) => n + d.level);
      p.satisfaction =
          (p.satisfaction +
                  math.min(.02, decor * .002) +
                  infoDeskBonus +
                  terminalComfort +
                  (cleanliness - .6) / 8)
              .clamp(0, 1);
    }
    if (_waitingKinds.contains(target.kind)) {
      p.satisfaction = (p.satisfaction + (target.level - 1) * .01).clamp(0, 1);
    }
    p.started = time;
    p.path = path;
    p.facilityId = target.id;
    p.nextEvent = start + duration;
    queues[target.id] = p.nextEvent;
    p.stage = nextKind == 'boardingGate' ? 'walkingToGate' : nextKind;
    if (target.kind == 'foodCart') {
      sell(p.count * 4, 'Food cart sales');
    } else if (target.kind == 'coffeeToGo') {
      sell(p.count * 6, 'Coffee to-go sales');
    } else if (target.kind == 'restaurant') {
      sell(p.count * 26, 'Restaurant covers');
      p.satisfaction = (p.satisfaction + .04).clamp(0, 1);
    } else if (target.kind == 'cafe') {
      sell(p.count * 8, 'Terminal café');
    } else if (target.kind == 'vendingMachine') {
      sell(p.count * 3, 'Vending machines');
    } else if (target.kind == 'flowerShop') {
      sell(p.count * 16, 'Flower shop sales');
    } else if (target.kind == 'perfumeShop') {
      // Low demand, high value: a quarter of the group buys, at 90 euro each.
      sell((p.count * .25).round() * 90, 'Perfume sales');
    } else if (target.kind == 'foodShop') {
      sell(p.count * 20, 'Duty-free food & drink sales');
    } else if (target.kind == 'kiosk') {
      sell(p.count * 9, 'Newsstand sales');
    } else if (target.kind == 'luxuryBoutique') {
      sell(p.count * 26, 'Luxury boutique sales');
      p.satisfaction = (p.satisfaction + .02).clamp(0, 1);
    } else if (target.kind == 'clothingShop') {
      sell(p.count * 18, 'Fashion boutique sales');
    } else if (nextKind == 'shop') {
      sell(p.count * 14, 'Duty-free sales');
    } else if (target.kind == 'arcade') {
      sell(p.count * 12, 'Arcade tokens');
      p.satisfaction = (p.satisfaction + .07).clamp(0, 1);
    } else if (target.kind == 'vipLounge') {
      sell(p.count * 35, 'VIP lounge access');
      p.satisfaction = (p.satisfaction + .08).clamp(0, 1);
    } else if (target.kind == 'lounge') {
      sell(p.count * 20, 'Lounge access');
      p.satisfaction = (p.satisfaction + .05).clamp(0, 1);
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
    final depot = sources.first;
    v.path = [
      ..._route(toSupply, [v.x, v.y], [depot.cx, depot.cy]),
      ..._route(route, [depot.cx, depot.cy], [stand.cx, stand.cy]).skip(1),
    ];
    v.returning = false;
    v.started = time;
    v.flightId = f.id;
    v.arriveAt = time + _pathLength(v.path) / vehicleSpeed;
    v.busyUntil =
        v.arriveAt +
        (kind == 'fuel'
                ? 8
                : kind == 'baggage'
                ? 6
                : 3) /
            (_boost(sources.first, .2) * _boost(stand, .15));
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
      v.busyUntil = time + math.max(1, _pathLength(v.path) / vehicleSpeed);
      v.arriveAt = v.busyUntil;
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
    final groups = passengers
        .where((p) => p.flightId == f.id && !p.arriving)
        .toList();
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
        (time - v.started) / math.max(.001, v.arriveAt - v.started),
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
    'signedOffers': signedOffers.toList(),
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
    w.signedOffers.addAll((j['signedOffers'] as List? ?? []).cast<String>());
    w.resolveConnections();
    return w;
  }
}
