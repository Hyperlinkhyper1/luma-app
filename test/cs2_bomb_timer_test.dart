import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/game_tools/cs2_overlays/cs2_bomb_timer_service.dart';

Map<String, dynamic> _state(
  String? bomb, {
  String token = 'secret-token-1234',
  Map<String, dynamic>? added,
  Map<String, dynamic>? previously,
}) => {
  'provider': {'name': 'Counter-Strike 2', 'appid': 730},
  if (bomb != null) 'round': {'phase': 'live', 'bomb': bomb},
  'auth': {'token': token},
  'added': ?added,
  'previously': ?previously,
};

void main() {
  group('Cs2BombTracker', () {
    test(
      'reports a plant, then the defuse, then the next round clearing it',
      () {
        final tracker = Cs2BombTracker();
        expect(tracker.update(_state(null)), isNull);
        expect(tracker.update(_state('planted')), Cs2BombEvent.planted);
        expect(tracker.update(_state('planted')), isNull);
        expect(tracker.update(_state('defused')), Cs2BombEvent.defused);
        expect(tracker.update(_state(null)), Cs2BombEvent.cleared);
        expect(tracker.update(_state(null)), isNull);
      },
    );

    test('reports an explosion', () {
      final tracker = Cs2BombTracker()..update(_state(null));
      tracker.update(_state('planted'));
      expect(tracker.update(_state('exploded')), Cs2BombEvent.exploded);
    });

    test(
      'ignores a bomb that was already planted before luma was listening',
      () {
        final tracker = Cs2BombTracker();
        expect(tracker.update(_state('planted')), isNull);
        expect(tracker.update(_state('defused')), Cs2BombEvent.defused);
      },
    );

    test('still counts a first update that is itself the plant', () {
      expect(
        Cs2BombTracker().update(
          _state(
            'planted',
            added: {
              'round': {'bomb': true},
            },
          ),
        ),
        Cs2BombEvent.planted,
      );
      expect(
        Cs2BombTracker().update(
          _state(
            'planted',
            previously: {
              'round': {'bomb': null},
            },
          ),
        ),
        Cs2BombEvent.planted,
      );
    });

    test('a round state without a bomb on the first update says nothing', () {
      expect(
        Cs2BombTracker().update({
          'round': {'phase': 'freezetime'},
        }),
        isNull,
      );
    });
  });

  test('urgency follows the 10 s no-kit and 5 s kit defuse times', () {
    expect(cs2BombUrgency(const Duration(seconds: 40)), Cs2BombUrgency.anyone);
    expect(cs2BombUrgency(const Duration(seconds: 10)), Cs2BombUrgency.anyone);
    expect(
      cs2BombUrgency(const Duration(milliseconds: 9999)),
      Cs2BombUrgency.kitOnly,
    );
    expect(cs2BombUrgency(const Duration(seconds: 5)), Cs2BombUrgency.kitOnly);
    expect(
      cs2BombUrgency(const Duration(milliseconds: 4999)),
      Cs2BombUrgency.tooLate,
    );
  });

  test('the config points CS2 at loopback with the token and round data', () {
    final config = cs2GsiConfig(token: 'abc123', port: 47821);
    expect(config, contains('"uri"\t\t"http://127.0.0.1:47821"'));
    expect(config, contains('"token"\t"abc123"'));
    expect(config, contains('"round"\t\t"1"'));
    expect(config, contains('"buffer"\t"0.0"'));
    expect(config, contains('"throttle"\t"0.0"'));
    expect(config.split('{').length, config.split('}').length);
  });

  group('Cs2BombTimerOptions', () {
    test('survive a JSON round trip', () {
      const options = Cs2BombTimerOptions(
        token: 'testtesttesttest',
        fuseSeconds: 45,
        overlayX: 100,
        overlayY: -20,
      );
      final back = Cs2BombTimerOptions.fromJson(
        jsonDecode(jsonEncode(options.toJson())) as Map<String, Object?>,
      );
      expect(back.token, options.token);
      expect(back.fuseSeconds, 45);
      expect(back.overlayX, 100);
      expect(back.overlayY, -20);
    });

    test('replace a missing token and clamp the fuse', () {
      final back = Cs2BombTimerOptions.fromJson({'fuseSeconds': 1});
      expect(back.token, hasLength(32));
      expect(back.fuseSeconds, 10);
      expect(back.overlayX, isNull);
    });
  });

  group('Cs2GsiListener', () {
    test('turns authenticated posts into events and drops the rest', () async {
      final listener = Cs2GsiListener(token: 'secret-token-1234', port: 0);
      final events = <Cs2BombEvent>[];
      listener.events.listen(events.add);
      await listener.start();
      addTearDown(listener.dispose);

      Future<int> post(Map<String, dynamic> body) async {
        final client = HttpClient();
        try {
          final request = await client.post(
            InternetAddress.loopbackIPv4.address,
            listener.boundPort!,
            '/',
          );
          request.headers.contentType = ContentType.json;
          request.write(jsonEncode(body));
          final response = await request.close();
          await response.drain<void>();
          return response.statusCode;
        } finally {
          client.close();
        }
      }

      expect(await post(_state(null)), 200);
      expect(listener.lastUpdate, isNotNull);
      expect(await post(_state('planted', token: 'wrong')), 200);
      expect(events, isEmpty);
      expect(await post(_state('planted')), 200);
      expect(await post(_state('defused')), 200);
      await Future<void>.delayed(Duration.zero);
      expect(events, [Cs2BombEvent.planted, Cs2BombEvent.defused]);
    });

    test('calls onUpdate for heartbeats too', () {
      var updates = 0;
      final listener = Cs2GsiListener(
        token: 'secret-token-1234',
        onUpdate: () => updates++,
      );
      listener.handle(_state(null));
      listener.handle(_state(null));
      listener.handle(_state(null, token: 'nope'));
      expect(updates, 2);
    });
  });
}
