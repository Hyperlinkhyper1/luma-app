import 'dart:typed_data';

import 'peer_protocol.dart';

/// The send side of the shared folder, as the mirror sees it. [PeerLink]
/// implements this, so the mirror never touches a socket and can be driven
/// by a fake in tests.
abstract class PeerShareChannel {
  /// Advertise everything in our shared folder, tombstones included.
  void sendShareIndex(List<SharedFileEntry> entries);

  /// Ask for the bytes of one file the peer advertised, resuming at [from].
  void requestShareFile(String path, {int from = 0});

  /// Serve one chunk. The future completes when the bytes are on the wire,
  /// which is what paces a large file against a slow link.
  Future<void> sendShareChunk(SharedChunkHeader header, Uint8List bytes);

  /// Decline a request — the file was deleted or can't be read.
  void sendShareUnavailable(String path, String reason);
}

/// What [PeerSyncController] hands the shared-folder mirror: one call per
/// thing a peer can do to us, always tagged with which device did it.
///
/// This is the only seam between P2P transport and the SFTP plugin's shared
/// folder. The controller knows nothing about files, and the mirror knows
/// nothing about sockets, mDNS or handshakes.
abstract class PeerShareDelegate {
  /// A peer finished its handshake. [channel] stays valid until
  /// [onPeerGone] fires for the same device.
  void onPeerAvailable(
    String deviceId,
    String deviceName,
    PeerShareChannel channel,
  );

  /// The link to [deviceId] ended. Anything in flight to or from it should
  /// be parked, not failed — the device usually comes back.
  void onPeerGone(String deviceId);

  /// A peer told us what its shared folder holds.
  void onPeerIndex(String deviceId, List<SharedFileEntry> entries);

  /// A peer wants the bytes of [path] from our folder, starting at [from].
  void onPeerRequest(String deviceId, String path, int from);

  /// One chunk of a file we asked for.
  Future<void> onPeerChunk(
    String deviceId,
    SharedChunkHeader header,
    Uint8List bytes,
  );

  /// A peer can't serve a file it advertised.
  void onPeerShareError(String deviceId, String path, String reason);
}
