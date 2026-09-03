import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart' show RouterParams;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A dumb broadcast relay for Subway Builder co-op sessions: the server
/// never parses game state, it just forwards every message a client in a
/// room sends to every *other* client in that room. All conflict handling
/// (host-authoritative economy, id namespacing) lives in the client's
/// mp.js — this only exists so players behind different networks can reach
/// each other. Rooms are purely in-memory and vanish once empty.
class SubwayRelay {
  final Map<String, Set<WebSocketChannel>> _rooms = {};
  int _totalSockets = 0;

  static const _maxRooms = 400;
  static const _maxPerRoom = 8;
  static const _maxTotalSockets = 1600;
  static const _maxMessageBytes = 64 * 1024;
  static final _roomCodeRe = RegExp(r'^[A-Za-z0-9]{4,16}$');

  /// A shelf [Handler] (`FutureOr<Response> Function(Request)`) — note this
  /// builds and invokes the actual upgrade handler per call rather than
  /// returning one, since shelf_router expects a plain Handler, not a
  /// function that itself returns a Handler.
  FutureOr<Response> subwayRoomHandler(Request request) {
    final room = request.params['room'] ?? '';
    if (!_roomCodeRe.hasMatch(room)) {
      return Response(400, body: 'bad room code');
    }
    if (_totalSockets >= _maxTotalSockets) {
      return Response(503, body: 'relay is full, try again later');
    }
    final existing = _rooms[room];
    if (existing == null && _rooms.length >= _maxRooms) {
      return Response(503, body: 'too many active rooms');
    }
    if (existing != null && existing.length >= _maxPerRoom) {
      return Response(409, body: 'room is full');
    }

    final ws = webSocketHandler((WebSocketChannel channel, String? protocol) {
      final peers = _rooms.putIfAbsent(room, () => {});
      peers.add(channel);
      _totalSockets++;
      stdout.writeln(
          '[subway] +peer room=$room size=${peers.length} total=$_totalSockets');

      channel.stream.listen(
        (message) {
          final size =
              message is String ? message.length : (message as List).length;
          if (size > _maxMessageBytes) return; // drop oversized frames silently
          for (final peer in peers) {
            if (!identical(peer, channel)) {
              try {
                peer.sink.add(message);
              } catch (_) {
                // peer socket is in a bad state; its own stream.listen
                // onDone will clean it up.
              }
            }
          }
        },
        onDone: () => _leave(room, channel),
        onError: (_) => _leave(room, channel),
        cancelOnError: true,
      );
    });

    return ws(request);
  }

  void _leave(String room, WebSocketChannel channel) {
    final peers = _rooms[room];
    if (peers == null) return;
    if (peers.remove(channel)) _totalSockets--;
    if (peers.isEmpty) _rooms.remove(room);
    stdout.writeln('[subway] -peer room=$room remaining=${peers.length}');
  }
}
