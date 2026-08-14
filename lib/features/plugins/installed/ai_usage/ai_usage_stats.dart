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

  int get totalTokens =>
      inputTokens + outputTokens + cacheReadTokens + cacheCreationTokens;
}

/// One local calendar day's totals, for the daily bar chart. [day] is local
/// midnight.
class AiDayUsageBucket {
  const AiDayUsageBucket({
    required this.day,
    required this.totalTokens,
    required this.cost,
  });

  final DateTime day;
  final int totalTokens;
  final double cost;
}

/// Range-wide summary shown in the stat tiles.
class AiUsageTotals {
  const AiUsageTotals({
    required this.turnCount,
    required this.sessionCount,
    required this.totalTokens,
    required this.cost,
    required this.hasUnbillable,
  });

  final int turnCount;
  final int sessionCount;
  final int totalTokens;
  final double cost;

  /// Whether any turn in range came from a model outside its provider's
  /// known pricing table — drives the cost tile's "*" footnote.
  final bool hasUnbillable;
}

int _totalTokensFor(AiUsageTurn t) =>
    t.inputTokens + t.outputTokens + t.cacheReadTokens + t.cacheCreationTokens;

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
  final tokensByDay = <DateTime, int>{};
  final costByDay = <DateTime, double>{};

  for (final t in turns) {
    final local = t.timestamp.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    tokensByDay.update(day, (v) => v + _totalTokensFor(t),
        ifAbsent: () => _totalTokensFor(t));
    final cost = costForTurn(t.source, t.model, t.inputTokens, t.outputTokens,
        t.cacheReadTokens, t.cacheCreationTokens);
    costByDay.update(day, (v) => v + cost, ifAbsent: () => cost);
  }

  final buckets = [
    for (final day in tokensByDay.keys)
      AiDayUsageBucket(
        day: day,
        totalTokens: tokensByDay[day]!,
        cost: costByDay[day]!,
      ),
  ];
  buckets.sort((a, b) => a.day.compareTo(b.day));
  return buckets;
}

/// Range-wide summary across [turns].
AiUsageTotals totals(Iterable<AiUsageTurn> turns) {
  var turnCount = 0;
  var totalTokens = 0;
  var cost = 0.0;
  var hasUnbillable = false;
  final sessions = <String>{};

  for (final t in turns) {
    turnCount++;
    totalTokens += _totalTokensFor(t);
    cost += costForTurn(t.source, t.model, t.inputTokens, t.outputTokens,
        t.cacheReadTokens, t.cacheCreationTokens);
    if (!isBillableModel(t.source, t.model)) hasUnbillable = true;
    sessions.add(t.sessionId);
  }

  return AiUsageTotals(
    turnCount: turnCount,
    sessionCount: sessions.length,
    totalTokens: totalTokens,
    cost: cost,
    hasUnbillable: hasUnbillable,
  );
}
