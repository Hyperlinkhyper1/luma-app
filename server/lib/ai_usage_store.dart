import 'dart:convert';
import 'dart:io';

const Map<String, int> kWebSearchWeeklyLimits = {
  'core': 5,
  'orbit': 35,
  'nova': 100,
};

int webSearchWeeklyLimitForPlan(String? planId) =>
    kWebSearchWeeklyLimits[planId] ?? kWebSearchWeeklyLimits['core']!;

class AiTokenBudget {
  const AiTokenBudget(this.weekly);

  final int weekly;
  int get fiveHour => weekly * 15 ~/ 100;
}

/// Rolling token allowances for the shared Luma AI key. Pulsar is Nova-only.
AiTokenBudget aiTokenBudget(String? planId, String mode) {
  if (mode == 'smartest') return const AiTokenBudget(4000000);
  final base = mode == 'smarter' ? 500000 : 750000;
  final multiplier = switch (planId) {
    'orbit' => 5,
    'nova' => 15,
    _ => 1,
  };
  return AiTokenBudget(base * multiplier);
}

/// Per-user AI usage bookkeeping for the shared, operator-funded keys:
///
/// * Google ("Luma AI" modes) chats burn **tokens**, tracked as
///   (timestamp, tokens, mode) events so both rolling windows — 5 hours and
///   7 days — can be summed exactly for each mode.
/// * Mistral ("Luma Support") chats burn **messages** — [kSupportMessagesPerDay]
///   per rolling day, counted separately from the token budget.
/// * Web searches use each plan's rolling weekly allowance.
///
/// Persisted as one JSON file in the data directory; events outside the
/// longest window are pruned on every touch so the file stays tiny.
class AiUsageStore {
  AiUsageStore._(this._file, this._data, this._callsFile, this._calls);

  final File _file;
  Future<void> _saveTail = Future.value();

  /// Every upstream call a user made on the operator's keys, kept for the
  /// admin dashboard: userId -> [[ms, feature, upstream, model, input,
  /// output, total, costUsd|null], ...]. Separate from [_data] because the
  /// budget windows prune after 7 days while this keeps a longer history.
  final File _callsFile;
  final Map<String, dynamic> _calls;
  Future<void> _callsSaveTail = Future.value();

  static const _callRetention = Duration(days: 180);
  static const _maxCallsPerUser = 5000;

  /// userId -> {'tokens': [[ms, tokens, mode], ...], 'support': [ms, ...],
  ///             'webSearches': [ms, ...]}
  final Map<String, dynamic> _data;

  static const _tokenWindow = Duration(days: 7);
  static const _supportWindow = Duration(days: 1);
  static const _webSearchWindow = Duration(days: 7);

  static Future<AiUsageStore> open(String dataDir) async {
    Future<(File, Map<String, dynamic>)> load(String name) async {
      final file = File('$dataDir${Platform.pathSeparator}$name');
      Map<String, dynamic> data = {};
      if (await file.exists()) {
        try {
          final decoded = jsonDecode(await file.readAsString());
          if (decoded is Map<String, dynamic>) data = decoded;
        } catch (_) {
          // Corrupt file — start fresh rather than refusing to boot.
        }
      }
      return (file, data);
    }

    final (file, data) = await load('ai_usage.json');
    final (callsFile, calls) = await load('ai_calls.json');
    return AiUsageStore._(file, data, callsFile, calls);
  }

  Map<String, dynamic> _entry(String userId) =>
      (_data[userId] as Map<String, dynamic>?) ?? {};

  List<(int, int, String)> _tokenEvents(String userId) {
    final raw = _entry(userId)['tokens'] as List? ?? const [];
    final cutoff = DateTime.now().subtract(_tokenWindow).millisecondsSinceEpoch;
    return [
      for (final e in raw)
        if (e is List &&
            e.length >= 2 &&
            e[0] is num &&
            e[1] is num &&
            (e[0] as num).toInt() > cutoff)
          (
            (e[0] as num).toInt(),
            (e[1] as num).toInt(),
            e.length > 2 && e[2] is String ? e[2] as String : 'normal'
          ),
    ];
  }

  List<int> _supportEvents(String userId) {
    final raw = _entry(userId)['support'] as List? ?? const [];
    final cutoff =
        DateTime.now().subtract(_supportWindow).millisecondsSinceEpoch;
    return [
      for (final e in raw)
        if (e is num && e.toInt() > cutoff) e.toInt(),
    ];
  }

  /// Total Google tokens this user consumed within the trailing [window].
  int tokensUsed(String userId, Duration window, {String? mode}) {
    final cutoff = DateTime.now().subtract(window).millisecondsSinceEpoch;
    var sum = 0;
    for (final e in _tokenEvents(userId)) {
      if (e.$1 > cutoff && (mode == null || e.$3 == mode)) sum += e.$2;
    }
    return sum;
  }

  /// Luma Support messages this user sent within the trailing day.
  int supportMessagesUsed(String userId) => _supportEvents(userId).length;

  List<int> _webSearchEvents(String userId) {
    final raw = _entry(userId)['webSearches'] as List? ?? const [];
    final cutoff =
        DateTime.now().subtract(_webSearchWindow).millisecondsSinceEpoch;
    return [
      for (final e in raw)
        if (e is num && e.toInt() > cutoff) e.toInt(),
    ];
  }

  int webSearchesUsed(String userId) => _webSearchEvents(userId).length;

  /// Reserves one search before calling SearXNG. This check and mutation happen
  /// before the first await, so concurrent requests in this isolate cannot
  /// exceed the user's plan allowance.
  Future<bool> consumeWebSearch(String userId, int limit) async {
    final events = _webSearchEvents(userId);
    if (limit <= 0 || events.length >= limit) return false;
    final entry = Map<String, dynamic>.from(_entry(userId));
    entry['webSearches'] = [
      ...events,
      DateTime.now().millisecondsSinceEpoch,
    ];
    _data[userId] = entry;
    await _save();
    return true;
  }

  Future<void> recordTokens(String userId, int tokens,
      {String mode = 'normal'}) async {
    if (tokens <= 0) return;
    final entry = Map<String, dynamic>.from(_entry(userId));
    entry['tokens'] = [
      for (final e in _tokenEvents(userId)) [e.$1, e.$2, e.$3],
      [DateTime.now().millisecondsSinceEpoch, tokens, mode],
    ];
    _data[userId] = entry;
    await _save();
  }

  Future<void> recordSupportMessage(String userId) async {
    final entry = Map<String, dynamic>.from(_entry(userId));
    entry['support'] = [
      ..._supportEvents(userId),
      DateTime.now().millisecondsSinceEpoch,
    ];
    _data[userId] = entry;
    await _save();
  }

  /// Logs one upstream call billed to the operator's keys. Recorded even
  /// when [usage] reports no tokens, so the request count stays honest.
  Future<void> recordCall(
    String userId, {
    required String feature,
    required String upstream,
    required String model,
    required AiCallUsage usage,
  }) async {
    final cutoff =
        DateTime.now().subtract(_callRetention).millisecondsSinceEpoch;
    final rows = [
      for (final row in _callRows(userId))
        if ((row[0] as int) > cutoff) row,
      [
        DateTime.now().millisecondsSinceEpoch,
        feature,
        upstream,
        usage.model ?? model,
        usage.inputTokens,
        usage.outputTokens,
        usage.totalTokens,
        usage.costUsd,
      ],
    ];
    if (rows.length > _maxCallsPerUser) {
      rows.removeRange(0, rows.length - _maxCallsPerUser);
    }
    _calls[userId] = rows;
    await _saveCalls();
  }

  List<List<Object?>> _callRows(String userId) {
    final raw = _calls[userId] as List? ?? const [];
    return [
      for (final row in raw)
        if (row is List && row.length >= 8 && row[0] is int)
          List<Object?>.from(row),
    ];
  }

  /// The admin dashboard's view of [userId]'s AI calls: one line per
  /// feature + provider + model, plus the most recent calls.
  Map<String, dynamic> callSummary(String userId, {int recent = 25}) {
    final rows = _callRows(userId);
    final weekAgo = DateTime.now()
        .subtract(const Duration(days: 7))
        .millisecondsSinceEpoch;
    final groups = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final at = row[0] as int;
      final total = _count(row[6]);
      final group = groups.putIfAbsent(
          '${row[1]}\u0000${row[2]}\u0000${row[3]}',
          () => {
                'feature': row[1],
                'upstream': row[2],
                'model': row[3],
                'calls': 0,
                'inputTokens': 0,
                'outputTokens': 0,
                'totalTokens': 0,
                'tokens7d': 0,
                'costUsd': null,
                'firstAtMs': at,
                'lastAtMs': at,
              });
      group['calls'] = (group['calls'] as int) + 1;
      group['inputTokens'] = (group['inputTokens'] as int) + _count(row[4]);
      group['outputTokens'] = (group['outputTokens'] as int) + _count(row[5]);
      group['totalTokens'] = (group['totalTokens'] as int) + total;
      if (at > weekAgo) group['tokens7d'] = (group['tokens7d'] as int) + total;
      if (row[7] case final num cost) {
        group['costUsd'] = ((group['costUsd'] as num?) ?? 0) + cost;
      }
      group['lastAtMs'] = at;
    }
    final models = groups.values.toList()
      ..sort((a, b) =>
          (b['totalTokens'] as int).compareTo(a['totalTokens'] as int));
    return {
      'models': models,
      'recent': [
        for (final row in rows.reversed.take(recent))
          {
            'atMs': row[0],
            'feature': row[1],
            'upstream': row[2],
            'model': row[3],
            'inputTokens': _count(row[4]),
            'outputTokens': _count(row[5]),
            'totalTokens': _count(row[6]),
            'costUsd': row[7],
          },
      ],
    };
  }

  static int _count(Object? v) => v is num ? v.toInt() : 0;

  /// Forgets a deleted account's usage history.
  Future<void> deleteUser(String userId) async {
    if (_calls.remove(userId) != null) await _saveCalls();
    if (_data.remove(userId) == null) return;
    await _save();
  }

  Future<void> _saveCalls() {
    final snapshot = jsonEncode(_calls);
    final save = _callsSaveTail.then((_) async {
      try {
        await _callsFile.writeAsString(snapshot, flush: true);
      } catch (_) {
        // Best effort — this log feeds the dashboard, never the metering.
      }
    });
    _callsSaveTail = save;
    return save;
  }

  Future<void> _save() {
    final snapshot = jsonEncode(_data);
    final save = _saveTail.then((_) async {
      try {
        await _file.writeAsString(snapshot, flush: true);
      } catch (_) {
        // Best effort — losing usage history on a disk hiccup only means a
        // user briefly gets more budget, never less.
      }
    });
    _saveTail = save;
    return save;
  }
}

/// Token counts (and cost, when the provider reports one) read out of an
/// upstream response. Understands the OpenAI-compatible `usage` block every
/// chat upstream returns, the image endpoints' input/output variant, and
/// Gemini's native `usageMetadata`.
class AiCallUsage {
  const AiCallUsage({
    this.inputTokens = 0,
    this.outputTokens = 0,
    int? totalTokens,
    this.costUsd,
    this.model,
  }) : totalTokens = totalTokens ?? inputTokens + outputTokens;

  final int inputTokens;
  final int outputTokens;
  final int totalTokens;
  final double? costUsd;

  /// The model the provider says actually answered, when it says.
  final String? model;

  static AiCallUsage parse(String responseBody) {
    Object? decoded;
    try {
      decoded = jsonDecode(responseBody);
    } catch (_) {
      return const AiCallUsage();
    }
    if (decoded is! Map) return const AiCallUsage();
    int count(Object? v) => v is num ? v.toInt() : 0;
    final rawModel = decoded['model'] ?? decoded['modelVersion'];
    final model = rawModel is String && rawModel.isNotEmpty ? rawModel : null;
    final usage = decoded['usage'];
    if (usage is Map) {
      final input = count(usage['prompt_tokens'] ?? usage['input_tokens']);
      final output =
          count(usage['completion_tokens'] ?? usage['output_tokens']);
      final total = count(usage['total_tokens']);
      final cost = usage['cost'];
      return AiCallUsage(
        inputTokens: input,
        outputTokens: output,
        totalTokens: total > 0 ? total : input + output,
        costUsd: cost is num ? cost.toDouble() : null,
        model: model,
      );
    }
    final meta = decoded['usageMetadata'];
    if (meta is Map) {
      final input = count(meta['promptTokenCount']);
      final output = count(meta['candidatesTokenCount']);
      final total = count(meta['totalTokenCount']);
      return AiCallUsage(
        inputTokens: input,
        outputTokens: output,
        totalTokens: total > 0 ? total : input + output,
        model: model,
      );
    }
    return AiCallUsage(model: model);
  }
}
