import 'dart:typed_data';

import '../../../l10n/current_l.dart';
import 'binary_utils.dart';
import 'corruption_recipe.dart';

/// The kinds of damage the corruptor knows how to inflict.
enum DamageStyle {
  bitRot,
  scramble,
  shuffle,
  headerSmash,
  truncate,
  junkInjection,
}

extension DamageStyleInfo on DamageStyle {
  String get label {
    final t = currentL;
    return switch (this) {
      DamageStyle.bitRot => t.converterDamageBitRotLabel,
      DamageStyle.scramble => t.converterDamageScrambleLabel,
      DamageStyle.shuffle => t.converterDamageShuffleLabel,
      DamageStyle.headerSmash => t.converterDamageHeaderSmashLabel,
      DamageStyle.truncate => t.converterDamageTruncateLabel,
      DamageStyle.junkInjection => t.converterDamageJunkLabel,
    };
  }

  String get description {
    final t = currentL;
    return switch (this) {
      DamageStyle.bitRot => t.converterDamageBitRotDesc,
      DamageStyle.scramble => t.converterDamageScrambleDesc,
      DamageStyle.shuffle => t.converterDamageShuffleDesc,
      DamageStyle.headerSmash => t.converterDamageHeaderSmashDesc,
      DamageStyle.truncate => t.converterDamageTruncateDesc,
      DamageStyle.junkInjection => t.converterDamageJunkDesc,
    };
  }

  /// Styles that permute or mask bytes without losing any. Without a recipe
  /// they are still not practically recoverable, but nothing was actually
  /// destroyed — worth saying out loud rather than overpromising.
  bool get destroysBytes =>
      this == DamageStyle.headerSmash || this == DamageStyle.truncate;
}

/// How hard to hit the file.
enum DamagePreset { light, medium, heavy, total }

extension DamagePresetInfo on DamagePreset {
  String get label {
    final t = currentL;
    return switch (this) {
      DamagePreset.light => t.converterPresetLight,
      DamagePreset.medium => t.converterPresetMedium,
      DamagePreset.heavy => t.converterPresetHeavy,
      DamagePreset.total => t.converterPresetTotal,
    };
  }

  int get intensity => switch (this) {
    DamagePreset.light => 10,
    DamagePreset.medium => 35,
    DamagePreset.heavy => 70,
    DamagePreset.total => 100,
  };

  String get hint {
    final t = currentL;
    return switch (this) {
      DamagePreset.light => t.converterPresetLightHint,
      DamagePreset.medium => t.converterPresetMediumHint,
      DamagePreset.heavy => t.converterPresetHeavyHint,
      DamagePreset.total => t.converterPresetTotalHint,
    };
  }
}

/// Everything the corruptor needs to know for one run.
class CorruptionSettings {
  const CorruptionSettings({
    required this.styles,
    required this.intensity,
    required this.seed,
    required this.recoverable,
  });

  final Set<DamageStyle> styles;

  /// 1–100.
  final int intensity;

  final int seed;

  /// When true a `.lumafix` recipe is produced and the damage can be undone
  /// exactly. When false nothing is recorded and the damage is permanent.
  final bool recoverable;
}

/// A corrupted file plus, when asked for, the recipe that undoes it.
class CorruptionResult {
  const CorruptionResult({
    required this.bytes,
    required this.recipe,
    required this.notes,
    required this.steps,
  });

  final Uint8List bytes;
  final CorruptionRecipe? recipe;

  /// Anything the user should know about what just happened.
  final List<String> notes;

  /// Human-readable description of every edit, in the order it was applied.
  final List<String> steps;

  bool get recoverable => recipe != null;
}

/// Applies deliberate damage to a file, optionally recording how to take it
/// back off again.
class FileCorruptor {
  FileCorruptor._();

  /// Below this a file is too small to carve up meaningfully.
  static const int minimumSize = 16;

  static CorruptionResult corrupt(
    Uint8List original,
    String fileName,
    CorruptionSettings settings,
  ) {
    if (original.length < minimumSize) {
      throw FormatException(
        currentL.converterCorruptTooSmall(original.length),
      );
    }
    if (settings.styles.isEmpty) {
      throw FormatException(currentL.converterCorruptPickStyle);
    }

    final planner = Prng(settings.seed ^ 0x5BD1E995);
    final intensity = settings.intensity.clamp(1, 100);
    final notes = <String>[];
    final ops = <DamageOp>[];

    var bytes = original;

    // Ordered so the size-changing steps land last; that keeps the offsets the
    // earlier steps chose meaningful while they run.
    for (final style in DamageStyle.values) {
      if (!settings.styles.contains(style)) continue;
      final op = _buildOp(style, bytes, intensity, planner, settings);
      if (op == null) {
        notes.add(currentL.converterCorruptStyleSkipped(style.label));
        continue;
      }
      ops.add(op);
      bytes = op.apply(bytes);
    }

    if (ops.isEmpty) {
      throw FormatException(currentL.converterCorruptNothingApplied);
    }

    if (!settings.recoverable) {
      final destroys = settings.styles.any((s) => s.destroysBytes);
      if (!destroys) {
        notes.add(currentL.converterCorruptNoRecipeRearranged);
      } else {
        notes.add(currentL.converterCorruptNoRecipeDestroyed);
      }
    }

    final recipe = settings.recoverable
        ? CorruptionRecipe(
            originalName: fileName,
            originalSize: original.length,
            originalSha256: sha256Hex(original),
            corruptedSize: bytes.length,
            corruptedSha256: sha256Hex(bytes),
            seed: settings.seed,
            createdAt: DateTime.now(),
            ops: ops,
          )
        : null;

    return CorruptionResult(
      bytes: bytes,
      recipe: recipe,
      notes: notes,
      steps: [for (final op in ops) op.describe()],
    );
  }

  static DamageOp? _buildOp(
    DamageStyle style,
    Uint8List bytes,
    int intensity,
    Prng planner,
    CorruptionSettings settings,
  ) {
    final size = bytes.length;
    final fraction = intensity / 100;
    final seed = planner.next();

    switch (style) {
      case DamageStyle.bitRot:
        // At full intensity roughly 2% of the file gets touched, which is far
        // more than enough to break anything compressed.
        final count = (size * fraction * 0.02).ceil().clamp(1, size);
        return FlipOp(start: 0, length: size, count: count, seed: seed);

      case DamageStyle.scramble:
        final span = (size * fraction * 0.3).round().clamp(1, size);
        final start = span >= size ? 0 : planner.nextInt(size - span);
        return XorOp(start: start, length: span, seed: seed);

      case DamageStyle.shuffle:
        final blockSize = (size ~/ 64).clamp(4, 64 * 1024);
        final region = (size * fraction).round().clamp(0, size);
        final blocks = region ~/ blockSize;
        if (blocks < 2) return null;
        final maxStart = size - blocks * blockSize;
        final start = maxStart <= 0 ? 0 : planner.nextInt(maxStart);
        return ShuffleOp(
          start: start,
          blockSize: blockSize,
          blocks: blocks,
          seed: seed,
        );

      case DamageStyle.headerSmash:
        // Enough to take out the magic bytes at the lightest setting, and a
        // good chunk of any real header at the heaviest.
        final span = (16 + size * fraction * 0.05).round().clamp(1, size);
        return ZeroOp(
          start: 0,
          length: span,
          data: settings.recoverable ? bytes.sublist(0, span) : null,
        );

      case DamageStyle.truncate:
        final cut = (size * fraction * 0.5).round().clamp(1, size - 1);
        final at = size - cut;
        return TruncateOp(
          at: at,
          tail: settings.recoverable ? bytes.sublist(at) : null,
        );

      case DamageStyle.junkInjection:
        final span = (size * fraction * 0.05).ceil().clamp(1, size);
        final at = planner.nextInt(size);
        return InsertOp(at: at, length: span, seed: seed);
    }
  }

  /// `photo.png` → `photo.corrupt.png`.
  static String suggestCorruptName(String original) {
    final dot = original.lastIndexOf('.');
    if (dot <= 0) return '$original.corrupt';
    return '${original.substring(0, dot)}.corrupt${original.substring(dot)}';
  }

  /// `photo.corrupt.png` → `photo.corrupt.png.lumafix`.
  static String suggestRecipeName(String corruptedName) =>
      '$corruptedName.$kRecipeExtension';
}
