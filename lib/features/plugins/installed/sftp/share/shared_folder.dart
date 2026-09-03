import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../../p2p/peer_protocol.dart';
import 'share_index.dart';

/// The shared folder on this device, plus the index that describes it.
///
/// Everything lives under the app's support directory:
///
///     luma_shared/            the files themselves — what the user sees
///     luma_shared/.incoming/  partial downloads, never advertised
///     luma_shared_index.json  sizes, hashes, mtimes and tombstones
///
/// The index sits *outside* the folder on purpose: it is bookkeeping, not
/// content, and putting it inside would make it a file that syncs itself.
class SharedFolder {
  SharedFolder._(this.root, this._indexFile);

  final Directory root;
  final File _indexFile;

  static const folderName = 'luma_shared';
  static const _indexFileName = 'luma_shared_index.json';
  static const _incomingDirName = '.incoming';

  /// Live files and tombstones, keyed by normalized relative path.
  final Map<String, SharedFileEntry> _index = {};

  Map<String, SharedFileEntry> get index => Map.unmodifiable(_index);

  /// Only the files that actually exist, for the folder pane.
  List<SharedFileEntry> get files => [
        for (final entry in _index.values)
          if (!entry.isDeleted) entry,
      ]..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));

  /// What the peers are told: live files *and* tombstones.
  List<SharedFileEntry> get advertisement => _index.values.toList();

  int get totalBytes =>
      files.fold<int>(0, (sum, entry) => sum + entry.size);

  Directory get incomingDir =>
      Directory('${root.path}${Platform.pathSeparator}$_incomingDirName');

  /// Opens (creating on first run) the folder and reads the index.
  static Future<SharedFolder> open() async {
    final support = await getApplicationSupportDirectory();
    final sep = Platform.pathSeparator;
    final root = Directory('${support.path}$sep$folderName');
    if (!await root.exists()) await root.create(recursive: true);
    final folder = SharedFolder._(
      root,
      File('${support.path}$sep$_indexFileName'),
    );
    await folder._loadIndex();
    return folder;
  }

  /// Builds one over a caller-supplied directory. Tests use this so they
  /// never touch the real support directory.
  static Future<SharedFolder> openAt(Directory root, File indexFile) async {
    if (!await root.exists()) await root.create(recursive: true);
    final folder = SharedFolder._(root, indexFile);
    await folder._loadIndex();
    return folder;
  }

  Future<void> _loadIndex() async {
    try {
      if (!await _indexFile.exists()) return;
      final raw = jsonDecode(await _indexFile.readAsString());
      final list = raw is Map<String, dynamic> ? raw['entries'] as List? : null;
      for (final item in list ?? const []) {
        final entry = SharedFileEntry.fromJson(item);
        if (entry != null) _index[entry.path] = entry;
      }
    } catch (_) {
      _index.clear();
    }
  }

  Future<void> saveIndex() async {
    final pruned = pruneTombstones(
      _index,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    if (pruned.length != _index.length) {
      _index
        ..clear()
        ..addAll(pruned);
    }
    await _indexFile.writeAsString(
      jsonEncode({'entries': [for (final e in _index.values) e.toJson()]}),
      flush: true,
    );
  }

  /// The local file behind [path]. Not guaranteed to exist.
  File fileFor(String path) => File(
        '${root.path}${Platform.pathSeparator}'
        '${path.replaceAll('/', Platform.pathSeparator)}',
      );

  SharedFileEntry? entryFor(String path) => _index[path];

  /// Reconciles the index with what is actually on disk: new files get
  /// hashed and added, changed files re-hashed, and files that vanished
  /// become tombstones so the delete reaches the other devices.
  ///
  /// Hashing is skipped when size and mtime both match the index — reading
  /// every byte of every file on each scan would make a folder of any size
  /// unusable.
  Future<bool> rescan() async {
    var changed = false;
    final seen = <String>{};

    if (await root.exists()) {
      await for (final entity in root.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final relative = _relativePathOf(entity.path);
        if (relative == null) continue;
        seen.add(relative);

        final stat = await entity.stat();
        final modifiedMs = stat.modified.millisecondsSinceEpoch;
        final existing = _index[relative];
        if (existing != null &&
            !existing.isDeleted &&
            existing.size == stat.size &&
            existing.modifiedMs == modifiedMs) {
          continue;
        }

        _index[relative] = SharedFileEntry(
          path: relative,
          size: stat.size,
          hash: await hashOf(entity),
          modifiedMs: modifiedMs,
        );
        changed = true;
      }
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    for (final entry in _index.values.toList()) {
      if (entry.isDeleted || seen.contains(entry.path)) continue;
      _index[entry.path] = entry.asDeleted(nowMs);
      changed = true;
    }

    if (changed) await saveIndex();
    return changed;
  }

  /// The index key for an absolute path inside the folder, or null when the
  /// path is staging (`.incoming`) or somehow outside the root.
  String? _relativePathOf(String absolute) {
    if (!absolute.startsWith(root.path)) return null;
    var relative = absolute.substring(root.path.length);
    final normalized = normalizeSharePath(relative);
    if (normalized == null) return null;
    if (normalized == _incomingDirName ||
        normalized.startsWith('$_incomingDirName/')) {
      return null;
    }
    return normalized;
  }

  /// Copies [source] into the folder, returning its index entry. A name
  /// already in use gets ` (2)`, ` (3)`… appended rather than overwriting —
  /// the copy would otherwise propagate as an edit to everyone.
  Future<SharedFileEntry> importFile(File source, {String? subdirectory}) async {
    final baseName = source.uri.pathSegments.isEmpty
        ? 'file'
        : source.uri.pathSegments.last;
    final prefix = subdirectory == null || subdirectory.isEmpty
        ? ''
        : '${normalizeSharePath(subdirectory) ?? ''}/';
    var relative = normalizeSharePath('$prefix$baseName') ?? 'file';

    if (_index[relative]?.isDeleted == false ||
        await fileFor(relative).exists()) {
      relative = _uniqueName(relative);
    }

    final target = fileFor(relative);
    final parent = target.parent;
    if (!await parent.exists()) await parent.create(recursive: true);
    await source.copy(target.path);

    final stat = await target.stat();
    final entry = SharedFileEntry(
      path: relative,
      size: stat.size,
      hash: await hashOf(target),
      modifiedMs: stat.modified.millisecondsSinceEpoch,
    );
    _index[relative] = entry;
    await saveIndex();
    return entry;
  }

  String _uniqueName(String relative) {
    final dot = relative.lastIndexOf('.');
    final slash = relative.lastIndexOf('/');
    final hasExtension = dot > slash + 1;
    final stem = hasExtension ? relative.substring(0, dot) : relative;
    final extension = hasExtension ? relative.substring(dot) : '';
    for (var n = 2; n < 1000; n++) {
      final candidate = '$stem ($n)$extension';
      if (_index[candidate] == null || _index[candidate]!.isDeleted) {
        if (!fileFor(candidate).existsSync()) return candidate;
      }
    }
    return '$stem (${DateTime.now().millisecondsSinceEpoch})$extension';
  }

  /// Removes a file and leaves a tombstone, so the delete travels to the
  /// other devices instead of the file coming straight back.
  Future<void> deleteEntry(String path) async {
    final file = fileFor(path);
    if (await file.exists()) await file.delete();
    final existing = _index[path];
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _index[path] = (existing ??
            SharedFileEntry(path: path, size: 0, hash: '', modifiedMs: nowMs))
        .asDeleted(nowMs);
    await saveIndex();
  }

  /// Applies a tombstone learned from a peer.
  Future<void> applyRemoteDelete(SharedFileEntry tombstone) async {
    final file = fileFor(tombstone.path);
    if (await file.exists()) await file.delete();
    _index[tombstone.path] = tombstone;
    await saveIndex();
  }

  /// Records a peer's tombstone for a file this device never held.
  Future<void> adoptTombstone(SharedFileEntry tombstone) async {
    _index[tombstone.path] = tombstone;
    await saveIndex();
  }

  /// The staging file a download accumulates into. Named from the path's
  /// hash so nested paths don't need directories in `.incoming`, and so a
  /// hostile name can't escape it.
  Future<File> stagingFileFor(String path) async {
    if (!await incomingDir.exists()) await incomingDir.create(recursive: true);
    final name = sha256.convert(utf8.encode(path)).toString();
    return File('${incomingDir.path}${Platform.pathSeparator}$name.part');
  }

  /// Moves a completed download into the folder and indexes it.
  Future<SharedFileEntry> commitStaged(
    File staged,
    String path, {
    required String hash,
    required int modifiedMs,
  }) async {
    final target = fileFor(path);
    final parent = target.parent;
    if (!await parent.exists()) await parent.create(recursive: true);
    if (await target.exists()) await target.delete();
    await staged.rename(target.path);

    // Carry the origin device's mtime across so the file's identity — and so
    // the merge's newest-wins comparison — is the same on every device.
    final modified = DateTime.fromMillisecondsSinceEpoch(modifiedMs);
    try {
      await target.setLastModified(modified);
    } catch (_) {
      // Some Android volumes refuse this; the index still records the
      // intended time, which is what the merge compares.
    }

    final entry = SharedFileEntry(
      path: path,
      size: await target.length(),
      hash: hash,
      modifiedMs: modifiedMs,
    );
    _index[path] = entry;
    await saveIndex();
    return entry;
  }

  /// Deletes any staged partial for [path] — used when a transfer is
  /// abandoned or the peer's copy turned out to have changed.
  Future<void> discardStaged(String path) async {
    try {
      final staged = await stagingFileFor(path);
      if (await staged.exists()) await staged.delete();
    } catch (_) {
      // Nothing to clean up.
    }
  }

  static Future<String> hashOf(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}
