/// The aircraft the player can buy or lease.
///
/// Model names and their published performance figures are plain facts, and
/// nothing here is drawn from manufacturer artwork — the fleet is rendered as
/// generic silhouettes. Figures are rounded, typical-configuration numbers:
/// this is a game, not a flight planner, and the balance below matters more
/// than the third significant digit.
class AircraftModel {
  const AircraftModel({
    required this.id,
    required this.name,
    required this.maker,
    required this.seats,
    required this.rangeKm,
    required this.cruiseKmh,
    required this.fuelKgPerKm,
    required this.priceEur,
    required this.minRunwayM,
    required this.maintPerHourEur,
    required this.mtowTonnes,
  });

  final String id;
  final String name;
  final String maker;
  final int seats;
  final int rangeKm;
  final double cruiseKmh;

  /// Fuel burn in kilograms per kilometre at typical load.
  final double fuelKgPerKm;

  final int priceEur;

  /// Runway length this type needs at maximum take-off weight.
  final int minRunwayM;

  final int maintPerHourEur;
  final int mtowTonnes;

  /// Daily cost of leasing instead of buying. Real dry leases run around
  /// 0.8% of list price a month, so a day is roughly price / 3750 — cheap to
  /// start, dramatically worse than owning if you keep it for years.
  int get leasePerDayEur => (priceEur / 3750).round();

  /// What a used airframe fetches back. Selling always loses money, which is
  /// what stops the fleet screen being a free undo button.
  int resaleValueEur(double hours) {
    final wear = (hours / 30000).clamp(0.0, 0.75);
    return (priceEur * 0.78 * (1 - wear)).round();
  }

  /// Whether this type can operate from a runway of [runwayM] metres.
  bool canUseRunway(int runwayM) => runwayM >= minRunwayM;
}

/// Ordered smallest to largest, which is also roughly the order a player
/// unlocks them.
const List<AircraftModel> kAircraftCatalog = [
  AircraftModel(
    id: 'atr72',
    name: 'ATR 72-600',
    maker: 'ATR',
    seats: 70,
    rangeKm: 1528,
    cruiseKmh: 510,
    fuelKgPerKm: 1.6,
    priceEur: 27000000,
    minRunwayM: 1290,
    maintPerHourEur: 900,
    mtowTonnes: 23,
  ),
  AircraftModel(
    id: 'e175',
    name: 'E175',
    maker: 'Embraer',
    seats: 88,
    rangeKm: 3900,
    cruiseKmh: 830,
    fuelKgPerKm: 2.5,
    priceEur: 48000000,
    minRunwayM: 1700,
    maintPerHourEur: 1200,
    mtowTonnes: 40,
  ),
  AircraftModel(
    id: 'e195e2',
    name: 'E195-E2',
    maker: 'Embraer',
    seats: 132,
    rangeKm: 4800,
    cruiseKmh: 833,
    fuelKgPerKm: 2.8,
    priceEur: 61000000,
    minRunwayM: 1800,
    maintPerHourEur: 1400,
    mtowTonnes: 61,
  ),
  AircraftModel(
    id: 'a220_300',
    name: 'A220-300',
    maker: 'Airbus',
    seats: 145,
    rangeKm: 6300,
    cruiseKmh: 870,
    fuelKgPerKm: 3.0,
    priceEur: 91000000,
    minRunwayM: 1890,
    maintPerHourEur: 1500,
    mtowTonnes: 70,
  ),
  AircraftModel(
    id: 'a320neo',
    name: 'A320neo',
    maker: 'Airbus',
    seats: 180,
    rangeKm: 6500,
    cruiseKmh: 833,
    fuelKgPerKm: 3.2,
    priceEur: 111000000,
    minRunwayM: 2100,
    maintPerHourEur: 1700,
    mtowTonnes: 79,
  ),
  AircraftModel(
    id: 'b737max8',
    name: '737 MAX 8',
    maker: 'Boeing',
    seats: 178,
    rangeKm: 6570,
    cruiseKmh: 839,
    fuelKgPerKm: 3.3,
    priceEur: 122000000,
    minRunwayM: 2100,
    maintPerHourEur: 1700,
    mtowTonnes: 82,
  ),
  AircraftModel(
    id: 'a321neo',
    name: 'A321neo',
    maker: 'Airbus',
    seats: 220,
    rangeKm: 7400,
    cruiseKmh: 833,
    fuelKgPerKm: 3.6,
    priceEur: 129000000,
    minRunwayM: 2200,
    maintPerHourEur: 1900,
    mtowTonnes: 97,
  ),
  AircraftModel(
    id: 'a330_900',
    name: 'A330-900',
    maker: 'Airbus',
    seats: 287,
    rangeKm: 13330,
    cruiseKmh: 871,
    fuelKgPerKm: 5.8,
    priceEur: 296000000,
    minRunwayM: 2770,
    maintPerHourEur: 3200,
    mtowTonnes: 251,
  ),
  AircraftModel(
    id: 'b787_9',
    name: '787-9 Dreamliner',
    maker: 'Boeing',
    seats: 296,
    rangeKm: 14140,
    cruiseKmh: 903,
    fuelKgPerKm: 5.6,
    priceEur: 293000000,
    minRunwayM: 2800,
    maintPerHourEur: 3100,
    mtowTonnes: 254,
  ),
  AircraftModel(
    id: 'a350_1000',
    name: 'A350-1000',
    maker: 'Airbus',
    seats: 369,
    rangeKm: 16100,
    cruiseKmh: 910,
    fuelKgPerKm: 6.4,
    priceEur: 366000000,
    minRunwayM: 2700,
    maintPerHourEur: 3500,
    mtowTonnes: 319,
  ),
  AircraftModel(
    id: 'b777_300er',
    name: '777-300ER',
    maker: 'Boeing',
    seats: 396,
    rangeKm: 13650,
    cruiseKmh: 905,
    fuelKgPerKm: 7.4,
    priceEur: 375000000,
    minRunwayM: 3120,
    maintPerHourEur: 3800,
    mtowTonnes: 352,
  ),
  AircraftModel(
    id: 'b747_8i',
    name: '747-8 Intercontinental',
    maker: 'Boeing',
    seats: 410,
    rangeKm: 14320,
    cruiseKmh: 920,
    fuelKgPerKm: 9.9,
    priceEur: 419000000,
    minRunwayM: 3100,
    maintPerHourEur: 4600,
    mtowTonnes: 448,
  ),
  AircraftModel(
    id: 'a380_800',
    name: 'A380-800',
    maker: 'Airbus',
    seats: 575,
    rangeKm: 14800,
    cruiseKmh: 903,
    fuelKgPerKm: 11.9,
    priceEur: 445000000,
    minRunwayM: 3000,
    maintPerHourEur: 5200,
    mtowTonnes: 575,
  ),
];

final Map<String, AircraftModel> kAircraftById = {
  for (final model in kAircraftCatalog) model.id: model,
};

AircraftModel? aircraftModelById(String? id) =>
    id == null ? null : kAircraftById[id];
