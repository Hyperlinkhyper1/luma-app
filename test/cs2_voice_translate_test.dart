import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:luma/features/plugins/installed/game_tools/cs2_translator/cs2_voice_protocol.dart';
import 'package:luma/features/plugins/installed/game_tools/cs2_translator/cs2_voice_recorder.dart';
import 'package:luma/features/plugins/installed/game_tools/cs2_translator/cs2_voice_translate_service.dart';

class _Recorder implements Cs2VoiceRecorder {
  int starts = 0;
  int stops = 0;
  int cancellations = 0;
  Completer<void>? opening;

  @override
  Future<void> start() async {
    starts++;
    await opening?.future;
  }

  @override
  Future<Uint8List> stop() async {
    stops++;
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<void> cancel() async {
    cancellations++;
  }
}

class _SlowCleanupRecorder extends _Recorder {
  final released = Completer<void>();

  @override
  Future<void> cancel() async {
    cancellations++;
    if (cancellations == 1) await released.future;
  }
}

void main() {
  test('voice translation cannot be armed while luma is closed', () async {
    final recorder = _Recorder();
    final service = Cs2VoiceTranslateService.forTesting(
      recorder: recorder,
      serverReady: () => true,
      appIsOpen: () async => false,
      translate: (_, _) async =>
          const Cs2VoiceTranslation(transcript: 'a', translation: 'b'),
      send: (text, _) async => text,
    );
    addTearDown(service.dispose);
    await service.setEnabled(true);
    await service.toggleRecording();
    expect(service.enabled, isFalse);
    expect(recorder.starts, 0);
    expect(service.error, contains('Open luma'));
  });

  test(
    'closing luma disables the shortcut and cancels an active microphone',
    () async {
      final closed = StreamController<void>.broadcast(sync: true);
      addTearDown(closed.close);
      final recorder = _Recorder();
      final service = Cs2VoiceTranslateService.forTesting(
        recorder: recorder,
        serverReady: () => true,
        appCloseEvents: closed.stream,
        translate: (_, _) async =>
            const Cs2VoiceTranslation(transcript: 'a', translation: 'b'),
        send: (text, _) async => text,
      );
      addTearDown(service.dispose);
      await service.setEnabled(true);
      await service.toggleRecording();
      expect(service.recording, isTrue);
      closed.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(service.enabled, isFalse);
      expect(service.recording, isFalse);
      expect(recorder.cancellations, greaterThan(0));
      await service.toggleRecording();
      expect(recorder.starts, 1);
    },
  );

  test(
    'closing luma discards an in-flight translation and reopening stays disabled',
    () async {
      final closed = StreamController<void>.broadcast(sync: true);
      addTearDown(closed.close);
      final pending = Completer<Cs2VoiceTranslation>();
      var open = true;
      var sends = 0;
      final service = Cs2VoiceTranslateService.forTesting(
        recorder: _Recorder(),
        serverReady: () => true,
        appIsOpen: () async => open,
        appCloseEvents: closed.stream,
        translate: (_, _) => pending.future,
        send: (text, _) async {
          sends++;
          return text;
        },
      );
      addTearDown(service.dispose);
      await service.setEnabled(true);
      await service.toggleRecording();
      final stopping = service.toggleRecording();
      await Future<void>.delayed(Duration.zero);
      open = false;
      closed.add(null);
      pending.complete(
        const Cs2VoiceTranslation(transcript: 'a', translation: 'b'),
      );
      await stopping;
      open = true;
      await service.toggleRecording();
      expect(sends, 0);
      expect(service.enabled, isFalse);
      expect(service.recording, isFalse);
    },
  );

  test(
    'a hidden window blocks a new recording even before a close event',
    () async {
      var open = true;
      final recorder = _Recorder();
      final service = Cs2VoiceTranslateService.forTesting(
        recorder: recorder,
        serverReady: () => true,
        appIsOpen: () async => open,
        translate: (_, _) async =>
            const Cs2VoiceTranslation(transcript: 'a', translation: 'b'),
        send: (text, _) async => text,
      );
      addTearDown(service.dispose);
      await service.setEnabled(true);
      open = false;
      await service.toggleRecording();
      expect(recorder.starts, 0);
      expect(service.enabled, isFalse);
    },
  );

  test(
    'hiding luma during translation blocks delivery without a close event',
    () async {
      var open = true;
      var sends = 0;
      final pending = Completer<Cs2VoiceTranslation>();
      final service = Cs2VoiceTranslateService.forTesting(
        recorder: _Recorder(),
        serverReady: () => true,
        appIsOpen: () async => open,
        translate: (_, _) => pending.future,
        send: (text, _) async {
          sends++;
          return text;
        },
      );
      addTearDown(service.dispose);
      await service.setEnabled(true);
      await service.toggleRecording();
      final stopping = service.toggleRecording();
      await Future<void>.delayed(Duration.zero);
      open = false;
      pending.complete(
        const Cs2VoiceTranslation(transcript: 'a', translation: 'b'),
      );
      await stopping;
      expect(sends, 0);
      expect(service.enabled, isFalse);
    },
  );

  test('closing luma during shortcut activation cannot reenable it', () async {
    final closed = StreamController<void>.broadcast(sync: true);
    addTearDown(closed.close);
    final visibility = Completer<bool>();
    final service = Cs2VoiceTranslateService.forTesting(
      recorder: _Recorder(),
      serverReady: () => true,
      appIsOpen: () => visibility.future,
      appCloseEvents: closed.stream,
      translate: (_, _) async =>
          const Cs2VoiceTranslation(transcript: 'a', translation: 'b'),
      send: (text, _) async => text,
    );
    addTearDown(service.dispose);
    final arming = service.setEnabled(true);
    await Future<void>.delayed(Duration.zero);
    closed.add(null);
    visibility.complete(true);
    await arming;
    expect(service.enabled, isFalse);
  });

  test('users can replace the default with their own system keybind', () async {
    final service = Cs2VoiceTranslateService.forTesting(
      recorder: _Recorder(),
      serverReady: () => true,
      translate: (_, _) async =>
          const Cs2VoiceTranslation(transcript: 'a', translation: 'b'),
      send: (text, _) async => text,
    );
    addTearDown(service.dispose);
    await service.setHotKey(
      HotKey(
        key: PhysicalKeyboardKey.f9,
        modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
        scope: HotKeyScope.inapp,
      ),
    );
    expect(service.hotKey.key, PhysicalKeyboardKey.f9);
    expect(service.hotKey.modifiers, [
      HotKeyModifier.control,
      HotKeyModifier.alt,
    ]);
    expect(service.hotKey.scope, HotKeyScope.system);
  });

  test('chat text cannot add commands or terminate a quoted say command', () {
    final text = sanitizeCs2ChatMessage('hello";quit\\\nnext\u0000line');
    expect(text, "hello' quit next line");
    expect(text, isNot(contains('"')));
    expect(text, isNot(contains(';')));
    expect(() => sanitizeCs2ChatMessage(' \n;\\ '), throwsFormatException);
  });

  test('chat is bounded by UTF-8 bytes without cutting Unicode characters', () {
    final text = sanitizeCs2ChatMessage(List.filled(100, '界😀').join());
    expect(utf8.encode(text).length, lessThanOrEqualTo(120));
    expect(utf8.decode(utf8.encode(text)), text);
    expect(text.contains('\uFFFD'), isFalse);
  });

  test('empty and malformed provider responses are rejected', () {
    for (final body in [
      <String, dynamic>{},
      {'transcript': '', 'translation': 'hello'},
      {'transcript': 'hello', 'translation': '\n '},
    ]) {
      expect(() => Cs2VoiceTranslation.fromJson(body), throwsFormatException);
    }
  });

  test('writes exactly one say command over a real loopback socket', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final received = Completer<String>();
    server.listen((socket) {
      final bytes = <int>[];
      socket.listen(
        bytes.addAll,
        onDone: () {
          received.complete(utf8.decode(bytes));
          socket.destroy();
        },
      );
    });
    final sent = await sendCs2Chat(
      'Hallo "team"; go\nB',
      () => true,
      connect: () => Socket.connect(InternetAddress.loopbackIPv4, server.port),
    );
    expect(sent, "Hallo 'team' go B");
    expect(
      await received.future.timeout(const Duration(seconds: 3)),
      'say "Hallo \'team\' go B"\n',
    );
  });

  test('cancellation after connection sends zero bytes', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final received = Completer<int>();
    server.listen((socket) {
      var count = 0;
      socket.listen(
        (bytes) => count += bytes.length,
        onDone: () {
          received.complete(count);
          socket.destroy();
        },
      );
    });
    await expectLater(
      sendCs2Chat(
        'hello',
        () => false,
        connect: () =>
            Socket.connect(InternetAddress.loopbackIPv4, server.port),
      ),
      throwsA(isA<Cs2VoiceCancelled>()),
    );
    expect(await received.future.timeout(const Duration(seconds: 3)), 0);
  });

  test(
    'key toggles recording, translates selected language, then sends once',
    () async {
      final recorder = _Recorder();
      var sends = 0;
      final service = Cs2VoiceTranslateService.forTesting(
        recorder: recorder,
        serverReady: () => true,
        translate: (audio, language) async {
          expect(recorder.stops, 1);
          expect(language, 'Dutch');
          return const Cs2VoiceTranslation(
            transcript: 'hello',
            translation: 'hallo',
          );
        },
        send: (text, current) async {
          expect(current(), isTrue);
          sends++;
          return text;
        },
      );
      addTearDown(service.dispose);
      await service.setTargetLanguage('Dutch');
      await service.setEnabled(true);
      await service.toggleRecording();
      expect(service.recording, isTrue);
      expect(sends, 0);
      await service.toggleRecording();
      expect(service.recording, isFalse);
      expect(service.busy, isFalse);
      expect(service.transcript, 'hello');
      expect(service.translation, 'hallo');
      expect(sends, 1);
    },
  );

  test('cancelled in-flight translation cannot send a late response', () async {
    final pending = Completer<Cs2VoiceTranslation>();
    var sends = 0;
    final service = Cs2VoiceTranslateService.forTesting(
      recorder: _Recorder(),
      serverReady: () => true,
      translate: (_, _) => pending.future,
      send: (text, current) async {
        sends++;
        return text;
      },
    );
    addTearDown(service.dispose);
    await service.setEnabled(true);
    await service.toggleRecording();
    final stopping = service.toggleRecording();
    await Future<void>.delayed(Duration.zero);
    service.cancel();
    pending.complete(
      const Cs2VoiceTranslation(transcript: 'hello', translation: 'hallo'),
    );
    await stopping;
    expect(sends, 0);
    expect(service.busy, isFalse);
  });

  test(
    'duplicate press during microphone startup does not start twice',
    () async {
      final recorder = _Recorder()..opening = Completer<void>();
      final service = Cs2VoiceTranslateService.forTesting(
        recorder: recorder,
        serverReady: () => true,
        translate: (_, _) async =>
            const Cs2VoiceTranslation(transcript: 'a', translation: 'b'),
        send: (text, _) async => text,
      );
      addTearDown(service.dispose);
      await service.setEnabled(true);
      final opening = service.toggleRecording();
      await Future<void>.delayed(Duration.zero);
      await service.toggleRecording();
      recorder.opening!.complete();
      await opening;
      expect(recorder.starts, 1);
      service.cancel();
    },
  );

  test('unapproved account cannot arm or start the microphone', () async {
    final recorder = _Recorder();
    final service = Cs2VoiceTranslateService.forTesting(
      recorder: recorder,
      serverReady: () => false,
      translate: (_, _) async =>
          const Cs2VoiceTranslation(transcript: 'a', translation: 'b'),
      send: (text, _) async => text,
    );
    addTearDown(service.dispose);
    await service.setEnabled(true);
    await service.toggleRecording();
    expect(service.enabled, isFalse);
    expect(recorder.starts, 0);
    expect(service.error, contains('approved'));
  });

  test(
    'repeated cancellation waits for the first recorder to release the mic',
    () async {
      final recorder = _SlowCleanupRecorder();
      final service = Cs2VoiceTranslateService.forTesting(
        recorder: recorder,
        serverReady: () => true,
        translate: (_, _) async =>
            const Cs2VoiceTranslation(transcript: 'a', translation: 'b'),
        send: (text, _) async => text,
      );
      addTearDown(service.dispose);
      await service.setEnabled(true);
      service.cancel();
      service.cancel();
      final opening = service.toggleRecording();
      await Future<void>.delayed(Duration.zero);
      expect(recorder.starts, 0);
      recorder.released.complete();
      await opening;
      expect(recorder.starts, 1);
    },
  );

  test('disabling while arming keeps the microphone disabled', () async {
    final service = Cs2VoiceTranslateService.forTesting(
      recorder: _Recorder(),
      serverReady: () => true,
      translate: (_, _) async =>
          const Cs2VoiceTranslation(transcript: 'a', translation: 'b'),
      send: (text, _) async => text,
    );
    addTearDown(service.dispose);
    final arming = service.setEnabled(true);
    await service.setEnabled(false);
    await arming;
    expect(service.enabled, isFalse);
  });

  test(
    'network failure leaves translation visible and reports no send',
    () async {
      final service = Cs2VoiceTranslateService.forTesting(
        recorder: _Recorder(),
        serverReady: () => true,
        translate: (_, _) async =>
            const Cs2VoiceTranslation(transcript: 'a', translation: 'b'),
        send: (_, _) async => throw const SocketException('connection refused'),
      );
      addTearDown(service.dispose);
      await service.setEnabled(true);
      await service.toggleRecording();
      await service.toggleRecording();
      expect(service.translation, 'b');
      expect(service.error, contains('2121'));
      expect(service.status, 'Message was not sent');
    },
  );
}
