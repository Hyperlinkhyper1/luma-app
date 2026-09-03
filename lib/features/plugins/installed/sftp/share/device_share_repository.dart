import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../../p2p/peer_protocol.dart';
import '../../../../../p2p/peer_share.dart';
import 'share_index.dart';
import 'shared_folder.dart';

/// Which way a shared file is moving.
enum ShareDirection { incoming, outgoing }

/// One file in motion between this device and another.
class ShareTransfer {
  ShareTransfer({
    required this.path,
    required this.deviceId,
    required this.deviceName,
    required this.direction,
    required this.totalBytes,
  });

  final String path;
  final String deviceId;
  final String deviceName;
  final ShareDirection direction;
  final int totalBytes;

  int bytesDone = 0;
  String? error;
  bool finished = false;

  String get name => path.split('/').last;

  double? get progress {
    if (totalBytes <= 0) return finished ? 1 : null;
    return (bytesDone / totalBytes).clamp(0.0, 1.0);
  }
}

/// One of the user's other devices, as the shared folder sees it.
class SharePeerStatus {
  SharePeerStatus({required this.deviceId, required this.deviceName});

  final String deviceId;
  String deviceName;

  bool connected = false;

  /// Files this device still has to fetch from that one.
  int pendingIn = 0;

  /// Files that device still has to fetch from this one, as of its last
  /// index — an estimate, and only while it is connected.
  int pendingOut = 0;

  DateTime? lastSyncedAt;
  String? error;
}

/// Keeps one folder identical across every device signed in to the account.
///
/// **No file byte ever goes near a luma server.** The mirror runs entirely on
/// the LAN links [PeerSyncController] already maintains: mDNS discovery, a
/// direct TCP socket between the two devices, and a handshake that proves
/// both ends hold the same account key. This class only ever sees a
/// [PeerShareChannel]; there is no HTTP client here and no code path that
/// could acquire one.
///
/// The algorithm is pull-only (see [planShareSync]): each side advertises its
/// whole index, and each side fetches what it is behind on. Deletes travel as
/// tombstones so a device that was off doesn't resurrect them.
class DeviceShareRepository extends ChangeNotifier implements PeerShareDelegate {
  DeviceShareRepository(this.folder);

  final SharedFolder folder;

  final Map<String, PeerShareChannel> _channels = {};
  final Map<String, SharePeerStatus> _peers = {};

  /// Paths still to fetch from each device, in the order we learned of them.
  final Map<String, Queue<String>> _pullQueues = {};

  /// The peer entry behind each queued pull, so a completed download can be
  /// verified and indexed with the origin's hash and mtime.
  final Map<String, Map<String, SharedFileEntry>> _pullMeta = {};

  /// Paths each device has asked us to serve.
  final Map<String, Queue<({String path, int from})>> _serveQueues = {};

  /// Chunk writes are serialized per device: the read loop delivers chunks
  /// without awaiting, so two of them could otherwise be inside the same
  /// file handle at once.
  final Map<String, Future<void>> _chunkChains = {};

  final Map<String, ShareTransfer> _incoming = {};
  final Map<String, ShareTransfer> _outgoing = {};
  final Map<String, RandomAccessFile> _incomingHandles = {};

  /// Finished transfers, newest first, for the activity list.
  final List<ShareTransfer> _history = [];

  bool _disposed = false;
  Timer? _rescanTimer;
  StreamSubscription<FileSystemEvent>? _watch;

  List<SharePeerStatus> get peers {
    final list = _peers.values.toList();
    list.sort((a, b) {
      if (a.connected != b.connected) return a.connected ? -1 : 1;
      return a.deviceName.toLowerCase().compareTo(b.deviceName.toLowerCase());
    });
    return list;
  }

  List<ShareTransfer> get active =>
      [..._incoming.values, ..._outgoing.values];

  List<ShareTransfer> get history => List.unmodifiable(_history);

  bool get isBusy => _incoming.isNotEmpty || _outgoing.isNotEmpty;

  int get connectedCount =>
      _peers.values.where((p) => p.connected).length;

  /// Scans the folder and starts watching it, so a file dropped in from
  /// outside the app still reaches the other devices.
  Future<void> start() async {
    await folder.rescan();
    _notify();
    try {
      _watch = folder.root
          .watch(recursive: true)
          .listen((_) => _scheduleRescan(), onError: (_) {});
    } catch (_) {
      // Not every platform/filesystem supports watching; the timer below is
      // the fallback that keeps the folder honest either way.
    }
    _rescanTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(refresh()),
    );
  }

  Timer? _rescanDebounce;

  void _scheduleRescan() {
    _rescanDebounce?.cancel();
    _rescanDebounce = Timer(
      const Duration(milliseconds: 700),
      () => unawaited(refresh()),
    );
  }

  /// Rescans the folder and, if anything changed, re-advertises it.
  Future<void> refresh() async {
    if (_disposed) return;
    final changed = await folder.rescan();
    if (changed) broadcastIndex();
    _notify();
  }

  /// Sends our index to every connected device.
  void broadcastIndex() {
    final entries = folder.advertisement;
    for (final channel in _channels.values) {
      channel.sendShareIndex(entries);
    }
  }

  // ---------------------------------------------------------- local edits

  /// Copies files into the shared folder. They reach the other devices on
  /// their own — immediately if a device is connected, on its next sighting
  /// otherwise.
  Future<void> addFiles(List<File> sources, {String? subdirectory}) async {
    for (final source in sources) {
      try {
        await folder.importFile(source, subdirectory: subdirectory);
      } catch (e) {
        final name = source.path.split(Platform.pathSeparator).last;
        _lastError = 'Could not add $name: $e';
      }
    }
    broadcastIndex();
    _notify();
  }

  /// Copies a whole folder in, keeping its shape: a dropped `photos/`
  /// arrives on the other devices as `photos/` with the same files inside,
  /// not as a flattened pile.
  Future<void> addDirectory(Directory source) async {
    final rootName = source.path
        .split(Platform.pathSeparator)
        .where((s) => s.isNotEmpty)
        .last;
    try {
      await for (final entity
          in source.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final relative = entity.parent.path.substring(source.path.length);
        final subdirectory =
            normalizeSharePath('$rootName${relative.replaceAll('\\', '/')}');
        await folder.importFile(entity, subdirectory: subdirectory);
      }
    } catch (e) {
      _lastError = 'Could not add $rootName: $e';
    }
    broadcastIndex();
    _notify();
  }

  /// Deletes from the shared folder on every device.
  Future<void> deleteFiles(List<String> paths) async {
    for (final path in paths) {
      await folder.deleteEntry(path);
    }
    broadcastIndex();
    _notify();
  }

  String? _lastError;
  String? get lastError => _lastError;

  void clearError() {
    _lastError = null;
    _notify();
  }

  // ------------------------------------------------------ delegate: peers

  @override
  void onPeerAvailable(
    String deviceId,
    String deviceName,
    PeerShareChannel channel,
  ) {
    _channels[deviceId] = channel;
    final peer = _peers.putIfAbsent(
      deviceId,
      () => SharePeerStatus(deviceId: deviceId, deviceName: deviceName),
    )
      ..deviceName = deviceName
      ..connected = true
      ..error = null;
    peer.pendingIn = _pullQueues[deviceId]?.length ?? 0;

    channel.sendShareIndex(folder.advertisement);
    // Anything left over from the last time this device was around goes out
    // again now — this is what "queued until the device shows up" means.
    _drainPulls(deviceId);
    _notify();
  }

  @override
  void onPeerGone(String deviceId) {
    _channels.remove(deviceId);
    _peers[deviceId]?.connected = false;

    // Park, don't fail: the partial download stays on disk and resumes from
    // its current length when the device comes back.
    unawaited(_closeIncomingHandle(deviceId));
    final transfer = _incoming.remove(deviceId);
    if (transfer != null) {
      // Put it back at the front of the queue so it is the first thing tried
      // on reconnect.
      _pullQueues.putIfAbsent(deviceId, Queue<String>.new).addFirst(transfer.path);
    }
    _outgoing.remove(deviceId);
    _serveQueues.remove(deviceId);
    _notify();
  }

  @override
  void onPeerIndex(String deviceId, List<SharedFileEntry> entries) {
    unawaited(_applyPeerIndex(deviceId, entries));
  }

  Future<void> _applyPeerIndex(
    String deviceId,
    List<SharedFileEntry> entries,
  ) async {
    // A peer names the paths, so every one of them is checked before it can
    // become a file name on this device.
    final safe = <SharedFileEntry>[];
    for (final entry in entries) {
      final path = normalizeSharePath(entry.path);
      if (path == null) continue;
      safe.add(
        SharedFileEntry(
          path: path,
          size: entry.size,
          hash: entry.hash,
          modifiedMs: entry.modifiedMs,
          deletedAtMs: entry.deletedAtMs,
        ),
      );
    }

    final decisions = planShareSync(ours: folder.index, theirs: safe);
    final queue = _pullQueues.putIfAbsent(deviceId, Queue<String>.new);
    final meta = _pullMeta.putIfAbsent(deviceId, () => {});

    for (final decision in decisions) {
      switch (decision.kind) {
        case ShareDecisionKind.adoptTombstone:
          await folder.adoptTombstone(decision.entry);
        case ShareDecisionKind.deleteLocal:
          await folder.applyRemoteDelete(decision.entry);
        case ShareDecisionKind.pull:
          meta[decision.path] = decision.entry;
          if (!queue.contains(decision.path) &&
              _incoming[deviceId]?.path != decision.path) {
            queue.add(decision.path);
          }
      }
    }

    final peer = _peers[deviceId];
    if (peer != null) {
      peer
        ..pendingIn = queue.length
        ..pendingOut = _countPeerIsMissing(safe)
        ..lastSyncedAt = DateTime.now();
    }

    _drainPulls(deviceId);
    _notify();
  }

  /// How many of our live files the peer's index doesn't have or is older
  /// on — what it is about to pull from us.
  int _countPeerIsMissing(List<SharedFileEntry> theirs) {
    final byPath = {for (final e in theirs) e.path: e};
    var count = 0;
    for (final ours in folder.index.values) {
      if (ours.isDeleted) continue;
      final theirEntry = byPath[ours.path];
      if (theirEntry == null || ours.stamp > theirEntry.stamp) count++;
    }
    return count;
  }

  @override
  void onPeerShareError(String deviceId, String path, String reason) {
    final transfer = _incoming[deviceId];
    if (transfer != null && transfer.path == path) {
      transfer
        ..error = reason
        ..finished = true;
      _finishIncoming(deviceId, transfer);
    }
    _pullQueues[deviceId]?.remove(path);
    unawaited(folder.discardStaged(path));
    _drainPulls(deviceId);
    _notify();
  }

  // -------------------------------------------------------- delegate: pull

  void _drainPulls(String deviceId) {
    if (_disposed) return;
    final channel = _channels[deviceId];
    if (channel == null) return;
    if (_incoming.containsKey(deviceId)) return; // one file at a time
    final queue = _pullQueues[deviceId];
    if (queue == null || queue.isEmpty) return;

    final path = queue.removeFirst();
    final entry = _pullMeta[deviceId]?[path];
    if (entry == null) {
      _drainPulls(deviceId);
      return;
    }

    _incoming[deviceId] = ShareTransfer(
      path: path,
      deviceId: deviceId,
      deviceName: _peers[deviceId]?.deviceName ?? deviceId,
      direction: ShareDirection.incoming,
      totalBytes: entry.size,
    );
    _peers[deviceId]?.pendingIn = queue.length;

    unawaited(_requestWithResume(channel, deviceId, path, entry));
  }

  Future<void> _requestWithResume(
    PeerShareChannel channel,
    String deviceId,
    String path,
    SharedFileEntry entry,
  ) async {
    var offset = 0;
    try {
      final staged = await folder.stagingFileFor(path);
      if (await staged.exists()) {
        // Only resume into a partial we know belongs to this exact version
        // of the file; otherwise the two halves would come from different
        // content and the hash check at the end would fail anyway.
        if (_stagedFor[path] == entry.hash) {
          offset = await staged.length();
          if (offset > entry.size) offset = 0;
        } else {
          await staged.delete();
        }
      }
    } catch (_) {
      offset = 0;
    }
    if (offset == 0) _stagedFor[path] = entry.hash;
    final transfer = _incoming[deviceId];
    if (transfer != null) transfer.bytesDone = offset;
    channel.requestShareFile(path, from: offset);
    _notify();
  }

  /// Which file version each staged partial belongs to, so a resume can't
  /// splice two different versions together.
  final Map<String, String> _stagedFor = {};

  @override
  Future<void> onPeerChunk(
    String deviceId,
    SharedChunkHeader header,
    Uint8List bytes,
  ) {
    // Chunks arrive without the read loop awaiting us, so they are chained
    // here rather than run concurrently — two writes into one handle would
    // otherwise interleave.
    final chain = (_chunkChains[deviceId] ?? Future<void>.value())
        .then((_) => _writeChunk(deviceId, header, bytes))
        .catchError((Object e) {
      _failIncoming(deviceId, '$e');
    });
    _chunkChains[deviceId] = chain;
    return chain;
  }

  Future<void> _writeChunk(
    String deviceId,
    SharedChunkHeader header,
    Uint8List bytes,
  ) async {
    if (_disposed) return;
    final path = normalizeSharePath(header.path);
    final transfer = _incoming[deviceId];
    if (path == null || transfer == null || transfer.path != path) {
      // A chunk for something we are not fetching — a stale reply from
      // before a disconnect. Dropping it is correct; the file is either
      // already here or still queued.
      return;
    }

    final staged = await folder.stagingFileFor(path);
    var handle = _incomingHandles[deviceId];
    if (handle == null) {
      if (header.offset == 0 && await staged.exists()) await staged.delete();
      handle = await staged.open(mode: FileMode.writeOnlyAppend);
      _incomingHandles[deviceId] = handle;
    }

    final length = await handle.length();
    if (header.offset != length) {
      // The sender and this partial disagree about where we are. Start over
      // rather than write bytes at the wrong offset.
      await _closeIncomingHandle(deviceId);
      await staged.delete().catchError((_) => staged);
      _stagedFor.remove(path);
      _failIncoming(deviceId, 'Transfer got out of step; it will start again.');
      return;
    }

    await handle.writeFrom(bytes);
    transfer.bytesDone = header.offset + bytes.length;
    _notify();

    if (!header.isLast) return;

    await _closeIncomingHandle(deviceId);
    final actualHash = await SharedFolder.hashOf(staged);
    if (header.hash.isNotEmpty && actualHash != header.hash) {
      await staged.delete().catchError((_) => staged);
      _stagedFor.remove(path);
      _failIncoming(
        deviceId,
        'The copy that arrived did not match the original; it will be '
        'fetched again.',
      );
      return;
    }

    await folder.commitStaged(
      staged,
      path,
      hash: actualHash,
      modifiedMs: header.modifiedMs,
    );
    _stagedFor.remove(path);
    transfer.finished = true;
    _finishIncoming(deviceId, transfer);
    _peers[deviceId]?.lastSyncedAt = DateTime.now();

    // Everyone else should hear about the new file too.
    broadcastIndex();
    _drainPulls(deviceId);
    _notify();
  }

  void _failIncoming(String deviceId, String message) {
    final transfer = _incoming[deviceId];
    if (transfer != null) {
      transfer
        ..error = message
        ..finished = true;
      _finishIncoming(deviceId, transfer);
    }
    _peers[deviceId]?.error = message;
    _drainPulls(deviceId);
    _notify();
  }

  void _finishIncoming(String deviceId, ShareTransfer transfer) {
    _incoming.remove(deviceId);
    _remember(transfer);
  }

  Future<void> _closeIncomingHandle(String deviceId) async {
    final handle = _incomingHandles.remove(deviceId);
    if (handle == null) return;
    try {
      await handle.close();
    } catch (_) {
      // Already gone.
    }
  }

  // -------------------------------------------------------- delegate: serve

  @override
  void onPeerRequest(String deviceId, String path, int from) {
    final normalized = normalizeSharePath(path);
    if (normalized == null) return;
    _serveQueues
        .putIfAbsent(deviceId, Queue<({String path, int from})>.new)
        .add((path: normalized, from: from));
    unawaited(_drainServes(deviceId));
  }

  Future<void> _drainServes(String deviceId) async {
    if (_outgoing.containsKey(deviceId)) return; // one at a time
    final queue = _serveQueues[deviceId];
    if (queue == null || queue.isEmpty) return;
    final job = queue.removeFirst();

    final channel = _channels[deviceId];
    if (channel == null) return;

    final entry = folder.entryFor(job.path);
    final file = folder.fileFor(job.path);
    if (entry == null || entry.isDeleted || !await file.exists()) {
      channel.sendShareUnavailable(job.path, 'No longer in the shared folder.');
      unawaited(_drainServes(deviceId));
      return;
    }

    final transfer = ShareTransfer(
      path: job.path,
      deviceId: deviceId,
      deviceName: _peers[deviceId]?.deviceName ?? deviceId,
      direction: ShareDirection.outgoing,
      totalBytes: entry.size,
    )..bytesDone = job.from;
    _outgoing[deviceId] = transfer;
    _notify();

    try {
      await _sendFile(channel, file, entry, job.from, transfer, deviceId);
      transfer.finished = true;
    } catch (e) {
      transfer
        ..error = '$e'
        ..finished = true;
      channel.sendShareUnavailable(job.path, 'Could not read the file.');
    }

    _outgoing.remove(deviceId);
    _remember(transfer);
    _notify();
    unawaited(_drainServes(deviceId));
  }

  Future<void> _sendFile(
    PeerShareChannel channel,
    File file,
    SharedFileEntry entry,
    int from,
    ShareTransfer transfer,
    String deviceId,
  ) async {
    final total = await file.length();
    final handle = await file.open();
    try {
      var offset = from < 0 || from > total ? 0 : from;
      await handle.setPosition(offset);

      // An empty file has no chunks to loop over, so it is served as a
      // single zero-length last chunk: the header alone tells the receiver
      // to commit the (empty) staging file.
      if (total == 0) {
        await channel.sendShareChunk(
          SharedChunkHeader(
            path: entry.path,
            offset: 0,
            length: 0,
            totalSize: 0,
            modifiedMs: entry.modifiedMs,
            hash: entry.hash,
            isLast: true,
          ),
          Uint8List(0),
        );
        transfer.bytesDone = 0;
        return;
      }

      while (offset < total) {
        if (_disposed || !_channels.containsKey(deviceId)) {
          throw const FileSystemException('The device went away.');
        }
        final take = (total - offset) < kShareChunkBytes
            ? total - offset
            : kShareChunkBytes;
        final bytes = await handle.read(take);
        if (bytes.isEmpty) break;
        final isLast = offset + bytes.length >= total;
        await channel.sendShareChunk(
          SharedChunkHeader(
            path: entry.path,
            offset: offset,
            length: bytes.length,
            totalSize: total,
            modifiedMs: entry.modifiedMs,
            hash: entry.hash,
            isLast: isLast,
          ),
          bytes,
        );
        offset += bytes.length;
        transfer.bytesDone = offset;
        _notify();
      }
    } finally {
      await handle.close();
    }
  }

  // ------------------------------------------------------------- plumbing

  void _remember(ShareTransfer transfer) {
    _history.insert(0, transfer);
    if (_history.length > 50) _history.removeRange(50, _history.length);
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  /// Human-readable summary of the folder for the header.
  String get summary {
    final count = folder.files.length;
    final size = folder.totalBytes;
    return '$count ${count == 1 ? 'file' : 'files'} · ${_formatBytes(size)}';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB', 'TB'];
    var value = bytes / 1024;
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} ${units[unit]}';
  }

  @override
  void dispose() {
    _disposed = true;
    _rescanDebounce?.cancel();
    _rescanTimer?.cancel();
    unawaited(_watch?.cancel());
    for (final deviceId in _incomingHandles.keys.toList()) {
      unawaited(_closeIncomingHandle(deviceId));
    }
    super.dispose();
  }
}

/// Debug helper: the index as pretty JSON. Handy when a device disagrees
/// with another about what the folder holds.
String debugDumpIndex(SharedFolder folder) => const JsonEncoder.withIndent('  ')
    .convert({'entries': [for (final e in folder.advertisement) e.toJson()]});
