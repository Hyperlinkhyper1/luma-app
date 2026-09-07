import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'binary_utils.dart';

/// The sidecar a recoverable corruption writes next to the damaged file.
const String kRecipeExtension = 'lumafix';

/// One reversible (or deliberately irreversible) edit made to a file.
///
/// Every op knows how to apply itself and, when it can, how to take itself
/// back off again. Ops that only permute or XOR bytes are their own inverse
/// and need to store nothing; ops that destroy bytes carry the originals in
/// [ZeroOp.data] / [TruncateOp.tail] when the corruption was made recoverable,
/// and carry nothing at all when it was not.
abstract class DamageOp {
  const DamageOp();

  String get type;

  Map<String, Object?> toJson();

  Uint8List apply(Uint8List bytes);

  /// Reverses [apply]. Only valid when [canUndo] is true.
  Uint8List undo(Uint8List bytes);

  bool get canUndo;

  String describe();

  static DamageOp fromJson(Map<String, Object?> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'flip':
        return FlipOp.fromJson(json);
      case 'xor':
        return XorOp.fromJson(json);
      case 'shuffle':
        return ShuffleOp.fromJson(json);
      case 'zero':
        return ZeroOp.fromJson(json);
      case 'truncate':
        return TruncateOp.fromJson(json);
      case 'insert':
        return InsertOp.fromJson(json);
      default:
        throw FormatException('Unknown damage step "$type".');
    }
  }
}

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw FormatException('Recipe step is missing "$key".');
}

/// Flips scattered individual bytes — classic bit rot.
class FlipOp extends DamageOp {
  const FlipOp({
    required this.start,
    required this.length,
    required this.count,
    required this.seed,
  });

  final int start;
  final int length;
  final int count;
  final int seed;

  factory FlipOp.fromJson(Map<String, Object?> json) => FlipOp(
    start: _int(json, 'start'),
    length: _int(json, 'length'),
    count: _int(json, 'count'),
    seed: _int(json, 'seed'),
  );

  @override
  String get type => 'flip';

  @override
  bool get canUndo => true;

  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'start': start,
    'length': length,
    'count': count,
    'seed': seed,
  };

  @override
  Uint8List apply(Uint8List bytes) {
    if (length <= 0 || start >= bytes.length) return bytes;
    final out = Uint8List.fromList(bytes);
    final span = length.clamp(0, out.length - start);
    if (span <= 0) return out;
    final random = Prng(seed);
    for (var i = 0; i < count; i++) {
      final offset = start + random.nextInt(span);
      final mask = random.nextNonZeroByte();
      if (offset < out.length) out[offset] ^= mask;
    }
    return out;
  }

  @override
  Uint8List undo(Uint8List bytes) => apply(bytes);

  @override
  String describe() =>
      'Flipped $count byte${count == 1 ? '' : 's'} across '
      '${formatOffsetRange(start, length)}';
}

/// XORs a whole region with a keystream — the bytes are still all there, but
/// nothing can read them.
class XorOp extends DamageOp {
  const XorOp({required this.start, required this.length, required this.seed});

  final int start;
  final int length;
  final int seed;

  factory XorOp.fromJson(Map<String, Object?> json) => XorOp(
    start: _int(json, 'start'),
    length: _int(json, 'length'),
    seed: _int(json, 'seed'),
  );

  @override
  String get type => 'xor';

  @override
  bool get canUndo => true;

  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'start': start,
    'length': length,
    'seed': seed,
  };

  @override
  Uint8List apply(Uint8List bytes) {
    final out = Uint8List.fromList(bytes);
    final random = Prng(seed);
    final end = (start + length).clamp(0, out.length);
    for (var i = start; i < end; i++) {
      out[i] ^= random.nextNonZeroByte();
    }
    return out;
  }

  @override
  Uint8List undo(Uint8List bytes) => apply(bytes);

  @override
  String describe() =>
      'Scrambled ${formatOffsetRange(start, length)} with a keystream';
}

/// Shuffles fixed-size blocks within a region.
class ShuffleOp extends DamageOp {
  const ShuffleOp({
    required this.start,
    required this.blockSize,
    required this.blocks,
    required this.seed,
  });

  final int start;
  final int blockSize;
  final int blocks;
  final int seed;

  factory ShuffleOp.fromJson(Map<String, Object?> json) => ShuffleOp(
    start: _int(json, 'start'),
    blockSize: _int(json, 'blockSize'),
    blocks: _int(json, 'blocks'),
    seed: _int(json, 'seed'),
  );

  @override
  String get type => 'shuffle';

  @override
  bool get canUndo => true;

  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'start': start,
    'blockSize': blockSize,
    'blocks': blocks,
    'seed': seed,
  };

  @override
  Uint8List apply(Uint8List bytes) {
    if (blocks < 2 || start + blocks * blockSize > bytes.length) return bytes;
    final out = Uint8List.fromList(bytes);
    final permutation = Prng(seed).permutation(blocks);
    for (var i = 0; i < blocks; i++) {
      final from = start + permutation[i] * blockSize;
      out.setRange(
        start + i * blockSize,
        start + i * blockSize + blockSize,
        bytes.sublist(from, from + blockSize),
      );
    }
    return out;
  }

  @override
  Uint8List undo(Uint8List bytes) {
    if (blocks < 2 || start + blocks * blockSize > bytes.length) return bytes;
    final out = Uint8List.fromList(bytes);
    final permutation = Prng(seed).permutation(blocks);
    for (var i = 0; i < blocks; i++) {
      final to = start + permutation[i] * blockSize;
      out.setRange(
        to,
        to + blockSize,
        bytes.sublist(start + i * blockSize, start + i * blockSize + blockSize),
      );
    }
    return out;
  }

  @override
  String describe() =>
      'Shuffled $blocks blocks of ${formatSize(blockSize)} from '
      '${formatOffset(start)}';
}

/// Overwrites a region with zeroes. Recoverable only when the original bytes
/// were kept in [data].
class ZeroOp extends DamageOp {
  const ZeroOp({required this.start, required this.length, this.data});

  final int start;
  final int length;
  final Uint8List? data;

  factory ZeroOp.fromJson(Map<String, Object?> json) {
    final encoded = json['data'] as String?;
    return ZeroOp(
      start: _int(json, 'start'),
      length: _int(json, 'length'),
      data: encoded == null ? null : base64Decode(encoded),
    );
  }

  @override
  String get type => 'zero';

  @override
  bool get canUndo => data != null;

  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'start': start,
    'length': length,
    if (data != null) 'data': base64Encode(data!),
  };

  @override
  Uint8List apply(Uint8List bytes) {
    final out = Uint8List.fromList(bytes);
    final end = (start + length).clamp(0, out.length);
    for (var i = start; i < end; i++) {
      out[i] = 0;
    }
    return out;
  }

  @override
  Uint8List undo(Uint8List bytes) {
    final original = data;
    if (original == null) {
      throw StateError('This step wiped bytes that were never recorded.');
    }
    final out = Uint8List.fromList(bytes);
    final end = start + original.length;
    if (end > out.length) {
      throw StateError('The file is shorter than the recipe expects.');
    }
    out.setRange(start, end, original);
    return out;
  }

  @override
  String describe() => 'Wiped ${formatOffsetRange(start, length)}';
}

/// Cuts the tail off. Recoverable only when the tail was kept.
class TruncateOp extends DamageOp {
  const TruncateOp({required this.at, this.tail});

  final int at;
  final Uint8List? tail;

  factory TruncateOp.fromJson(Map<String, Object?> json) {
    final encoded = json['tail'] as String?;
    return TruncateOp(
      at: _int(json, 'at'),
      tail: encoded == null ? null : base64Decode(encoded),
    );
  }

  @override
  String get type => 'truncate';

  @override
  bool get canUndo => tail != null;

  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'at': at,
    if (tail != null) 'tail': base64Encode(tail!),
  };

  @override
  Uint8List apply(Uint8List bytes) =>
      at >= bytes.length ? bytes : bytes.sublist(0, at < 0 ? 0 : at);

  @override
  Uint8List undo(Uint8List bytes) {
    final rest = tail;
    if (rest == null) {
      throw StateError('This step cut off bytes that were never recorded.');
    }
    return concatBytes([bytes, rest]);
  }

  @override
  String describe() => 'Cut the file off at ${formatOffset(at)}';
}

/// Injects junk bytes, shifting everything after them. Always reversible: the
/// inserted bytes simply come back out.
class InsertOp extends DamageOp {
  const InsertOp({required this.at, required this.length, required this.seed});

  final int at;
  final int length;
  final int seed;

  factory InsertOp.fromJson(Map<String, Object?> json) => InsertOp(
    at: _int(json, 'at'),
    length: _int(json, 'length'),
    seed: _int(json, 'seed'),
  );

  @override
  String get type => 'insert';

  @override
  bool get canUndo => true;

  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'at': at,
    'length': length,
    'seed': seed,
  };

  @override
  Uint8List apply(Uint8List bytes) {
    if (length <= 0) return bytes;
    final where = at.clamp(0, bytes.length);
    final random = Prng(seed);
    final junk = Uint8List(length);
    for (var i = 0; i < length; i++) {
      junk[i] = random.nextByte();
    }
    return concatBytes([bytes.sublist(0, where), junk, bytes.sublist(where)]);
  }

  @override
  Uint8List undo(Uint8List bytes) {
    final where = at.clamp(0, bytes.length);
    final end = (where + length).clamp(0, bytes.length);
    return concatBytes([bytes.sublist(0, where), bytes.sublist(end)]);
  }

  @override
  String describe() =>
      'Injected ${formatSize(length)} of junk at ${formatOffset(at)}';
}

/// The `.lumafix` sidecar: everything the fixer needs to walk a corrupted file
/// back to exactly what it was.
class CorruptionRecipe {
  const CorruptionRecipe({
    required this.originalName,
    required this.originalSize,
    required this.originalSha256,
    required this.corruptedSize,
    required this.corruptedSha256,
    required this.seed,
    required this.createdAt,
    required this.ops,
  });

  static const int formatVersion = 1;

  final String originalName;
  final int originalSize;
  final String originalSha256;
  final int corruptedSize;
  final String corruptedSha256;
  final int seed;
  final DateTime createdAt;
  final List<DamageOp> ops;

  bool get fullyReversible => ops.every((op) => op.canUndo);

  Map<String, Object?> toJson() => {
    'lumafix': formatVersion,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'originalName': originalName,
    'originalSize': originalSize,
    'originalSha256': originalSha256,
    'corruptedSize': corruptedSize,
    'corruptedSha256': corruptedSha256,
    'seed': seed,
    'ops': [for (final op in ops) op.toJson()],
  };

  Uint8List encode() {
    const encoder = JsonEncoder.withIndent('  ');
    return Uint8List.fromList(utf8.encode(encoder.convert(toJson())));
  }

  static CorruptionRecipe decode(List<int> bytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const FormatException('That is not a readable .lumafix recipe.');
    }
    if (decoded is! Map) {
      throw const FormatException('That is not a readable .lumafix recipe.');
    }
    final json = Map<String, Object?>.from(decoded);
    final version = json['lumafix'];
    if (version is! int) {
      throw const FormatException('That file is not a luma recovery recipe.');
    }
    if (version > formatVersion) {
      throw FormatException(
        'This recipe was written by a newer version of luma (format $version). '
        'Update the app to use it.',
      );
    }
    final rawOps = json['ops'];
    if (rawOps is! List) {
      throw const FormatException('The recipe has no steps to undo.');
    }
    return CorruptionRecipe(
      originalName: json['originalName'] as String? ?? 'restored.bin',
      originalSize: (json['originalSize'] as num?)?.toInt() ?? 0,
      originalSha256: json['originalSha256'] as String? ?? '',
      corruptedSize: (json['corruptedSize'] as num?)?.toInt() ?? 0,
      corruptedSha256: json['corruptedSha256'] as String? ?? '',
      seed: (json['seed'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      ops: [
        for (final op in rawOps)
          DamageOp.fromJson(Map<String, Object?>.from(op as Map)),
      ],
    );
  }

  /// Undoes every step, newest first.
  Uint8List restore(Uint8List corrupted) {
    var bytes = corrupted;
    for (final op in ops.reversed) {
      bytes = op.undo(bytes);
    }
    return bytes;
  }
}

String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();
