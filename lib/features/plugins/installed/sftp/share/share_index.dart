import '../../../../../p2p/peer_protocol.dart';

/// What this device has to do about one path after comparing indexes.
enum ShareDecisionKind {
  /// The peer's copy is newer — fetch its bytes.
  pull,

  /// The peer deleted it more recently than our copy was written — remove
  /// ours and remember the tombstone.
  deleteLocal,

  /// A tombstone for something we never had. Worth recording anyway: with
  /// three or more devices, this device is how the delete reaches the one
  /// that still holds the file.
  adoptTombstone,
}

/// One path's outcome from [planShareSync].
class ShareDecision {
  const ShareDecision(this.kind, this.entry);

  final ShareDecisionKind kind;

  /// The peer's entry that justified the decision.
  final SharedFileEntry entry;

  String get path => entry.path;

  @override
  String toString() => '${kind.name}(${entry.path})';
}

/// Works out what to do with a peer's index, given ours.
///
/// Deliberately **pull-only**: it never returns "push". Both devices run this
/// against the same pair of indexes, so whichever one is behind fetches from
/// the other. Nothing has to agree on who sends — each side just fetches what
/// it lacks, which means a file crosses the wire once, in one direction, with
/// no coordination and no duplicate transfer when both sides connect at once.
///
/// [ours] maps path → our entry, tombstones included. Anything we hold that
/// the peer lacks produces no decision here; the peer's own run of this
/// function will pull it from us.
List<ShareDecision> planShareSync({
  required Map<String, SharedFileEntry> ours,
  required Iterable<SharedFileEntry> theirs,
}) {
  final decisions = <ShareDecision>[];

  for (final remote in theirs) {
    final local = ours[remote.path];

    if (local == null) {
      decisions.add(
        ShareDecision(
          remote.isDeleted
              ? ShareDecisionKind.adoptTombstone
              : ShareDecisionKind.pull,
          remote,
        ),
      );
      continue;
    }

    if (remote.stamp > local.stamp) {
      decisions.add(
        ShareDecision(
          remote.isDeleted
              ? ShareDecisionKind.deleteLocal
              : ShareDecisionKind.pull,
          remote,
        ),
      );
      continue;
    }

    if (remote.stamp == local.stamp &&
        !remote.isDeleted &&
        !local.isDeleted &&
        remote.hash != local.hash &&
        remote.hash.isNotEmpty &&
        local.hash.isNotEmpty) {
      // Same instant, different bytes — two devices wrote the same path
      // while apart. Somebody has to lose, and both ends must pick the same
      // loser or they would swap copies forever, so the higher hash wins.
      // It is arbitrary, but it is arbitrary in the same direction on both
      // devices, which is the only property that matters.
      if (remote.hash.compareTo(local.hash) > 0) {
        decisions.add(ShareDecision(ShareDecisionKind.pull, remote));
      }
    }
  }

  return decisions;
}

/// Drops tombstones old enough that every device has certainly seen them.
///
/// Without this the index grows forever. The window has to be generous: prune
/// a tombstone before a device that has been off all that time reconnects,
/// and that device pushes the deleted file back to everyone.
Map<String, SharedFileEntry> pruneTombstones(
  Map<String, SharedFileEntry> index, {
  required int nowMs,
  Duration keepFor = const Duration(days: 90),
}) {
  final cutoff = nowMs - keepFor.inMilliseconds;
  return {
    for (final entry in index.entries)
      if (!(entry.value.isDeleted && entry.value.deletedAtMs! < cutoff))
        entry.key: entry.value,
  };
}

/// Normalizes a path to the form used as a file's identity in the index:
/// '/'-separated, no leading or trailing separator, no '.' or '..' segments,
/// and no drive letters — so the same file has the same key on Windows and
/// Android, and a hostile peer can't name a path outside the folder.
///
/// Returns null when nothing usable survives, which the caller must treat as
/// "reject this entry" rather than as an empty path.
String? normalizeSharePath(String raw) {
  final segments = raw
      .replaceAll('\\', '/')
      .split('/')
      .where((s) => s.isNotEmpty && s != '.' && s != '..')
      .where((s) => !s.contains(':'))
      .toList();
  if (segments.isEmpty) return null;
  return segments.join('/');
}
