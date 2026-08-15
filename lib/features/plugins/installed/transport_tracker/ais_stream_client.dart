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

  /// Every message type that can place a vessel on the map or name one.
  ///
  /// Subscribing to `PositionReport` alone (AIS types 1/2/3) only covers
  /// Class A transponders — the ones commercial shipping is required to
  /// carry. Leisure boats, small fishing vessels and most harbour craft use
  /// Class B, whose positions arrive as `StandardClassBPositionReport` and
  /// `ExtendedClassBPositionReport`, and whose names arrive as
  /// `StaticDataReport`. Leaving those out hides a large share of the
  /// traffic in any coastal area.
  static const messageTypes = <String>[
    'PositionReport',
    'StandardClassBPositionReport',
    'ExtendedClassBPositionReport',
    'ShipStaticData',
    'StaticDataReport',
  ];

  /// Raw frames received since the last [connect], and how many of those
  /// produced a usable position. Surfaced in the UI so an empty map can be
  /// told apart from a feed that is arriving but not parsing.
  int rawMessageCount = 0;
  int usableMessageCount = 0;

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
    rawMessageCount = 0;
    usableMessageCount = 0;
    try {
      final socket = await WebSocket.connect(_endpoint)
          .timeout(const Duration(seconds: 12));
      _socket = socket;
      socket.add(jsonEncode(_subscription(apiKey, box)));
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
    socket.add(jsonEncode(_subscription(apiKey, box)));
  }

  static Map<String, dynamic> _subscription(String apiKey, AisBoundingBox box) => {
        'APIKey': apiKey,
        'BoundingBoxes': [
          [
            [box.south, box.west],
            [box.north, box.east],
          ],
        ],
        'FilterMessageTypes': messageTypes,
      };

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
        'FilterMessageTypes': messageTypes,
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
    rawMessageCount++;
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final meta = msg['MetaData'] as Map<String, dynamic>?;
    if (meta == null) {
      final err = msg['error'] ?? msg['Error'] ?? msg['message'];
      if (err != null) _errorController.add(err.toString());
      return;
    }

    // Every message type carries the position in its metadata envelope, so
    // a vessel can always be placed even when the payload itself is a
    // name-only report (type 24) or a type this client doesn't decode.
    final mmsi = _asInt(meta['MMSI']);
    final lat = _asDouble(meta['latitude']) ?? _asDouble(meta['Latitude']);
    final lon = _asDouble(meta['longitude']) ?? _asDouble(meta['Longitude']);
    if (mmsi == null || lat == null || lon == null) return;

    final metaName = _cleanText(meta['ShipName'] as String?);
    final type = msg['MessageType'] as String?;
    final message = msg['Message'] as Map<String, dynamic>?;
    final body = (message?[type] as Map<String, dynamic>?) ?? const {};

    usableMessageCount++;

    switch (type) {
      // Class A (1/2/3) and Class B (18) share these field names; 18 simply
      // has no navigational status.
      case 'PositionReport':
      case 'StandardClassBPositionReport':
        _patchController.add(VesselPatch(
          mmsi: mmsi,
          latitude: lat,
          longitude: lon,
          name: metaName,
          sog: _asDouble(body['Sog']),
          cog: _asDouble(body['Cog']),
          trueHeading: _heading(body['TrueHeading']),
          navStatus: _asInt(body['NavigationalStatus']),
        ));
      // Class B extended (19) additionally carries name and ship type.
      case 'ExtendedClassBPositionReport':
        _patchController.add(VesselPatch(
          mmsi: mmsi,
          latitude: lat,
          longitude: lon,
          name: _cleanText(body['Name'] as String?) ?? metaName,
          sog: _asDouble(body['Sog']),
          cog: _asDouble(body['Cog']),
          trueHeading: _heading(body['TrueHeading']),
          shipType: _asInt(body['Type']),
        ));
      case 'ShipStaticData':
        _patchController.add(VesselPatch(
          mmsi: mmsi,
          latitude: lat,
          longitude: lon,
          name: _cleanText(body['Name'] as String?) ?? metaName,
          shipType: _asInt(body['Type']),
          imo: _asInt(body['ImoNumber']),
          callSign: _cleanText(body['CallSign'] as String?),
          destination: _cleanText(body['Destination'] as String?),
          draught: _asDouble(body['MaximumStaticDraught']),
        ));
      // Class B static (24) is split across two part reports: A carries the
      // name, B the call sign and ship type. Either may arrive alone.
      case 'StaticDataReport':
        final reportA = body['ReportA'] as Map<String, dynamic>?;
        final reportB = body['ReportB'] as Map<String, dynamic>?;
        _patchController.add(VesselPatch(
          mmsi: mmsi,
          latitude: lat,
          longitude: lon,
          name: _cleanText(reportA?['Name'] as String?) ?? metaName,
          shipType: _asInt(reportB?['ShipType']),
          callSign: _cleanText(reportB?['CallSign'] as String?),
        ));
      default:
        // Unknown type, but the envelope still located a vessel.
        _patchController.add(VesselPatch(
          mmsi: mmsi,
          latitude: lat,
          longitude: lon,
          name: metaName,
        ));
    }
  }

  /// 511 is the AIS "heading not available" sentinel.
  static int? _heading(dynamic v) {
    final h = _asInt(v);
    return (h != null && h >= 0 && h < 360) ? h : null;
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
