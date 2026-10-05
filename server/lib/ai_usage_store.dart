import 'dart:convert';
import 'dart:io';
import 'dart:math';

const Map<String, int> kWebSearchWeeklyLimits = {
  'core': 5,
  'orbit': 35,
  'nova': 100,
};

int webSearchWeeklyLimitForPlan(String? planId) =>
    kWebSearchWeeklyLimits[planId] ?? kWebSearchWeeklyLimits['core']!;

/// AI Detector reviews each plan includes per rolling week.
const Map<String, int> kAiCheckerWeeklyChecks = {
  'core': 0,
  'orbit': 10,
  'nova': 30,
};

/// Share of the weekly Luma AI limit one review costs once the included
/// checks are used up. Pricier plans pay less per extra check.
const Map<String, int> kAiCheckerExchangePercent = {
  'core': 10,
  'orbit': 4,
  'nova': 2,
};

int aiCheckerWeeklyChecksForPlan(String? planId) =>
    kAiCheckerWeeklyChecks[planId] ?? kAiCheckerWeeklyChecks['core']!;

int aiCheckerExchangePercentForPlan(String? planId) =>
    kAiCheckerExchangePercent[planId] ?? kAiCheckerExchangePercent['core']!;

/// A one-time pack of extra Luma AI usage units. Credits never expire and are
/// only drawn on once the plan's rolling 5-hour or weekly allowance is used
/// up, at the same mode weights as the allowance.
class AiCreditPack {
  const AiCreditPack(this.id, this.tokens, this.priceCents);

  final String id;
  final int tokens;
  final int priceCents;
}

const List<AiCreditPack> kAiCreditPacks = [
  AiCreditPack('credits_1m', 1000000, 200),
  AiCreditPack('credits_2_5m', 2500000, 400),
  AiCreditPack('credits_5m', 5000000, 750),
  AiCreditPack('credits_10m', 10000000, 1400),
];

AiCreditPack? aiCreditPackById(String? id) {
  for (final pack in kAiCreditPacks) {
    if (pack.id == id) return pack;
  }
  return null;
}

/// One allowance of usage units per plan, shared by every Luma AI mode. A
/// unit is one Aurora token; the better modes drain it faster
/// ([kAiModeWeightTenths]).
class AiTokenBudget {
  const AiTokenBudget(this.weekly);

  final int weekly;
  int get fiveHour => weekly * 15 ~/ 100;
}

/// Rolling usage allowance for the shared Luma AI keys. Pulsar is Nova-only.
AiTokenBudget aiTokenBudget(String? planId) => AiTokenBudget(switch (planId) {
      'orbit' => 5000000,
      'nova' => 14000000,
      _ => 1000000,
    });

/// How fast each mode drains the shared allowance, in tenths of a unit per
/// token: Aurora 1x, Nebula 1.5x, Pulsar 2.5x.
const Map<String, int> kAiModeWeightTenths = {
  'normal': 10,
  'smarter': 15,
  'smartest': 25,
};

int aiModeWeightTenths(String mode) => kAiModeWeightTenths[mode] ?? 10;

/// The usage units [tokens] of [mode] take out of the allowance.
int aiUsageUnits(int tokens, String mode) =>
    (tokens * aiModeWeightTenths(mode) + 5) ~/ 10;

/// Per-user AI usage bookkeeping for the shared, operator-funded keys:
///
/// * Luma AI chats burn **usage units** from one allowance shared by every
///   mode, tracked as (timestamp, tokens, mode, units) events so both rolling
///   windows — 5 hours and 7 days — can be summed exactly. A mode's weight
///   ([kAiModeWeightTenths]) turns its tokens into units.
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

  /// How many days back [callSummary]'s `daily` series reaches.
  static const dailyDays = 30;

  /// userId -> {'tokens': [[ms, tokens, mode, units], ...], 'support': [ms, ...],
  ///             'webSearches': [ms, ...]}
  final Map<String, dynamic> _data;

  static const _tokenWindow = Duration(days: 7);
  static const _supportWindow = Duration(days: 1);
  static const _webSearchWindow = Duration(days: 7);
  static const _aiCheckWindow = Duration(days: 7);

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

  /// (ms, raw tokens, mode, usage units). Events stored before units existed
  /// have no fourth field; they are weighted by their mode as they are read.
  List<(int, int, String, int)> _tokenEvents(String userId) {
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
            e.length > 2 && e[2] is String ? e[2] as String : 'normal',
            e.length > 3 && e[3] is num
                ? (e[3] as num).toInt()
                : aiUsageUnits((e[1] as num).toInt(),
                    e.length > 2 && e[2] is String ? e[2] as String : 'normal'),
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

  /// Raw tokens this user consumed within the trailing [window], optionally
  /// of one [mode]. What the allowance sees is [unitsUsed].
  int tokensUsed(String userId, Duration window, {String? mode}) {
    final cutoff = DateTime.now().subtract(window).millisecondsSinceEpoch;
    var sum = 0;
    for (final e in _tokenEvents(userId)) {
      if (e.$1 > cutoff && (mode == null || e.$3 == mode)) sum += e.$2;
    }
    return sum;
  }

  /// Usage units this user spent, across every mode, within the trailing
  /// [window] — the number the plan's allowance is measured in.
  int unitsUsed(String userId, Duration window) {
    final cutoff = DateTime.now().subtract(window).millisecondsSinceEpoch;
    var sum = 0;
    for (final e in _tokenEvents(userId)) {
      if (e.$1 > cutoff) sum += e.$4;
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

  List<int> _aiCheckEvents(String userId) {
    final raw = _entry(userId)['aiChecks'] as List? ?? const [];
    final cutoff =
        DateTime.now().subtract(_aiCheckWindow).millisecondsSinceEpoch;
    return [
      for (final e in raw)
        if (e is num && e.toInt() > cutoff) e.toInt(),
    ];
  }

  /// Included AI Detector reviews this user used within the trailing week.
  /// Reviews paid for out of the weekly limit are not counted here.
  int aiChecksUsed(String userId) => _aiCheckEvents(userId).length;

  Future<void> recordAiCheck(String userId) async {
    final entry = Map<String, dynamic>.from(_entry(userId));
    entry['aiChecks'] = [
      ..._aiCheckEvents(userId),
      DateTime.now().millisecondsSinceEpoch,
    ];
    _data[userId] = entry;
    await _save();
  }

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

  /// Logs [tokens] of [mode]. [units] is what they cost the allowance; it
  /// defaults to the mode's weight times the tokens.
  Future<void> recordTokens(String userId, int tokens,
      {String mode = 'normal', int? units}) async {
    if (tokens <= 0) return;
    final entry = Map<String, dynamic>.from(_entry(userId));
    entry['tokens'] = [
      for (final e in _tokenEvents(userId)) [e.$1, e.$2, e.$3, e.$4],
      [
        DateTime.now().millisecondsSinceEpoch,
        tokens,
        mode,
        units ?? aiUsageUnits(tokens, mode),
      ],
    ];
    _data[userId] = entry;
    await _save();
  }

  /// Purchased extra tokens still unspent.
  int creditBalance(String userId) {
    final v = _entry(userId)['credits'];
    return v is num && v > 0 ? v.toInt() : 0;
  }

  Future<void> addCredits(String userId, int tokens) async {
    if (tokens <= 0) return;
    final entry = Map<String, dynamic>.from(_entry(userId));
    entry['credits'] = creditBalance(userId) + tokens;
    _data[userId] = entry;
    await _save();
  }

  Future<void> _spendCredits(String userId, int tokens) async {
    final entry = Map<String, dynamic>.from(_entry(userId));
    final left = creditBalance(userId) - tokens;
    entry['credits'] = left > 0 ? left : 0;
    _data[userId] = entry;
    await _save();
  }

  bool _windowsOpen(String userId, AiTokenBudget budget) =>
      unitsUsed(userId, const Duration(hours: 5)) < budget.fiveHour &&
      unitsUsed(userId, const Duration(days: 7)) < budget.weekly;

  bool _windowsFit(String userId, AiTokenBudget budget, int cost) =>
      unitsUsed(userId, const Duration(hours: 5)) + cost <= budget.fiveHour &&
      unitsUsed(userId, const Duration(days: 7)) + cost <= budget.weekly;

  /// Whether a request may start: the plan's allowance has room, or purchased
  /// credits can cover it.
  bool canSpend(String userId, AiTokenBudget budget) =>
      _windowsOpen(userId, budget) || creditBalance(userId) > 0;

  /// Whether a flat-priced action costing [cost] units can be paid for.
  bool canAfford(String userId, AiTokenBudget budget, int cost) =>
      _windowsFit(userId, budget, cost) || creditBalance(userId) >= cost;

  /// Charges [tokens] of [mode] to the plan's allowance while it has room,
  /// and to purchased credits once it does not. Either way the better modes
  /// cost more: the charge is the tokens times the mode's weight.
  Future<void> charge(
      String userId, int tokens, String mode, AiTokenBudget budget) async {
    if (_windowsOpen(userId, budget) || creditBalance(userId) <= 0) {
      return recordTokens(userId, tokens, mode: mode);
    }
    return _spendCredits(userId, aiUsageUnits(tokens, mode));
  }

  /// Like [charge] for a flat [cost], already in usage units, that must fit
  /// whole in the allowance. The mode only labels the event; it adds no weight.
  Future<void> chargeFlat(
      String userId, int cost, String mode, AiTokenBudget budget) async {
    if (_windowsFit(userId, budget, cost) || creditBalance(userId) < cost) {
      return recordTokens(userId, cost, mode: mode, units: cost);
    }
    return _spendCredits(userId, cost);
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
    bool includeInUsage = false,
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
        includeInUsage,
        '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}',
        usage.cacheReadTokens,
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

  List<Map<String, Object?>> usageCalls(String userId) => [
        for (final row in _callRows(userId))
          if (row.length >= 10 && row[8] == true)
            {
              'id': row[9],
              'atMs': row[0],
              'feature': row[1],
              'upstream': row[2],
              'model': row[3],
              'inputTokens': row[4],
              'outputTokens': row[5],
              'totalTokens': row[6],
              'costUsd': row[7],
              'cacheReadTokens': row.length > 10 ? row[10] : 0,
            },
      ];

  /// The admin dashboard's view of [userId]'s AI calls: one line per
  /// feature + provider + model, plus the most recent calls.
  Map<String, dynamic> callSummary(String userId, {int recent = 25}) {
    final rows = _callRows(userId);
    final weekAgo =
        DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
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
    // Per UTC day for the dashboard's charts: only days that saw a call,
    // with each day's tokens split by feature.
    final now = DateTime.now().toUtc();
    final dailyCutoff = DateTime.utc(now.year, now.month, now.day)
        .subtract(const Duration(days: dailyDays - 1))
        .millisecondsSinceEpoch;
    final days = <int, Map<String, dynamic>>{};
    for (final row in rows) {
      final at = row[0] as int;
      if (at < dailyCutoff) continue;
      final d = DateTime.fromMillisecondsSinceEpoch(at, isUtc: true);
      final dayMs = DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch;
      final day = days.putIfAbsent(
          dayMs,
          () => {
                'dayMs': dayMs,
                'calls': 0,
                'tokens': 0,
                'costUsd': null,
                'features': <String, int>{},
              });
      final total = _count(row[6]);
      day['calls'] = (day['calls'] as int) + 1;
      day['tokens'] = (day['tokens'] as int) + total;
      if (row[7] case final num cost) {
        day['costUsd'] = ((day['costUsd'] as num?) ?? 0) + cost;
      }
      final features = day['features'] as Map<String, int>;
      features['${row[1]}'] = (features['${row[1]}'] ?? 0) + total;
    }
    return {
      'models': models,
      'daily': days.values.toList()
        ..sort((a, b) => (a['dayMs'] as int).compareTo(b['dayMs'] as int)),
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
    this.cacheReadTokens = 0,
    int? totalTokens,
    this.costUsd,
    this.model,
  }) : totalTokens = totalTokens ?? inputTokens + outputTokens;

  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
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
      final details =
          usage['prompt_tokens_details'] ?? usage['input_tokens_details'];
      return AiCallUsage(
        inputTokens: input,
        outputTokens: output,
        totalTokens: total > 0 ? total : input + output,
        costUsd: cost is num ? cost.toDouble() : null,
        cacheReadTokens: details is Map ? count(details['cached_tokens']) : 0,
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
        cacheReadTokens: count(meta['cachedContentTokenCount']),
        model: model,
      );
    }
    return AiCallUsage(model: model);
  }
}
