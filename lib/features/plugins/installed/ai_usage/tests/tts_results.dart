/// One script of the Text to Speech test, as `/api/v1/ai-benchmarks/tts`
/// lists it. Every model reads exactly this [text].
class TtsScript {
  const TtsScript({required this.id, required this.voice, required this.text});

  /// `station_announcement`, `poem_female`, `poem_male` or `speech_male`.
  final String id;

  /// `female` or `male`.
  final String voice;
  final String text;

  static TtsScript? fromJson(Object? raw) {
    if (raw is! Map || raw['id'] is! String || raw['text'] is! String) {
      return null;
    }
    return TtsScript(
      id: raw['id'] as String,
      voice: raw['voice'] == 'male' ? 'male' : 'female',
      text: raw['text'] as String,
    );
  }
}

/// One model's reading of one script.
class TtsClipInfo {
  const TtsClipInfo({
    required this.test,
    required this.ok,
    this.voice,
    this.format,
    this.ms = 0,
    this.seconds,
    this.costUsd,
  });

  final String test;
  final bool ok;
  final String? voice;

  /// `mp3` or `wav`.
  final String? format;

  /// How long the server waited for the clip.
  final int ms;

  /// How long the clip plays.
  final double? seconds;
  final double? costUsd;

  static TtsClipInfo? fromJson(Object? raw) {
    if (raw is! Map || raw['test'] is! String) return null;
    final format = raw['format'];
    return TtsClipInfo(
      test: raw['test'] as String,
      ok: raw['ok'] == true && (format == 'mp3' || format == 'wav'),
      voice: raw['voice'] is String ? raw['voice'] as String : null,
      format: format is String ? format : null,
      ms: raw['ms'] is num ? (raw['ms'] as num).toInt() : 0,
      seconds: raw['seconds'] is num ? (raw['seconds'] as num).toDouble() : null,
      costUsd: raw['costUsd'] is num ? (raw['costUsd'] as num).toDouble() : null,
    );
  }
}

/// One speech model's latest run through all the scripts.
class TtsEntry {
  const TtsEntry({
    required this.runId,
    required this.model,
    required this.clips,
    this.femaleVoice,
    this.maleVoice,
    this.costUsd = 0,
    this.totalMs = 0,
    this.finishedAtMs = 0,
  });

  final String runId;
  final String model;
  final String? femaleVoice;
  final String? maleVoice;
  final double costUsd;
  final int totalMs;
  final int finishedAtMs;
  final List<TtsClipInfo> clips;

  String get vendor => model.contains('/') ? model.split('/').first : model;
  String get shortName =>
      model.contains('/') ? model.substring(model.indexOf('/') + 1) : model;

  TtsClipInfo? clip(String test) {
    for (final c in clips) {
      if (c.test == test) return c;
    }
    return null;
  }

  static TtsEntry? fromJson(Object? raw) {
    if (raw is! Map || raw['runId'] is! String || raw['model'] is! String) {
      return null;
    }
    return TtsEntry(
      runId: raw['runId'] as String,
      model: raw['model'] as String,
      femaleVoice: raw['femaleVoice'] is String ? raw['femaleVoice'] as String : null,
      maleVoice: raw['maleVoice'] is String ? raw['maleVoice'] as String : null,
      costUsd: raw['costUsd'] is num ? (raw['costUsd'] as num).toDouble() : 0,
      totalMs: raw['totalMs'] is num ? (raw['totalMs'] as num).toInt() : 0,
      finishedAtMs:
          raw['finishedAtMs'] is num ? (raw['finishedAtMs'] as num).toInt() : 0,
      clips: [
        if (raw['clips'] case final List list)
          for (final c in list)
            ?TtsClipInfo.fromJson(c),
      ],
    );
  }
}

/// The Text to Speech test's results: the scripts and every model's clips.
class TtsBoard {
  const TtsBoard({
    required this.scripts,
    required this.entries,
    this.otherScripts = 0,
  });

  final List<TtsScript> scripts;

  /// Sorted by model id.
  final List<TtsEntry> entries;

  /// Runs left off because they read older scripts.
  final int otherScripts;

  factory TtsBoard.fromJson(Map<String, dynamic> json) {
    final hidden = json['hidden'];
    return TtsBoard(
      scripts: [
        if (json['tests'] case final List list)
          for (final t in list)
            ?TtsScript.fromJson(t),
      ],
      entries: [
        if (json['models'] case final List list)
          for (final m in list)
            ?TtsEntry.fromJson(m),
      ],
      otherScripts: hidden is Map && hidden['otherScripts'] is num
          ? (hidden['otherScripts'] as num).toInt()
          : 0,
    );
  }
}

/// Dollars at the precision a fraction of a cent needs.
String ttsMoney(double v) {
  if (v <= 0) return r'$0';
  if (v >= 1) return '\$${v.toStringAsFixed(2)}';
  if (v >= 0.01) return '\$${v.toStringAsFixed(3)}';
  return '\$${v.toStringAsPrecision(2)}';
}

/// Seconds with one decimal, e.g. `4.2 s`.
String ttsSeconds(double s) => '${s.toStringAsFixed(1)} s';
