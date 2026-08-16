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

  /// How often the timer wakes. Which feeds actually get fetched on a given
  /// tick is decided per feed by the intervals below.
  static const pollInterval = Duration(seconds: 30);

  /// Positions are small (~400 KB) and are the thing that visibly moves.
  static const positionsInterval = Duration(seconds: 30);

  /// The update feeds are 3-4 MB each and change slowly, so they are pulled
  /// far less often. Trains still appear to move between fetches because
  /// their positions are re-interpolated against the clock every tick.
  static const updatesInterval = Duration(minutes: 2);

  /// OVapi returns HTTP 429 if it is polled too hard. When that happens the
  /// client backs off exponentially rather than hammering it further.
  static const _maxBackoff = Duration(minutes: 8);

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

  /// Fetches immediately, outside the poll cadence (used on manual refresh
  /// and once the stop cache arrives, which is what makes trains placeable).
  Future<void> refresh() => _fetchOnce();

  /// Recomputes train positions against the clock and re-emits, without
  /// touching the network.
  void repositionTrains() {
    if (_vehiclesController.isClosed) return;
    final trains =
        wantsTrains ? interpolateTrains(_trainTrips, stops) : const <TransitVehicle>[];
    _vehiclesController.add([..._positions, ...trains]);
  }

  /// Stops used to place interpolated trains and to name calls. Set by the
  /// host once the cache is available; without it trains cannot be placed.
  GtfsStopsCache? stops;

  /// Remaining calls per trip, keyed by trip id, from both update feeds.
  Map<String, TripUpdate> _tripUpdates = const {};
  Map<String, TripUpdate> get tripUpdates => _tripUpdates;

  /// Per-URL conditional-request state, so an unchanged feed costs a 304
  /// instead of several megabytes.
  final _etags = <String, String>{};
  final _lastFetched = <String, DateTime>{};

  List<TransitVehicle> _positions = const [];
  List<TripUpdate> _trainTrips = const [];
  Duration _backoff = Duration.zero;
  DateTime? _blockedUntil;

  /// Set by the host: trains are only worth their 3.7 MB feed when the user
  /// actually wants to see them.
  bool wantsTrains = true;

  bool _isDue(String url, Duration interval) {
    final last = _lastFetched[url];
    return last == null || DateTime.now().difference(last) >= interval;
  }

  /// Returns the body, or null when nothing new is available (304, an
  /// error, or a rate-limit hold).
  Future<Uint8List?> _fetch(String url) async {
    final headers = <String, String>{};
    final etag = _etags[url];
    if (etag != null) headers['If-None-Match'] = etag;

    final response = await _http
        .get(Uri.parse(url), headers: headers)
        .timeout(const Duration(seconds: 45));

    _lastFetched[url] = DateTime.now();

    if (response.statusCode == 304) return null;

    if (response.statusCode == 429) {
      // Back off hard and stop asking for a while.
      _backoff = _backoff == Duration.zero
          ? const Duration(minutes: 1)
          : Duration(seconds: (_backoff.inSeconds * 2).clamp(60, _maxBackoff.inSeconds));
      _blockedUntil = DateTime.now().add(_backoff);
      _errorController.add(
          'The transit feed is rate-limiting this device. Pausing for '
          '${_backoff.inMinutes} min.');
      return null;
    }

    if (response.statusCode != 200) {
      _errorController.add('Transit feed returned HTTP ${response.statusCode}.');
      return null;
    }

    _backoff = Duration.zero;
    _blockedUntil = null;
    final newEtag = response.headers['etag'];
    if (newEtag != null) _etags[url] = newEtag;
    return Uint8List.fromList(response.bodyBytes);
  }

  Future<void> _fetchOnce() async {
    if (_fetching) return;
    _fetching = true;
    if (_current != TransitConnectionState.live) {
      _setState(TransitConnectionState.loading);
    }
    try {
      final blocked =
          _blockedUntil != null && DateTime.now().isBefore(_blockedUntil!);

      if (!blocked && _isDue(nlVehiclePositionsUrl, positionsInterval)) {
        final bytes = await _fetch(nlVehiclePositionsUrl);
        if (bytes != null) {
          _positions = parseVehiclePositions(bytes, idParser: parseOvapiId);
        }
      }

      // Stop predictions and train journeys change slowly; a failure in
      // either must not take the vehicle layer down with it.
      if (!blocked && _isDue(nlTripUpdatesUrl, updatesInterval)) {
        try {
          final bytes = await _fetch(nlTripUpdatesUrl);
          if (bytes != null) {
            final merged = <String, TripUpdate>{..._tripUpdates};
            for (final update in parseTripUpdates(bytes)) {
              if (update.tripId != null) merged[update.tripId!] = update;
            }
            _tripUpdates = merged;
          }
        } catch (_) {
          // Keep whatever was already loaded.
        }
      }

      if (!blocked && wantsTrains && _isDue(nlTrainUpdatesUrl, updatesInterval)) {
        try {
          final bytes = await _fetch(nlTrainUpdatesUrl);
          if (bytes != null) {
            _trainTrips = parseTripUpdates(bytes);
            final merged = <String, TripUpdate>{..._tripUpdates};
            for (final update in _trainTrips) {
              if (update.tripId != null) merged[update.tripId!] = update;
            }
            _tripUpdates = merged;
          }
        } catch (_) {
          // Keep whatever was already loaded.
        }
      }

      // Recomputed every tick, not just on fetch, so trains keep moving
      // between the (infrequent) downloads of their journeys.
      final trains =
          wantsTrains ? interpolateTrains(_trainTrips, stops) : const <TransitVehicle>[];

      if (_positions.isNotEmpty || trains.isNotEmpty) {
        _setState(TransitConnectionState.live);
      }
      if (!_vehiclesController.isClosed) {
        _vehiclesController.add([..._positions, ...trains]);
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
