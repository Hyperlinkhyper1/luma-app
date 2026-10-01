import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luma/features/plugins/installed/text_library/minecraft/classroom_api.dart';
import 'package:luma/features/plugins/installed/text_library/minecraft/classroom_store.dart';
import 'package:luma/sync/server_access.dart';

void main() {
  setUp(() => ServerAccessGate.instance.setApproved(false));
  tearDown(() => ServerAccessGate.instance.setApproved(false));

  group('saved lesson', () {
    test('keeps the page\'s shape but trims what could fill the disk', () {
      final cleaned =
          cleanClassroomState({
                'lesson': {'subject': 'Wiskunde', 'topic': 'x' * 5000},
                'session': {
                  'items': [
                    for (var i = 0; i < 60; i++)
                      {'question': 'Q$i', 'answer': 'A', 'skipped': false},
                  ],
                  'index': 3,
                },
                'junk': Object(),
              })
              as Map;
      expect((cleaned['lesson'] as Map)['subject'], 'Wiskunde');
      expect(((cleaned['lesson'] as Map)['topic'] as String).length, 2000);
      expect(((cleaned['session'] as Map)['items'] as List).length, 40);
      expect((cleaned['session'] as Map)['index'], 3);
      expect(cleaned['junk'], isNull);
    });

    test('stops at a sane depth', () {
      Object nested = 'deep';
      for (var i = 0; i < 20; i++) {
        nested = [nested];
      }
      expect(jsonEncode(cleanClassroomState(nested)), isNot(contains('deep')));
    });
  });

  group('server calls', () {
    test('refuse to leave the device until the account is approved', () async {
      var called = false;
      final api = ClassroomApi(
        'https://sync.example.com',
        token: 't',
        client: MockClient((_) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        api.state(),
        throwsA(
          isA<ClassroomException>().having((e) => e.code, 'code', 'signin'),
        ),
      );
      expect(called, isFalse);
    });

    test('send the lesson and hand back the question', () async {
      ServerAccessGate.instance.setApproved(true);
      late http.Request sent;
      final api = ClassroomApi(
        'https://sync.example.com/',
        token: 'tok',
        client: MockClient((request) async {
          sent = request;
          return http.Response(
            jsonEncode({'question': 'Hoe lang is c?', 'choices': <String>[]}),
            200,
          );
        }),
      );
      final q = await api.question({
        'lesson': {'subject': 'Wiskunde'},
        'asked': ['Eerdere vraag'],
        'number': 2,
        'language': 'nl',
      });
      expect(q['question'], 'Hoe lang is c?');
      expect(
        sent.url.toString(),
        'https://sync.example.com/api/v1/classroom/question',
      );
      expect(sent.headers['Authorization'], 'Bearer tok');
      final body = jsonDecode(sent.body) as Map;
      expect(body['asked'], ['Eerdere vraag']);
      expect((body['lesson'] as Map)['subject'], 'Wiskunde');
    });

    test('carry the server\'s refusal code to the page', () async {
      ServerAccessGate.instance.setApproved(true);
      final api = ClassroomApi(
        'https://sync.example.com',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': 'country_locked',
              'message': 'Your country is already set.',
            }),
            409,
          ),
        ),
      );
      await expectLater(
        api.setCountry('Deutschland'),
        throwsA(
          isA<ClassroomException>()
              .having((e) => e.code, 'code', 'country_locked')
              .having((e) => e.message, 'message', contains('already set')),
        ),
      );
    });
  });
}
