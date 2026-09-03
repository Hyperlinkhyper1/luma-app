import 'dart:io';

import '../sftp_paths.dart';

/// Turns a path a connected device asked for into a real path on this
/// machine — or refuses.
///
/// This is the single place where a remote name becomes a local file, so it
/// is the one place an escape from the shared folder could happen. Everything
/// the host serves goes through [resolve]; there is no other path in
/// [SftpHostServer] that touches the filesystem.
///
/// Three separate defences, because each catches something the others miss:
///
/// 1. **Lexical.** The path is normalised POSIX-style and every segment is
///    checked individually. `..` cannot survive normalisation, and a segment
///    that still contains a separator, a NUL, or (on Windows) a drive colon
///    is rejected rather than being handed to `dart:io`.
/// 2. **Prefix.** The assembled path must sit under the root, compared on the
///    *canonical* root so that a root reached through a symlink or a
///    short 8.3 name still matches.
/// 3. **Symlink.** The deepest part of the path that actually exists is
///    resolved through its links, and that result must also sit under the
///    root. This is what stops a link inside the shared folder from being
///    followed out of it — `shared/escape -> C:\Users` would otherwise pass
///    both checks above.
///
/// A path that fails any of them throws [HostAccessDenied]; the host turns
/// that into an error reply and the connection carries on.
class HostJail {
  HostJail._(this.root, this._canonicalRoot);

  /// The folder being shared, as the user chose it.
  final Directory root;

  /// [root] with links resolved and casing settled, which is what the prefix
  /// comparison actually uses.
  final String _canonicalRoot;

  /// Builds a jail for [directory], creating it if it is not there yet.
  static Future<HostJail> forDirectory(Directory directory) async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final canonical = await directory.resolveSymbolicLinks();
    return HostJail._(directory, _withTrailingSeparator(canonical));
  }

  /// Windows compares paths case-insensitively; Linux does not. Getting this
  /// backwards would either reject valid paths or accept escaping ones.
  static bool get _caseInsensitive => Platform.isWindows || Platform.isMacOS;

  /// The local path for [remotePath], which is always interpreted relative to
  /// the root no matter what it looks like.
  ///
  /// Set [mustExist] when the caller is reading; leave it false for a create,
  /// where only the parent has to be there.
  Future<String> resolve(String remotePath, {bool mustExist = false}) async {
    final segments = _segments(remotePath);
    final local = segments.isEmpty
        ? root.path
        : '${_withTrailingSeparator(root.path)}'
            '${segments.join(Platform.pathSeparator)}';

    await _assertInside(local, mustExist: mustExist);
    return local;
  }

  /// Splits [remotePath] into checked segments. Throws rather than silently
  /// dropping anything: a segment this rejects means the peer asked for
  /// something it should not have, and quietly serving a different file would
  /// be worse than an error.
  List<String> _segments(String remotePath) {
    if (remotePath.contains('\u0000')) {
      throw const HostAccessDenied('That path is not a valid name.');
    }
    final normalized = RemotePath.normalize(remotePath);
    final segments = <String>[];
    for (final segment in normalized.split(RemotePath.separator)) {
      if (segment.isEmpty || segment == '.') continue;
      if (segment == '..') {
        // normalize() already collapses these; one surviving means the input
        // was crafted rather than typed.
        throw const HostAccessDenied(
          'That path points outside the shared folder.',
        );
      }
      if (segment.contains('/') || segment.contains(r'\')) {
        throw const HostAccessDenied('That path is not a valid name.');
      }
      if (Platform.isWindows && segment.contains(':')) {
        throw const HostAccessDenied('That path is not a valid name.');
      }
      segments.add(segment);
    }
    return segments;
  }

  /// Checks [local] against the canonical root, resolving as far down the
  /// path as actually exists.
  Future<void> _assertInside(String local, {required bool mustExist}) async {
    if (!_isUnderRoot(local)) {
      throw const HostAccessDenied(
        'That path points outside the shared folder.',
      );
    }

    final resolved = await _resolveDeepestExisting(local);
    if (resolved == null) {
      if (mustExist) {
        throw const HostAccessDenied('That item is not in the shared folder.');
      }
      return;
    }
    if (!_isUnderRoot(resolved.path)) {
      // A symlink inside the folder that points out of it. Following it would
      // hand over a file the user never shared.
      throw const HostAccessDenied(
        'That item is a link out of the shared folder, so it is not served.',
      );
    }
    if (mustExist && !resolved.isTarget) {
      throw const HostAccessDenied('That item is not in the shared folder.');
    }
  }

  /// Walks up from [local] until something exists, and resolves that through
  /// its symlinks. Returns null when not even the root's child level is there.
  Future<({String path, bool isTarget})?> _resolveDeepestExisting(
    String local,
  ) async {
    var candidate = local;
    var isTarget = true;
    for (var depth = 0; depth < 256; depth++) {
      if (await FileSystemEntity.isLink(candidate) ||
          await File(candidate).exists() ||
          await Directory(candidate).exists()) {
        try {
          final real = await Directory(candidate).resolveSymbolicLinks();
          return (path: real, isTarget: isTarget);
        } catch (_) {
          // resolveSymbolicLinks throws on a dangling link. Treating that as
          // an escape is the safe reading: we cannot see where it lands.
          throw const HostAccessDenied(
            'That item is a link that cannot be followed, so it is not served.',
          );
        }
      }
      final parent = File(candidate).parent.path;
      if (parent == candidate) return null;
      candidate = parent;
      isTarget = false;
      if (!_isUnderRoot(candidate) && !_isRoot(candidate)) return null;
    }
    return null;
  }

  bool _isRoot(String path) =>
      _compare(_withTrailingSeparator(path), _canonicalRoot) == 0;

  bool _isUnderRoot(String path) {
    final normalized = _withTrailingSeparator(path);
    if (_compare(normalized, _canonicalRoot) == 0) return true;
    if (normalized.length < _canonicalRoot.length) return false;
    return _compare(
          normalized.substring(0, _canonicalRoot.length),
          _canonicalRoot,
        ) ==
        0;
  }

  static int _compare(String a, String b) => _caseInsensitive
      ? a.toLowerCase().compareTo(b.toLowerCase())
      : a.compareTo(b);

  static String _withTrailingSeparator(String path) =>
      path.endsWith(Platform.pathSeparator)
          ? path
          : '$path${Platform.pathSeparator}';

  /// The remote path (`/photos/trip.jpg`) for a local one, used when the host
  /// reports what it is serving. Returns null when [local] is not inside.
  String? toRemotePath(String local) {
    if (!_isUnderRoot(local)) return null;
    final relative = local.length <= _canonicalRoot.length
        ? ''
        : local.substring(_canonicalRoot.length);
    final segments = relative
        .split(RegExp(r'[\\/]'))
        .where((s) => s.isNotEmpty)
        .toList();
    return RemotePath.normalize('/${segments.join('/')}');
  }
}

/// Thrown when a requested path is not one this host will serve.
class HostAccessDenied implements Exception {
  const HostAccessDenied(this.message);

  final String message;

  @override
  String toString() => message;
}
