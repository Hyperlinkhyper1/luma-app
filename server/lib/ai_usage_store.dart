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
  AiUsageStore._(this._file, this._data);

  final File _file;
  Future<void> _saveTail = Future.value();

  /// userId -> {'tokens': [[ms, tokens, mode], ...], 'support': [ms, ...],
  ///             'webSearches': [ms, ...]}
  final Map<String, dynamic> _data;

  static const _tokenWindow = Duration(days: 7);
  static const _supportWindow = Duration(days: 1);
  static const _webSearchWindow = Duration(days: 7);

  static Future<AiUsageStore> open(String dataDir) async {
    final file = File('$dataDir${Platform.pathSeparator}ai_usage.json');
    Map<String, dynamic> data = {};
    if (await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {
        // Corrupt file — start fresh rather than refusing to boot.
      }
    }
    return AiUsageStore._(file, data);
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
