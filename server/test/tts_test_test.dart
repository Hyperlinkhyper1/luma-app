import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:luma_sync_server/tts_test.dart';
import 'package:test/test.dart';

void main() {
  group('scripts', () {
    test('two tests per voice, unique ids', () {
      expect(kTtsTests.map((t) => t.id).toSet(), hasLength(kTtsTests.length));
      expect(kTtsTests.where((t) => t.voice == 'female'), hasLength(2));
      expect(kTtsTests.where((t) => t.voice == 'male'), hasLength(2));
      expect(kTtsScriptHash, matches(RegExp(r'^[0-9a-f]{8}$')));
    });

    test('both poem readings read the same poem', () {
      expect(ttsTestById('poem_female')!.text, ttsTestById('poem_male')!.text);
    });
  });

  group('voices', () {
    test('picks the known voice of each family', () {
      const gemini = ['Zephyr', 'Puck', 'Charon', 'Kore', 'Fenrir'];
      expect(guessTtsVoice(gemini, 'female'), 'Kore');
      expect(guessTtsVoice(gemini, 'male'), 'Charon');
      const eleven = ['adam', 'alice', 'george', 'sarah'];
      expect(guessTtsVoice(eleven, 'female'), 'sarah');
      expect(guessTtsVoice(eleven, 'male'), 'george');
    });

    test('prefers English voices', () {
      const azure = [
        'de-DE-Mia:MAI-Voice-2.1',
        'de-DE-Klaus:MAI-Voice-2.1',
        'en-GB-Emily:MAI-Voice-2.1',
        'en-GB-Harry:MAI-Voice-2.1',
      ];
      expect(guessTtsVoice(azure, 'female'), 'en-GB-Emily:MAI-Voice-2.1');
      expect(guessTtsVoice(azure, 'male'), 'en-GB-Harry:MAI-Voice-2.1');
    });

    test('reads gender from names and prefixes', () {
      expect(ttsVoiceGender('af_bella'), 'female');
      expect(ttsVoiceGender('am_onyx'), 'male');
      expect(ttsVoiceGender('English_CalmWoman'), 'female');
      expect(ttsVoiceGender('English_Trustworth_Man'), 'male');
      expect(ttsVoiceGender('read_speech_a'), isNull);
      expect(guessTtsVoice(const [], 'male'), isNull);
    });
  });

  group('audio', () {
    test('pcm becomes a playable wav of the right length', () {
      final wav = pcmToWav(List.filled(48000, 0), sampleRate: 24000);
      expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
      expect(ascii.decode(wav.sublist(8, 12)), 'WAVE');
      expect(audioSeconds(wav, 'wav'), closeTo(1.0, 1e-9));
      expect(pcmSampleRate('audio/pcm;rate=16000'), 16000);
      expect(pcmSampleRate('audio/pcm'), 24000);
    });

    test('mp3 length from the first frame bitrate', () {
      // MPEG-1 layer III, 128 kbps: 16,000 bytes play for one second.
      final mp3 = Uint8List(16000);
      mp3.setAll(0, [0xff, 0xfb, 0x90, 0x00]);
      expect(audioSeconds(mp3, 'mp3'), closeTo(1.0, 1e-9));
    });
  });

  group('runTtsModel', () {
    TtsRun newRun(String model) => TtsRun(
          id: 'r1',
          model: model,
          femaleVoice: 'Kore',
          maleVoice: 'Charon',
          startedAtMs: 0,
          scripts: kTtsScriptHash,
        );

    test('reads every script with the right voice, billed cost', () async {
      final run = newRun('elevenlabs/eleven-v3');
      final bodies = <Map<String, dynamic>>[];
      final saved = <String>[];
      await runTtsModel(
        run,
        speak: (body) async {
          bodies.add(body);
          return TtsReply(
              audio: [1, 2, 3], contentType: 'audio/mpeg', generationId: 'g');
        },
        cost: (_) async => 0.01,
        saveAudio: (clip, _) async => saved.add(clip.test),
      );
      expect(bodies, hasLength(4));
      for (final (i, t) in kTtsTests.indexed) {
        expect(bodies[i]['input'], t.text);
        expect(bodies[i]['voice'], t.voice == 'female' ? 'Kore' : 'Charon');
        expect(bodies[i]['response_format'], 'mp3');
      }
      expect(saved, kTtsTests.map((t) => t.id));
      expect(run.costUsd, closeTo(0.04, 1e-9));
      expect(run.costEstimated, isFalse);
      expect(run.okClips, 4);
    });

    test('pcm-only models get wav clips and a list-price estimate', () async {
      final run = newRun('google/gemini-3.1-flash-tts-preview');
      await runTtsModel(
        run,
        speak: (body) async {
          expect(body['response_format'], 'pcm');
          return const TtsReply(audio: [0, 0, 0, 0], contentType: 'audio/pcm');
        },
        cost: (_) async => fail('no generation id, no lookup'),
        saveAudio: (_, bytes) async =>
            expect(ascii.decode(bytes.sublist(0, 4)), 'RIFF'),
        price: {'prompt': 0.000001},
      );
      expect(run.clips.every((c) => c.format == 'wav'), isTrue);
      expect(run.costEstimated, isTrue);
      expect(run.clips.first.costUsd,
          closeTo(kTtsTests.first.text.length * 0.000001, 1e-12));
    });

    test('a 400 on mp3 retries once as pcm and keeps it', () async {
      final run = newRun('somebody/voice-1');
      final formats = <String>[];
      await runTtsModel(
        run,
        speak: (body) async {
          formats.add(body['response_format'] as String);
          return body['response_format'] == 'mp3'
              ? const TtsReply(status: 400, error: 'mp3 not supported')
              : const TtsReply(audio: [0, 0], contentType: 'audio/pcm');
        },
        cost: (_) async => null,
        saveAudio: (_, __) async {},
      );
      expect(formats, ['mp3', 'pcm', 'pcm', 'pcm', 'pcm']);
      expect(run.okClips, 4);
    });

    test('a refused key stops the run after one clip', () async {
      final run = newRun('elevenlabs/eleven-v3');
      await runTtsModel(
        run,
        speak: (_) async =>
            const TtsReply(status: 401, error: 'HTTP 401', fatal: true),
        cost: (_) async => null,
        saveAudio: (_, __) async {},
      );
      expect(run.clips, hasLength(1));
      expect(run.note, 'HTTP 401');
    });
  });

  group('TtsTestStore', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('luma_tts'));
    tearDown(() async => dir.delete(recursive: true));

    test('round-trips runs and deletes their audio', () async {
      final store = TtsTestStore(dir.path);
      final run = TtsRun(
        id: 'abc1',
        model: 'x-ai/grok-voice-tts-1.0',
        femaleVoice: 'eve',
        maleVoice: 'rex',
        startedAtMs: 5,
        scripts: kTtsScriptHash,
        status: 'done',
      );
      final clip = TtsClip(test: 'poem_male', voice: 'rex', format: 'mp3');
      run.clips.add(clip);
      await store.addAll([run]);
      await store.saveAudio(run, clip, [9, 9]);
      expect(File('${dir.path}/tts_runs/abc1/poem_male.mp3').existsSync(), isTrue);

      final again = TtsTestStore(dir.path);
      expect(again.runs.single.clip('poem_male')!.voice, 'rex');
      expect(await again.delete('abc1'), isTrue);
      expect(Directory('${dir.path}/tts_runs/abc1').existsSync(), isFalse);
    });

    test('refuses ids that would leave the folder', () {
      final store = TtsTestStore(dir.path);
      expect(store.audioFile('../x', 'poem_male', 'mp3'), isNull);
      expect(store.audioFile('abc', '..', 'mp3'), isNull);
      expect(store.audioFile('abc', 'poem_male', 'exe'), isNull);
    });

    test('a run cut off by a restart loads as stopped', () async {
      await File('${dir.path}/tts_tests.json').writeAsString(jsonEncode({
        'runs': [
          {'id': 'r', 'model': 'm/x', 'status': 'running', 'scripts': ''},
        ],
      }));
      final store = TtsTestStore(dir.path);
      expect(store.runs.single.status, 'stopped');
      expect(store.busy, isFalse);
    });
  });
}
