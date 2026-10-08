import 'dart:convert';
import 'dart:typed_data';

import '../../../../l10n/current_l.dart';
import '../binary_utils.dart';
import '../repair_report.dart';

final RegExp _objectPattern = RegExp(r'(\d{1,10})\s+(\d{1,5})\s+obj\b');
final RegExp _rootPattern = RegExp(r'/Root\s+(\d{1,10})\s+(\d{1,5})\s+R');
final RegExp _catalogPattern = RegExp(r'/Type\s*/Catalog');

/// Rebuilds a PDF's cross-reference table.
///
/// A PDF is a bag of numbered objects plus an index at the end saying what byte
/// each one starts at. Damage anywhere in the file shifts those byte offsets,
/// and every reader refuses the document even though the objects themselves are
/// fine. Rebuilding the index by scanning for the objects is the standard fix,
/// and it is what "repair" means in every other PDF tool too.
Uint8List repairPdf(Uint8List bytes, RepairLog log) {
  var data = bytes;

  // Byte-for-byte round trip: latin1 maps each byte to one code unit, so string
  // offsets and byte offsets stay the same number.
  var text = latin1.decode(data, allowInvalid: true);

  final headerAt = text.indexOf('%PDF-');
  if (headerAt < 0) {
    log.fixed(currentL.repairPdfHeaderAdded);
    data = concatBytes([latin1.encode('%PDF-1.7\n'), data]);
    text = latin1.decode(data, allowInvalid: true);
  } else if (headerAt > 0) {
    log.fixed(currentL.repairPdfJunkDropped(formatSize(headerAt)));
    data = data.sublist(headerAt);
    text = latin1.decode(data, allowInvalid: true);
  }

  final offsets = <int, int>{};
  for (final match in _objectPattern.allMatches(text)) {
    final number = int.tryParse(match.group(1)!);
    if (number == null || number == 0) continue;
    // A later definition of the same object wins, which is how incremental
    // updates are meant to resolve.
    offsets[number] = match.start;
  }

  if (offsets.isEmpty) {
    log.failed(currentL.repairPdfNoObjects);
    return data;
  }

  log.info(currentL.repairPdfObjectsIntact(offsets.length));

  if (text.contains('/Encrypt')) {
    log.warning(currentL.repairPdfEncrypted);
  }

  final root = _findRoot(text, offsets);
  if (root == null) {
    log.failed(currentL.repairPdfNoCatalog);
  } else {
    log.info(currentL.repairPdfCatalogFound(root));
  }

  final hadStartxref = text.contains('startxref');
  final maxObject = offsets.keys.reduce((a, b) => a > b ? a : b);

  final buffer = StringBuffer();
  // The rebuilt index has to start on its own line.
  final needsNewline = data.isNotEmpty && data[data.length - 1] != 0x0A;
  if (needsNewline) buffer.write('\n');
  final xrefOffset = data.length + (needsNewline ? 1 : 0);

  buffer.write('xref\n0 ${maxObject + 1}\n');
  buffer.write('0000000000 65535 f \n');
  var free = 0;
  for (var i = 1; i <= maxObject; i++) {
    final offset = offsets[i];
    if (offset == null) {
      buffer.write('0000000000 65535 f \n');
      free++;
    } else {
      buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }
  }
  buffer.write('trailer\n<< /Size ${maxObject + 1}');
  if (root != null) buffer.write(' /Root $root 0 R');
  buffer.write(' >>\nstartxref\n$xrefOffset\n%%EOF\n');

  if (free > 0) {
    log.warning(currentL.repairPdfFreeSlots(free));
  }
  log.fixed(
    hadStartxref
        ? currentL.repairPdfXrefRebuilt
        : currentL.repairPdfXrefFromScratch,
  );

  return concatBytes([data, latin1.encode(buffer.toString())]);
}

int? _findRoot(String text, Map<int, int> offsets) {
  // The old trailer, when there still is one, names the catalog directly.
  final declared = _rootPattern.allMatches(text).toList();
  if (declared.isNotEmpty) {
    final number = int.tryParse(declared.last.group(1)!);
    if (number != null && offsets.containsKey(number)) return number;
  }

  // Otherwise find the object that calls itself the catalog.
  final catalog = _catalogPattern.firstMatch(text);
  if (catalog == null) return null;
  int? best;
  var bestOffset = -1;
  for (final entry in offsets.entries) {
    if (entry.value <= catalog.start && entry.value > bestOffset) {
      bestOffset = entry.value;
      best = entry.key;
    }
  }
  return best;
}
