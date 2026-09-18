import 'dart:math' as math;

/// Great-circle geometry for the airline sim.
///
/// Two very different jobs get confused easily, so they are kept apart on
/// purpose: distances here are real great-circle kilometres (they drive block
/// time, fuel burn and therefore every cost in the game), while *drawing* a
/// route on the world map goes through `MillerProjection` in
/// `lib/account/travel/world_map_data.dart`. Projecting a distance, or
/// measuring one in unit space, is the obvious bug in this file's vicinity.
class Geo {
  const Geo._();

  /// Mean Earth radius, in kilometres.
  static const double earthRadiusKm = 6371.0088;

  static double _rad(double degrees) => degrees * math.pi / 180;

  /// Great-circle distance between two points in kilometres (haversine).
  static double distanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    // atan2 rather than asin: it stays accurate for antipodal pairs, where
    // `a` creeps above 1 and asin would return NaN.
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// A point [t] of the way (0..1) along the great circle from 1 to 2, as
  /// (latitude, longitude) in degrees. Used to draw route arcs that bend the
  /// way a real flight path does instead of running straight across the map.
  static ({double lat, double lon}) interpolate(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
    double t,
  ) {
    final phi1 = _rad(lat1);
    final lambda1 = _rad(lon1);
    final phi2 = _rad(lat2);
    final lambda2 = _rad(lon2);

    final delta = distanceKm(lat1, lon1, lat2, lon2) / earthRadiusKm;
    // Coincident endpoints leave sin(delta) at zero; there is nothing to
    // interpolate, so hand back the start point rather than dividing by it.
    if (delta < 1e-9) return (lat: lat1, lon: lon1);

    final sinDelta = math.sin(delta);
    final a = math.sin((1 - t) * delta) / sinDelta;
    final b = math.sin(t * delta) / sinDelta;

    final x = a * math.cos(phi1) * math.cos(lambda1) +
        b * math.cos(phi2) * math.cos(lambda2);
    final y = a * math.cos(phi1) * math.sin(lambda1) +
        b * math.cos(phi2) * math.sin(lambda2);
    final z = a * math.sin(phi1) + b * math.sin(phi2);

    return (
      lat: math.atan2(z, math.sqrt(x * x + y * y)) * 180 / math.pi,
      lon: math.atan2(y, x) * 180 / math.pi,
    );
  }

  /// Block time in hours: time in the air plus a fixed half hour of taxi,
  /// hold and turnaround at each end.
  static double blockHours(double distanceKm, double cruiseKmh) {
    if (cruiseKmh <= 0) return 0;
    return distanceKm / cruiseKmh + 0.5;
  }
}
