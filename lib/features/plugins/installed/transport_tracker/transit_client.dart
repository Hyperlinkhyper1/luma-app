import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'gtfs_realtime.dart';
import 'gtfs_stops.dart';
import 'transit_vehicle.dart';

enum TransitConnectionState { idle, loading, live, error }

/// Polls a GTFS-realtime `VehiclePositions` feed for live public-transport
/// positions.
///
/// The default source is OVapi's nationwide Dutch feed, which needs no API
/// key. It is fetched here in Dart rather than from the WebView because the
/// endpoint sends no CORS headers — a browser request from the map page
/// would be blocked, while `dart:io` is not subject to that.
///
/// This is deliberately *not* routed through `GatedServerClient`: OVapi is a
/// third-party open-data endpoint, not a luma server, so the account gate in
/// `lib/sync/server_access.dart` does not apply.
class TransitClient {
  TransitClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client(),
        _ownsClient = httpClient == null;

  static const nlVehiclePositionsUrl =
      'https://gtfs.ovapi.nl/nl/vehiclePositions.pb';

  /// Stop-level predictions for buses, trams and metros — the source of the
  /// "next stops" list.
  static const nlTripUpdatesUrl = 'https://gtfs.ovapi.nl/nl/tripUpdates.pb';

  /// The train equivalent. Trains are absent from the vehicle-position feed
  /// entirely, so their positions are derived from this (see
  /// [interpolateTrains]).
  static const nlTrainUpdatesUrl = 'https://gtfs.ovapi.nl/nl/trainUpdates.pb';

  /// The publisher refreshes roughly every 20s; polling faster only burns
  /// bandwidth for the same payload.
  static const pollInterval = Duration(seconds: 20);

  final http.Client _http;
  final bool _ownsClient;

  Timer? _timer;
  bool _fetching = false;

  final _vehiclesController =
      StreamController<List<TransitVehicle>>.broadcast();
  final _stateController =
      StreamController<TransitConnectionState>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<List<TransitVehicle>> get vehicles => _vehiclesController.stream;
  Stream<TransitConnectionState> get state => _stateController.stream;
  Stream<String> get errors => _errorController.stream;

  TransitConnectionState _current = TransitConnectionState.idle;
  TransitConnectionState get currentState => _current;

  bool get running => _timer != null;

  /// Splits an OVapi entity id (`date:OPERATOR:LINE:journey[:extra]`) into
  /// the operator and line parts. Ids that don't match are passed through
  /// with nulls so the vehicle still renders.
  static ({String? operator, String? line}) parseOvapiId(String entityId) {
    final parts = entityId.split(':');
    if (parts.length < 3) return (operator: null, line: null);
    return (operator: parts[1], line: parts[2]);
  }

  void start() {
    if (_timer != null) return;
    unawaited(_fetchOnce());
    _timer = Timer.periodic(pollInterval, (_) => unawaited(_fetchOnce()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _setState(TransitConnectionState.idle);
  }

  /// Fetches immediately, outside the poll cadence (used on manual refresh).
  Future<void> refresh() => _fetchOnce();

  /// Stops used to place interpolated trains and to name calls. Set by the
  /// host once the cache is available; without it trains cannot be placed.
  GtfsStopsCache? stops;

  /// Remaining calls per trip, keyed by trip id, from both update feeds.
  Map<String, TripUpdate> _tripUpdates = const {};
  Map<String, TripUpdate> get tripUpdates => _tripUpdates;

  Future<Uint8List?> _fetch(String url) async {
    final response =
        await _http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      _errorController.add('$url returned HTTP ${response.statusCode}.');
      return null;
    }
    return Uint8List.fromList(response.bodyBytes);
  }

  Future<void> _fetchOnce() async {
    if (_fetching) return;
    _fetching = true;
    if (_current != TransitConnectionState.live) {
      _setState(TransitConnectionState.loading);
    }
    try {
      final positionBytes = await _fetch(nlVehiclePositionsUrl);
      if (positionBytes == null) {
        _setState(TransitConnectionState.error);
        return;
      }
      final vehicles = parseVehiclePositions(
        positionBytes,
        idParser: parseOvapiId,
      );

      // Trip updates power the next-stops list; a failure here must not take
      // the vehicle layer down with it.
      final updates = <String, TripUpdate>{};
      for (final url in [nlTripUpdatesUrl, nlTrainUpdatesUrl]) {
        try {
          final bytes = await _fetch(url);
          if (bytes == null) continue;
          for (final update in parseTripUpdates(bytes)) {
            final id = update.tripId;
            if (id != null) updates[id] = update;
          }
        } catch (_) {
          // Keep whatever did load.
        }
      }
      _tripUpdates = updates;

      final trains = interpolateTrains(updates.values, stops);
      _setState(TransitConnectionState.live);
      if (!_vehiclesController.isClosed) {
        _vehiclesController.add([...vehicles, ...trains]);
      }
    } catch (e) {
      _setState(TransitConnectionState.error);
      _errorController.add('Could not load the transit feed: $e');
    } finally {
      _fetching = false;
    }
  }

  /// Places trains between the stations they are running between.
  ///
  /// The Dutch open feeds publish no train *positions* at all — only their
  /// remaining calls and delays. A train's whereabouts is therefore derived
  /// the same way public trackers such as TRAVIC do it: find the pair of
  /// consecutive calls that now falls between, then interpolate along the
  /// straight line joining those two stations.
  ///
  /// That means a train follows chords between stations rather than the
  /// actual track geometry (the shapes file is 255 MB and is not fetched),
  /// so positions are indicative rather than survey-accurate.
  static List<TransitVehicle> interpolateTrains(
    Iterable<TripUpdate> updates,
    GtfsStopsCache? stops, {
    DateTime? now,
  }) {
    if (stops == null || stops.isEmpty) return const [];
    final at = now ?? DateTime.now();
    final out = <TransitVehicle>[];

    for (final update in updates) {
      final calls = update.calls;
      if (calls.length < 2) continue;

      for (var i = 0; i < calls.length - 1; i++) {
        final from = calls[i];
        final to = calls[i + 1];
        final departure = from.departure ?? from.arrival;
        final arrival = to.arrival ?? to.departure;
        if (departure == null || arrival == null) continue;
        if (at.isBefore(departure) || at.isAfter(arrival)) continue;

        final fromStop = stops.lookup(from.stopId);
        final toStop = stops.lookup(to.stopId);
        // Only this one segment can contain `at`, so an unusable pair means
        // the train simply cannot be placed — better than placing it wrong.
        if (fromStop == null || toStop == null) break;
        if (!fromStop.hasPosition || !toStop.hasPosition) break;

        final span = arrival.difference(departure).inMilliseconds;
        final progress = span <= 0
            ? 0.0
            : (at.difference(departure).inMilliseconds / span).clamp(0.0, 1.0);

        out.add(TransitVehicle(
          id: 'train:${update.tripId}',
          latitude: fromStop.lat + (toStop.lat - fromStop.lat) * progress,
          longitude: fromStop.lon + (toStop.lon - fromStop.lon) * progress,
          mode: TransitMode.train,
          operator: 'NS',
          line: update.routeId,
          label: update.vehicleLabel,
          timestamp: at,
          tripId: update.tripId,
          interpolated: true,
        ));
        break;
      }
    }
    return out;
  }

  void _setState(TransitConnectionState s) {
    _current = s;
    if (!_stateController.isClosed) _stateController.add(s);
  }

  Future<void> dispose() async {
    stop();
    if (_ownsClient) _http.close();
    await _vehiclesController.close();
    await _stateController.close();
    await _errorController.close();
  }
}
