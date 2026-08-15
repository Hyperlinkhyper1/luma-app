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
        if (vf == 2 && vw == 2) {
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
