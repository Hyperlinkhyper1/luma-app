import 'ai_model.dart';

/// A sortable leaderboard column.
///
/// [help] is the tooltip: these are composite ratings from different
/// upstreams, and a column header that doesn't say what it measures invites
/// people to compare numbers that aren't comparable.
enum AiLeaderboardColumn {
  rank(label: 'RANK', help: 'Position in the current sort'),
  name(
    label: 'MODEL',
    help: 'Model name and the provider that serves it',
    defaultDescending: false,
  ),
  llmStats(
    label: 'LLM STATS',
    help: 'Overall composite rating across every benchmark in the index',
  ),
  coding(
    label: 'CODING',
    help: 'Code generation and repair benchmarks',
  ),
  agent(
    label: 'AGENT',
    help: 'Long-horizon tool use and multi-step task benchmarks',
  ),
  codeArena(
    label: 'CODE ARENA',
    help: 'Head-to-head Elo from human preference on coding tasks',
  ),
  params(
    label: 'PARAMS',
    help: 'Total parameter count, in billions — only known for open-weight '
        'models',
  ),
  context(
    label: 'CONTEXT',
    help: 'Largest prompt the model accepts, in tokens',
  ),
  price(
    label: r'PRICE $/M',
    help: 'Input and output price averaged, in USD per million tokens',
    defaultDescending: false,
  ),
  license(
    label: 'LICENSE',
    help: 'Open padlock means the weights are downloadable',
  );

  const AiLeaderboardColumn({
    required this.label,
    required this.help,
    this.defaultDescending = true,
  });

  final String label;
  final String help;

  /// Which way this column sorts the first time it is clicked. Ratings want
  /// best-first; names and prices want smallest-first.
  final bool defaultDescending;
}

/// Applies the search box, the provider menu and the open-weights toggle, then
/// sorts. Pure, so the leaderboard's ordering rules can be tested without
/// building a widget.
///
/// Models missing the sorted-on value always sink to the bottom regardless of
/// direction: an unrated model is not the *cheapest* or the *best*, it is
/// simply unknown, and letting nulls float to the top of an ascending price
/// sort would put every unpriced model above the genuinely cheap ones.
List<AiModel> filterAndSortModels(
  List<AiModel> models, {
  String query = '',
  String? vendor,
  bool openWeightsOnly = false,
  AiLeaderboardColumn sortBy = AiLeaderboardColumn.llmStats,
  bool descending = true,
}) {
  final needle = query.trim().toLowerCase();
  final rows = [
    for (final m in models)
      if ((vendor == null || m.vendor == vendor) &&
          (!openWeightsOnly || m.openWeights) &&
          (needle.isEmpty ||
              m.name.toLowerCase().contains(needle) ||
              m.vendorName.toLowerCase().contains(needle) ||
              m.id.toLowerCase().contains(needle)))
        m,
  ];

  rows.sort((a, b) {
    // Missing values are settled *before* the direction is applied. Folding
    // them into the comparison instead would put every unpriced model above
    // the genuinely cheap ones the moment the price column flips direction.
    final aValue = _sortValue(a, sortBy);
    final bValue = _sortValue(b, sortBy);
    if (aValue == null || bValue == null) {
      if (aValue == bValue) return _byName(a, b);
      return aValue == null ? 1 : -1;
    }
    final result = aValue.compareTo(bValue);
    if (result != 0) return descending ? -result : result;
    // Ties keep a stable, readable order rather than whatever the sort
    // happened to leave behind.
    return _byName(a, b);
  });
  return rows;
}

/// The value a column sorts on, in its natural ascending order, or null when
/// this model has no value for it.
///
/// Text columns come back as their own comparable so one code path covers
/// every column: [Comparable] rather than a number.
Comparable<Object>? _sortValue(AiModel m, AiLeaderboardColumn column) =>
    switch (column) {
      AiLeaderboardColumn.name => m.name.toLowerCase(),
      // Ascending puts closed models first, so the column's descending
      // default lands on open weights first.
      AiLeaderboardColumn.license => m.openWeights ? 1 : 0,
      AiLeaderboardColumn.rank ||
      AiLeaderboardColumn.llmStats =>
        m.llmStatsIndex,
      AiLeaderboardColumn.coding => m.codingIndex,
      AiLeaderboardColumn.agent => m.agentIndex,
      AiLeaderboardColumn.codeArena => m.codeArena,
      AiLeaderboardColumn.params => m.parametersB,
      AiLeaderboardColumn.context => m.contextTokens,
      AiLeaderboardColumn.price => m.avgPricePerM,
    };

int _byName(AiModel a, AiModel b) =>
    a.name.toLowerCase().compareTo(b.name.toLowerCase());

/// The providers present in [models], as (key, display name), alphabetical by
/// display name — the provider filter's menu.
List<({String key, String name})> vendorsOf(List<AiModel> models) {
  final names = <String, String>{};
  for (final m in models) {
    names[m.vendor] = m.vendorName;
  }
  final entries = [
    for (final e in names.entries) (key: e.key, name: e.value),
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return entries;
}
