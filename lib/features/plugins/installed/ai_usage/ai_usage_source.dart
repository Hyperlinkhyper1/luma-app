/// Which local coding CLI a stored [AiUsageTurn] came from — determines
/// which provider's pricing table applies.
///
/// [antigravity] is a different kind of source from the others: Google
/// Antigravity's local logs don't record token counts at all, only message
/// text. Its turns carry an *estimated* token count derived from message
/// length (~4 chars/token), never an exact metered count. Cost is priced
/// only when the detected model matches a known Gemini or Claude family
/// (see `ai_usage_pricing.dart`'s `_antigravityPricingFor`) and is always
/// shown more tentatively than Claude Code/Codex's exact figures — see
/// `antigravity_scanner.dart` and `_displayName`/the `~` cost prefix in
/// `ai_usage_page.dart` for how this is surfaced distinctly in the UI.
///
/// [opencode] is unique in that a single turn can go through *any*
/// configured provider, not just one fixed to the tool itself. Its scanner
/// stores the turn's model as `"<providerID>/<modelID>"` (e.g.
/// `"anthropic/claude-opus-4-6"`) so pricing/display can route per-turn by
/// provider — see `opencode_scanner.dart`.
enum AiUsageSource { claudeCode, codexCli, antigravity, opencode }

/// Reasoning-effort tier a turn was run at — the same tiers Claude Code
/// itself uses. Claude Code is the only source that records one, so turns
/// from the other sources store null.
///
/// A closed set, stored via `textEnum` like [AiUsageSource] rather than as a
/// free string, so the UI's switch over it is exhaustive and no display code
/// has to defend against blanks or unknown spellings. `effortFromLog`
/// is the single place a raw log value is turned into one of these.
enum AiEffort { minimal, low, medium, high, xhigh, max }

/// Parses the raw `effort` field of a Claude Code JSONL record. Returns null
/// for absent, blank, or unrecognised values — all of which display as
/// "Unspecified" rather than inventing a tier.
AiEffort? effortFromLog(String? raw) {
  if (raw == null) return null;
  final normalized = raw.trim().toLowerCase();
  for (final effort in AiEffort.values) {
    if (effort.name == normalized) return effort;
  }
  return null;
}
