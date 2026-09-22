import 'ai_usage_pricing_anthropic.dart';
import 'ai_usage_pricing_gemini.dart';
import 'ai_usage_pricing_openai.dart';
import 'ai_usage_pricing_rates.dart';
import 'ai_usage_source.dart';

/// Static Mistral API pricing for the models luma's "Luma Support" provider
/// can answer with. Manually maintained snapshot, effective Sep 2026 — needs
/// updating by hand as Mistral changes prices. Keys are slug prefixes, so a
/// `-latest` alias or a dated `-2509` snapshot both resolve. Mistral has no
/// separate cache pricing, so both cache rates are 0.
const Map<String, AiPricingRates> kMistralPricing = {
  'mistral-small': AiPricingRates(input: 0.10, output: 0.30, cacheWrite: 0, cacheRead: 0),
  'mistral-medium': AiPricingRates(input: 0.40, output: 2.00, cacheWrite: 0, cacheRead: 0),
  'mistral-large': AiPricingRates(input: 0.50, output: 1.50, cacheWrite: 0, cacheRead: 0),
  'magistral-small': AiPricingRates(input: 0.50, output: 1.50, cacheWrite: 0, cacheRead: 0),
  'magistral-medium': AiPricingRates(input: 2.00, output: 5.00, cacheWrite: 0, cacheRead: 0),
  'ministral-8b': AiPricingRates(input: 0.10, output: 0.10, cacheWrite: 0, cacheRead: 0),
  'ministral-3b': AiPricingRates(input: 0.04, output: 0.04, cacheWrite: 0, cacheRead: 0),
  'codestral': AiPricingRates(input: 0.30, output: 0.90, cacheWrite: 0, cacheRead: 0),
};

/// Resolves a Mistral slug, longest key first so `magistral-small` is never
/// shadowed. Anything unrecognized — a hosted agent's model, a new release —
/// prices at Mistral Small, the model Luma Support is configured with.
AiPricingRates mistralPricingFor(String model) {
  final m = model.toLowerCase();
  final keysByLengthDesc = kMistralPricing.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final key in keysByLengthDesc) {
    if (m.startsWith(key)) return kMistralPricing[key]!;
  }
  return kMistralPricing['mistral-small']!;
}

/// Which Gemini each rolling `-latest` alias is priced as. Google never says
/// in the response which release an alias resolved to, so this is the one
/// place that guess lives — bump it when Google moves the alias.
const Map<String, String> kGeminiLatestAliases = {
  'flash-lite': 'Gemini 3.5 Flash-Lite',
  'flash': 'Gemini 3.5 Flash',
  'pro': 'Gemini 3.1 Pro',
};

/// Turns a Gemini API slug into the display name [kGeminiPricing] is keyed
/// by: `"gemini-3.5-flash-lite"` -> `"Gemini 3.5 Flash-Lite"`, and a
/// version-less alias like `"gemini-flash-latest"` via
/// [kGeminiLatestAliases]. Null for anything that isn't a Gemini slug.
String? geminiDisplayNameForSlug(String slug) {
  var s = slug.toLowerCase().trim();
  if (s.startsWith('models/')) s = s.substring('models/'.length);
  final match =
      RegExp(r'^gemini-(?:(\d+(?:\.\d+)?)-)?(pro|flash)(-lite)?').firstMatch(s);
  if (match == null) return null;
  final version = match.group(1);
  final tier = '${match.group(2)}${match.group(3) ?? ''}';
  if (version == null) return kGeminiLatestAliases[tier];
  final name = switch (tier) {
    'pro' => 'Pro',
    'flash' => 'Flash',
    _ => 'Flash-Lite',
  };
  return 'Gemini $version $name';
}

/// Pricing for a [AiUsageSource.luma] turn's `"<providerId>/<model>"`.
/// Anthropic and OpenAI reuse the same tables Claude Code and Codex CLI are
/// priced with. Null only for a malformed model string or a Gemini release
/// the Gemini table doesn't know yet.
AiPricingRates? lumaPricingFor(String? model) {
  if (model == null) return null;
  final split = splitLumaModel(model);
  if (split == null) return null;
  final (provider, modelId) = split;
  return switch (provider) {
    'anthropic' => anthropicPricingFor(modelId),
    'openai' => openAiPricingFor(modelId),
    'mistral' => mistralPricingFor(modelId),
    'google' => switch (geminiDisplayNameForSlug(modelId)) {
        final name? => geminiPricingFor(name),
        null => null,
      },
    _ => null,
  };
}

/// Splits a luma turn's stored model into provider and model id — the same
/// `"<provider>/<model>"` shape opencode uses, so it shares that parser.
(String provider, String modelId)? splitLumaModel(String model) =>
    splitOpencodeModel(model);
