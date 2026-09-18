import '../data/aircraft.dart';

/// Start windows an airline accepts, in minutes of the day. `ALL` is any time.
const airportSlots = <String, (int, int)>{
  'EAM': (0, 360),
  'AM': (360, 720),
  'AN': (720, 1080),
  'PM': (1080, 1440),
};

/// How long a flight of each size class holds its stand, in minutes.
const haulMinutes = {'SH': 180, 'MH': 240, 'LH': 360};

/// A flight lands at the start of its stand slot and pushes back this long
/// before the slot ends, leaving time to taxi out.
const slotExitMinutes = 30;

/// How far ahead the planning board accepts flights.
const planningHorizonDays = 14;

/// Size class the planner shows for an aircraft: short, medium or long haul.
String aircraftSizeClass(AircraftModel model) => model.mtowTonnes <= 45
    ? 'SH'
    : model.mtowTonnes <= 100
    ? 'MH'
    : 'LH';

bool slotAllows(String slot, double arrival) {
  final window = airportSlots[slot];
  if (window == null) return true;
  final minute = ((arrival % 1440) + 1440) % 1440;
  return minute >= window.$1 && minute < window.$2;
}

String slotLabel(String slot) {
  final window = airportSlots[slot];
  if (window == null) return 'any time';
  String hh(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:00';
  return '$slot (${hh(window.$1)}–${hh(window.$2)})';
}

class AirportAirline {
  const AirportAirline(this.name, this.fleet, this.slots, this.services);
  final String name;
  final List<String> fleet, slots, services;
}

/// Airlines that send contract offers. Invented names; the three first ones
/// also back the permanent starter offers.
const airportAirlines = <AirportAirline>[
  AirportAirline('Coastal Connect', ['atr72', 'e175'], ['EAM', 'AM', 'ALL'], [
    'fuelDepot',
    'baggage',
  ]),
  AirportAirline(
    'Meridian Airways',
    ['a320neo', 'b737max8', 'a220_300'],
    ['AM', 'AN'],
    ['fuelDepot', 'baggage', 'cafe'],
  ),
  AirportAirline(
    'Aurora International',
    ['b787_9', 'a330_900', 'a350_1000'],
    ['AN', 'PM'],
    ['fuelDepot', 'baggage', 'cafe', 'seating', 'toilets'],
  ),
  AirportAirline(
    'Northwind Regional',
    ['atr72', 'e175', 'e195e2'],
    ['EAM', 'AM'],
    ['fuelDepot', 'baggage'],
  ),
  AirportAirline('Harbor Hopper', ['atr72'], ['ALL'], ['fuelDepot']),
  AirportAirline('Sunline Charter', ['a321neo', 'b737max8'], ['PM', 'EAM'], [
    'fuelDepot',
    'baggage',
    'shop',
  ]),
  AirportAirline('Crescent Air', ['a320neo', 'a321neo'], ['AN', 'PM'], [
    'fuelDepot',
    'baggage',
    'cafe',
    'shop',
  ]),
  AirportAirline(
    'Atlas Pacific',
    ['b777_300er', 'a350_1000', 'b747_8i'],
    ['PM', 'EAM'],
    ['fuelDepot', 'baggage', 'cafe', 'lounge', 'toilets'],
  ),
  AirportAirline('Kestrel Jet', ['e195e2', 'a220_300'], ['AM', 'ALL'], [
    'fuelDepot',
    'baggage',
  ]),
];

/// What an airline proposes: a daily [regular] series, or [charter] flights
/// the player places one by one.
class AirportOffer {
  const AirportOffer({
    required this.id,
    required this.carrier,
    required this.modelId,
    required this.type,
    required this.flights,
    required this.slot,
    required this.passengers,
    required this.fee,
    required this.penalty,
    required this.requiredServices,
    this.expiresDay,
  });

  static const regular = 'regular', charter = 'charter';

  final String id, carrier, modelId, type, slot;
  final int flights, passengers, fee, penalty;
  final List<String> requiredServices;

  /// Last day the offer can be signed; null for the permanent starter offers.
  final int? expiresDay;

  AircraftModel get model => aircraftModelById(modelId)!;
  String get haul => aircraftSizeClass(model);
  int get standMinutes => haulMinutes[haul]!;
  bool get isRegular => type == regular;

  /// Days after signing within which a regular series must start, or by
  /// which every charter flight must have flown.
  int get placementDays => isRegular ? 3 : 6;

  Map<String, Object?> toJson() => {
    'id': id,
    'carrier': carrier,
    'modelId': modelId,
    'type': type,
    'flights': flights,
    'slot': slot,
    'slotLabel': slotLabel(slot),
    'passengers': passengers,
    'fee': fee,
    'penalty': penalty,
    'requiredServices': requiredServices,
    'expiresDay': expiresDay,
    'haul': haul,
    'standMinutes': standMinutes,
    'placementDays': placementDays,
    'runwayM': model.minRunwayM,
    'total': fee * flights,
  };

  factory AirportOffer.fromJson(Map<String, Object?> j) => AirportOffer(
    id: j['id'] as String,
    carrier: j['carrier'] as String,
    modelId: j['modelId'] as String,
    type: j['type'] == charter ? charter : regular,
    flights: (j['flights'] as num).toInt(),
    slot: j['slot'] as String? ?? 'ALL',
    passengers: (j['passengers'] as num).toInt(),
    fee: (j['fee'] as num).toInt(),
    penalty: (j['penalty'] as num).toInt(),
    requiredServices: (j['requiredServices'] as List? ?? [])
        .cast<String>()
        .toList(),
    expiresDay: (j['expiresDay'] as num?)?.toInt(),
  );
}

/// Always on offer, so a new airport has something that fits its starter
/// facilities. Each can be signed again once its previous contract is over.
const airportOffers = [
  AirportOffer(
    id: 'coastal',
    carrier: 'Coastal Connect',
    modelId: 'atr72',
    type: AirportOffer.regular,
    flights: 7,
    slot: 'ALL',
    passengers: 56,
    fee: 42000,
    penalty: 12000,
    requiredServices: ['fuelDepot', 'baggage'],
  ),
  AirportOffer(
    id: 'meridian',
    carrier: 'Meridian Airways',
    modelId: 'a320neo',
    type: AirportOffer.regular,
    flights: 7,
    slot: 'AM',
    passengers: 144,
    fee: 95000,
    penalty: 30000,
    requiredServices: ['fuelDepot', 'baggage', 'cafe', 'baggageCarousel'],
  ),
  AirportOffer(
    id: 'aurora',
    carrier: 'Aurora International',
    modelId: 'b787_9',
    type: AirportOffer.regular,
    flights: 7,
    slot: 'AN',
    passengers: 237,
    fee: 160000,
    penalty: 55000,
    requiredServices: [
      'fuelDepot',
      'baggage',
      'cafe',
      'seating',
      'toilets',
      'baggageCarousel',
    ],
  ),
];

/// A stable pseudo-random stream: offers must be identical on every device
/// and after every reload, so nothing here may touch an unseeded Random.
class _Stream {
  _Stream(int seed) : _state = (seed * 2654435761) & 0x7fffffff;
  int _state;
  int next(int bound) {
    _state = (_state * 48271) % 0x7fffffff;
    return _state % bound;
  }
}

/// The offers airlines publish on [publishedDay]; each stays open two days.
/// The first of each day is short haul, so a young airport always has
/// something its starter runway and stands can take.
List<AirportOffer> offersPublishedOn(int publishedDay) => [
  for (var i = 0; i < 3; i++) _generate(publishedDay, i),
];

bool _shortHaul(String modelId) =>
    aircraftSizeClass(aircraftModelById(modelId)!) == 'SH';

AirportOffer _generate(int day, int index) {
  final r = _Stream(day * 31 + index * 7 + 11);
  final regional = index == 0;
  final airlines = [
    for (final a in airportAirlines)
      if (!regional || a.fleet.any(_shortHaul)) a,
  ];
  final airline = airlines[r.next(airlines.length)];
  final fleet = [
    for (final id in airline.fleet)
      if (!regional || _shortHaul(id)) id,
  ];
  final model = aircraftModelById(fleet[r.next(fleet.length)])!;
  final charter = r.next(3) == 0;
  final haul = aircraftSizeClass(model);
  final flights = charter ? 2 + r.next(4) : 3 + r.next(5);
  final load = .7 + r.next(26) / 100;
  final passengers = (model.seats * load).round();
  final base = switch (haul) {
    'SH' => 30000 + r.next(20001),
    'MH' => 70000 + r.next(40001),
    _ => 140000 + r.next(60001),
  };
  final fee = ((base * load / .85) * (charter ? 1.25 : 1) / 100).round() * 100;
  return AirportOffer(
    id: 'o$day-$index',
    carrier: airline.name,
    modelId: model.id,
    type: charter ? AirportOffer.charter : AirportOffer.regular,
    flights: flights,
    slot: charter ? 'ALL' : airline.slots[r.next(airline.slots.length)],
    passengers: passengers,
    fee: fee,
    penalty: (fee * .3 / 100).round() * 100,
    requiredServices: [
      ...airline.services,
      if (haul != 'SH') 'baggageCarousel',
    ],
    expiresDay: day + 2,
  );
}

class AirportContract {
  AirportContract({
    required this.id,
    required this.offer,
    required this.signedDay,
    this.placed = 0,
    this.startDay,
    this.endDay,
    int? deadlineDay,
    this.satisfaction = 1,
    this.cancelled = false,
    this.lapsed = 0,
  }) : deadlineDay = deadlineDay ?? signedDay + offer.placementDays;

  final String id;
  final AirportOffer offer;
  final int signedDay;

  /// Flights put on the timetable so far, including ones already flown.
  int placed;

  /// Flights that were never placed and were forfeited with a penalty.
  int lapsed;
  int? startDay, endDay;

  /// Unplaced flights must be on the timetable by the end of this day.
  int deadlineDay;
  double satisfaction;
  bool cancelled;

  String get offerId => offer.id;
  String get carrier => offer.carrier;
  int get remaining => cancelled ? 0 : offer.flights - placed - lapsed;

  Map<String, Object?> toJson() => {
    'id': id,
    'offerId': offer.id,
    'offer': offer.toJson(),
    'carrier': offer.carrier,
    'signedDay': signedDay,
    'placed': placed,
    'lapsed': lapsed,
    'remaining': remaining,
    'startDay': startDay,
    'endDay': endDay,
    'deadlineDay': deadlineDay,
    'satisfaction': satisfaction,
    'cancelled': cancelled,
  };

  factory AirportContract.fromJson(Map<String, Object?> j) {
    final stored = j['offer'];
    final offer = stored is Map
        ? AirportOffer.fromJson(Map<String, Object?>.from(stored))
        : airportOffers.firstWhere((o) => o.id == j['offerId']);
    final startDay = (j['startDay'] as num?)?.toInt();
    return AirportContract(
      id: j['id'] as String,
      offer: offer,
      signedDay: (j['signedDay'] as num?)?.toInt() ?? startDay ?? 1,
      // Saves from before placement existed scheduled everything at signing.
      placed: (j['placed'] as num?)?.toInt() ?? offer.flights,
      lapsed: (j['lapsed'] as num?)?.toInt() ?? 0,
      startDay: startDay,
      endDay: (j['endDay'] as num?)?.toInt(),
      deadlineDay: (j['deadlineDay'] as num?)?.toInt(),
      satisfaction: (j['satisfaction'] as num?)?.toDouble() ?? 1,
      cancelled: j['cancelled'] == true,
    );
  }
}
