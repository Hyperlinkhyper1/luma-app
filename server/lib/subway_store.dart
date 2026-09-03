import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'util.dart';

/// A persistent Subway Builder co-op room. The server never simulates the
/// game — it only holds membership (who's allowed in) and the last full
/// state snapshot any member pushed, so a room stays joinable without its
/// creator's client needing to be online. Live play still happens over the
/// [SubwayRelay] WebSocket; this is what makes rejoining/late-joining work.
class SubwayRoom {
  SubwayRoom({
    required this.code,
    required this.ownerId,
    required this.createdAtMs,
    required this.memberIds,
    this.updatedAtMs,
    this.stateVersion = 0,
    this.clockHolderId,
    this.clockLeaseExpiresAtMs,
  });

  final String code;
  final String ownerId;
  final int createdAtMs;

  /// Everyone allowed to join, including the owner. A userId lands here
  /// either via an explicit chat-contact invite or by presenting the room
  /// code to the join endpoint — both are "invited", just through different
  /// channels; there is no public room listing or discovery.
  final Set<String> memberIds;

  int? updatedAtMs;
  int stateVersion;

  /// Whoever currently owns the "run the world clock" lease for this room
  /// (see Api._claimSubwayClock) — floats to whichever connected member
  /// grabbed it first, so no single player's client has to stay online for
  /// the room to remain playable by everyone else. Null / expired lease
  /// means the room is effectively paused until someone claims it again.
  String? clockHolderId;
  int? clockLeaseExpiresAtMs;

  bool isMember(String userId) => memberIds.contains(userId);

  Map<String, dynamic> toJson() => {
        'code': code,
        'ownerId': ownerId,
        'createdAtMs': createdAtMs,
        'memberIds': memberIds.toList(),
        'updatedAtMs': updatedAtMs,
        'stateVersion': stateVersion,
        'clockHolderId': clockHolderId,
        'clockLeaseExpiresAtMs': clockLeaseExpiresAtMs,
      };

  factory SubwayRoom.fromJson(Map<String, dynamic> j) => SubwayRoom(
        code: j['code'] as String,
        ownerId: j['ownerId'] as String,
        createdAtMs: j['createdAtMs'] as int,
        memberIds: {
          ...(j['memberIds'] as List).map((e) => e as String),
        },
        updatedAtMs: j['updatedAtMs'] as int?,
        stateVersion: j['stateVersion'] as int? ?? 0,
        clockHolderId: j['clockHolderId'] as String?,
        clockLeaseExpiresAtMs: j['clockLeaseExpiresAtMs'] as int?,
      );
}

/// File-backed store for co-op rooms, mirroring the conventions in
/// store.dart/chat_store.dart. Room metadata lives in one JSON file; each
/// room's (usually small, but unbounded in principle) game-state snapshot
/// gets its own file under `subway_state/`, same reasoning as Store keeping
/// blobs separate from `collections.json`.
class SubwayStore {
  SubwayStore._(this.rootPath);

  final String rootPath;
  final Map<String, SubwayRoom> roomsByCode = {};

  static const _codeChars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // no 0/O/1/I/L
  static const codeLength = 6;

  String get _roomsFile => '$rootPath/subway_rooms.json';
  String _stateFile(String code) => '$rootPath/subway_state/$code.json';

  static Future<SubwayStore> open(String path) async {
    final store = SubwayStore._(path);
    await Directory('$path/subway_state').create(recursive: true);
    for (final r in await _readJsonList(store._roomsFile)) {
      final room = SubwayRoom.fromJson(r as Map<String, dynamic>);
      store.roomsByCode[room.code] = room;
    }
    return store;
  }

  static Future<List<dynamic>> _readJsonList(String path) async {
    final file = File(path);
    if (!await file.exists()) return const [];
    final decoded = jsonDecode(await file.readAsString());
    return decoded is List ? decoded : const [];
  }

  Future<void> saveRooms() => atomicWriteString(_roomsFile,
      jsonEncode(roomsByCode.values.map((r) => r.toJson()).toList()));

  String newRoomCode() {
    final rng = Random.secure();
    String gen() => List.generate(
        codeLength, (_) => _codeChars[rng.nextInt(_codeChars.length)]).join();
    var code = gen();
    while (roomsByCode.containsKey(code)) {
      code = gen();
    }
    return code;
  }

  List<SubwayRoom> roomsForUser(String userId) =>
      roomsByCode.values.where((r) => r.isMember(userId)).toList();

  Future<void> writeState(String code, String json) async {
    await atomicWriteString(_stateFile(code), json);
  }

  Future<String?> readState(String code) async {
    final file = File(_stateFile(code));
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  Future<void> deleteRoom(String code) async {
    roomsByCode.remove(code);
    final file = File(_stateFile(code));
    if (await file.exists()) await file.delete();
    await saveRooms();
  }
}

/// Short-lived, single-use tickets that authorize one WebSocket upgrade.
///
/// Browsers cannot attach an `Authorization` header to a WebSocket handshake
/// (the JS `WebSocket` constructor has no header API), so the long-lived
/// session bearer token can't be used directly without putting it in the
/// connection URL — which proxies/load balancers commonly log. A ticket
/// minted just before connecting, valid for a few seconds and consumed on
/// first use, keeps the real session token out of any URL or log line.
/// Purely in-memory: losing these on restart just means an in-flight
/// connect attempt has to re-mint one, no real consequence.
class SubwayTicketStore {
  final Map<String, _SubwayTicket> _byTicket = {};
  static const ttl = Duration(seconds: 45);

  String mint(String userId, String roomCode) {
    _prune();
    final ticket = base64UrlEncode(
        List<int>.generate(24, (_) => Random.secure().nextInt(256)));
    _byTicket[ticket] = _SubwayTicket(
      userId: userId,
      roomCode: roomCode,
      expiresAtMs: DateTime.now().millisecondsSinceEpoch + ttl.inMilliseconds,
    );
    return ticket;
  }

  /// Consumes and returns the ticket's (userId, roomCode) if valid for the
  /// given room, or null (already used, expired, or wrong room).
  ({String userId, String roomCode})? redeem(String ticket, String roomCode) {
    final t = _byTicket.remove(ticket);
    if (t == null) return null;
    if (t.roomCode != roomCode) return null;
    if (t.expiresAtMs <= DateTime.now().millisecondsSinceEpoch) return null;
    return (userId: t.userId, roomCode: t.roomCode);
  }

  void _prune() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _byTicket.removeWhere((_, t) => t.expiresAtMs <= now);
  }
}

class _SubwayTicket {
  _SubwayTicket(
      {required this.userId, required this.roomCode, required this.expiresAtMs});
  final String userId;
  final String roomCode;
  final int expiresAtMs;
}
