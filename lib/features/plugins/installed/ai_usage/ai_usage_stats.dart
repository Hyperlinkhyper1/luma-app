import 'ai_usage_pricing.dart';
import 'ai_usage_source.dart';
import 'data/ai_usage_database.dart';

/// Quick time-range presets shown in the page's filter bar. `all` has no
/// lower bound.
enum AiUsageRangePreset {
  today('Today'),
  last7Days('7d'),
  last30Days('30d'),
  all('All');

  const AiUsageRangePreset(this.label);
  final String label;
}

/// Resolves [preset] to a `[start, end)` local-time window anchored at [now].
/// A null start means unbounded (used for [AiUsageRangePreset.all]).
(DateTime?, DateTime) resolveAiUsageRange(AiUsageRangePreset preset, DateTime now) {
  final todayStart = DateTime(now.year, now.month, now.day);
  switch (preset) {
    case AiUsageRangePreset.today:
      return (todayStart, now);
    case AiUsageRangePreset.last7Days:
      return (now.subtract(const Duration(days: 7)), now);
    case AiUsageRangePreset.last30Days:
      return (now.subtract(const Duration(days: 30)), now);
    case AiUsageRangePreset.all:
      return (null, now);
  }
}

/// Total usage for one (source, model) pair within a queried range. Keying
/// by the pair — not the model name alone — means same-named models from
/// different sources can never merge, and cost lookups always use the right
/// provider's pricing table.
class ModelUsageTotal {
  const ModelUsageTotal({
    required this.source,
    required this.model,
    required this.turnCount,
    required this.inputTokens,
    required this.outputTokens,
    required this.cacheReadTokens,
    required this.cacheCreationTokens,
    required this.cost,
    required this.billable,
  });

  final AiUsageSource source;
  final String model;
  final int turnCount;
  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final int cacheCreationTokens;
  final double cost;
  final bool billable;

  /// Input + output + first-time cache writes — i.e. tokens that represent
  /// genuinely new content. Deliberately excludes [cacheReadTokens]: a
  /// cache read is Anthropic/OpenAI re-serving context that was already
  /// counted when it was first written, and in a long agentic session the
  /// same growing context gets re-read on nearly every turn — so summing
  /// it in would count the same conversation history over and over and
  /// balloon "tokens used" into something that no longer means "how much
  /// did I use." Cache reads are still real and still billed (at a steep
  /// discount) — see [cacheReadTokens] and [cost], which does include them.
  int get totalTokens => inputTokens + outputTokens + cacheCreationTokens;
}

/// One local calendar day's totals, for the daily bar chart. [day] is local
/// midnight. Carries all four token categories separately (not just a
/// combined total) so the chart can stack them and show the real
/// input/output/cache-read/cache-creation split, per day.
class AiDayUsageBucket {
  const AiDayUsageBucket({
    required this.day,
    required this.inputTokens,
    required this.outputTokens,
    required this.cacheReadTokens,
    required this.cacheCreationTokens,
    required this.cost,
  });

  final DateTime day;
  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final int cacheCreationTokens;
  final double cost;

  /// Same "new tokens only" definition as [ModelUsageTotal.totalTokens] —
  /// excludes [cacheReadTokens].
  int get totalTokens => inputTokens + outputTokens + cacheCreationTokens;
}

/// Fallback label for turns with no derivable project (currently every
/// Antigravity turn, and any Claude Code/Codex turn with a missing/empty
/// `cwd`) — a real, visible row rather than silently dropped.
const String kUnknownProject = 'Unknown project';

/// Total usage for one project (derived from `cwd`, see
/// `ai_usage_project.dart`) within a queried range.
class ProjectUsageTotal {
  const ProjectUsageTotal({
    required this.project,
    required this.turnCount,
    required this.sessionCount,
    required this.inputTokens,
    required this.outputTokens,
    required this.cost,
  });

  final String project;
  final int turnCount;
  final int sessionCount;
  final int inputTokens;
  final int outputTokens;
  final double cost;

  int get totalTokens => inputTokens + outputTokens;
}

/// Total usage for one session (keyed by (source, sessionId) — see
/// [ModelUsageTotal] for why the pair, not the id alone) within a queried
/// range. Backs the leaderboard-style "longest/priciest session" stats.
class SessionUsageTotal {
  const SessionUsageTotal({
    required this.sessionId,
    required this.source,
    required this.project,
    required this.turnCount,
    required this.start,
    required this.end,
    required this.cost,
  });

  final String sessionId;
  final AiUsageSource source;
  final String? project;
  final int turnCount;

  /// Timestamp of this session's first and last turn — not necessarily
  /// "active" time throughout (a resumed session can have a long idle gap
  /// in the middle), so [duration] is a wall-clock span, not time-on-task.
  final DateTime start;
  final DateTime end;
  final double cost;

  Duration get duration => end.difference(start);
}

/// One local hour-of-day's average activity, for the peak-hours chart.
/// [hour] is 0-23, local time.
class AiHourlyUsageBucket {
  const AiHourlyUsageBucket({
    required this.hour,
    required this.totalTurns,
    required this.avgTurns,
    required this.avgTokens,
  });

  final int hour;
  final int totalTurns;

  /// [totalTurns] divided by the number of distinct local calendar days
  /// present anywhere in the aggregated turns (not the selected range's
  /// full length) — see `aggregateByHour`.
  final double avgTurns;

  /// This hour's average "new tokens" per day (same input + output +
  /// cache-write definition as [ModelUsageTotal.totalTokens]) — what "peak
  /// hours" is actually judged on, since a heavy hour isn't always a
  /// high-turn-count one.
  final double avgTokens;
}

/// Range-wide summary shown in the stat tiles.
class AiUsageTotals {
  const AiUsageTotals({
    required this.turnCount,
    required this.sessionCount,
    required this.totalTokens,
    required this.cacheReadTokens,
    required this.cost,
    required this.hasUnbillable,
  });

  final int turnCount;
  final int sessionCount;

  /// New tokens only (input + output + cache writes) — see
  /// [ModelUsageTotal.totalTokens] for why cache reads are excluded here.
  final int totalTokens;

  /// Cached context re-read across all turns in range — shown as its own
  /// stat rather than folded into [totalTokens]; still factored into
  /// [cost] at the provider's discounted cache-read rate.
  final int cacheReadTokens;
  final double cost;

  /// Whether any turn in range came from a model outside its provider's
  /// known pricing table — drives the cost tile's "*" footnote.
  final bool hasUnbillable;
}

int _totalTokensFor(AiUsageTurn t) =>
    t.inputTokens + t.outputTokens + t.cacheCreationTokens;

/// Totals per (source, model) pair across [turns], sorted by descending
/// token count.
List<ModelUsageTotal> aggregateByModel(Iterable<AiUsageTurn> turns) {
  final byKey = <(AiUsageSource, String), List<AiUsageTurn>>{};
  for (final t in turns) {
    byKey.putIfAbsent((t.source, t.model), () => []).add(t);
  }

  final totals = [
    for (final entry in byKey.entries)
      ModelUsageTotal(
        source: entry.key.$1,
        model: entry.key.$2,
        turnCount: entry.value.length,
        inputTokens: entry.value.fold(0, (a, t) => a + t.inputTokens),
        outputTokens: entry.value.fold(0, (a, t) => a + t.outputTokens),
        cacheReadTokens: entry.value.fold(0, (a, t) => a + t.cacheReadTokens),
        cacheCreationTokens:
            entry.value.fold(0, (a, t) => a + t.cacheCreationTokens),
        cost: entry.value.fold(
          0.0,
          (a, t) => a +
              costForTurn(t.source, t.model, t.inputTokens, t.outputTokens,
                  t.cacheReadTokens, t.cacheCreationTokens),
        ),
        billable: isBillableModel(entry.key.$1, entry.key.$2),
      ),
  ];
  totals.sort((a, b) => b.totalTokens.compareTo(a.totalTokens));
  return totals;
}

/// Buckets [turns] by local calendar day, for the daily bar chart. Days with
/// no turns are omitted; callers wanting a continuous axis fill gaps
/// themselves.
List<AiDayUsageBucket> aggregateByDay(Iterable<AiUsageTurn> turns) {
  final inputByDay = <DateTime, int>{};
  final outputByDay = <DateTime, int>{};
  final cacheReadByDay = <DateTime, int>{};
  final cacheCreationByDay = <DateTime, int>{};
  final costByDay = <DateTime, double>{};

  for (final t in turns) {
    final local = t.timestamp.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    inputByDay.update(day, (v) => v + t.inputTokens, ifAbsent: () => t.inputTokens);
    outputByDay.update(day, (v) => v + t.outputTokens, ifAbsent: () => t.outputTokens);
    cacheReadByDay.update(day, (v) => v + t.cacheReadTokens,
        ifAbsent: () => t.cacheReadTokens);
    cacheCreationByDay.update(day, (v) => v + t.cacheCreationTokens,
        ifAbsent: () => t.cacheCreationTokens);
    final cost = costForTurn(t.source, t.model, t.inputTokens, t.outputTokens,
        t.cacheReadTokens, t.cacheCreationTokens);
    costByDay.update(day, (v) => v + cost, ifAbsent: () => cost);
  }

  final buckets = [
    for (final day in inputByDay.keys)
      AiDayUsageBucket(
        day: day,
        inputTokens: inputByDay[day]!,
        outputTokens: outputByDay[day]!,
        cacheReadTokens: cacheReadByDay[day]!,
        cacheCreationTokens: cacheCreationByDay[day]!,
        cost: costByDay[day]!,
      ),
  ];
  buckets.sort((a, b) => a.day.compareTo(b.day));
  return buckets;
}

/// Totals per project (derived from `cwd`; see `ai_usage_project.dart`)
/// across [turns], sorted by descending token count. Turns with no
/// derivable project (`t.project == null`) fold into [kUnknownProject]
/// rather than being dropped.
List<ProjectUsageTotal> aggregateByProject(Iterable<AiUsageTurn> turns) {
  final byProject = <String, List<AiUsageTurn>>{};
  for (final t in turns) {
    byProject.putIfAbsent(t.project ?? kUnknownProject, () => []).add(t);
  }

  final totals = [
    for (final entry in byProject.entries)
      ProjectUsageTotal(
        project: entry.key,
        turnCount: entry.value.length,
        sessionCount: entry.value.map((t) => t.sessionId).toSet().length,
        inputTokens: entry.value.fold(0, (a, t) => a + t.inputTokens),
        outputTokens: entry.value.fold(0, (a, t) => a + t.outputTokens),
        cost: entry.value.fold(
          0.0,
          (a, t) => a +
              costForTurn(t.source, t.model, t.inputTokens, t.outputTokens,
                  t.cacheReadTokens, t.cacheCreationTokens),
        ),
      ),
  ];
  totals.sort((a, b) => b.totalTokens.compareTo(a.totalTokens));
  return totals;
}

/// Totals per session (keyed by (source, sessionId)) across [turns], sorted
/// by descending cost. Backs the "longest session" / "priciest session"
/// leaderboard stats.
List<SessionUsageTotal> aggregateBySession(Iterable<AiUsageTurn> turns) {
  final byKey = <(AiUsageSource, String), List<AiUsageTurn>>{};
  for (final t in turns) {
    byKey.putIfAbsent((t.source, t.sessionId), () => []).add(t);
  }

  final sessions = [
    for (final entry in byKey.entries)
      SessionUsageTotal(
        sessionId: entry.key.$2,
        source: entry.key.$1,
        project: entry.value.first.project,
        turnCount: entry.value.length,
        start: entry.value.map((t) => t.timestamp).reduce((a, b) => a.isBefore(b) ? a : b),
        end: entry.value.map((t) => t.timestamp).reduce((a, b) => a.isAfter(b) ? a : b),
        cost: entry.value.fold(
          0.0,
          (a, t) => a +
              costForTurn(t.source, t.model, t.inputTokens, t.outputTokens,
                  t.cacheReadTokens, t.cacheCreationTokens),
        ),
      ),
  ];
  sessions.sort((a, b) => b.cost.compareTo(a.cost));
  return sessions;
}

/// The longest run of consecutive local calendar days with at least one
/// turn anywhere in [turns]. [days] is 0 when [turns] is empty, in which
/// case [start]/[end] are null.
({int days, DateTime? start, DateTime? end}) longestActiveDayStreak(
  Iterable<AiUsageTurn> turns,
) {
  final activeDays = <DateTime>{};
  for (final t in turns) {
    final local = t.timestamp.toLocal();
    activeDays.add(DateTime(local.year, local.month, local.day));
  }
  if (activeDays.isEmpty) return (days: 0, start: null, end: null);

  final sorted = activeDays.toList()..sort();
  var bestLen = 1, bestStart = 0;
  var curLen = 1, curStart = 0;
  for (var i = 1; i < sorted.length; i++) {
    if (sorted[i].difference(sorted[i - 1]).inDays == 1) {
      curLen++;
    } else {
      curLen = 1;
      curStart = i;
    }
    if (curLen > bestLen) {
      bestLen = curLen;
      bestStart = curStart;
    }
  }
  return (days: bestLen, start: sorted[bestStart], end: sorted[bestStart + bestLen - 1]);
}

/// Averages [turns] by local hour-of-day (0-23, always all 24 returned,
/// empty hours included as 0). Each hour's average divides by the number of
/// distinct local calendar days present anywhere in [turns] — not the
/// selected range's full length — so a hand-picked range with mostly-empty
/// days doesn't dilute the average toward zero. Today counts the moment it
/// has any turn, the same as any other day; hours later than the current
/// time-of-day are correctly 0 for today (they haven't happened yet) but
/// still share that day's place in the denominator — a small, inherent
/// downward skew for whichever hours haven't happened yet today that
/// shrinks as more days accumulate in the range.
List<AiHourlyUsageBucket> aggregateByHour(Iterable<AiUsageTurn> turns) {
  final turnsByHour = List<int>.filled(24, 0);
  final tokensByHour = List<int>.filled(24, 0);
  final days = <DateTime>{};

  for (final t in turns) {
    final local = t.timestamp.toLocal();
    turnsByHour[local.hour]++;
    tokensByHour[local.hour] += _totalTokensFor(t);
    days.add(DateTime(local.year, local.month, local.day));
  }

  final dayCount = days.isEmpty ? 1 : days.length;
  return [
    for (var hour = 0; hour < 24; hour++)
      AiHourlyUsageBucket(
        hour: hour,
        totalTurns: turnsByHour[hour],
        avgTurns: turnsByHour[hour] / dayCount,
        avgTokens: tokensByHour[hour] / dayCount,
      ),
  ];
}

/// Range-wide summary across [turns].
AiUsageTotals totals(Iterable<AiUsageTurn> turns) {
  var turnCount = 0;
  var totalTokens = 0;
  var cacheReadTokens = 0;
  var cost = 0.0;
  var hasUnbillable = false;
  final sessions = <String>{};

  for (final t in turns) {
    turnCount++;
    totalTokens += _totalTokensFor(t);
    cacheReadTokens += t.cacheReadTokens;
    cost += costForTurn(t.source, t.model, t.inputTokens, t.outputTokens,
        t.cacheReadTokens, t.cacheCreationTokens);
    if (!isBillableModel(t.source, t.model)) hasUnbillable = true;
    sessions.add(t.sessionId);
  }

  return AiUsageTotals(
    turnCount: turnCount,
    sessionCount: sessions.length,
    totalTokens: totalTokens,
    cacheReadTokens: cacheReadTokens,
    cost: cost,
    hasUnbillable: hasUnbillable,
  );
}
