import 'dart:convert';
import 'dart:typed_data';

/// Wire protocol for luma peer-to-peer sync.
///
/// Every unit on the wire is a length-prefixed frame:
///
///     [ 4-byte big-endian length ][ payload bytes ]
///
/// A payload is either a JSON control message (always decodes to a
/// `Map<String, dynamic>` with a `type` field) or — for a `blob` frame — the
/// raw sealed snapshot bytes that follow the `blob` control message that
/// announced them. See [PeerLink] for the read state machine.
///
/// Control messages share a small, fixed vocabulary so unknown keys can be
/// ignored gracefully (forward compatibility).

/// The mDNS service type luma devices advertise and browse for.
const String kLumaPeerServiceType = '_luma-sync._tcp';

/// Maximum frame size (8 MiB). Sealed snapshots are gzip-compressed; this is
/// plenty for the largest collection (the password vault, finance DB, etc.)
/// while still bounding a hostile or buggy peer's memory blow-up.
const int kMaxFrameBytes = 8 * 1024 * 1024;

/// How much of a shared file travels in one `share-chunk` frame. Small
/// enough that progress moves visibly and neither side buffers much, large
/// enough that a big file isn't thousands of round trips. Must stay well
/// under [kMaxFrameBytes].
const int kShareChunkBytes = 256 * 1024;

/// One file in the shared folder, as advertised in a `share-index`.
///
/// A tombstone (`deletedAtMs != null`) is how a delete travels: the entry
/// stays in the index with no bytes behind it, so a device that was offline
/// when the file was deleted removes its copy instead of pushing it back.
class SharedFileEntry {
  const SharedFileEntry({
    required this.path,
    required this.size,
    required this.hash,
    required this.modifiedMs,
    this.deletedAtMs,
  });

  /// Path relative to the shared folder root, always '/'-separated so the
  /// same file has the same identity on Windows and Android.
  final String path;

  final int size;

  /// SHA-256 of the contents, hex. Empty for a tombstone.
  final String hash;

  /// Local modification time when this device last wrote the file.
  final int modifiedMs;

  /// When the file was deleted, or null while it exists.
  final int? deletedAtMs;

  bool get isDeleted => deletedAtMs != null;

  /// The moment this entry describes — the delete for a tombstone, the write
  /// otherwise. Merging compares these, so a delete can beat an older write
  /// and a newer write can beat an older delete.
  int get stamp => deletedAtMs ?? modifiedMs;

  SharedFileEntry asDeleted(int deletedAtMs) => SharedFileEntry(
        path: path,
        size: 0,
        hash: '',
        modifiedMs: modifiedMs,
        deletedAtMs: deletedAtMs,
      );

  Map<String, Object?> toJson() => {
        'p': path,
        's': size,
        'h': hash,
        'm': modifiedMs,
        if (deletedAtMs != null) 'd': deletedAtMs,
      };

  static SharedFileEntry? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final path = raw['p'] as String?;
    if (path == null || path.isEmpty) return null;
    return SharedFileEntry(
      path: path,
      size: (raw['s'] as num?)?.toInt() ?? 0,
      hash: raw['h'] as String? ?? '',
      modifiedMs: (raw['m'] as num?)?.toInt() ?? 0,
      deletedAtMs: (raw['d'] as num?)?.toInt(),
    );
  }
}

/// The header that precedes a chunk's raw bytes on the wire.
class SharedChunkHeader {
  const SharedChunkHeader({
    required this.path,
    required this.offset,
    required this.length,
    required this.totalSize,
    required this.modifiedMs,
    required this.hash,
    required this.isLast,
  });

  final String path;
  final int offset;
  final int length;
  final int totalSize;
  final int modifiedMs;

  /// SHA-256 of the whole file, so the receiver can verify what it assembled
  /// before putting it in the folder.
  final String hash;
  final bool isLast;

  Map<String, Object?> toJson() => {
        'type': 'share-chunk',
        'path': path,
        'offset': offset,
        'length': length,
        'total': totalSize,
        'modifiedMs': modifiedMs,
        'hash': hash,
        'last': isLast,
      };

  static SharedChunkHeader? fromJson(Map<String, dynamic> j) {
    final path = j['path'] as String?;
    final length = (j['length'] as num?)?.toInt();
    if (path == null || path.isEmpty || length == null) return null;
    // Zero is legal and means "an empty file": the header alone completes
    // the transfer, with no raw bytes behind it.
    if (length < 0 || length > kMaxFrameBytes) return null;
    return SharedChunkHeader(
      path: path,
      offset: (j['offset'] as num?)?.toInt() ?? 0,
      length: length,
      totalSize: (j['total'] as num?)?.toInt() ?? 0,
      modifiedMs: (j['modifiedMs'] as num?)?.toInt() ?? 0,
      hash: j['hash'] as String? ?? '',
      isLast: j['last'] == true,
    );
  }
}

/// Per-collection state advertised in `hello`/`welcome`.
///
/// - [cloudVersion] is the last server version this device agrees it has seen
///   (0 if never cloud-synced). Both devices comparing this can tell whether
///   they are based on the same cloud snapshot.
/// - [savedAtMs] is the local edit timestamp driving newest-edit-wins.
class PeerCollectionState {
  const PeerCollectionState({
    required this.cloudVersion,
    required this.savedAtMs,
  });

  final int cloudVersion;
  final int savedAtMs;

  Map<String, Object?> toJson() => {
        'v': cloudVersion,
        't': savedAtMs,
      };

  static PeerCollectionState fromJson(Object? raw) {
    final j = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    return PeerCollectionState(
      cloudVersion: j['v'] as int? ?? 0,
      savedAtMs: j['t'] as int? ?? 0,
    );
  }
}

/// Identity + proof exchanged during the handshake.
class PeerHello {
  const PeerHello({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.token,
    required this.collections,
  });

  /// Stable random id for this device (so two devices can recognize each
  /// other across reconnects and dedupe in the UI).
  final String deviceId;

  /// Human label shown in the UI ("Pixel 7", "Office laptop").
  final String deviceName;

  /// "android" / "windows" / etc. — informational only.
  final String platform;

  /// HMAC of the account encryption key. Must match locally or the peer is
  /// dropped before any payload is exchanged.
  final String token;

  /// The peer's currently enabled collections + their state.
  final Map<String, PeerCollectionState> collections;

  Map<String, Object?> toJson() => {
        'type': 'hello',
        'deviceId': deviceId,
        'name': deviceName,
        'platform': platform,
        'token': token,
        'collections': collections.map((k, v) => MapEntry(k, v.toJson())),
      };

  static PeerHello fromJson(Map<String, dynamic> j) {
    final cols = <String, PeerCollectionState>{};
    final raw = j['collections'];
    if (raw is Map<String, dynamic>) {
      raw.forEach((id, v) => cols[id] = PeerCollectionState.fromJson(v));
    }
    return PeerHello(
      deviceId: j['deviceId'] as String? ?? '',
      deviceName: j['name'] as String? ?? 'Unknown device',
      platform: j['platform'] as String? ?? '',
      token: j['token'] as String? ?? '',
      collections: cols,
    );
  }
}

/// Encode a JSON control message as a length-prefixed frame.
Uint8List encodeFrame(Map<String, Object?> message) {
  final payload = Uint8List.fromList(utf8.encode(jsonEncode(message)));
  final out = Uint8List(payload.length + 4);
  out.buffer.asByteData().setUint32(0, payload.length, Endian.big);
  out.setRange(4, 4 + payload.length, payload);
  return out;
}

/// Read a single length-prefixed frame from [pending] (bytes already
/// received but not yet consumed). Returns:
///  - `(payload, consumed)` when a complete frame is available.
///  - `null` if more bytes are needed.
/// Throws [PeerProtocolException] on an oversize or empty frame.
({Uint8List payload, int consumed})? decodeFrame(Uint8List pending) {
  if (pending.length < 4) return null;
  // `pending` is very often itself a view (Uint8List.sublistView) into a
  // larger buffer shared with earlier-consumed frames — that's the whole
  // point of the read loop reslicing it after each frame. `pending.buffer`
  // returns that SHARED underlying buffer, so `pending.buffer.asByteData()`
  // (no offset) reads from the buffer's absolute start, NOT from `pending`'s
  // own logical start. When two different-length frames arrive in one
  // chunk, this silently re-read the FIRST frame's length for every frame
  // after it. `ByteData.sublistView` correctly accounts for `pending`'s own
  // offsetInBytes.
  final length = ByteData.sublistView(pending, 0, 4).getUint32(0, Endian.big);
  if (length == 0 || length > kMaxFrameBytes) {
    throw PeerProtocolException('Invalid frame length: $length');
  }
  if (pending.length < 4 + length) return null;
  final payload = Uint8List.sublistView(pending, 4, 4 + length);
  return (payload: payload, consumed: 4 + length);
}

class PeerProtocolException implements Exception {
  const PeerProtocolException(this.message);
  final String message;

  @override
  String toString() => message;
}
