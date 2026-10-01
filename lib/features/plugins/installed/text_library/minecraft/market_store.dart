import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// A piece of furniture bought from the wandering trader and placed in the
/// hall or out on the island: which piece, the corner of its footprint, the
/// floor it stands on and how many quarter turns it is turned.
class PlacedPiece {
  const PlacedPiece({
    required this.id,
    required this.x,
    required this.z,
    this.floor = 0,
    this.rot = 0,
  });

  final String id;
  final int x;
  final int z;
  final int floor;
  final int rot;

  Map<String, Object?> toJson() => {
    'id': id,
    'x': x,
    'z': z,
    'floor': floor,
    'rot': rot,
  };
}

/// The Minecraft hall's wandering trader: how far round his hour the clock
/// is (he is at his stall for the second half of it), what the reader has
/// bought and not yet placed, and the furniture standing about.
///
/// Like the post, the page does the timing and hands the whole state over
/// whenever it changes; it is kept on this device only.
class MarketState {
  const MarketState({
    this.clock = 0,
    this.crate = const {},
    this.placed = const [],
    this.warned = false,
    this.pet,
  });

  /// Seconds the hall is open between one visit and the next.
  static const cycle = 3600;
  static const maxPieces = 200;
  static const maxStack = 99;

  /// Seconds into the current hour.
  final int clock;

  /// Pieces bought and waiting in the crate, by id.
  final Map<String, int> crate;
  final List<PlacedPiece> placed;

  /// Whether the reader has been told he is packing up this visit.
  final bool warned;

  /// The pet he has with him this visit ('dog', 'cat', 'fish', …); the
  /// page picks a new one each time he comes and checks the id on load.
  final String? pet;

  static final _id = RegExp(r'^[a-z_]{1,24}$');

  static int? _int(Object? value) => switch (value) {
    final num n when n.isFinite => n.round(),
    _ => null,
  };

  /// Whatever the page sent, cleaned up: counts are whole and in range,
  /// placed pieces have a footprint corner, and anything else is dropped.
  /// Which ids exist is the page's business; it checks them on load.
  factory MarketState.fromJson(Object? json) {
    if (json is! Map) return const MarketState();
    final clock = _int(json['clock']) ?? 0;
    final crate = <String, int>{};
    final rawCrate = json['crate'];
    if (rawCrate is Map) {
      for (final MapEntry(:key, :value) in rawCrate.entries) {
        final n = _int(value) ?? 0;
        if (key is String && _id.hasMatch(key) && n > 0) {
          crate[key] = n.clamp(1, maxStack);
        }
      }
    }
    final placed = <PlacedPiece>[];
    final rawPlaced = json['placed'];
    if (rawPlaced is List) {
      for (final p in rawPlaced) {
        if (placed.length >= maxPieces) break;
        if (p is! Map) continue;
        final id = p['id'];
        final x = _int(p['x']), z = _int(p['z']);
        if (id is! String || !_id.hasMatch(id) || x == null || z == null) {
          continue;
        }
        if (x.abs() > 512 || z.abs() > 512) continue;
        placed.add(
          PlacedPiece(
            id: id,
            x: x,
            z: z,
            floor: (_int(p['floor']) ?? 0).clamp(0, 16),
            rot: (_int(p['rot']) ?? 0) % 4,
          ),
        );
      }
    }
    return MarketState(
      clock: clock.clamp(0, cycle - 1),
      crate: crate,
      placed: placed,
      warned: json['warned'] == true,
      pet: switch (json['pet']) {
        final String id when _id.hasMatch(id) => id,
        _ => null,
      },
    );
  }

  Map<String, Object?> toJson() => {
    'clock': clock,
    'crate': crate,
    'placed': [for (final p in placed) p.toJson()],
    'warned': warned,
    if (pet != null) 'pet': pet,
  };
}

Future<File> _file() async {
  final support = await getApplicationSupportDirectory();
  return File(
    '${support.path}${Platform.pathSeparator}text_library_market.json',
  );
}

Future<MarketState?> loadMarket() async {
  try {
    final file = await _file();
    if (!await file.exists()) return null;
    return MarketState.fromJson(jsonDecode(await file.readAsString()));
  } catch (_) {
    return null;
  }
}

Future<void> _saving = Future.value();

/// Saves one after another, so a quick run of changes lands in order.
Future<void> saveMarket(MarketState state) {
  final next = _saving.catchError((Object _) {}).then((_) async {
    final file = await _file();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(state.toJson()), flush: true);
    await temp.rename(file.path);
  });
  _saving = next;
  return next;
}
