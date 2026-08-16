import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/transport_tracker/gtfs_realtime.dart';
import 'package:luma/features/plugins/installed/transport_tracker/gtfs_stops.dart';
import 'package:luma/features/plugins/installed/transport_tracker/transit_client.dart';
import 'package:luma/features/plugins/installed/transport_tracker/transit_vehicle.dart';
import 'package:luma/features/plugins/installed/transport_tracker/vessel.dart';

/// Builds protobuf wire-format bytes, so the decoder can be exercised
/// against a feed shaped exactly like OVapi's without shipping a fixture or
/// touching the network.
class _ProtoWriter {
  final _bytes = <int>[];

  void varint(int value) {
    var v = value;
    while (true) {
      final byte = v & 0x7f;
      v >>= 7;
      if (v == 0) {
        _bytes.add(byte);
        break;
      }
      _bytes.add(byte | 0x80);
    }
  }

  void tag(int field, int wire) => varint((field << 3) | wire);

  void string(int field, String value) {
    final encoded = utf8.encode(value);
    tag(field, 2);
    varint(encoded.length);
    _bytes.addAll(encoded);
  }

  void float(int field, double value) {
    tag(field, 5);
    final b = ByteData(4)..setFloat32(0, value, Endian.little);
    _bytes.addAll(b.buffer.asUint8List());
  }

  void uint(int field, int value) {
    tag(field, 0);
    varint(value);
  }

  void message(int field, _ProtoWriter inner) {
    tag(field, 2);
    varint(inner._bytes.length);
    _bytes.addAll(inner._bytes);
  }

  Uint8List toBytes() => Uint8List.fromList(_bytes);
}

Uint8List _feed(List<({String id, double lat, double lon, String? label})> rows) {
  final feed = _ProtoWriter();
  for (final row in rows) {
    final position = _ProtoWriter()
      ..float(1, row.lat)
      ..float(2, row.lon)
      ..float(5, 12.5);
    final vehicle = _ProtoWriter()..message(2, position)..uint(5, 1755300000);
    if (row.label != null) {
      vehicle.message(8, _ProtoWriter()..string(2, row.label!));
    }
    final entity = _ProtoWriter()
      ..string(1, row.id)
      ..message(4, vehicle);
    feed.message(2, entity);
  }
  return feed.toBytes();
}

void main() {
  group('GTFS-realtime decoding', () {
    test('decodes vehicle positions from a feed message', () {
      final bytes = _feed([
        (id: '2026-08-16:GVB:285:107498', lat: 52.37938, lon: 4.90164, label: '1902'),
        (id: '2026-08-15:RET:M008:453295', lat: 51.86236, lon: 4.3773, label: '5410'),
      ]);

      final vehicles = parseVehiclePositions(
        bytes,
        idParser: TransitClient.parseOvapiId,
      );

      expect(vehicles, hasLength(2));
      expect(vehicles.first.id, '2026-08-16:GVB:285:107498');
      expect(vehicles.first.latitude, closeTo(52.37938, 0.0001));
      expect(vehicles.first.longitude, closeTo(4.90164, 0.0001));
      expect(vehicles.first.label, '1902');
      expect(vehicles.first.operator, 'GVB');
      expect(vehicles.first.line, '285');
    });

    test('drops entities that carry no position', () {
      final feed = _ProtoWriter();
      feed.message(2, _ProtoWriter()..string(1, '2026-08-16:GVB:1:1'));
      final vehicles = parseVehiclePositions(
        feed.toBytes(),
        idParser: TransitClient.parseOvapiId,
      );
      expect(vehicles, isEmpty);
    });

    test('skips unknown fields instead of losing the rest of the feed', () {
      // A publisher adding a field the decoder does not know about must not
      // break the entities that follow it.
      final position = _ProtoWriter()..float(1, 52.1)..float(2, 4.5);
      final vehicle = _ProtoWriter()
        ..string(99, 'some future field')
        ..message(2, position);
      final entity = _ProtoWriter()
        ..string(1, '2026-08-16:QBUZZ:z870:6003')
        ..message(4, vehicle);
      final feed = _ProtoWriter()..message(2, entity);

      final vehicles = parseVehiclePositions(
        feed.toBytes(),
        idParser: TransitClient.parseOvapiId,
      );
      expect(vehicles, hasLength(1));
      expect(vehicles.single.operator, 'QBUZZ');
    });

    test('parses malformed entity ids without dropping the vehicle', () {
      final bytes = _feed([(id: 'nonsense', lat: 52.0, lon: 5.0, label: null)]);
      final vehicles = parseVehiclePositions(
        bytes,
        idParser: TransitClient.parseOvapiId,
      );
      expect(vehicles, hasLength(1));
      expect(vehicles.single.operator, isNull);
      expect(vehicles.single.mode, TransitMode.bus);
    });
  });

  group('transit mode inference', () {
    test('maps operators that run a single mode', () {
      expect(transitModeFor('NS', '4500'), TransitMode.train);
      expect(transitModeFor('DOEKSEN', '1'), TransitMode.ferry);
    });

    test('separates Rotterdam metro from tram', () {
      expect(transitModeFor('RET', 'M008'), TransitMode.metro);
      expect(transitModeFor('RET', 'B'), TransitMode.metro);
      expect(transitModeFor('RET', '21'), TransitMode.tram);
    });

    test('separates Amsterdam metro, tram and bus by line number', () {
      expect(transitModeFor('GVB', '52'), TransitMode.metro);
      expect(transitModeFor('GVB', '13'), TransitMode.tram);
      expect(transitModeFor('GVB', '285'), TransitMode.bus);
    });

    test('falls back to bus for anything unrecognised', () {
      expect(transitModeFor('QBUZZ', 'z870'), TransitMode.bus);
      expect(transitModeFor(null, null), TransitMode.bus);
    });
  });

  group('trip updates', () {
    Uint8List tripFeed(String tripId, List<({String stop, int seq, int epoch, int delay})> calls) {
      final tu = _ProtoWriter()..message(1, _ProtoWriter()..string(1, tripId));
      for (final c in calls) {
        final departure = _ProtoWriter()..uint(1, c.delay)..uint(2, c.epoch);
        tu.message(
            2,
            _ProtoWriter()
              ..uint(1, c.seq)
              ..string(4, c.stop)
              ..message(3, departure));
      }
      final entity = _ProtoWriter()..string(1, 'e1')..message(3, tu);
      return (_ProtoWriter()..message(2, entity)).toBytes();
    }

    test('decodes calls with times and delays, in stop order', () {
      final bytes = tripFeed('T1', [
        (stop: 'B', seq: 2, epoch: 1755300600, delay: 120),
        (stop: 'A', seq: 1, epoch: 1755300000, delay: 0),
      ]);
      final updates = parseTripUpdates(bytes);
      expect(updates, hasLength(1));
      final calls = updates.single.calls;
      expect(calls.map((c) => c.stopId), ['A', 'B']);
      expect(calls.last.delaySeconds, 120);
      expect(calls.first.time!.millisecondsSinceEpoch, 1755300000 * 1000);
    });
  });

  group('train interpolation', () {
    final stopsCsv = 'stop_id,stop_name,stop_lat,stop_lon\n'
        'A,Alkmaar,52.0,4.0\n'
        'B,Bergen,52.0,5.0\n'
        'Z,Zero Station,0.0,0.0\n';

    TripUpdate tripBetween(String from, String to, DateTime dep, DateTime arr) =>
        TripUpdate(tripId: 'T', calls: [
          StopCall(stopId: from, stopSequence: 1, departure: dep),
          StopCall(stopId: to, stopSequence: 2, arrival: arr),
        ]);

    test('places a train partway between two stations', () {
      final stops = GtfsStopsCache.fromCsv(stopsCsv);
      final dep = DateTime(2026, 8, 16, 12, 0);
      final arr = DateTime(2026, 8, 16, 12, 10);
      final trains = TransitClient.interpolateTrains(
        [tripBetween('A', 'B', dep, arr)],
        stops,
        now: DateTime(2026, 8, 16, 12, 5),
      );
      expect(trains, hasLength(1));
      // Halfway through the leg, so halfway along it.
      expect(trains.single.longitude, closeTo(4.5, 0.001));
      expect(trains.single.mode, TransitMode.train);
      expect(trains.single.interpolated, isTrue);
    });

    test('never places a train using a station with no coordinates', () {
      // Several cross-border stations are published as 0,0 — a real point
      // in the Gulf of Guinea. Interpolating toward it must be refused.
      final stops = GtfsStopsCache.fromCsv(stopsCsv);
      final trains = TransitClient.interpolateTrains(
        [
          tripBetween('A', 'Z', DateTime(2026, 8, 16, 12, 0),
              DateTime(2026, 8, 16, 12, 10))
        ],
        stops,
        now: DateTime(2026, 8, 16, 12, 5),
      );
      expect(trains, isEmpty);
    });

    test('ignores journeys that are not currently running', () {
      final stops = GtfsStopsCache.fromCsv(stopsCsv);
      final trains = TransitClient.interpolateTrains(
        [
          tripBetween('A', 'B', DateTime(2026, 8, 16, 12, 0),
              DateTime(2026, 8, 16, 12, 10))
        ],
        stops,
        now: DateTime(2026, 8, 16, 18, 0),
      );
      expect(trains, isEmpty);
    });

    test('does nothing without a stop cache', () {
      expect(
        TransitClient.interpolateTrains([
          tripBetween('A', 'B', DateTime(2026, 8, 16, 12, 0),
              DateTime(2026, 8, 16, 12, 10))
        ], null),
        isEmpty,
      );
    });
  });

  group('GTFS stop parsing', () {
    test('reads quoted names containing commas', () {
      final stops = GtfsStopsCache.fromCsv(
        'stop_id,stop_name,stop_lat,stop_lon\n'
        '1,"Den Haag, Centraal",52.08,4.32\n',
      );
      expect(stops.lookup('1')?.name, 'Den Haag, Centraal');
    });

    test('flags stops published without coordinates', () {
      final stops = GtfsStopsCache.fromCsv(
        'stop_id,stop_name,stop_lat,stop_lon\n'
        '1,Real Place,52.08,4.32\n'
        '2,No Coordinates,0.0,0.0\n',
      );
      expect(stops.lookup('1')!.hasPosition, isTrue);
      expect(stops.lookup('2')!.hasPosition, isFalse);
    });

    test('falls back past an id prefix', () {
      final stops = GtfsStopsCache.fromCsv(
        'stop_id,stop_name,stop_lat,stop_lon\n'
        '1234,Utrecht,52.08,5.11\n',
      );
      expect(stops.lookup('stoparea:1234')?.name, 'Utrecht');
    });
  });

  group('AIS vessel categories', () {
    test('maps ship type codes to categories', () {
      expect(vesselCategoryForShipType(70), VesselCategory.cargo);
      expect(vesselCategoryForShipType(80), VesselCategory.tanker);
      expect(vesselCategoryForShipType(60), VesselCategory.passenger);
      expect(vesselCategoryForShipType(30), VesselCategory.fishing);
      expect(vesselCategoryForShipType(37), VesselCategory.pleasureCraft);
      expect(vesselCategoryForShipType(null), VesselCategory.unspecified);
    });
  });

  group('AIS vessel merging', () {
    test('a static-data report fills in details without losing the position',
        () {
      final vessel = Vessel.fromPatch(const VesselPatch(
        mmsi: 244660000,
        latitude: 51.9,
        longitude: 4.4,
        sog: 12.3,
      ));
      final merged = vessel.mergedWith(const VesselPatch(
        mmsi: 244660000,
        latitude: 51.91,
        longitude: 4.41,
        name: 'EENDRACHT',
        shipType: 70,
        callSign: 'PBAB',
      ));

      expect(merged.name, 'EENDRACHT');
      expect(merged.callSign, 'PBAB');
      expect(merged.category, VesselCategory.cargo);
      // The newer position wins, and the speed from the earlier report is
      // kept because the static report carries none.
      expect(merged.latitude, closeTo(51.91, 0.0001));
      expect(merged.sog, 12.3);
    });
  });
}
