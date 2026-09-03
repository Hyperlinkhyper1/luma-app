import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:luma/features/converter/corruption/binary_utils.dart';
import 'package:luma/features/converter/corruption/corruption_recipe.dart';
import 'package:luma/features/converter/corruption/file_corruptor.dart';
import 'package:luma/features/converter/corruption/file_repair_service.dart';
import 'package:luma/features/converter/corruption/file_signatures.dart';
import 'package:luma/features/converter/corruption/repair_report.dart';

Uint8List _sample([int size = 4096]) {
  final random = Prng(20260903);
  final bytes = Uint8List(size);
  for (var i = 0; i < size; i++) {
    bytes[i] = random.nextByte();
  }
  return bytes;
}

Uint8List _png({int width = 8, int height = 8}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(200, 30, 90));
  return img.encodePng(image);
}

Uint8List _zip() {
  final archive = Archive();
  archive.add(ArchiveFile.bytes('hello.txt', utf8.encode('hello ' * 200)));
  archive.add(
    ArchiveFile.bytes('nested/data.json', utf8.encode('{"a":1,"b":[2,3]}')),
  );
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}

Uint8List _wav({int samples = 512}) {
  final dataBytes = samples * 2;
  final bytes = Uint8List(44 + dataBytes);
  bytes.setRange(0, 4, asciiBytes('RIFF'));
  writeU32le(bytes, 4, bytes.length - 8);
  bytes.setRange(8, 12, asciiBytes('WAVE'));
  bytes.setRange(12, 16, asciiBytes('fmt '));
  writeU32le(bytes, 16, 16);
  writeU16le(bytes, 20, 1);
  writeU16le(bytes, 22, 1);
  writeU32le(bytes, 24, 44100);
  writeU32le(bytes, 28, 88200);
  writeU16le(bytes, 32, 2);
  writeU16le(bytes, 34, 16);
  bytes.setRange(36, 40, asciiBytes('data'));
  writeU32le(bytes, 40, dataBytes);
  return bytes;
}

Uint8List _bmp({int width = 4, int height = 4}) {
  const headerSize = 54;
  final rowBytes = ((width * 24 + 31) ~/ 32) * 4;
  final bytes = Uint8List(headerSize + rowBytes * height);
  bytes.setRange(0, 2, asciiBytes('BM'));
  writeU32le(bytes, 2, bytes.length);
  writeU32le(bytes, 10, headerSize);
  writeU32le(bytes, 14, 40);
  writeU32le(bytes, 18, width);
  writeU32le(bytes, 22, height);
  writeU16le(bytes, 26, 1);
  writeU16le(bytes, 28, 24);
  return bytes;
}

Uint8List _pdf() {
  final buffer = StringBuffer()
    ..write('%PDF-1.4\n')
    ..write('1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n')
    ..write('2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n')
    ..write('3 0 obj\n<< /Type /Page /Parent 2 0 R >>\nendobj\n')
    ..write('xref\n0 4\n')
    ..write('0000000000 65535 f \n')
    ..write('0000000009 00000 n \n')
    ..write('0000000060 00000 n \n')
    ..write('0000000120 00000 n \n')
    ..write('trailer\n<< /Size 4 /Root 1 0 R >>\nstartxref\n180\n%%EOF\n');
  return Uint8List.fromList(latin1.encode(buffer.toString()));
}

CorruptionSettings _settings(
  Set<DamageStyle> styles, {
  bool recoverable = true,
  int intensity = 40,
  int seed = 987654321,
}) => CorruptionSettings(
  styles: styles,
  intensity: intensity,
  seed: seed,
  recoverable: recoverable,
);

void main() {
  group('Prng', () {
    test('is deterministic for a given seed', () {
      final a = List.generate(64, (_) => Prng(42).next());
      final b = List.generate(64, (_) => Prng(42).next());
      expect(a, b);
    });

    test('produces a real permutation', () {
      final permutation = Prng(7).permutation(50);
      expect(permutation.length, 50);
      expect(permutation.toSet().length, 50);
    });
  });

  group('Crc32', () {
    test('matches the known IEEE check value', () {
      expect(Crc32.compute(asciiBytes('123456789')), 0xCBF43926);
    });
  });

  group('corrupt and restore', () {
    final original = _sample();

    for (final style in DamageStyle.values) {
      test('${style.label} round-trips exactly through its recipe', () {
        final result = FileCorruptor.corrupt(
          original,
          'sample.bin',
          _settings({style}),
        );
        expect(result.recipe, isNotNull);
        expect(result.bytes, isNot(equals(original)));

        final restored = FileRepairService.restoreFromRecipe(
          corrupted: result.bytes,
          recipe: result.recipe!,
          corruptedName: 'sample.corrupt.bin',
        );
        expect(restored.restoredExactly, isTrue);
        expect(restored.bytes, equals(original));
      });
    }

    test('every style at once still round-trips', () {
      final result = FileCorruptor.corrupt(
        original,
        'sample.bin',
        _settings(DamageStyle.values.toSet(), intensity: 80),
      );
      final restored = FileRepairService.restoreFromRecipe(
        corrupted: result.bytes,
        recipe: result.recipe!,
        corruptedName: 'sample.corrupt.bin',
      );
      expect(restored.bytes, equals(original));
      expect(restored.restoredExactly, isTrue);
    });

    test('the recipe survives a JSON round-trip', () {
      final result = FileCorruptor.corrupt(
        original,
        'sample.bin',
        _settings({DamageStyle.headerSmash, DamageStyle.shuffle}),
      );
      final reloaded = CorruptionRecipe.decode(result.recipe!.encode());
      expect(reloaded.ops.length, result.recipe!.ops.length);
      expect(reloaded.restore(result.bytes), equals(original));
    });

    test('the same seed corrupts identically twice', () {
      final a = FileCorruptor.corrupt(
        original,
        'a.bin',
        _settings({DamageStyle.bitRot, DamageStyle.scramble}),
      );
      final b = FileCorruptor.corrupt(
        original,
        'a.bin',
        _settings({DamageStyle.bitRot, DamageStyle.scramble}),
      );
      expect(a.bytes, equals(b.bytes));
    });

    test('a different seed corrupts differently', () {
      final a = FileCorruptor.corrupt(
        original,
        'a.bin',
        _settings({DamageStyle.bitRot}, seed: 1),
      );
      final b = FileCorruptor.corrupt(
        original,
        'a.bin',
        _settings({DamageStyle.bitRot}, seed: 2),
      );
      expect(a.bytes, isNot(equals(b.bytes)));
    });
  });

  group('unrecoverable corruption', () {
    test('writes no recipe', () {
      final result = FileCorruptor.corrupt(
        _sample(),
        'sample.bin',
        _settings({DamageStyle.headerSmash}, recoverable: false),
      );
      expect(result.recipe, isNull);
      expect(result.recoverable, isFalse);
    });

    test('destroys the wiped bytes rather than storing them', () {
      final result = FileCorruptor.corrupt(
        _sample(),
        'sample.bin',
        _settings({DamageStyle.headerSmash}, recoverable: false),
      );
      expect(result.bytes.take(16), everyElement(0));
    });

    test('says so when the damage only permutes bytes', () {
      final result = FileCorruptor.corrupt(
        _sample(),
        'sample.bin',
        _settings({DamageStyle.shuffle}, recoverable: false),
      );
      expect(result.notes.join(' '), contains('technically still in there'));
    });

    test('a recipe with unrecorded destruction refuses to restore', () {
      final recipe = CorruptionRecipe(
        originalName: 'x.bin',
        originalSize: 100,
        originalSha256: '',
        corruptedSize: 100,
        corruptedSha256: '',
        seed: 1,
        createdAt: DateTime.now(),
        ops: const [ZeroOp(start: 0, length: 10)],
      );
      expect(
        () => FileRepairService.restoreFromRecipe(
          corrupted: Uint8List(100),
          recipe: recipe,
          corruptedName: 'x.bin',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('a recipe for a different file is rejected', () {
      final result = FileCorruptor.corrupt(
        _sample(),
        'sample.bin',
        _settings({DamageStyle.bitRot}),
      );
      expect(
        () => FileRepairService.restoreFromRecipe(
          corrupted: _sample(2048),
          recipe: result.recipe!,
          corruptedName: 'other.bin',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('signature detection', () {
    test('names a PNG from its magic bytes', () {
      expect(FileSignatures.detectAt(_png())?.extension, 'png');
    });

    test('finds a signature hidden behind junk', () {
      final withJunk = concatBytes([Uint8List(500), _png()]);
      final found = FileSignatures.findSignature(withJunk);
      expect(found?.$1.extension, 'png');
      expect(found?.$2, 500);
    });

    test('reads the extension off a name', () {
      expect(FileSignatures.extensionOf('a.b.PNG'), 'png');
      expect(FileSignatures.extensionOf('noextension'), '');
    });
  });

  group('PNG repair', () {
    test('rewrites a wiped signature', () {
      final broken = Uint8List.fromList(_png());
      broken.fillRange(0, 8, 0);
      final result = FileRepairService.repair(broken, 'photo.png');
      expect(result.changed, isTrue);
      expect(result.bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      expect(img.decodePng(result.bytes), isNotNull);
    });

    test('closes a truncated file with an IEND chunk', () {
      final png = _png(width: 32, height: 32);
      final broken = png.sublist(0, png.length - 30);
      final result = FileRepairService.repair(broken, 'photo.png');
      expect(result.changed, isTrue);
      expect(
        String.fromCharCodes(
          result.bytes.sublist(
            result.bytes.length - 8,
            result.bytes.length - 4,
          ),
        ),
        'IEND',
      );
    });

    test('recomputes a broken chunk checksum', () {
      final broken = Uint8List.fromList(_png());
      // The IHDR CRC sits at bytes 29..32.
      broken[29] ^= 0xFF;
      final result = FileRepairService.repair(broken, 'photo.png');
      expect(result.fixCount, greaterThan(0));
      expect(img.decodePng(result.bytes), isNotNull);
    });

    test('leaves a healthy PNG alone', () {
      final result = FileRepairService.repair(_png(), 'photo.png');
      expect(result.changed, isFalse);
    });

    test('drops junk glued to the front', () {
      final withJunk = concatBytes([asciiBytes('GARBAGE!'), _png()]);
      final result = FileRepairService.repair(withJunk, 'photo.png');
      expect(img.decodePng(result.bytes), isNotNull);
    });
  });

  group('ZIP repair', () {
    test('rebuilds a lost central directory', () {
      final zip = _zip();
      // Cut off everything from the central directory onwards, which is what a
      // half-finished download leaves behind.
      final centralAt = indexOfBytes(zip, const [0x50, 0x4B, 0x01, 0x02]);
      expect(centralAt, greaterThan(0));
      final broken = zip.sublist(0, centralAt);

      final result = FileRepairService.repair(broken, 'bundle.zip');
      expect(result.changed, isTrue);

      final decoded = ZipDecoder().decodeBytes(result.bytes);
      expect(decoded.files.map((f) => f.name).toSet(), {
        'hello.txt',
        'nested/data.json',
      });
      expect(
        utf8.decode(decoded.findFile('nested/data.json')!.content),
        '{"a":1,"b":[2,3]}',
      );
    });

    test('recovers entries after a smashed header', () {
      final zip = Uint8List.fromList(_zip());
      zip.fillRange(0, 4, 0);
      final result = FileRepairService.repair(zip, 'bundle.zip');
      final decoded = ZipDecoder().decodeBytes(result.bytes);
      expect(decoded.files, isNotEmpty);
    });

    test('flags a docx that is missing its required parts', () {
      final result = FileRepairService.repair(_zip(), 'report.docx');
      expect(
        result.notes.any(
          (note) =>
              note.severity == RepairSeverity.failed &&
              note.message.contains('[Content_Types].xml'),
        ),
        isTrue,
      );
    });
  });

  group('WAV repair', () {
    test('corrects size fields left behind by a cut-short recording', () {
      final wav = _wav();
      final broken = wav.sublist(0, wav.length - 200);
      final result = FileRepairService.repair(broken, 'take.wav');
      expect(result.changed, isTrue);
      expect(readU32le(result.bytes, 4), result.bytes.length - 8);
      expect(readU32le(result.bytes, 40), result.bytes.length - 44);
    });

    test('restores a wiped RIFF magic from the chunk names', () {
      final broken = Uint8List.fromList(_wav());
      broken.fillRange(0, 12, 0);
      final result = FileRepairService.repair(broken, 'take.wav');
      expect(String.fromCharCodes(result.bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(result.bytes.sublist(8, 12)), 'WAVE');
    });
  });

  group('BMP repair', () {
    test('recalculates the size and pixel offset', () {
      final broken = Uint8List.fromList(_bmp());
      writeU32le(broken, 2, 999999);
      writeU32le(broken, 10, 12);
      final result = FileRepairService.repair(broken, 'tile.bmp');
      expect(readU32le(result.bytes, 2), result.bytes.length);
      expect(readU32le(result.bytes, 10), 54);
    });

    test('pads a truncated bitmap back to full height', () {
      final bmp = _bmp(width: 8, height: 8);
      final broken = bmp.sublist(0, bmp.length - 40);
      final result = FileRepairService.repair(broken, 'tile.bmp');
      expect(result.bytes.length, bmp.length);
    });
  });

  group('GIF repair', () {
    test('appends a missing trailer', () {
      final gif = Uint8List(32);
      gif.setRange(0, 6, asciiBytes('GIF89a'));
      writeU16le(gif, 6, 4);
      writeU16le(gif, 8, 4);
      final result = FileRepairService.repair(gif, 'anim.gif');
      expect(result.bytes.last, 0x3B);
    });
  });

  group('PDF repair', () {
    test('rebuilds the cross-reference table', () {
      final pdf = _pdf();
      // Corrupt every recorded offset, which is exactly what an edit anywhere
      // earlier in the file does.
      final broken = latin1.encode(
        latin1.decode(pdf).replaceAll('0000000060', '0000009999'),
      );
      final result = FileRepairService.repair(
        Uint8List.fromList(broken),
        'doc.pdf',
      );
      expect(result.changed, isTrue);
      final text = latin1.decode(result.bytes);
      expect(text.trimRight().endsWith('%%EOF'), isTrue);
      expect(text.contains('/Root 1 0 R'), isTrue);
      // The rebuilt table must point at where object 2 really starts.
      final startxref = int.parse(
        RegExp(r'startxref\s+(\d+)\s+%%EOF\s*$').firstMatch(text)!.group(1)!,
      );
      expect(startxref, lessThan(result.bytes.length));
      expect(text.substring(startxref, startxref + 4), 'xref');
    });

    test('strips junk before the PDF header', () {
      final withJunk = concatBytes([asciiBytes('JUNKJUNK'), _pdf()]);
      final result = FileRepairService.repair(withJunk, 'doc.pdf');
      expect(latin1.decode(result.bytes).startsWith('%PDF-'), isTrue);
    });
  });

  group('generic repair', () {
    test('names a file whose extension lies about its contents', () {
      final result = FileRepairService.repair(_png(), 'photo.jpg');
      expect(result.formatLabel, 'PNG image');
      expect(result.suggestedName, endsWith('.png'));
      expect(
        result.notes.any((note) => note.message.contains('named .jpg')),
        isTrue,
      );
    });

    test('trims zero-fill left by an interrupted copy', () {
      final data = concatBytes([_sample(1024), Uint8List(4096)]);
      final result = FileRepairService.repair(data, 'blob.dat');
      expect(result.bytes.length, lessThan(data.length));
    });

    test('refuses an empty file', () {
      expect(
        () => FileRepairService.repair(Uint8List(0), 'empty.bin'),
        throwsA(isA<FormatException>()),
      );
    });

    test('drops the .corrupt marker from the suggested name', () {
      final result = FileRepairService.repair(_png(), 'photo.corrupt.png');
      expect(result.suggestedName, 'photo.fixed.png');
    });
  });

  group('corruptor guards', () {
    test('rejects a file too small to damage', () {
      expect(
        () => FileCorruptor.corrupt(
          Uint8List(4),
          'tiny.bin',
          _settings({DamageStyle.bitRot}),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects an empty damage selection', () {
      expect(
        () => FileCorruptor.corrupt(_sample(), 'a.bin', _settings({})),
        throwsA(isA<FormatException>()),
      );
    });

    test('names the output files predictably', () {
      expect(
        FileCorruptor.suggestCorruptName('photo.png'),
        'photo.corrupt.png',
      );
      expect(
        FileCorruptor.suggestRecipeName('photo.corrupt.png'),
        'photo.corrupt.png.lumafix',
      );
    });
  });
}
