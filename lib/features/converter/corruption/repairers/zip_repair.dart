import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../binary_utils.dart';
import '../repair_report.dart';

const List<int> _localSig = [0x50, 0x4B, 0x03, 0x04];
const List<int> _centralSig = [0x50, 0x4B, 0x01, 0x02];
const List<int> _eocdSig = [0x50, 0x4B, 0x05, 0x06];
const List<int> _descriptorSig = [0x50, 0x4B, 0x07, 0x08];

const int _localHeaderSize = 30;
const int _centralHeaderSize = 46;
const int _eocdSize = 22;

/// Rebuilds a ZIP from its local file headers.
///
/// Almost every "corrupt archive" is really a lost central directory: the entry
/// data is still sitting there, but the index at the end of the file that says
/// where each entry starts is gone or wrong. Every local header repeats enough
/// of that index to reconstruct it, so this walks the file start to end,
/// decompresses each entry to check it is real, and writes a fresh archive out
/// of the ones that survive.
///
/// DOCX, XLSX, PPTX, ODT, EPUB, JAR and APK are all ZIPs, so they all come
/// through here.
Uint8List repairZip(
  Uint8List bytes,
  RepairLog log, {
  String extension = 'zip',
}) {
  final entries = <_ZipEntry>[];
  var offset = 0;
  var skipped = 0;

  while (offset >= 0 && offset + _localHeaderSize <= bytes.length) {
    final at = matchesAt(bytes, offset, _localSig)
        ? offset
        : indexOfBytes(bytes, _localSig, offset);
    if (at < 0) break;
    if (at > offset) {
      log.warning(
        'Skipped ${formatSize(at - offset)} of unreadable bytes before the '
        'entry at ${formatOffset(at)}.',
      );
    }

    final entry = _readEntry(bytes, at, log);
    if (entry == null) {
      skipped++;
      offset = at + 4;
      continue;
    }
    entries.add(entry);
    offset = entry.nextOffset;
  }

  if (entries.isEmpty) {
    log.failed(
      'No recoverable entries were found — every local file header is gone, so '
      'there is nothing left to rebuild the archive from.',
    );
    return bytes;
  }

  if (skipped > 0) {
    log.warning(
      '$skipped entr${skipped == 1 ? 'y was' : 'ies were'} damaged beyond use '
      'and left out of the rebuilt archive.',
    );
  }

  final hadCentral = indexOfBytes(bytes, _centralSig) >= 0;
  final hadEocd = lastIndexOfBytes(bytes, _eocdSig) >= 0;
  if (!hadCentral || !hadEocd) {
    log.fixed(
      'Rebuilt the missing central directory from ${entries.length} local '
      'file header${entries.length == 1 ? '' : 's'}.',
    );
  } else {
    log.fixed(
      'Rewrote the central directory and end-of-archive record around '
      '${entries.length} recovered entr${entries.length == 1 ? 'y' : 'ies'}.',
    );
  }

  _checkOfficeMembers(entries, extension, log);

  return _writeZip(entries);
}

/// Reads one local file header and the entry data behind it.
_ZipEntry? _readEntry(Uint8List bytes, int at, RepairLog log) {
  if (at + _localHeaderSize > bytes.length) return null;

  final flags = readU16le(bytes, at + 6);
  final method = readU16le(bytes, at + 8);
  final modTime = readU16le(bytes, at + 10);
  final modDate = readU16le(bytes, at + 12);
  var storedCrc = readU32le(bytes, at + 14);
  var compressedSize = readU32le(bytes, at + 18);
  final nameLength = readU16le(bytes, at + 26);
  final extraLength = readU16le(bytes, at + 28);

  if (nameLength == 0 || nameLength > 4096) return null;
  final nameEnd = at + _localHeaderSize + nameLength;
  if (nameEnd > bytes.length) return null;

  String name;
  try {
    name = const Utf8Decoder(
      allowMalformed: true,
    ).convert(bytes.sublist(at + _localHeaderSize, nameEnd));
  } catch (_) {
    return null;
  }
  if (!_looksLikeEntryName(name)) return null;

  final dataStart = nameEnd + extraLength;
  if (dataStart > bytes.length) return null;

  // Where the entry data has to stop: the next header, or the end of file.
  var boundary = _nextBoundary(bytes, dataStart);

  // Bit 3 means the sizes were not known when the entry was written and live
  // in a data descriptor after the data instead.
  final streamed = (flags & 0x08) != 0;
  if (streamed ||
      compressedSize == 0 ||
      dataStart + compressedSize > boundary) {
    final descriptor = _findDescriptor(bytes, dataStart, boundary);
    if (descriptor != null) {
      storedCrc = descriptor.crc;
      compressedSize = descriptor.compressedSize;
      boundary = descriptor.at;
    }
  }

  var dataEnd = dataStart + compressedSize;
  if (compressedSize == 0 || dataEnd > boundary) dataEnd = boundary;
  if (dataEnd < dataStart) return null;

  final raw = bytes.sublist(dataStart, dataEnd);

  // A directory entry: no data, name ends in a slash.
  if (name.endsWith('/')) {
    return _ZipEntry(
      name: name,
      method: 0,
      modTime: modTime,
      modDate: modDate,
      data: Uint8List(0),
      compressed: Uint8List(0),
      crc: 0,
      nextOffset: dataEnd,
    );
  }

  Uint8List content;
  if (method == 0) {
    content = raw;
  } else if (method == 8) {
    content = _inflatePartial(raw);
    if (content.isEmpty && raw.isNotEmpty) {
      log.warning('"$name" could not be decompressed at all — dropped.');
      return null;
    }
  } else {
    log.warning(
      '"$name" uses compression method $method, which luma cannot decompress. '
      'It was copied through untouched.',
    );
    return _ZipEntry(
      name: name,
      method: method,
      modTime: modTime,
      modDate: modDate,
      data: raw,
      compressed: raw,
      crc: storedCrc,
      nextOffset: dataEnd,
    );
  }

  final actualCrc = Crc32.compute(content);
  if (storedCrc != 0 && actualCrc != storedCrc) {
    log.warning(
      '"$name" does not match its checksum — the contents came out damaged, '
      'but the entry was kept so you can see what is left of it.',
    );
  }

  final deflated = method == 8
      ? Uint8List.fromList(Deflate(content).getBytes())
      : content;
  return _ZipEntry(
    name: name,
    method: method == 8 ? 8 : 0,
    modTime: modTime,
    modDate: modDate,
    data: content,
    compressed: deflated,
    crc: actualCrc,
    nextOffset: dataEnd,
  );
}

/// Rejects the "names" that fall out of reading a random stretch of the file
/// as if it were a local header. A real entry name is printable and has no
/// control characters in it.
bool _looksLikeEntryName(String name) {
  if (name.isEmpty) return false;
  for (final unit in name.codeUnits) {
    if (unit < 0x20 || unit == 0x7F) return false;
  }
  return true;
}

/// Inflates as much as the stream allows, keeping whatever came out before it
/// broke.
Uint8List _inflatePartial(Uint8List raw) {
  final output = OutputMemoryStream();
  try {
    Inflate(raw, output: output);
  } catch (_) {
    // A truncated deflate stream throws once it runs out of input; everything
    // it managed to decode is already in [output].
  }
  return output.getBytes();
}

int _nextBoundary(Uint8List bytes, int from) {
  final local = indexOfBytes(bytes, _localSig, from);
  final central = indexOfBytes(bytes, _centralSig, from);
  var boundary = bytes.length;
  if (local >= 0 && local < boundary) boundary = local;
  if (central >= 0 && central < boundary) boundary = central;
  return boundary;
}

_Descriptor? _findDescriptor(Uint8List bytes, int from, int boundary) {
  // The signature is optional, so try the signed form first and then assume an
  // unsigned descriptor sits immediately before the boundary.
  final at = indexOfBytes(bytes, _descriptorSig, from, boundary + 4);
  if (at >= 0 && at + 16 <= bytes.length) {
    return _Descriptor(
      at: at,
      crc: readU32le(bytes, at + 4),
      compressedSize: readU32le(bytes, at + 8),
    );
  }
  if (boundary - 12 >= from) {
    return _Descriptor(
      at: boundary - 12,
      crc: readU32le(bytes, boundary - 12),
      compressedSize: readU32le(bytes, boundary - 8),
    );
  }
  return null;
}

/// Office and e-book containers have members they cannot live without; saying
/// which one is missing is more useful than "the file is still broken".
void _checkOfficeMembers(
  List<_ZipEntry> entries,
  String extension,
  RepairLog log,
) {
  const requirements = <String, List<String>>{
    'docx': ['[Content_Types].xml', 'word/document.xml'],
    'xlsx': ['[Content_Types].xml', 'xl/workbook.xml'],
    'pptx': ['[Content_Types].xml', 'ppt/presentation.xml'],
    'odt': ['mimetype', 'content.xml'],
    'ods': ['mimetype', 'content.xml'],
    'odp': ['mimetype', 'content.xml'],
    'epub': ['mimetype', 'META-INF/container.xml'],
  };
  final required = requirements[extension];
  if (required == null) return;

  final names = entries.map((entry) => entry.name).toSet();
  final missing = required.where((name) => !names.contains(name)).toList();
  if (missing.isEmpty) {
    log.info(
      'All the parts a .$extension needs are present, so it should open.',
    );
  } else {
    log.failed(
      'The .$extension is still missing ${missing.join(', ')}. Those parts '
      'carry the document itself, and nothing can regenerate them.',
    );
  }
}

Uint8List _writeZip(List<_ZipEntry> entries) {
  final parts = <List<int>>[];
  final offsets = <int>[];
  var position = 0;

  for (final entry in entries) {
    final name = utf8.encode(entry.name);
    final header = Uint8List(_localHeaderSize + name.length);
    header.setRange(0, 4, _localSig);
    writeU16le(header, 4, 20);
    writeU16le(header, 6, 0);
    writeU16le(header, 8, entry.method);
    writeU16le(header, 10, entry.modTime);
    writeU16le(header, 12, entry.modDate);
    writeU32le(header, 14, entry.crc);
    writeU32le(header, 18, entry.compressed.length);
    writeU32le(header, 22, entry.data.length);
    writeU16le(header, 26, name.length);
    writeU16le(header, 28, 0);
    header.setRange(_localHeaderSize, _localHeaderSize + name.length, name);

    offsets.add(position);
    parts.add(header);
    parts.add(entry.compressed);
    position += header.length + entry.compressed.length;
  }

  final centralStart = position;
  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final name = utf8.encode(entry.name);
    final record = Uint8List(_centralHeaderSize + name.length);
    record.setRange(0, 4, _centralSig);
    writeU16le(record, 4, 20);
    writeU16le(record, 6, 20);
    writeU16le(record, 8, 0);
    writeU16le(record, 10, entry.method);
    writeU16le(record, 12, entry.modTime);
    writeU16le(record, 14, entry.modDate);
    writeU32le(record, 16, entry.crc);
    writeU32le(record, 20, entry.compressed.length);
    writeU32le(record, 24, entry.data.length);
    writeU16le(record, 28, name.length);
    writeU16le(record, 30, 0);
    writeU16le(record, 32, 0);
    writeU16le(record, 34, 0);
    writeU16le(record, 36, 0);
    writeU32le(record, 38, entry.name.endsWith('/') ? 0x10 : 0);
    writeU32le(record, 42, offsets[i]);
    record.setRange(_centralHeaderSize, _centralHeaderSize + name.length, name);
    parts.add(record);
    position += record.length;
  }

  final eocd = Uint8List(_eocdSize);
  eocd.setRange(0, 4, _eocdSig);
  writeU16le(eocd, 4, 0);
  writeU16le(eocd, 6, 0);
  writeU16le(eocd, 8, entries.length);
  writeU16le(eocd, 10, entries.length);
  writeU32le(eocd, 12, position - centralStart);
  writeU32le(eocd, 16, centralStart);
  writeU16le(eocd, 20, 0);
  parts.add(eocd);

  return concatBytes(parts);
}

class _ZipEntry {
  const _ZipEntry({
    required this.name,
    required this.method,
    required this.modTime,
    required this.modDate,
    required this.data,
    required this.compressed,
    required this.crc,
    required this.nextOffset,
  });

  final String name;
  final int method;
  final int modTime;
  final int modDate;
  final Uint8List data;
  final Uint8List compressed;
  final int crc;
  final int nextOffset;
}

class _Descriptor {
  const _Descriptor({
    required this.at,
    required this.crc,
    required this.compressedSize,
  });

  final int at;
  final int crc;
  final int compressedSize;
}
