import 'dart:convert';
import 'dart:typed_data';

import 'transit_vehicle.dart';

/// A hand-rolled reader for the slice of GTFS-realtime this plugin needs.
///
/// The official `gtfs-realtime-bindings` package pulls in `protobuf` and a
/// code-generation step; the feed fields used here are a handful of scalars,
/// so the wire format is decoded directly instead. Protobuf is designed to
/// be forward compatible — unknown fields are skipped by wire type — so this
/// keeps working if the publisher adds fields.
///
/// Field numbers come from the GTFS-realtime spec:
///   FeedMessage.entity        = 2
///   FeedEntity.id             = 1, .vehicle = 4
///   VehiclePosition.trip      = 1, .position = 2, .timestamp = 5, .vehicle = 8
///   Position.latitude         = 1, .longitude = 2, .bearing = 3, .speed = 5
///   TripDescriptor.trip_id    = 1, .route_id = 5
///   VehicleDescriptor.id      = 1, .label = 2
class _ProtoReader {
  _ProtoReader(this._bytes, this._pos, this._end);

  final Uint8List _bytes;
  int _pos;
  final int _end;

  bool get done => _pos >= _end;

  int varint() {
    var result = 0;
    var shift = 0;
    while (_pos < _end) {
      final byte = _bytes[_pos++];
      result |= (byte & 0x7f) << shift;
      if ((byte & 0x80) == 0) break;
      shift += 7;
      if (shift > 63) break;
    }
    return result;
  }

  /// Returns (fieldNumber, wireType).
  (int, int) key() {
    final v = varint();
    return (v >> 3, v & 7);
  }

  double float32() {
    final v = ByteData.sublistView(_bytes, _pos, _pos + 4).getFloat32(0, Endian.little);
    _pos += 4;
    return v;
  }

  /// Start/end offsets of a length-delimited field, without copying.
  (int, int) lengthDelimited() {
    final len = varint();
    final start = _pos;
    final end = (start + len).clamp(start, _end);
    _pos = end;
    return (start, end);
  }

  String string() {
    final (s, e) = lengthDelimited();
    return utf8.decode(_bytes.sublist(s, e), allowMalformed: true);
  }

  /// Skips a field whose contents aren't needed. Returns false when the wire
  /// type is unrecognised, which means the stream can no longer be trusted.
  bool skip(int wireType) {
    switch (wireType) {
      case 0:
        varint();
        return true;
      case 1:
        _pos += 8;
        return true;
      case 2:
        lengthDelimited();
        return true;
      case 5:
        _pos += 4;
        return true;
      default:
        return false;
    }
  }

  _ProtoReader sub(int start, int end) => _ProtoReader(_bytes, start, end);
}

class _Position {
  double? lat;
  double? lon;
  double? speed;
}

/// Decodes a GTFS-realtime `FeedMessage` into the vehicles it carries.
///
/// Entities without a position are dropped. [idParser] turns the feed's
/// entity id into operator/line metadata; it differs per publisher, so the
/// caller supplies it.
List<TransitVehicle> parseVehiclePositions(
  Uint8List bytes, {
  required ({String? operator, String? line}) Function(String entityId) idParser,
}) {
  final out = <TransitVehicle>[];
  final root = _ProtoReader(bytes, 0, bytes.length);

  while (!root.done) {
    final (field, wire) = root.key();
    if (field == 2 && wire == 2) {
      final (entStart, entEnd) = root.lengthDelimited();
      final vehicle = _parseEntity(root.sub(entStart, entEnd), root, idParser);
      if (vehicle != null) out.add(vehicle);
    } else if (!root.skip(wire)) {
      break;
    }
  }
  return out;
}

TransitVehicle? _parseEntity(
  _ProtoReader entity,
  _ProtoReader owner,
  ({String? operator, String? line}) Function(String) idParser,
) {
  String? entityId;
  _Position? position;
  String? label;
  String? tripId;
  int? timestamp;

  while (!entity.done) {
    final (field, wire) = entity.key();
    if (field == 1 && wire == 2) {
      entityId = entity.string();
    } else if (field == 4 && wire == 2) {
      final (vs, ve) = entity.lengthDelimited();
      final v = entity.sub(vs, ve);
      while (!v.done) {
        final (vf, vw) = v.key();
        if (vf == 1 && vw == 2) {
          final (trs, tre) = v.lengthDelimited();
          tripId = _parseTrip(v.sub(trs, tre)).tripId;
        } else if (vf == 2 && vw == 2) {
          final (ps, pe) = v.lengthDelimited();
          position = _parsePosition(v.sub(ps, pe));
        } else if (vf == 8 && vw == 2) {
          final (ds, de) = v.lengthDelimited();
          label = _parseVehicleLabel(v.sub(ds, de));
        } else if (vf == 5 && vw == 0) {
          timestamp = v.varint();
        } else if (!v.skip(vw)) {
          break;
        }
      }
    } else if (!entity.skip(wire)) {
      break;
    }
  }

  if (entityId == null || position?.lat == null || position?.lon == null) {
    return null;
  }
  final meta = idParser(entityId);
  return TransitVehicle(
    id: entityId,
    latitude: position!.lat!,
    longitude: position.lon!,
    mode: transitModeFor(meta.operator, meta.line),
    operator: meta.operator,
    line: meta.line,
    label: label,
    tripId: tripId,
    speed: position.speed,
    timestamp: (timestamp != null && timestamp > 0)
        ? DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)
        : null,
  );
}

_Position _parsePosition(_ProtoReader r) {
  final p = _Position();
  while (!r.done) {
    final (field, wire) = r.key();
    if (field == 1 && wire == 5) {
      p.lat = r.float32();
    } else if (field == 2 && wire == 5) {
      p.lon = r.float32();
    } else if (field == 5 && wire == 5) {
      p.speed = r.float32();
    } else if (!r.skip(wire)) {
      break;
    }
  }
  return p;
}

/// TripDescriptor: `trip_id` = 1, `route_id` = 5.
({String? tripId, String? routeId}) _parseTrip(_ProtoReader r) {
  String? tripId;
  String? routeId;
  while (!r.done) {
    final (field, wire) = r.key();
    if (field == 1 && wire == 2) {
      tripId = r.string();
    } else if (field == 5 && wire == 2) {
      routeId = r.string();
    } else if (!r.skip(wire)) {
      break;
    }
  }
  return (tripId: tripId, routeId: routeId);
}

/// One predicted call at a stop within a trip.
class StopCall {
  const StopCall({
    required this.stopId,
    this.stopSequence,
    this.arrival,
    this.departure,
    this.delaySeconds,
  });

  final String? stopId;
  final int? stopSequence;
  final DateTime? arrival;
  final DateTime? departure;

  /// Seconds behind schedule; negative means early.
  final int? delaySeconds;

  /// When the vehicle is expected to leave (or, at the final stop, arrive).
  DateTime? get time => departure ?? arrival;
}

/// A live trip with its remaining calls, from a `TripUpdate` feed.
class TripUpdate {
  const TripUpdate({
    required this.tripId,
    required this.calls,
    this.routeId,
    this.vehicleLabel,
    this.delaySeconds,
  });

  final String? tripId;
  final String? routeId;
  final String? vehicleLabel;
  final int? delaySeconds;
  final List<StopCall> calls;
}

/// Decodes a GTFS-realtime `FeedMessage` carrying `TripUpdate` entities.
///
/// Field numbers: FeedEntity.trip_update = 3; TripUpdate.trip = 1,
/// .stop_time_update = 2, .vehicle = 3, .delay = 5; StopTimeUpdate
/// .stop_sequence = 1, .arrival = 2, .departure = 3, .stop_id = 4;
/// StopTimeEvent.delay = 1, .time = 2.
List<TripUpdate> parseTripUpdates(Uint8List bytes) {
  final out = <TripUpdate>[];
  final root = _ProtoReader(bytes, 0, bytes.length);

  while (!root.done) {
    final (field, wire) = root.key();
    if (field == 2 && wire == 2) {
      final (entStart, entEnd) = root.lengthDelimited();
      final entity = root.sub(entStart, entEnd);
      while (!entity.done) {
        final (ef, ew) = entity.key();
        if (ef == 3 && ew == 2) {
          final (ts, te) = entity.lengthDelimited();
          final update = _parseTripUpdate(entity.sub(ts, te));
          if (update != null) out.add(update);
        } else if (!entity.skip(ew)) {
          break;
        }
      }
    } else if (!root.skip(wire)) {
      break;
    }
  }
  return out;
}

TripUpdate? _parseTripUpdate(_ProtoReader r) {
  String? tripId;
  String? routeId;
  String? vehicleLabel;
  int? delay;
  final calls = <StopCall>[];

  while (!r.done) {
    final (field, wire) = r.key();
    if (field == 1 && wire == 2) {
      final (s, e) = r.lengthDelimited();
      final trip = _parseTrip(r.sub(s, e));
      tripId = trip.tripId;
      routeId = trip.routeId;
    } else if (field == 2 && wire == 2) {
      final (s, e) = r.lengthDelimited();
      final call = _parseStopCall(r.sub(s, e));
      if (call != null) calls.add(call);
    } else if (field == 3 && wire == 2) {
      final (s, e) = r.lengthDelimited();
      vehicleLabel = _parseVehicleLabel(r.sub(s, e));
    } else if (field == 5 && wire == 0) {
      delay = _zigZagSafe(r.varint());
    } else if (!r.skip(wire)) {
      break;
    }
  }

  if (tripId == null && calls.isEmpty) return null;
  calls.sort((a, b) => (a.stopSequence ?? 0).compareTo(b.stopSequence ?? 0));
  return TripUpdate(
    tripId: tripId,
    routeId: routeId,
    vehicleLabel: vehicleLabel,
    delaySeconds: delay,
    calls: calls,
  );
}

StopCall? _parseStopCall(_ProtoReader r) {
  String? stopId;
  int? sequence;
  DateTime? arrival;
  DateTime? departure;
  int? delay;

  while (!r.done) {
    final (field, wire) = r.key();
    if (field == 1 && wire == 0) {
      sequence = r.varint();
    } else if (field == 4 && wire == 2) {
      stopId = r.string();
    } else if ((field == 2 || field == 3) && wire == 2) {
      final (s, e) = r.lengthDelimited();
      final event = _parseStopTimeEvent(r.sub(s, e));
      if (field == 2) {
        arrival = event.time;
      } else {
        departure = event.time;
      }
      delay ??= event.delay;
    } else if (!r.skip(wire)) {
      break;
    }
  }

  if (stopId == null && arrival == null && departure == null) return null;
  return StopCall(
    stopId: stopId,
    stopSequence: sequence,
    arrival: arrival,
    departure: departure,
    delaySeconds: delay,
  );
}

({DateTime? time, int? delay}) _parseStopTimeEvent(_ProtoReader r) {
  DateTime? time;
  int? delay;
  while (!r.done) {
    final (field, wire) = r.key();
    if (field == 1 && wire == 0) {
      delay = _zigZagSafe(r.varint());
    } else if (field == 2 && wire == 0) {
      final seconds = r.varint();
      if (seconds > 0) {
        time = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    } else if (!r.skip(wire)) {
      break;
    }
  }
  return (time: time, delay: delay);
}

/// GTFS-realtime declares delays as signed `int32`, which protobuf encodes
/// as a plain (non-zigzag) varint — negatives arrive as a 64-bit two's
/// complement value that has to be folded back into range.
int _zigZagSafe(int raw) {
  if (raw >= 0x80000000) {
    final wrapped = raw - 0x100000000;
    if (wrapped > -0x80000000) return wrapped;
  }
  return raw;
}

String? _parseVehicleLabel(_ProtoReader r) {
  String? id;
  String? label;
  while (!r.done) {
    final (field, wire) = r.key();
    if (field == 1 && wire == 2) {
      id = r.string();
    } else if (field == 2 && wire == 2) {
      label = r.string();
    } else if (!r.skip(wire)) {
      break;
    }
  }
  return label ?? id;
}
