import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/game_tools/cs2_translator/cs2_voice_protocol.dart';
import 'package:luma/features/plugins/installed/game_tools/cs2_translator/cs2_voice_recorder.dart';

class _CommandConsumer implements StreamConsumer<List<int>> {
  _CommandConsumer(this.onCommand);
  final void Function(String) onCommand;

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final command
        in stream.transform(utf8.decoder).transform(const LineSplitter())) {
      onCommand(command);
    }
  }

  @override
  Future<void> close() async {}
}

class _RecorderProcess implements Process {
  _RecorderProcess({this.respond = true}) {
    stdin = IOSink(
      _CommandConsumer((command) {
        commands.add(command);
        if (!respond) return;
        if (command == 'stop') {
          emit({
            'event': 'audio',
            'data': base64Encode([1, 2, 3]),
          });
        }
        finish();
      }),
      encoding: utf8,
    );
  }

  final bool respond;
  final commands = <String>[];
  final output = StreamController<List<int>>();
  final errors = StreamController<List<int>>();
  final exited = Completer<int>();
  bool killed = false;
  void emit(Map<String, Object> event) =>
      output.add(utf8.encode('${jsonEncode(event)}\n'));

  void finish() {
    if (exited.isCompleted) return;
    exited.complete(0);
    unawaited(output.close());
    unawaited(errors.close());
  }

  @override
  Future<int> get exitCode => exited.future;
  @override
  int get pid => 123;
  @override
  late final IOSink stdin;
  @override
  Stream<List<int>> get stdout => output.stream;
  @override
  Stream<List<int>> get stderr => errors.stream;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    finish();
    return true;
  }
}

void main() {
  late _RecorderProcess process;
  late WindowsCs2VoiceRecorder recorder;
  String? scriptPath;

  setUp(() {
    process = _RecorderProcess();
    scriptPath = null;
  });

  void createRecorder() {
    recorder = WindowsCs2VoiceRecorder.forTesting(
      loadScript: () async => 'fake recorder script',
      startProcess: (executable, arguments) async {
        expect(executable, 'powershell.exe');
        expect(arguments, containsAllInOrder(['-WindowStyle', 'Hidden']));
        scriptPath = arguments.last;
        expect(await File(scriptPath!).readAsString(), 'fake recorder script');
        process.emit({'event': 'recording'});
        return process;
      },
      stopTimeout: const Duration(milliseconds: 30),
      cleanupTimeout: const Duration(milliseconds: 30),
    );
  }

  tearDown(() async {
    await recorder.cancel();
    await process.stdin.close();
    expect(scriptPath == null || !await File(scriptPath!).exists(), isTrue);
  });

  test('stop receives helper audio and removes the temporary helper', () async {
    createRecorder();
    await recorder.start();
    expect(await recorder.stop(), [1, 2, 3]);
    expect(process.commands.first, 'stop');
    expect(process.killed, false);
  });

  test(
    'a stalled helper reports a microphone error and is terminated',
    () async {
      process = _RecorderProcess(respond: false);
      createRecorder();
      await recorder.start();
      await expectLater(
        recorder.stop(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('microphone did not finish'),
          ),
        ),
      );
      expect(process.killed, true);
      expect(process.commands, containsAllInOrder(['stop', 'cancel']));
    },
  );

  test(
    'cancelling a pending stop unblocks it without waiting for its deadline',
    () async {
      process = _RecorderProcess(respond: false);
      createRecorder();
      await recorder.start();
      final stopped = recorder.stop();
      final cancelled = expectLater(stopped, throwsA(isA<Cs2VoiceCancelled>()));
      await recorder.cancel();
      await cancelled;
      expect(process.killed, true);
    },
  );

  test(
    'native microphone errors are returned instead of a generic timeout',
    () async {
      process = _RecorderProcess(respond: false);
      createRecorder();
      await recorder.start();
      process.emit({
        'event': 'error',
        'message': 'No default recording device',
      });
      await expectLater(
        recorder.stop(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('No default recording device'),
          ),
        ),
      );
    },
  );
}
