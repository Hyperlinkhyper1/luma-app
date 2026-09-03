/// One provider's per-model token rates, in USD per million tokens.
class AiPricingRates {
  const AiPricingRates({
    required this.input,
    required this.output,
    required this.cacheWrite,
    required this.cacheRead,
  });

  final double input;
  final double output;
  final double cacheWrite;
  final double cacheRead;
}

/// Strips a single trailing reasoning-effort parenthetical, e.g.
/// `"Gemini 3.5 Flash (Medium)"` -> `"Gemini 3.5 Flash"`,
/// `"Claude Opus 4.6 (Thinking)"` -> `"Claude Opus 4.6"`. Antigravity
/// appends one of these to whichever model it names in its own UI text;
/// the suffix changes response behavior, not the provider's per-token
/// price, so pricing lookups need it removed first. Returns [model]
/// unchanged if it has no trailing `(...)`.
String stripReasoningEffortSuffix(String model) =>
    model.replaceAll(RegExp(r'\s*\([^()]*\)\s*$'), '').trim();
