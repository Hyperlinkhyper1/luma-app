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
  final length =
      pending.buffer.asByteData().getUint32(0, Endian.big);
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
