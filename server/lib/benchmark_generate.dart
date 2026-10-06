import 'dart:convert';
import 'dart:io';

import 'ai_mode_routing.dart';
import 'ai_usage_store.dart';

/// Restarts one interrupted transport without joining two generated pages.
/// Provider errors and completed model responses are never retried.
Future<T> retryBenchmarkStream<T>(
  ChatStreamAccumulator acc,
  Future<T> Function() request, {
  required bool Function() canRetry,
  required Future<void> Function() beforeRetry,
}) async {
  for (var attempt = 0;; attempt++) {
    try {
      return await request();
    } on IOException {
      if (attempt >= 1 ||
          !canRetry() ||
          acc.done ||
          acc.finishReason != null ||
          acc.error != null) {
        rethrow;
      }
      await beforeRetry();
      if (!canRetry()) rethrow;
      acc.reset();
    }
  }
}

/// EOF without a terminal event is a broken stream, even if HTTP was 200.
void checkBenchmarkStreamEnd(ChatStreamAccumulator acc) {
  if (!acc.done && acc.finishReason == null && acc.error == null) {
    throw const HttpException('Connection closed before generation finished');
  }
}

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

/// Whether [page] ends with its closing tag. This validation alone cannot
/// establish why an incomplete response ended.
bool benchmarkHtmlComplete(String page) =>
    page.toLowerCase().trimRight().endsWith('</html>');

typedef BenchmarkGenerationResult = ({
  String status,
  String reason,
  String validation
});

BenchmarkGenerationResult benchmarkGenerationResult({
  required String reply,
  String? finishReason,
  String? nativeFinishReason,
  int? httpStatus,
  String? error,
}) {
  final page = extractBenchmarkHtml(reply);
  final validation = page == null
      ? 'No HTML page'
      : benchmarkHtmlComplete(page)
          ? 'Closing </html> present'
          : 'Missing closing </html>';
  final finish = finishReason?.trim().toUpperCase();
  const limits = {'LENGTH', 'MAX_TOKENS', 'MAX_OUTPUT_TOKENS'};
  if (limits.contains(finish) ||
      limits.contains(nativeFinishReason?.trim().toUpperCase())) {
    return (
      status: 'TRUNCATED',
      reason: 'Output limit reached',
      validation: validation
    );
  }
  if (httpStatus == 429) {
    return (
      status: 'RATE_LIMITED',
      reason: error ?? 'Provider rate limit reached',
      validation: validation
    );
  }
  if (httpStatus == 503 || httpStatus == 502 || httpStatus == 529) {
    return (
      status: 'PROVIDER_BUSY',
      reason: error ?? 'Provider temporarily unavailable',
      validation: validation
    );
  }
  if (error != null || (httpStatus != null && httpStatus != 200)) {
    return (
      status: 'MODEL_ERROR',
      reason: error ?? 'Provider returned HTTP $httpStatus',
      validation: validation
    );
  }
  if (page == null || !benchmarkHtmlComplete(page)) {
    return (
      status: 'INVALID_OUTPUT',
      reason: finishReason == null
          ? 'Incomplete or invalid HTML; termination cause unknown'
          : 'Incomplete or invalid HTML',
      validation: validation,
    );
  }
  if (finish != null && finish != 'STOP') {
    return (
      status: 'MODEL_ERROR',
      reason: 'Provider ended generation: $finishReason',
      validation: validation
    );
  }
  return (
    status: 'PASS',
    reason: 'HTML completion checks passed',
    validation: validation
  );
}

/// The roster name for [modelName] at [effort]: OpenRouter's
/// "Anthropic: Claude Sonnet 5.5" loses its company prefix (the vendor badge
/// shows that) and gains the effort, "Claude Sonnet 5.5 (High)".
String benchmarkDisplayName(String modelName, String effort) {
  var name = modelName.trim();
  final colon = name.indexOf(': ');
  if (colon > 0 && colon < 30) name = name.substring(colon + 2).trim();
  name = name.replaceFirst(RegExp(r'\s*\(batch\)$', caseSensitive: false), '');
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
  String? nativeFinishReason;
  AiCallUsage usage = const AiCallUsage();
  int get tokens => usage.totalTokens;
  String? error;
  int? errorCode;
  int? providerStatus;
  bool done = false;

  String get content => _content.toString();
  int get contentChars => _content.length;

  void reset() {
    _content.clear();
    reasoningChars = 0;
    finishReason = null;
    nativeFinishReason = null;
    usage = const AiCallUsage();
    error = null;
    errorCode = null;
    providerStatus = null;
    done = false;
  }

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
      errorCode = int.tryParse('${err['code']}');
    } else if (err is String) {
      error = err;
    }
    if (chunk['usage'] is Map || chunk['usageMetadata'] is Map) {
      usage = AiCallUsage.parse(data);
    }
    _addGoogleCandidates(chunk);
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
    if (choice['native_finish_reason'] is String)
      nativeFinishReason = choice['native_finish_reason'] as String;
    final reason = choice['finish_reason'] ??
        choice['finishReason'] ??
        choice['native_finish_reason'];
    if (reason is String && reason.isNotEmpty) finishReason = reason;
  }

  /// Takes a whole, non-streamed chat completion body at once, the shape a
  /// batch result carries.
  void addCompletion(Map body) {
    final err = body['error'];
    if (err is Map) {
      error = '${err['message'] ?? err['code'] ?? 'Upstream error'}';
      errorCode = int.tryParse('${err['code']}');
    } else if (err is String) {
      error = err;
    }
    if (body['usage'] is Map || body['usageMetadata'] is Map)
      usage = AiCallUsage.parse(jsonEncode(body));
    _addGoogleCandidates(body);
    final choices = body['choices'];
    if (choices is List && choices.isNotEmpty && choices.first is Map) {
      final choice = choices.first as Map;
      final message = choice['message'];
      if (message is Map) {
        final c = message['content'];
        if (c is String) _content.write(c);
        for (final k in const ['reasoning', 'reasoning_content']) {
          final r = message[k];
          if (r is String) reasoningChars += r.length;
        }
      }
      if (choice['native_finish_reason'] is String)
        nativeFinishReason = choice['native_finish_reason'] as String;
      final reason = choice['finish_reason'] ??
          choice['finishReason'] ??
          choice['native_finish_reason'];
      if (reason is String && reason.isNotEmpty) finishReason = reason;
    }
    done = true;
  }

  void _addGoogleCandidates(Map body) {
    if (body['choices'] is List && (body['choices'] as List).isNotEmpty) return;
    final candidates = body['candidates'];
    if (candidates is! List || candidates.isEmpty || candidates.first is! Map)
      return;
    final candidate = candidates.first as Map;
    final reason = candidate['finishReason'];
    if (reason is String && reason.isNotEmpty) finishReason = reason;
    final content = candidate['content'];
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List) return;
    for (final part in parts) {
      if (part is! Map || part['text'] is! String) continue;
      final text = part['text'] as String;
      if (part['thought'] == true) {
        reasoningChars += text.length;
      } else {
        _content.write(text);
      }
    }
  }
}

/// OpenRouter's suffix for a model's half-price batch variant
/// (`anthropic/claude-sonnet-5.5:batch`). Those only run through its async
/// Batch API, never the streamed chat endpoint.
const kBenchmarkBatchSuffix = ':batch';

/// Whether [modelId] on [upstream] has to go through OpenRouter's Batch API.
bool isBenchmarkBatchModel(AiUpstream upstream, String modelId) =>
    upstream == AiUpstream.openrouter &&
    modelId.endsWith(kBenchmarkBatchSuffix) &&
    modelId.length > kBenchmarkBatchSuffix.length;

/// The model slug a batch is submitted under: the batch variant's base
/// model, which OpenRouter then routes to one of its `:batch` endpoints.
String benchmarkBatchBaseModel(String modelId) =>
    modelId.endsWith(kBenchmarkBatchSuffix)
        ? modelId.substring(0, modelId.length - kBenchmarkBatchSuffix.length)
        : modelId;

/// Batch statuses OpenRouter never moves on from.
const kBenchmarkBatchTerminal = {'completed', 'failed', 'expired', 'cancelled'};

/// Reads a finished OpenRouter batch object (`GET /batches/{id}`) holding
/// the one scene request into [acc], as if it had been streamed. Returns
/// why it produced nothing usable, or null when [acc] now holds the reply.
String? readBenchmarkBatch(Map batch, ChatStreamAccumulator acc) {
  String? message(Object? err) {
    if (err is Map) {
      acc.errorCode ??= int.tryParse('${err['code']}');
      final m = err['message'] ?? err['code'];
      return m == null ? null : '$m';
    }
    return err is String && err.isNotEmpty ? err : null;
  }

  // The batch's own usage carries what OpenRouter actually charged.
  void batchUsage() {
    final usage = batch['usage'];
    if (usage is Map && usage.isNotEmpty) {
      acc.usage = AiCallUsage.parse(jsonEncode({'usage': usage}));
    }
  }

  batchUsage();
  final status = batch['status'];
  if (status != 'completed') {
    final why = message(batch['error']);
    final label = status is String ? status : 'unknown';
    return 'The batch ended $label${why == null ? '' : ': $why'}.';
  }
  final results = batch['results'];
  final result = results is List && results.isNotEmpty && results.first is Map
      ? results.first as Map
      : null;
  if (result == null) return 'The batch finished with no result.';
  final failed = message(result['error']);
  if (failed != null) return failed;
  final response = result['response'];
  final body = response is Map ? response['body'] : null;
  if (body is! Map) return 'The batch result holds no response.';
  final code = response is Map ? response['status_code'] : null;
  acc.providerStatus = code is num ? code.toInt() : null;
  if (code is num && code != 200) {
    return 'HTTP ${code.toInt()}${message(body['error']) == null ? '' : ': ${message(body['error'])}'}';
  }
  acc.addCompletion(body);
  batchUsage();
  return null;
}
