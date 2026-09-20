import 'package:flutter/widgets.dart';

/// What a pet result actually opens: a built-in section of the app or an
/// installed plugin. Only used to tint/annotate the row — both open the same
/// way.
enum PetTargetKind { section, plugin }

/// One thing the pet can take you to. Built by the shell, which is the only
/// place that knows both the fixed destinations and the installed plugins —
/// see `AppShell`.
@immutable
class PetTarget {
  const PetTarget({
    required this.id,
    required this.label,
    required this.icon,
    required this.kind,
    required this.open,
    this.keywords = const [],
  });

  /// Stable across restarts (`section:3`, `plugin:mind-map`): the recents list
  /// is persisted by id, so it must not be a list position.
  final String id;

  final String label;
  final IconData icon;
  final PetTargetKind kind;

  /// Extra words that should match this target without being shown, so
  /// "money" finds Finance and "todo" finds Errands.
  final List<String> keywords;

  /// Opens the target. The panel closes itself first, so this runs against a
  /// shell that is already back to its normal size.
  final VoidCallback open;
}

/// Scores [label] against [query], both already lowercased. Higher is better;
/// null means no match at all.
///
/// The tiers, in order: the whole label, a prefix of it, the start of any word
/// in it, a substring anywhere, and finally a subsequence (typing "mnmp" for
/// "Mind Map"). Shorter labels win inside a tier, so "Notes" beats
/// "Note-taking plugin" for "note".
int? scorePetLabel(String label, String query) {
  if (query.isEmpty) return 0;
  if (label == query) return 1000;
  if (label.startsWith(query)) return 800 - label.length;
  for (var i = 1; i < label.length; i++) {
    // A word start: the character after a space or separator.
    final prev = label[i - 1];
    if (prev != ' ' && prev != '-' && prev != '_' && prev != '/') continue;
    if (label.startsWith(query, i)) return 600 - label.length;
  }
  if (label.contains(query)) return 400 - label.length;

  // Subsequence: every query character appears in order. Matches that stay
  // bunched together score higher than ones scattered across the label.
  var at = 0;
  var gaps = 0;
  var last = -1;
  for (final rune in query.runes) {
    final found = label.indexOf(String.fromCharCode(rune), at);
    if (found < 0) return null;
    if (last >= 0) gaps += found - last - 1;
    last = found;
    at = found + 1;
  }
  return 200 - gaps;
}

/// Bottom of the band keyword matches are squashed into — clear of the best
/// subsequence match on a real label, and clear below the worst literal one.
const int _keywordBandFloor = 210;

/// Orders [targets] for the given [query].
///
/// With no query this is the recents list (most recent first) followed by
/// everything else in its natural order, so the panel opens on something
/// useful rather than an empty box. With a query it is every target that
/// matches at all, best first, with recently opened targets breaking ties.
List<PetTarget> rankPetTargets(
  List<PetTarget> targets,
  String query, {
  List<String> recentIds = const [],
}) {
  final trimmed = query.trim().toLowerCase();

  int recentRank(PetTarget t) {
    final i = recentIds.indexOf(t.id);
    return i < 0 ? recentIds.length : i;
  }

  if (trimmed.isEmpty) {
    final recent = <PetTarget>[];
    final rest = <PetTarget>[];
    for (final t in targets) {
      (recentIds.contains(t.id) ? recent : rest).add(t);
    }
    recent.sort((a, b) => recentRank(a).compareTo(recentRank(b)));
    return [...recent, ...rest];
  }

  final scored = <({PetTarget target, int score})>[];
  for (final t in targets) {
    var best = scorePetLabel(t.label.toLowerCase(), trimmed);
    for (final keyword in t.keywords) {
      final raw = scorePetLabel(keyword.toLowerCase(), trimmed);
      if (raw == null) continue;
      // Keywords are hidden aliases, so they get their own band: above a
      // scraped-together subsequence match on the label, but below any
      // literal one. Typing "money" should still put a thing actually called
      // "Money jar" above Finance.
      final score = _keywordBandFloor + raw ~/ 10;
      if (best == null || score > best) best = score;
    }
    if (best != null) scored.add((target: t, score: best));
  }

  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    final byRecent = recentRank(a.target).compareTo(recentRank(b.target));
    if (byRecent != 0) return byRecent;
    return a.target.label.compareTo(b.target.label);
  });
  return [for (final s in scored) s.target];
}
