/// Which local coding CLI a stored [AiUsageTurn] came from — determines
/// which provider's pricing table applies.
///
/// [antigravity] is a different kind of source from the other two: Google
/// Antigravity's local logs don't record token counts at all, only message
/// text. Its turns carry an *estimated* token count derived from message
/// length (~4 chars/token), never an exact metered count. Cost is priced
/// only when the detected model matches a known Gemini or Claude family
/// (see `ai_usage_pricing.dart`'s `_antigravityPricingFor`) and is always
/// shown more tentatively than Claude Code/Codex's exact figures — see
/// `antigravity_scanner.dart` and `_displayName`/the `~` cost prefix in
/// `ai_usage_page.dart` for how this is surfaced distinctly in the UI.
enum AiUsageSource { claudeCode, codexCli, antigravity }
