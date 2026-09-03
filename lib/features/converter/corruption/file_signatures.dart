import 'dart:typed_data';

import 'binary_utils.dart';

/// The repairer that knows how to work on a given family of files.
enum RepairFamily { png, jpeg, gif, bmp, zip, pdf, riff, mp3, mp4, generic }

/// One known file type: what it starts with, what to call it, and who repairs
/// it.
class FileSignature {
  const FileSignature({
    required this.label,
    required this.extension,
    required this.magic,
    this.offset = 0,
    this.family = RepairFamily.generic,
    this.extras = const <String>[],
  });

  final String label;
  final String extension;
  final List<int> magic;

  /// Where the magic bytes live. Almost always 0, but a few formats (MP4's
  /// `ftyp`, RIFF's `WAVE`) sit further in.
  final int offset;

  final RepairFamily family;

  /// Other extensions that legitimately carry this signature.
  final List<String> extras;

  /// Whether this signature is distinctive enough to hunt for inside a file.
  ///
  /// Two- and three-byte magics — and ones made mostly of zeroes, like the
  /// Windows icon header — turn up by chance in ordinary binary data, so
  /// scanning for them finds "a file" in the middle of anything.
  bool get scannable =>
      magic.length >= 4 && magic.where((b) => b != 0).length >= 3;

  bool matches(List<int> bytes, [int base = 0]) =>
      matchesAt(bytes, base + offset, magic);
}

/// The signature table.
///
/// It is deliberately long: the fixer can only give useful advice about a file
/// whose real type it can name, even when the family that repairs it is only
/// [RepairFamily.generic].
class FileSignatures {
  FileSignatures._();

  static const List<FileSignature> all = [
    // Images
    FileSignature(
      label: 'PNG image',
      extension: 'png',
      magic: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
      family: RepairFamily.png,
    ),
    FileSignature(
      label: 'JPEG image',
      extension: 'jpg',
      magic: [0xFF, 0xD8, 0xFF],
      family: RepairFamily.jpeg,
      extras: ['jpeg', 'jpe', 'jfif'],
    ),
    FileSignature(
      label: 'GIF image',
      extension: 'gif',
      magic: [0x47, 0x49, 0x46, 0x38],
      family: RepairFamily.gif,
    ),
    FileSignature(
      label: 'BMP image',
      extension: 'bmp',
      magic: [0x42, 0x4D],
      family: RepairFamily.bmp,
      extras: ['dib'],
    ),
    FileSignature(
      label: 'TIFF image',
      extension: 'tiff',
      magic: [0x49, 0x49, 0x2A, 0x00],
      extras: ['tif'],
    ),
    FileSignature(
      label: 'TIFF image',
      extension: 'tiff',
      magic: [0x4D, 0x4D, 0x00, 0x2A],
      extras: ['tif'],
    ),
    FileSignature(
      label: 'WebP image',
      extension: 'webp',
      magic: [0x57, 0x45, 0x42, 0x50],
      offset: 8,
      family: RepairFamily.riff,
    ),
    FileSignature(
      label: 'Windows icon',
      extension: 'ico',
      magic: [0x00, 0x00, 0x01, 0x00],
    ),
    FileSignature(
      label: 'Photoshop document',
      extension: 'psd',
      magic: [0x38, 0x42, 0x50, 0x53],
    ),
    FileSignature(
      label: 'AVIF/HEIC image',
      extension: 'avif',
      magic: [0x66, 0x74, 0x79, 0x70],
      offset: 4,
      family: RepairFamily.mp4,
      extras: ['heic', 'heif'],
    ),

    // Documents
    FileSignature(
      label: 'PDF document',
      extension: 'pdf',
      magic: [0x25, 0x50, 0x44, 0x46, 0x2D],
      family: RepairFamily.pdf,
    ),
    FileSignature(
      label: 'Rich text document',
      extension: 'rtf',
      magic: [0x7B, 0x5C, 0x72, 0x74, 0x66],
    ),
    FileSignature(
      label: 'Legacy Office document',
      extension: 'doc',
      magic: [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1],
      extras: ['xls', 'ppt', 'msi'],
    ),

    // Archives and the ZIP-based office formats
    FileSignature(
      label: 'ZIP archive',
      extension: 'zip',
      magic: [0x50, 0x4B, 0x03, 0x04],
      family: RepairFamily.zip,
      extras: [
        'docx',
        'xlsx',
        'pptx',
        'odt',
        'ods',
        'odp',
        'epub',
        'jar',
        'apk',
        'ipa',
        'kra',
        'sketch',
      ],
    ),
    FileSignature(
      label: 'Empty ZIP archive',
      extension: 'zip',
      magic: [0x50, 0x4B, 0x05, 0x06],
      family: RepairFamily.zip,
    ),
    FileSignature(
      label: 'RAR archive',
      extension: 'rar',
      magic: [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07],
    ),
    FileSignature(
      label: '7-Zip archive',
      extension: '7z',
      magic: [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C],
    ),
    FileSignature(
      label: 'GZip archive',
      extension: 'gz',
      magic: [0x1F, 0x8B],
      extras: ['tgz'],
    ),
    FileSignature(
      label: 'BZip2 archive',
      extension: 'bz2',
      magic: [0x42, 0x5A, 0x68],
    ),
    FileSignature(
      label: 'XZ archive',
      extension: 'xz',
      magic: [0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00],
    ),
    FileSignature(
      label: 'Zstandard archive',
      extension: 'zst',
      magic: [0x28, 0xB5, 0x2F, 0xFD],
    ),
    FileSignature(
      label: 'TAR archive',
      extension: 'tar',
      magic: [0x75, 0x73, 0x74, 0x61, 0x72],
      offset: 257,
    ),

    // Audio and video
    FileSignature(
      label: 'WAV audio',
      extension: 'wav',
      magic: [0x57, 0x41, 0x56, 0x45],
      offset: 8,
      family: RepairFamily.riff,
    ),
    FileSignature(
      label: 'AVI video',
      extension: 'avi',
      magic: [0x41, 0x56, 0x49, 0x20],
      offset: 8,
      family: RepairFamily.riff,
    ),
    FileSignature(
      label: 'MP3 audio',
      extension: 'mp3',
      magic: [0x49, 0x44, 0x33],
      family: RepairFamily.mp3,
    ),
    FileSignature(
      label: 'MP4 video',
      extension: 'mp4',
      magic: [0x66, 0x74, 0x79, 0x70],
      offset: 4,
      family: RepairFamily.mp4,
      extras: ['m4a', 'm4v', 'mov', '3gp'],
    ),
    FileSignature(
      label: 'FLAC audio',
      extension: 'flac',
      magic: [0x66, 0x4C, 0x61, 0x43],
    ),
    FileSignature(
      label: 'Ogg media',
      extension: 'ogg',
      magic: [0x4F, 0x67, 0x67, 0x53],
      extras: ['oga', 'ogv', 'opus'],
    ),
    FileSignature(
      label: 'Matroska video',
      extension: 'mkv',
      magic: [0x1A, 0x45, 0xDF, 0xA3],
      extras: ['webm', 'mka'],
    ),
    FileSignature(
      label: 'MIDI file',
      extension: 'mid',
      magic: [0x4D, 0x54, 0x68, 0x64],
    ),

    // Executables, data and the rest
    FileSignature(
      label: 'Windows executable',
      extension: 'exe',
      magic: [0x4D, 0x5A],
      extras: ['dll', 'sys'],
    ),
    FileSignature(
      label: 'ELF binary',
      extension: 'elf',
      magic: [0x7F, 0x45, 0x4C, 0x46],
      extras: ['so'],
    ),
    FileSignature(
      label: 'SQLite database',
      extension: 'db',
      magic: [0x53, 0x51, 0x4C, 0x69, 0x74, 0x65, 0x20, 0x66],
      extras: ['sqlite', 'sqlite3'],
    ),
    FileSignature(
      label: 'WebAssembly module',
      extension: 'wasm',
      magic: [0x00, 0x61, 0x73, 0x6D],
    ),
    FileSignature(
      label: 'Java class',
      extension: 'class',
      magic: [0xCA, 0xFE, 0xBA, 0xBE],
    ),
    FileSignature(
      label: 'TrueType font',
      extension: 'ttf',
      magic: [0x00, 0x01, 0x00, 0x00, 0x00],
    ),
    FileSignature(
      label: 'OpenType font',
      extension: 'otf',
      magic: [0x4F, 0x54, 0x54, 0x4F],
    ),
    FileSignature(
      label: 'WOFF font',
      extension: 'woff',
      magic: [0x77, 0x4F, 0x46, 0x46],
    ),
    FileSignature(
      label: 'WOFF2 font',
      extension: 'woff2',
      magic: [0x77, 0x4F, 0x46, 0x32],
    ),
    FileSignature(
      label: 'Minecraft NBT (gzip)',
      extension: 'nbt',
      magic: [0x1F, 0x8B, 0x08],
      extras: ['schem', 'litematic', 'schematic'],
    ),
    FileSignature(
      label: 'luma recovery recipe',
      extension: 'lumafix',
      magic: [0x7B, 0x0A, 0x20, 0x20, 0x22, 0x6C, 0x75, 0x6D, 0x61, 0x66],
    ),
  ];

  /// The signature this file starts with, if any.
  static FileSignature? detectAt(Uint8List bytes, [int base = 0]) {
    FileSignature? best;
    for (final signature in all) {
      if (!signature.matches(bytes, base)) continue;
      // Prefer the longest match, so `ftyp`-at-4 beats nothing and the ZIP
      // local header beats a two-byte fallback.
      if (best == null ||
          signature.offset + signature.magic.length >
              best.offset + best.magic.length) {
        best = signature;
      }
    }
    return best;
  }

  /// Finds a signature somewhere in the first [window] bytes, which is how a
  /// file with junk glued to the front gets identified.
  ///
  /// Only [FileSignature.scannable] signatures are considered, because the
  /// short ones match random data often enough to send the repairer off after
  /// a file that was never there.
  static (FileSignature, int)? findSignature(
    Uint8List bytes, {
    int window = 1 << 16,
  }) {
    final limit = bytes.length < window ? bytes.length : window;
    for (var base = 0; base < limit; base++) {
      final signature = detectAt(bytes, base);
      if (signature != null && signature.scannable) return (signature, base);
    }
    return null;
  }

  /// Looks for one particular signature, which is worth doing when the file's
  /// name already says what it should have been.
  static int findSpecific(
    Uint8List bytes,
    FileSignature signature, {
    int window = 1 << 16,
  }) {
    final limit = bytes.length < window ? bytes.length : window;
    for (var base = 0; base < limit; base++) {
      if (signature.matches(bytes, base)) return base;
    }
    return -1;
  }

  /// The lower-case extension of [fileName], without the dot.
  static String extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  /// True when [extension] is a legitimate name for [signature].
  static bool extensionFits(FileSignature signature, String extension) =>
      extension == signature.extension || signature.extras.contains(extension);

  /// The repair family implied by a file's name when its bytes give nothing
  /// away — a wiped header still leaves the extension to go on.
  static FileSignature? byExtension(String extension) {
    if (extension.isEmpty) return null;
    for (final signature in all) {
      if (extensionFits(signature, extension)) return signature;
    }
    return null;
  }
}
