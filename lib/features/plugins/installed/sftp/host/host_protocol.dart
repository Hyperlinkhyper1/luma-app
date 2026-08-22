/// The wire format spoken between a luma device that is hosting its files
/// (`SftpHostServer`) and a luma device browsing them (`LumaHostSession`).
///
/// It is *not* SSH. dartssh2 is a client-only library — it has no server-side
/// key exchange, user authentication, channel layer or SFTP subsystem — so
/// hosting over real SSH would mean writing an SSH-2 server from scratch.
/// What is here instead is a much smaller protocol that does the same job for
/// luma-to-luma transfers, with the security properties written down in
/// [host_crypto.dart]: an authenticated key exchange bound to the host's
/// pairing password, then AES-256-GCM on every byte that follows.
///
/// ## Framing
///
/// Every frame is a 4-byte big-endian length followed by that many bytes.
/// During the handshake those bytes are plaintext JSON (they carry nothing
/// but public ephemeral keys, a salt, and proofs). Afterwards every frame
/// body is an AES-GCM sealed record; see [HostSecureChannel].
///
/// A decrypted record is one byte of [HostFrameKind] followed by its body:
///
/// * [HostFrameKind.control] — UTF-8 JSON, a request or a reply.
/// * [HostFrameKind.chunk]   — a 4-byte big-endian request id, then raw file
///   bytes. Used in both directions: the host streams them for a download,
///   the client streams them for an upload.
library;

import 'dart:convert';
import 'dart:typed_data';

/// Bumped when a change would make two versions misunderstand each other.
/// The host refuses a client that does not match.
const int kHostProtocolVersion = 1;

/// The port the host listens on unless the user picks another.
const int kDefaultHostPort = 7420;

/// Bytes of file content per [HostFrameKind.chunk] frame. Large enough that
/// the per-frame overhead disappears, small enough that progress moves
/// visibly and a cancel is acted on promptly.
const int kHostChunkBytes = 256 * 1024;

/// Hard ceiling on a single frame. A peer that announces more than this is
/// dropped without allocating for it, so a hostile or broken sender cannot
/// make this device reserve arbitrary memory.
const int kMaxHostFrameBytes = kHostChunkBytes + 64 * 1024;

/// How long a connection may sit in the handshake before it is dropped.
const Duration kHostHandshakeTimeout = Duration(seconds: 15);

enum HostFrameKind {
  control(0x01),
  chunk(0x02);

  const HostFrameKind(this.id);

  final int id;

  static HostFrameKind? fromId(int id) {
    for (final kind in HostFrameKind.values) {
      if (kind.id == id) return kind;
    }
    return null;
  }
}

/// Every operation a browsing device may ask the host to perform.
///
/// The set is deliberately closed: [HostOp.parse] returns null for anything
/// else, and the host answers an unknown op with an error rather than
/// guessing. Nothing here can execute a command, open a shell, or reach
/// outside the shared folder.
enum HostOp {
  list('ls'),
  stat('stat'),
  makeDirectory('mkdir'),
  rename('mv'),
  removeFile('rm'),
  removeDirectory('rmdir'),
  chmod('chmod'),
  readOpen('read'),
  readStop('readstop'),
  writeOpen('wopen'),
  writeClose('wclose');

  const HostOp(this.wire);

  final String wire;

  static HostOp? parse(String? wire) {
    for (final op in HostOp.values) {
      if (op.wire == wire) return op;
    }
    return null;
  }
}

/// Server-pushed events that belong to a request rather than answering it:
/// the end of a download stream, or the reason one stopped early.
const String kEventEof = 'eof';
const String kEventError = 'err';

/// One directory entry as it travels over the wire. Field names are short
/// because a large directory sends thousands of them.
class HostEntry {
  const HostEntry({
    required this.name,
    required this.isDirectory,
    this.isLink = false,
    this.size = 0,
    this.modifiedMs,
    this.mode,
  });

  final String name;
  final bool isDirectory;
  final bool isLink;
  final int size;
  final int? modifiedMs;
  final int? mode;

  Map<String, dynamic> toJson() => {
        'n': name,
        'd': isDirectory,
        if (isLink) 'l': true,
        's': size,
        if (modifiedMs != null) 'm': modifiedMs,
        if (mode != null) 'o': mode,
      };

  static HostEntry fromJson(Map<String, dynamic> json) => HostEntry(
        name: json['n']?.toString() ?? '',
        isDirectory: json['d'] == true,
        isLink: json['l'] == true,
        size: (json['s'] as num?)?.toInt() ?? 0,
        modifiedMs: (json['m'] as num?)?.toInt(),
        mode: (json['o'] as num?)?.toInt(),
      );
}

/// Anything the protocol layer rejects: a malformed frame, a version
/// mismatch, a body that is not the shape its op requires.
class HostProtocolException implements Exception {
  const HostProtocolException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Builds the framed bytes for one control message.
Uint8List encodeControlFrame(Map<String, dynamic> message) {
  final json = utf8.encode(jsonEncode(message));
  final out = Uint8List(1 + json.length);
  out[0] = HostFrameKind.control.id;
  out.setAll(1, json);
  return out;
}

/// Builds the framed bytes for one slice of file content.
Uint8List encodeChunkFrame(int requestId, List<int> bytes) {
  final out = Uint8List(5 + bytes.length);
  out[0] = HostFrameKind.chunk.id;
  _writeUint32(out, 1, requestId);
  out.setAll(5, bytes);
  return out;
}

/// One decoded record: exactly one of [control] or [chunk] is set.
class HostFrame {
  const HostFrame.control(Map<String, dynamic> this.control)
      : chunkId = null,
        chunk = null;

  const HostFrame.chunk(int this.chunkId, Uint8List this.chunk)
      : control = null;

  final Map<String, dynamic>? control;
  final int? chunkId;
  final Uint8List? chunk;

  bool get isControl => control != null;
}

/// Reverses [encodeControlFrame] / [encodeChunkFrame].
///
/// Throws [HostProtocolException] rather than returning null so a caller
/// cannot forget to check: every failure here means the peer sent something
/// it should not have, and the connection is torn down.
HostFrame decodeFrame(Uint8List body) {
  if (body.isEmpty) {
    throw const HostProtocolException('Empty frame.');
  }
  final kind = HostFrameKind.fromId(body[0]);
  switch (kind) {
    case HostFrameKind.control:
      final Object? decoded;
      try {
        decoded = jsonDecode(utf8.decode(body.sublist(1)));
      } catch (_) {
        throw const HostProtocolException('Control frame was not valid JSON.');
      }
      if (decoded is! Map<String, dynamic>) {
        throw const HostProtocolException('Control frame was not an object.');
      }
      return HostFrame.control(decoded);
    case HostFrameKind.chunk:
      if (body.length < 5) {
        throw const HostProtocolException('Truncated chunk frame.');
      }
      return HostFrame.chunk(
        _readUint32(body, 1),
        Uint8List.sublistView(body, 5),
      );
    case null:
      throw HostProtocolException('Unknown frame kind 0x${body[0].toRadixString(16)}.');
  }
}

/// A request the client sends and expects one reply to.
Map<String, dynamic> hostRequest(
  int id,
  HostOp op, [
  Map<String, dynamic> fields = const {},
]) =>
    {'i': id, 'op': op.wire, ...fields};

/// The success reply to request [id].
Map<String, dynamic> hostOk(int id, [Map<String, dynamic> fields = const {}]) =>
    {'i': id, 'ok': true, ...fields};

/// The failure reply to request [id]. [message] is shown to the person at the
/// other end, so it says what happened without naming absolute paths on this
/// machine.
Map<String, dynamic> hostError(int id, String message) =>
    {'i': id, 'ok': false, 'e': message};

/// A push that belongs to request [id] but is not its reply.
Map<String, dynamic> hostEvent(int id, String event, [String? message]) =>
    {'i': id, 'ev': event, 'e': ?message};

void _writeUint32(Uint8List out, int offset, int value) {
  out[offset] = (value >> 24) & 0xff;
  out[offset + 1] = (value >> 16) & 0xff;
  out[offset + 2] = (value >> 8) & 0xff;
  out[offset + 3] = value & 0xff;
}

int _readUint32(Uint8List bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];

/// Splits a byte stream into length-prefixed frames.
///
/// Kept separate from the socket so the framing can be tested directly, and
/// so both ends use exactly the same reader. It refuses a frame larger than
/// [kMaxHostFrameBytes] before allocating anything for it.
class HostFrameReader {
  final _buffer = BytesBuilder(copy: false);
  Uint8List _pending = Uint8List(0);

  /// Feeds [data] in and returns every complete frame it completed.
  List<Uint8List> add(List<int> data) {
    _buffer.add(data);
    if (_buffer.isNotEmpty) {
      final merged = Uint8List(_pending.length + _buffer.length)
        ..setAll(0, _pending)
        ..setAll(_pending.length, _buffer.takeBytes());
      _pending = merged;
    }

    final frames = <Uint8List>[];
    var offset = 0;
    while (_pending.length - offset >= 4) {
      final length = _readUint32(_pending, offset);
      if (length < 0 || length > kMaxHostFrameBytes) {
        throw HostProtocolException(
          'Frame of $length bytes is larger than this connection allows.',
        );
      }
      if (_pending.length - offset - 4 < length) break;
      frames.add(Uint8List.sublistView(_pending, offset + 4, offset + 4 + length));
      offset += 4 + length;
    }
    if (offset > 0) {
      _pending = Uint8List.fromList(Uint8List.sublistView(_pending, offset));
    }
    return frames;
  }
}

/// Prefixes [body] with its length, ready for the socket.
Uint8List frameBytes(Uint8List body) {
  final out = Uint8List(4 + body.length);
  _writeUint32(out, 0, body.length);
  out.setAll(4, body);
  return out;
}
