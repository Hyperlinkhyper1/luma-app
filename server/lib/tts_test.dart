import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'util.dart';

/// The Text to Speech benchmark: every speech model reads the same four
/// scripts, two in a woman's voice and two in a man's. Nothing is scored by
/// the server; the clips are stored with what each cost and how long it took,
/// and people listen to them side by side in AI Usage → Tests.
class TtsTest {
  const TtsTest({
    required this.id,
    required this.title,
    required this.voice,
    required this.instructions,
    required this.text,
  });

  final String id;
  final String title;

  /// `female` or `male`: which of the two voices picked per model reads it.
  final String voice;

  /// Delivery directions, sent as the request's `instructions`. Models that
  /// take none ignore them; they are never part of the spoken text.
  final String instructions;

  /// The text read aloud, identical for every model.
  final String text;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'voice': voice,
        'instructions': instructions,
        'text': text,
      };
}

const _kPoem = 'The Lamplighter\'s Hour.\n\n'
    'When evening folds the harbour into grey,\n'
    'and gulls go quiet on the leaning posts,\n'
    'the lamplighter walks out along the quay\n'
    'and wakes the lanterns one by one, like ghosts.\n\n'
    'He does not hurry. Every flame he lifts\n'
    'is someone\'s window, someone\'s road back home;\n'
    'the tide forgets the names of all its ships,\n'
    'but he remembers each, and walks alone.\n\n'
    'And when the last light trembles into gold,\n'
    'he stops a moment where the water ends,\n'
    'and listens to the dark, and is not cold,\n'
    'for every lamp behind him is a friend.';

/// The four tests, in the order the app lists them. Changing any text here
/// changes [kTtsScriptHash], which takes every older run off the app's page
/// so all the clips it shows always read the same words.
const kTtsTests = <TtsTest>[
  TtsTest(
    id: 'station_announcement',
    title: 'Train station announcement',
    voice: 'female',
    instructions: 'A calm, clear, professional female station announcer '
        'speaking over a public-address system. Measured pace, crisp '
        'consonants, a short pause between sentences.',
    text: 'Good afternoon. The fourteen thirty-two intercity service to '
        'Amsterdam Centraal, calling at Utrecht Centraal, Amersfoort and '
        'Zwolle, is now arriving on platform four. Please stand behind the '
        'yellow line until the train has come to a complete stop. This train '
        'has eight carriages; first class is in carriages one and two, at the '
        'front of the train. Due to engineering works near Hilversum, '
        'passengers for Almere should change at Amersfoort. We apologise for '
        'the inconvenience, and wish you a pleasant journey.',
  ),
  TtsTest(
    id: 'poem_female',
    title: 'Poem reading (woman)',
    voice: 'female',
    instructions: 'Read this poem aloud slowly and expressively, as a woman '
        'at a quiet poetry reading. Pause at line ends and longer between '
        'stanzas.',
    text: _kPoem,
  ),
  TtsTest(
    id: 'poem_male',
    title: 'Poem reading (man)',
    voice: 'male',
    instructions: 'Read this poem aloud slowly and expressively, as a man '
        'at a quiet poetry reading. Pause at line ends and longer between '
        'stanzas.',
    text: _kPoem,
  ),
  TtsTest(
    id: 'speech_male',
    title: 'Speech (man)',
    voice: 'male',
    instructions: 'A confident, warm male speaker giving a short public '
        'speech to a crowd outdoors. Natural pauses, energy rising toward '
        'the end.',
    text: 'Friends, neighbours, and everyone who came out tonight in the '
        'rain: thank you. Ten years ago this bridge was a fence and a warning '
        'sign. People said it would cost too much, take too long, and that '
        'nobody would ever use it. They were right about the first two. But '
        'look around you. Children walk to school across it now. The bakery '
        'on the far side opened a second shop. Old friends who lived a river '
        'apart have coffee on Sundays again. Nothing we build matters as much '
        'as what it lets people do together. So tonight, we don\'t cut a '
        'ribbon. We open a door. Welcome to the Riverside Bridge.',
  ),
];

TtsTest? ttsTestById(String id) {
  for (final t in kTtsTests) {
    if (t.id == id) return t;
  }
  return null;
}

/// FNV-1a over every test's id, voice and text. Runs are stamped with it.
final String kTtsScriptHash = () {
  var h = 0x811c9dc5;
  for (final t in kTtsTests) {
    for (final unit in utf8.encode('${t.id}|${t.voice}|${t.text}\n')) {
      h = ((h ^ unit) * 0x01000193) & 0xffffffff;
    }
  }
  return h.toRadixString(16).padLeft(8, '0');
}();

const kTtsMaxRuns = 300;
const kTtsMaxModelsPerBatch = 40;

const _femaleNames = {
  'kore', 'aoede', 'leda', 'zephyr', 'callirrhoe', 'autonoe', 'despina',
  'erinome', 'laomedeia', 'achernar', 'gacrux', 'pulcherrima',
  'vindemiatrix', 'sulafat', 'sarah', 'alice', 'laura', 'jessica', 'lily',
  'matilda', 'bella', 'nadine', 'tabitha', 'noelle', 'meredith', 'sabrina',
  'jane', 'harper', 'emily', 'mia', 'isla', 'valeria', 'soleil', 'thalia',
  'asteria', 'athena', 'amalthea', 'andromeda', 'hannah', 'heather',
  'brooke', 'bree', 'brittany', 'alexis', 'elise', 'gemma', 'haley', 'eve',
  'ara', 'tara', 'leah', 'jess', 'heart', 'emma', 'isabella', 'nicole',
  'nova', 'sky', 'shimmer', 'coral', 'sage', 'ballad', 'woman', 'female',
  'girl', 'lady',
};

const _maleNames = {
  'charon', 'puck', 'orus', 'fenrir', 'enceladus', 'iapetus', 'umbriel',
  'algieba', 'algenib', 'rasalgethi', 'alnilam', 'schedar', 'achird',
  'zubenelgenubi', 'sadachbia', 'sadaltager', 'george', 'brian', 'daniel',
  'adam', 'bill', 'callum', 'charlie', 'chris', 'eric', 'harry', 'liam',
  'roger', 'will', 'bram', 'gareth', 'lucian', 'weston', 'vincent', 'paul',
  'oliver', 'grant', 'klaus', 'apollo', 'arcas', 'aries', 'atlas', 'orion',
  'bruce', 'cliff', 'cole', 'colin', 'conor', 'donovan', 'drew', 'jack',
  'kai', 'rex', 'sal', 'leo', 'dan', 'zac', 'michael', 'onyx', 'echo',
  'fable', 'ash', 'man', 'male', 'bloke', 'guy', 'boy',
};

/// The first pick per voice when a model offers it, so the well-known
/// voices of each family win over a name that merely matches.
const _preferred = {
  'female': [
    'kore', 'sarah', 'nadine', 'en-us-harper', 'aura-2-thalia-en',
    'flux-hannah-en', 'english_calmwoman', 'eve', 'af_heart', 'tara',
    'coral',
  ],
  'male': [
    'charon', 'george', 'bram', 'en-gb-harry', 'aura-2-apollo-en',
    'flux-bruce-en', 'english_trustworth_man', 'rex', 'am_michael', 'leo',
    'onyx',
  ],
};

const _foreignLocales = {
  'fr', 'es', 'de', 'it', 'ja', 'zh', 'pt', 'nl', 'cs', 'da', 'ko', 'hi',
  'ru', 'pl', 'sv', 'nb', 'fi', 'tr', 'ar', 'cmn', 'yue',
};

List<String> _tokens(String voice) => voice
    .toLowerCase()
    .split(RegExp(r'[^a-z]+'))
    .where((s) => s.isNotEmpty)
    .toList();

/// Which voice a name sounds like: `female`, `male`, or null when the name
/// says nothing (Sesame's `read_speech_a`, numbered voices…).
String? ttsVoiceGender(String voice) {
  final tokens = _tokens(voice);
  if (tokens.isEmpty) return null;
  if (tokens.first == 'af' || tokens.first == 'bf') return 'female';
  if (tokens.first == 'am' || tokens.first == 'bm') return 'male';
  for (final t in tokens) {
    if (_femaleNames.contains(t) ||
        t.endsWith('woman') ||
        t.endsWith('girl') ||
        t.endsWith('lady')) {
      return 'female';
    }
  }
  for (final t in tokens) {
    if (_maleNames.contains(t) || t.endsWith('man')) return 'male';
  }
  return null;
}

/// A sensible voice of [gender] out of a model's [voices], preferring
/// English ones. Null when the model lists no voices at all, which leaves
/// the choice to the provider's default.
String? guessTtsVoice(List<String> voices, String gender) {
  if (voices.isEmpty) return null;
  final english = voices
      .where((v) => !_tokens(v).any(_foreignLocales.contains))
      .toList();
  final pool = english.isEmpty ? voices : english;
  final lower = {for (final v in pool) v.toLowerCase(): v};
  for (final p in _preferred[gender] ?? const <String>[]) {
    for (final entry in lower.entries) {
      if (entry.key == p || entry.key.startsWith('$p:')) return entry.value;
    }
  }
  for (final v in pool) {
    if (ttsVoiceGender(v) == gender) return v;
  }
  final other = gender == 'female' ? 'male' : 'female';
  for (final v in pool) {
    if (ttsVoiceGender(v) != other) return v;
  }
  return pool.first;
}

/// Raw 16-bit little-endian mono PCM wrapped in a WAV header, so browsers
/// and the app's player can play it as-is.
Uint8List pcmToWav(List<int> pcm, {int sampleRate = 24000, int channels = 1}) {
  const bits = 16;
  final byteRate = sampleRate * channels * bits ~/ 8;
  final header = ByteData(44)
    ..setUint32(0, 0x52494646) // RIFF
    ..setUint32(4, 36 + pcm.length, Endian.little)
    ..setUint32(8, 0x57415645) // WAVE
    ..setUint32(12, 0x666d7420) // fmt
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, channels, Endian.little)
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, byteRate, Endian.little)
    ..setUint16(32, channels * bits ~/ 8, Endian.little)
    ..setUint16(34, bits, Endian.little)
    ..setUint32(36, 0x64617461) // data
    ..setUint32(40, pcm.length, Endian.little);
  return Uint8List.fromList([...header.buffer.asUint8List(), ...pcm]);
}

/// The sample rate a `audio/pcm;rate=…` content type names, else 24 kHz —
/// what Gemini, HeyGen and Azure send.
int pcmSampleRate(String? contentType) {
  final m = RegExp(r'rate=(\d+)').firstMatch(contentType ?? '');
  final rate = m == null ? null : int.tryParse(m.group(1)!);
  return rate != null && rate >= 8000 && rate <= 96000 ? rate : 24000;
}

/// How long a WAV or MP3 clip plays, in seconds; null when it can't tell.
/// MP3 is read from its first frame's bitrate, which is exact for the
/// constant-bitrate files TTS providers send.
double? audioSeconds(List<int> bytes, String format) {
  if (format == 'wav') {
    if (bytes.length < 44) return null;
    final d = ByteData.sublistView(Uint8List.fromList(bytes.sublist(0, 44)));
    final byteRate = d.getUint32(28, Endian.little);
    if (byteRate == 0) return null;
    return (bytes.length - 44) / byteRate;
  }
  var i = 0;
  if (bytes.length > 10 &&
      bytes[0] == 0x49 &&
      bytes[1] == 0x44 &&
      bytes[2] == 0x33) {
    final size = (bytes[6] & 0x7f) << 21 |
        (bytes[7] & 0x7f) << 14 |
        (bytes[8] & 0x7f) << 7 |
        (bytes[9] & 0x7f);
    i = 10 + size;
  }
  const v1l3 = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320];
  const v2l3 = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160];
  for (; i + 4 <= bytes.length && i < 1 << 16; i++) {
    if (bytes[i] != 0xff || bytes[i + 1] & 0xe0 != 0xe0) continue;
    final version = (bytes[i + 1] >> 3) & 3;
    final layer = (bytes[i + 1] >> 1) & 3;
    final index = bytes[i + 2] >> 4;
    if (layer != 1 || index == 0 || index == 15 || version == 1) continue;
    final kbps = version == 3 ? v1l3[index] : v2l3[index];
    return (bytes.length - i) * 8 / (kbps * 1000);
  }
  return null;
}

/// One script read by one model.
class TtsClip {
  TtsClip({
    required this.test,
    required this.voice,
    this.format,
    this.bytes = 0,
    this.ms = 0,
    this.seconds,
    this.costUsd,
    this.costEstimated = false,
    this.error,
  });

  final String test;
  final String? voice;

  /// `mp3` or `wav`; null when the clip failed.
  String? format;
  int bytes;

  /// Wall-clock time the request took, from sending to the last byte.
  int ms;

  /// How long the clip plays.
  double? seconds;

  /// What OpenRouter billed, or the model's list price times the text when
  /// it had no figure for the generation ([costEstimated]).
  double? costUsd;
  bool costEstimated;
  String? error;

  bool get ok => error == null && format != null;

  Map<String, dynamic> toJson() => {
        'test': test,
        'voice': voice,
        if (format != null) 'format': format,
        'bytes': bytes,
        'ms': ms,
        if (seconds != null) 'seconds': double.parse(seconds!.toStringAsFixed(2)),
        if (costUsd != null) 'costUsd': costUsd,
        if (costEstimated) 'costEstimated': true,
        if (error != null) 'error': error,
      };

  static TtsClip? fromJson(Object? raw) {
    if (raw is! Map || raw['test'] is! String) return null;
    return TtsClip(
      test: raw['test'] as String,
      voice: raw['voice'] is String ? raw['voice'] as String : null,
      format: raw['format'] is String ? raw['format'] as String : null,
      bytes: raw['bytes'] is int ? raw['bytes'] as int : 0,
      ms: raw['ms'] is int ? raw['ms'] as int : 0,
      seconds: raw['seconds'] is num ? (raw['seconds'] as num).toDouble() : null,
      costUsd: raw['costUsd'] is num ? (raw['costUsd'] as num).toDouble() : null,
      costEstimated: raw['costEstimated'] == true,
      error: raw['error'] is String ? raw['error'] as String : null,
    );
  }
}

/// One model through all four scripts.
class TtsRun {
  TtsRun({
    required this.id,
    required this.model,
    required this.femaleVoice,
    required this.maleVoice,
    required this.startedAtMs,
    required this.scripts,
    this.ownKey = false,
    this.keyHint,
    this.status = 'queued',
    this.finishedAtMs,
    this.note,
    List<TtsClip>? clips,
  }) : clips = clips ?? [];

  final String id;
  final String model;
  final String? femaleVoice;
  final String? maleVoice;
  int startedAtMs;

  /// [kTtsScriptHash] when the run started.
  final String scripts;
  final bool ownKey;
  final String? keyHint;

  /// queued, running, done, failed or stopped.
  String status;
  int? finishedAtMs;
  String? note;
  final List<TtsClip> clips;
  bool stopRequested = false;

  bool get active => status == 'queued' || status == 'running';

  String? voiceFor(String gender) =>
      gender == 'female' ? femaleVoice : maleVoice;

  TtsClip? clip(String test) {
    for (final c in clips) {
      if (c.test == test) return c;
    }
    return null;
  }

  double get costUsd =>
      clips.fold(0.0, (sum, c) => sum + (c.costUsd ?? 0));
  bool get costEstimated => clips.any((c) => c.costEstimated);
  int get totalMs => clips.fold(0, (sum, c) => sum + c.ms);
  int get okClips => clips.where((c) => c.ok).length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'model': model,
        'femaleVoice': femaleVoice,
        'maleVoice': maleVoice,
        'startedAtMs': startedAtMs,
        'scripts': scripts,
        'ownKey': ownKey,
        if (keyHint != null) 'keyHint': keyHint,
        'status': status,
        if (finishedAtMs != null) 'finishedAtMs': finishedAtMs,
        if (note != null) 'note': note,
        'clips': [for (final c in clips) c.toJson()],
      };

  /// [toJson] plus the totals the dashboard shows.
  Map<String, dynamic> summaryJson() => {
        ...toJson(),
        'costUsd': costUsd,
        'costEstimated': costEstimated,
        'totalMs': totalMs,
        'total': kTtsTests.length,
        'done': clips.length,
        'current': scripts == kTtsScriptHash,
      };

  static TtsRun? fromJson(Object? raw) {
    if (raw is! Map || raw['id'] is! String || raw['model'] is! String) {
      return null;
    }
    final run = TtsRun(
      id: raw['id'] as String,
      model: raw['model'] as String,
      femaleVoice: raw['femaleVoice'] is String ? raw['femaleVoice'] as String : null,
      maleVoice: raw['maleVoice'] is String ? raw['maleVoice'] as String : null,
      startedAtMs: raw['startedAtMs'] is int ? raw['startedAtMs'] as int : 0,
      scripts: raw['scripts'] is String ? raw['scripts'] as String : '',
      ownKey: raw['ownKey'] == true,
      keyHint: raw['keyHint'] is String ? raw['keyHint'] as String : null,
      status: raw['status'] is String ? raw['status'] as String : 'failed',
      finishedAtMs: raw['finishedAtMs'] is int ? raw['finishedAtMs'] as int : null,
      note: raw['note'] is String ? raw['note'] as String : null,
      clips: [
        if (raw['clips'] case final List list)
          for (final c in list)
            if (TtsClip.fromJson(c) case final clip?) clip,
      ],
    );
    // A server restart drops the batch in flight; don't leave it spinning.
    if (run.active) {
      run.status = 'stopped';
      run.note ??= 'The server restarted during this run.';
    }
    return run;
  }
}

/// What one speech request produced.
class TtsReply {
  const TtsReply({
    this.audio,
    this.contentType,
    this.generationId,
    this.status = 200,
    this.error,
    this.fatal = false,
  });

  final List<int>? audio;
  final String? contentType;
  final String? generationId;
  final int status;
  final String? error;

  /// The key was refused or the account is out of credit: the rest of the
  /// batch would fail the same way.
  final bool fatal;
}

typedef TtsSpeechCall = Future<TtsReply> Function(Map<String, dynamic> body);
typedef TtsCostLookup = Future<double?> Function(String generationId);

/// Providers that only ever answer in PCM; everything else is asked for MP3.
bool ttsPcmOnly(String model) =>
    model.startsWith('heygen/') ||
    (model.startsWith('google/') && model.contains('tts'));

/// Reads every test with [run]'s voices, storing each clip through
/// [saveAudio]. A 400 on the asked format is retried once in the other.
Future<void> runTtsModel(
  TtsRun run, {
  required TtsSpeechCall speak,
  required TtsCostLookup cost,
  required Future<void> Function(TtsClip clip, List<int> audio) saveAudio,
  Map<String, double>? price,
  Future<void> Function()? onProgress,
}) async {
  var format = ttsPcmOnly(run.model) ? 'pcm' : 'mp3';
  for (final test in kTtsTests) {
    if (run.stopRequested) break;
    final voice = run.voiceFor(test.voice);
    Map<String, dynamic> body(String f) => {
          'model': run.model,
          'input': test.text,
          if (voice != null) 'voice': voice,
          'instructions': test.instructions,
          'response_format': f,
        };
    final watch = Stopwatch()..start();
    var reply = await speak(body(format));
    if (reply.status == 400 && reply.audio == null) {
      final other = format == 'mp3' ? 'pcm' : 'mp3';
      final retry = await speak(body(other));
      if (retry.audio != null) {
        format = other;
        reply = retry;
      }
    }
    watch.stop();
    final clip = TtsClip(test: test.id, voice: voice, ms: watch.elapsedMilliseconds);
    final audio = reply.audio;
    if (audio == null || audio.isEmpty) {
      clip.error = reply.error ?? 'No audio in the reply.';
      run.clips.add(clip);
      if (reply.fatal) {
        run.note = clip.error;
        break;
      }
    } else {
      final pcm = format == 'pcm' ||
          (reply.contentType ?? '').contains('pcm') ||
          (reply.contentType ?? '').contains('L16');
      final bytes = pcm
          ? pcmToWav(audio, sampleRate: pcmSampleRate(reply.contentType))
          : audio;
      clip
        ..format = pcm ? 'wav' : 'mp3'
        ..bytes = bytes.length
        ..seconds = audioSeconds(bytes, pcm ? 'wav' : 'mp3');
      if (reply.generationId case final id?) clip.costUsd = await cost(id);
      if (clip.costUsd == null && price != null) {
        final perChar = price['prompt'] ?? 0;
        final perSecond = price['completion'] ?? 0;
        clip
          ..costUsd = perChar * test.text.length +
              (perChar == 0 ? perSecond * (clip.seconds ?? 0) : 0)
          ..costEstimated = true;
      }
      await saveAudio(clip, bytes);
      run.clips.add(clip);
    }
    await onProgress?.call();
  }
  if (run.okClips == 0 && run.note == null && !run.stopRequested) {
    run.note = run.clips.isEmpty ? 'Nothing ran.' : run.clips.first.error;
  }
}

/// The runs and their audio: `tts_tests.json` plus one folder of clips per
/// run under `tts_runs/`.
class TtsTestStore {
  TtsTestStore(String dataDir)
      : _file = File('$dataDir/tts_tests.json'),
        audioDir = Directory('$dataDir/tts_runs') {
    try {
      if (!_file.existsSync()) return;
      final decoded = jsonDecode(_file.readAsStringSync());
      if (decoded is! Map) return;
      if (decoded['runs'] case final List runs) {
        for (final raw in runs) {
          if (TtsRun.fromJson(raw) case final run?) _runs.add(run);
        }
      }
    } catch (e) {
      stderr.writeln('[luma] could not read ${_file.path}: $e');
    }
  }

  final File _file;
  final Directory audioDir;
  final AsyncLock _lock = AsyncLock();
  final List<TtsRun> _runs = [];

  /// Newest first.
  List<TtsRun> get runs => List.unmodifiable(_runs.reversed);

  TtsRun? run(String id) {
    for (final r in _runs) {
      if (r.id == id) return r;
    }
    return null;
  }

  bool get busy => _runs.any((r) => r.active);
  List<TtsRun> get active => _runs.where((r) => r.active).toList();

  static final _safeId = RegExp(r'^[a-z0-9_]{1,64}$');

  /// Where [run]'s clip for [test] lives, or null for ids that could
  /// escape the folder.
  File? audioFile(String runId, String test, String format) {
    if (!_safeId.hasMatch(runId) || !_safeId.hasMatch(test)) return null;
    if (format != 'mp3' && format != 'wav') return null;
    return File('${audioDir.path}/$runId/$test.$format');
  }

  Future<void> saveAudio(TtsRun run, TtsClip clip, List<int> bytes) async {
    final file = audioFile(run.id, clip.test, clip.format ?? '');
    if (file == null) return;
    await file.parent.create(recursive: true);
    await atomicWriteBytes(file.path, bytes);
  }

  Future<void> addAll(List<TtsRun> runs) async {
    _runs.addAll(runs);
    while (_runs.length > kTtsMaxRuns) {
      final oldest = _runs.indexWhere((r) => !r.active);
      if (oldest < 0) break;
      await _deleteAudio(_runs.removeAt(oldest).id);
    }
    await persist();
  }

  Future<bool> delete(String id) async {
    final before = _runs.length;
    _runs.removeWhere((r) => r.id == id && !r.active);
    if (_runs.length == before) return false;
    await _deleteAudio(id);
    await persist();
    return true;
  }

  Future<void> _deleteAudio(String id) async {
    if (!_safeId.hasMatch(id)) return;
    final dir = Directory('${audioDir.path}/$id');
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } on FileSystemException catch (e) {
      stderr.writeln('[luma] could not delete ${dir.path}: $e');
    }
  }

  Future<void> persist() => _lock.synchronized(() => atomicWriteString(
      _file.path,
      jsonEncode({
        'runs': [for (final r in _runs) r.toJson()],
      })));
}
