import 'dart:convert';

import 'ai_mode_routing.dart';
import 'ai_usage_store.dart';

Future<void> recordBenchmarkGenerationUsage(
  AiUsageStore store,
  Map<String, String> userIdsByEmail,
  AiModeRoute route,
  AiCallUsage usage,
) async {
  final ownerId = userIdsByEmail['aydenjue@outlook.com'];
  if (ownerId == null || usage.totalTokens <= 0) return;
  await store.recordCall(ownerId,
      feature: 'Add benchmark',
      upstream: route.upstream.label,
      model: route.model,
      usage: usage,
      includeInUsage: true);
}

/// Helpers for the dashboard's "Add benchmark": reading a streamed
/// chat completion, pulling the page out of the reply and naming the new
/// roster entry the way hand uploads are named. The job itself (HTTP,
/// storage, GitHub) lives in `api_benchmark_generate.dart`.

/// Reasoning efforts "Add benchmark" offers, and how each reads in the
/// entry's name: `Sonnet 5.5 (High)`. Empty leaves the model's default;
/// `none` turns reasoning off, and neither adds a suffix.
const kBenchmarkEfforts = <String, String>{
  '': '',
  'none': '',
  'minimal': 'Minimal',
  'low': 'Low',
  'medium': 'Medium',
  'high': 'High',
  'xhigh': 'Xhigh',
};

/// The page in a model's [reply], or null when there is none. Prefers the
/// longest fenced block that holds a page (models fence despite being told
/// not to), else the span from `<!doctype`/`<html` to the last `</html>`,
/// or to the end of the reply when the closing tag never came.
String? extractBenchmarkHtml(String reply) {
  final text = reply.replaceAll(
      RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '');
  String? best;
  for (final m in RegExp(r'```[A-Za-z0-9_-]*[ \t]*\r?\n([\s\S]*?)```')
      .allMatches(text)) {
    final body = m.group(1)!.trim();
    if (_pageStart(body) != null &&
        (best == null || body.length > best.length)) {
      best = body;
    }
  }
  if (best != null) return best;
  final start = _pageStart(text);
  if (start == null) return null;
  final end = text.toLowerCase().lastIndexOf('</html>');
  final page =
      end > start ? text.substring(start, end + 7) : text.substring(start);
  return page.trim();
}

int? _pageStart(String s) {
  final m =
      RegExp(r'<!doctype html|<html[\s>]', caseSensitive: false).firstMatch(s);
  return m?.start;
}

/// Whether [page] ends with its closing tag. A page cut off by the token
/// limit doesn't.
bool benchmarkHtmlComplete(String page) =>
    page.toLowerCase().trimRight().endsWith('</html>');

/// The roster name for [modelName] at [effort]: OpenRouter's
/// "Anthropic: Claude Sonnet 5.5" loses its company prefix (the vendor badge
/// shows that) and gains the effort, "Claude Sonnet 5.5 (High)".
String benchmarkDisplayName(String modelName, String effort) {
  var name = modelName.trim();
  final colon = name.indexOf(': ');
  if (colon > 0 && colon < 30) name = name.substring(colon + 2).trim();
  final label = kBenchmarkEfforts[effort] ?? '';
  final full = label.isEmpty ? name : '$name ($label)';
  return full.length > 80 ? full.substring(0, 80).trim() : full;
}

/// The app's vendor key for [modelId] on [upstream], or '' to let the app
/// work it out from the name. OpenRouter ids carry it as their first
/// segment (`x-ai/grok-5`); it only counts when the app knows the company.
String benchmarkVendorFor(
    AiUpstream upstream, String modelId, Set<String> known) {
  final String key = switch (upstream) {
    AiUpstream.google => 'google',
    AiUpstream.mistral => 'mistralai',
    AiUpstream.openrouter =>
      modelId.contains('/') ? modelId.substring(0, modelId.indexOf('/')) : '',
  };
  return known.contains(key) ? key : '';
}

/// The id slug the upload dialog derives from a model name, matching its
/// JavaScript `slug()`: "Sonnet 5.5 (High)" → `sonnet_55`.
String benchmarkSlug(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'\([^)]*\)'), ' ')
    .replaceAll('.', '')
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

/// A fresh scene id for [kind]: `pagoda_sonnet_55_high`, or with `_2`,
/// `_3`… when [taken] already has it, so a new run never overwrites an
/// existing contestant.
String benchmarkSceneId(
    String kind, String displayName, String effort, Set<String> taken) {
  final effortPart = (kBenchmarkEfforts[effort] ?? '').isEmpty ? '' : effort;
  var base = [kind, benchmarkSlug(displayName), effortPart]
      .where((p) => p.isNotEmpty)
      .join('_');
  if (base == kind) base = '${kind}_model';
  if (base.length > 74)
    base = base.substring(0, 74).replaceAll(RegExp(r'_+$'), '');
  if (!taken.contains(base)) return base;
  for (var n = 2;; n++) {
    final id = '${base}_$n';
    if (!taken.contains(id)) return id;
  }
}

/// Collects a streamed OpenAI-style chat completion (server-sent events,
/// one `data: {…}` line per chunk) as it arrives. All three upstreams
/// speak this shape; reasoning shows up as `reasoning` (OpenRouter) or
/// `reasoning_content` (Google, Mistral) and only counts toward progress.
class ChatStreamAccumulator {
  final StringBuffer _content = StringBuffer();
  int reasoningChars = 0;
  String? finishReason;
  AiCallUsage usage = const AiCallUsage();
  int get tokens => usage.totalTokens;
  String? error;
  bool done = false;

  String get content => _content.toString();
  int get contentChars => _content.length;

  void addLine(String line) {
    if (!line.startsWith('data:')) return;
    final data = line.substring(5).trim();
    if (data.isEmpty) return;
    if (data == '[DONE]') {
      done = true;
      return;
    }
    Object? chunk;
    try {
      chunk = jsonDecode(data);
    } on FormatException {
      return;
    }
    if (chunk is! Map) return;
    final err = chunk['error'];
    if (err is Map) {
      error = '${err['message'] ?? err['code'] ?? 'Upstream error'}';
    } else if (err is String) {
      error = err;
    }
    if (chunk['usage'] is Map || chunk['usageMetadata'] is Map) {
      usage = AiCallUsage.parse(data);
    }
    final choices = chunk['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) return;
    final choice = choices.first as Map;
    final delta = choice['delta'];
    if (delta is Map) {
      final c = delta['content'];
      if (c is String) _content.write(c);
      for (final k in const ['reasoning', 'reasoning_content']) {
        final r = delta[k];
        if (r is String) reasoningChars += r.length;
      }
    }
    final reason = choice['finish_reason'];
    if (reason is String && reason.isNotEmpty) finishReason = reason;
  }
}
