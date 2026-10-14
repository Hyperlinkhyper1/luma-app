import 'dart:io';

/// Counts every file under Luma's storage roots, including new stores, temporary
/// files and hidden files. Overlapping roots are counted only once; links inside
/// a root are not followed into unrelated storage.
Future<StorageUsage> measureStorageUsage(Map<String, String> roots) async {
  final seen = <String>{};
  final entries = <Map<String, dynamic>>[];
  var complete = true;

  Future<int> bytesIn(FileSystemEntity entity) async {
    final key = Platform.isWindows ? entity.path.toLowerCase() : entity.path;
    if (!seen.add(key)) return 0;
    try {
      if (entity is File) return await entity.length();
      if (entity is Directory) {
        var bytes = 0;
        await for (final child in entity.list(followLinks: false)) {
          bytes += await bytesIn(child);
        }
        return bytes;
      }
    } on FileSystemException {
      complete = false;
    }
    return 0;
  }

  for (final root in roots.entries) {
    try {
      final directory = Directory(root.key);
      if (!await directory.exists()) continue;
      final canonical = Directory(await directory.resolveSymbolicLinks());
      final bytes = await bytesIn(canonical);
      if (bytes > 0) {
        entries.add({'id': root.key, 'label': root.value, 'bytes': bytes});
      }
    } on FileSystemException {
      complete = false;
    }
  }
  entries.sort((a, b) => (b['bytes'] as int).compareTo(a['bytes'] as int));
  return StorageUsage(entries, complete: complete);
}

class StorageUsage {
  StorageUsage(this.entries, {required this.complete});

  final List<Map<String, dynamic>> entries;
  final bool complete;

  int get totalBytes =>
      entries.fold(0, (sum, entry) => sum + (entry['bytes'] as int));

  String get capacityText =>
      '${complete ? (totalBytes / 1000000000).toStringAsFixed(2) : '–'}/256GB';

  Map<String, dynamic> toJson() => {
        'totalBytes': totalBytes,
        'complete': complete,
        'capacityText': capacityText,
        'entries': entries,
      };
}
