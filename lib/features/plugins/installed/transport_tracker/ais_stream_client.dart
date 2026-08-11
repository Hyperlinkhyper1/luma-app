import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'vessel.dart';

/// A rectangular map viewport to subscribe AIS reports for.
class AisBoundingBox {
  const AisBoundingBox({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south;
  final double west;
  final double north;
  final double east;
}

enum AisConnectionState { idle, connecting, live, error, closed }

/// Thin client for aisstream.io's public WebSocket AIS feed
/// (wss://stream.aisstream.io/v0/stream). Docs: https://aisstream.io/documentation
///
/// Subscribes to `PositionReport` and `ShipStaticData` messages inside a
/// bounding box using the caller's own API key, and republishes each report
/// as a [VesselPatch] on [patches]. Reconnecting (e.g. to move to a new
/// bounding box) is just calling [connect] again — it tears down any
/// existing socket first.
class AisStreamClient {
  static const _endpoint = 'wss://stream.aisstream.io/v0/stream';

  WebSocket? _socket;
  StreamSubscription? _sub;

  final _patchController = StreamController<VesselPatch>.broadcast();
  final _stateController = StreamController<AisConnectionState>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<VesselPatch> get patches => _patchController.stream;
  Stream<AisConnectionState> get state => _stateController.stream;
  Stream<String> get errors => _errorController.stream;

  AisConnectionState _current = AisConnectionState.idle;
  AisConnectionState get currentState => _current;

  Future<void> connect({
    required String apiKey,
    required AisBoundingBox box,
  }) async {
    await disconnect();
    _setState(AisConnectionState.connecting);
    try {
      final socket = await WebSocket.connect(_endpoint)
          .timeout(const Duration(seconds: 12));
      _socket = socket;
      socket.add(jsonEncode({
        'APIKey': apiKey,
        'BoundingBoxes': [
          [
            [box.south, box.west],
            [box.north, box.east],
          ],
        ],
        'FilterMessageTypes': ['PositionReport', 'ShipStaticData'],
      }));
      _sub = socket.listen(
        _onMessage,
        onError: (Object e) {
          _errorController.add('Connection error: $e');
          _setState(AisConnectionState.error);
        },
        onDone: () {
          if (_current != AisConnectionState.error) {
            _setState(AisConnectionState.closed);
          }
        },
        cancelOnError: false,
      );
      _setState(AisConnectionState.live);
    } catch (e) {
      _setState(AisConnectionState.error);
      _errorController.add('Could not connect: $e');
    }
  }

  /// Re-subscribes the already-open connection to a new bounding box —
  /// aisstream.io accepts a fresh subscription message on the same socket
  /// (throttled to roughly once a second server-side), so panning the map
  /// while live doesn't need a full reconnect.
  void updateBoundingBox({required String apiKey, required AisBoundingBox box}) {
    final socket = _socket;
    if (socket == null || _current != AisConnectionState.live) return;
    socket.add(jsonEncode({
      'APIKey': apiKey,
      'BoundingBoxes': [
        [
          [box.south, box.west],
          [box.north, box.east],
        ],
      ],
      'FilterMessageTypes': ['PositionReport', 'ShipStaticData'],
    }));
  }

  /// Opens a short-lived throwaway connection to sanity-check an API key,
  /// independent of any tracking connection already in progress. Returns
  /// null when the key looks accepted, or an error message otherwise.
  static Future<String?> testKey(String apiKey) async {
    WebSocket? socket;
    StreamSubscription? sub;
    try {
      socket = await WebSocket.connect(_endpoint).timeout(const Duration(seconds: 10));
      socket.add(jsonEncode({
        'APIKey': apiKey,
        'BoundingBoxes': [
          [
            [0.0, 0.0],
            [0.01, 0.01],
          ],
        ],
        'FilterMessageTypes': ['PositionReport'],
      }));
      final completer = Completer<String?>();
      sub = socket.listen(
        (raw) {
          try {
            final msg = jsonDecode(raw as String) as Map<String, dynamic>;
            final err = msg['error'] ?? msg['Error'];
            if (err != null && !completer.isCompleted) {
              completer.complete(err.toString());
            }
          } catch (_) {}
        },
        onError: (Object e) {
          if (!completer.isCompleted) completer.complete('Connection error: $e');
        },
      );
      return await completer.future.timeout(
        const Duration(seconds: 4),
        onTimeout: () => null,
      );
    } catch (e) {
      return 'Could not connect: $e';
    } finally {
      await sub?.cancel();
      await socket?.close();
    }
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    await _socket?.close();
    _socket = null;
    if (_current == AisConnectionState.live ||
        _current == AisConnectionState.connecting) {
      _setState(AisConnectionState.idle);
    }
  }

  void _setState(AisConnectionState s) {
    _current = s;
    if (!_stateController.isClosed) _stateController.add(s);
  }

  void _onMessage(dynamic raw) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final meta = msg['MetaData'] as Map<String, dynamic>?;
    if (meta == null) {
      final err = msg['error'] ?? msg['Error'];
      if (err != null) _errorController.add(err.toString());
      return;
    }

    final mmsi = _asInt(meta['MMSI']);
    final lat = _asDouble(meta['latitude']);
    final lon = _asDouble(meta['longitude']);
    if (mmsi == null || lat == null || lon == null) return;

    final metaName = _cleanText(meta['ShipName'] as String?);
    final type = msg['MessageType'] as String?;
    final message = msg['Message'] as Map<String, dynamic>?;

    if (type == 'PositionReport') {
      final pr = message?['PositionReport'] as Map<String, dynamic>?;
      if (pr == null) return;
      final heading = _asInt(pr['TrueHeading']);
      _patchController.add(VesselPatch(
        mmsi: mmsi,
        latitude: lat,
        longitude: lon,
        name: metaName,
        sog: _asDouble(pr['Sog']),
        cog: _asDouble(pr['Cog']),
        // 511 is the AIS "not available" sentinel for true heading.
        trueHeading: (heading != null && heading < 360) ? heading : null,
        navStatus: _asInt(pr['NavigationalStatus']),
      ));
    } else if (type == 'ShipStaticData') {
      final sd = message?['ShipStaticData'] as Map<String, dynamic>?;
      if (sd == null) return;
      final staticName = _cleanText(sd['Name'] as String?);
      _patchController.add(VesselPatch(
        mmsi: mmsi,
        latitude: lat,
        longitude: lon,
        name: staticName ?? metaName,
        shipType: _asInt(sd['Type']),
        imo: _asInt(sd['ImoNumber']),
        callSign: _cleanText(sd['CallSign'] as String?),
        destination: _cleanText(sd['Destination'] as String?),
        draught: _asDouble(sd['MaximumStaticDraught']),
      ));
    }
  }

  /// AIS 6-bit text fields pad unused trailing characters with `@`.
  static String? _cleanText(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.replaceAll('@', ' ').trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static double? _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _patchController.close();
    await _stateController.close();
    await _errorController.close();
  }
}
