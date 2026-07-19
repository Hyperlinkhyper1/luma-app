import 'dart:convert';
import 'dart:io';

/// Per-user AI usage bookkeeping for the shared, operator-funded keys:
///
/// * Google ("Luma AI" modes) chats burn **tokens**, tracked as
///   (timestamp, tokens) events so both rolling windows — 5 hours and 7
///   days — can be summed exactly. Limits live in [kAiTokens5h] /
///   [kAiTokensWeek]; the raw numbers are never sent to clients, only
///   percentages (see Api._aiStatus).
/// * Mistral ("Luma Support") chats burn **messages** — [kSupportMessagesPerDay]
///   per rolling day, counted separately from the token budget.
///
/// Persisted as one JSON file in the data directory; events outside the
/// longest window are pruned on every touch so the file stays tiny.
class AiUsageStore {
  AiUsageStore._(this._file, this._data);

  final File _file;

  /// userId -> {'tokens': [[ms, tokens], ...], 'support': [ms, ...]}
  final Map<String, dynamic> _data;

  static const _tokenWindow = Duration(days: 7);
  static const _supportWindow = Duration(days: 1);

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

  List<List<int>> _tokenEvents(String userId) {
    final raw = _entry(userId)['tokens'] as List? ?? const [];
    final cutoff =
        DateTime.now().subtract(_tokenWindow).millisecondsSinceEpoch;
    return [
      for (final e in raw)
        if (e is List && e.length == 2 && (e[0] as num).toInt() > cutoff)
          [(e[0] as num).toInt(), (e[1] as num).toInt()],
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
  int tokensUsed(String userId, Duration window) {
    final cutoff = DateTime.now().subtract(window).millisecondsSinceEpoch;
    var sum = 0;
    for (final e in _tokenEvents(userId)) {
      if (e[0] > cutoff) sum += e[1];
    }
    return sum;
  }

  /// Luma Support messages this user sent within the trailing day.
  int supportMessagesUsed(String userId) => _supportEvents(userId).length;

  Future<void> recordTokens(String userId, int tokens) async {
    if (tokens <= 0) return;
    final entry = Map<String, dynamic>.from(_entry(userId));
    entry['tokens'] = [
      ..._tokenEvents(userId),
      [DateTime.now().millisecondsSinceEpoch, tokens],
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

  Future<void> _save() async {
    try {
      await _file.writeAsString(jsonEncode(_data), flush: true);
    } catch (_) {
      // Best effort — losing usage history on a disk hiccup only means a
      // user briefly gets more budget, never less.
    }
  }
}
