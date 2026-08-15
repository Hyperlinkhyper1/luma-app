import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'gtfs_realtime.dart';
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

  Future<void> _fetchOnce() async {
    if (_fetching) return;
    _fetching = true;
    if (_current != TransitConnectionState.live) {
      _setState(TransitConnectionState.loading);
    }
    try {
      final response = await _http
          .get(Uri.parse(nlVehiclePositionsUrl))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        _setState(TransitConnectionState.error);
        _errorController.add(
            'Transit feed returned HTTP ${response.statusCode}.');
        return;
      }
      final vehicles = parseVehiclePositions(
        Uint8List.fromList(response.bodyBytes),
        idParser: parseOvapiId,
      );
      _setState(TransitConnectionState.live);
      if (!_vehiclesController.isClosed) _vehiclesController.add(vehicles);
    } catch (e) {
      _setState(TransitConnectionState.error);
      _errorController.add('Could not load the transit feed: $e');
    } finally {
      _fetching = false;
    }
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
