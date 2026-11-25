import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'ai_mode_routing.dart';
import 'ai_usage_store.dart';

/// Restarts an automatically sized generation after the provider reports an
/// output limit, allowing the caller to request a more compact response.
/// The caller records each attempt and resets [acc] in [beforeRetry].
Future<T> retryBenchmarkCompacted<T>(
  ChatStreamAccumulator acc,
  Future<T> Function() request, {
  required int Function() attempt,
  required bool autoCompact,
  required bool Function() canRetry,
  required bool Function(T) isSuccess,
  required Future<void> Function() beforeRetry,
}) async {
  while (true) {
    final result = await request();
    if (!autoCompact ||
        attempt() >= 2 ||
        !canRetry() ||
        !isSuccess(result) ||
        acc.error != null ||
        !benchmarkWasTruncated(acc)) {
      return result;
    }
    await beforeRetry();
    if (!canRetry()) return result;
  }
}

/// How long to wait before each automatic restart of a run whose upstream
/// failed on its own end; its length is the number of restarts.
const kBenchmarkRetryBackoff = [Duration(seconds: 20), Duration(seconds: 60)];

/// The waits used instead when the upstream answered 429 without saying how
/// long to wait: free endpoints rate-limit for minutes, not seconds, so the
/// regular backoff only spends the restart on another 429.
const kBenchmarkRateLimitBackoff = [Duration(minutes: 2), Duration(minutes: 5)];

/// A longer upstream cooldown ends the run with its rate-limit error.
const kBenchmarkMaxRetryWait = Duration(minutes: 10);

class BenchmarkRateLimit {
  const BenchmarkRateLimit({
    this.retryAfter,
    this.reset,
    this.dailyQuotaExhausted = false,
  });

  factory BenchmarkRateLimit.fromError(Object? error,
      {String? retryAfter, String? reset}) {
    final metadata = error is Map ? error['metadata'] : null;
    final headers = metadata is Map ? metadata['headers'] : null;
    String? header(String name) {
      if (headers is! Map) return null;
      for (final entry in headers.entries) {
        if (entry.key.toString().toLowerCase() == name) {
          return entry.value?.toString();
        }
      }
      return null;
    }

    return BenchmarkRateLimit(
      retryAfter: retryAfter ?? header(HttpHeaders.retryAfterHeader),
      reset: reset ?? header('x-ratelimit-reset'),
      dailyQuotaExhausted: metadata is Map &&
          metadata['limit_source'] == 'openrouter_free_tier_daily',
    );
  }

  factory BenchmarkRateLimit.fromResponse(String body, HttpHeaders headers) {
    Object? error;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) error = decoded['error'];
    } on FormatException {
      // Some providers return plain text. The response headers still apply.
    }
    return BenchmarkRateLimit.fromError(error,
        retryAfter: headers.value(HttpHeaders.retryAfterHeader),
        reset: headers.value('x-ratelimit-reset'));
  }

  final String? retryAfter;
  final String? reset;
  final bool dailyQuotaExhausted;
}

/// How long to wait before restart [attempt] (0-based) of a run whose last
/// request failed. A rate limit uses Retry-After, the OpenRouter reset time,
/// or the fallback delay. Null means the run should end with the error.
Duration? benchmarkRetryWait({
  required int attempt,
  required Duration planned,
  required bool rateLimited,
  BenchmarkRateLimit? rateLimit,
  DateTime? now,
}) {
  if (!rateLimited) return planned;
  if (rateLimit?.dailyQuotaExhausted ?? false) return null;
  final time = now ?? DateTime.now();
  Duration? asked;
  final value = rateLimit?.retryAfter?.trim();
  if (value != null && value.isNotEmpty) {
    final seconds = int.tryParse(value);
    if (seconds != null) {
      if (seconds > kBenchmarkMaxRetryWait.inSeconds) return null;
      asked =
          Duration(seconds: seconds.clamp(0, kBenchmarkMaxRetryWait.inSeconds));
    } else {
      try {
        asked = HttpDate.parse(value).difference(time);
      } on HttpException {
        // Try the reset time when Retry-After is malformed.
      }
    }
  }
  final reset = int.tryParse(rateLimit?.reset?.trim() ?? '');
  if (asked == null && reset != null && reset > 0) {
    final ms = reset - time.millisecondsSinceEpoch;
    if (ms > kBenchmarkMaxRetryWait.inMilliseconds) return null;
    asked = Duration(
        milliseconds: ms.clamp(0, kBenchmarkMaxRetryWait.inMilliseconds));
  }
  if (asked == null) {
    return kBenchmarkRateLimitBackoff[
        attempt.clamp(0, kBenchmarkRateLimitBackoff.length - 1)];
  }
  if (asked > kBenchmarkMaxRetryWait) return null;
  const minimum = Duration(seconds: 1);
  return asked < minimum ? minimum : asked;
}

/// The result of a streamed run that ended in a timeout. [total] is the
/// run's overall deadline, otherwise the upstream sent nothing for [idle].
/// Neither is the model's fault, so neither is a MODEL_ERROR; [failures]
/// are the upstream failures that made the run start over first.
({String status, String reason}) benchmarkTimeoutResult({
  required bool total,
  required Duration idle,
  required Duration limit,
  List<String> failures = const [],
}) {
  final history = failures.isEmpty
      ? ''
      : ' after ${failures.length} restart${failures.length == 1 ? '' : 's'} '
          '(${failures.join('; ')})';
  return total
      ? (
          status: 'TIMED_OUT',
          reason: 'The run passed its ${limit.inMinutes}-minute limit before '
              'the page was finished$history.'
        )
      : (
          status: 'PROVIDER_ERROR',
          reason: 'The upstream sent nothing for ${idle.inMinutes} '
              'minutes$history.'
        );
}

/// The message of the [TimeoutException] a run throws once it passes its
/// overall deadline. Unlike an idle timeout, it is never retried.
const kBenchmarkTotalTimeout = 'total';

const _transientStatuses = {
  408,
  429,
  500,
  502,
  503,
  504,
  520,
  521,
  522,
  523,
  524,
  529
};
const _permanentStatuses = {400, 401, 402, 403, 404, 405, 413, 422};
final _transientMessage = RegExp(
    r'time ?out|timed out|server error|try again|temporarily|overloaded|'
    r'unavailable|bad gateway|gateway|internal error|connection (reset|closed|error)',
    caseSensitive: false);

/// Whether a provider failure is the upstream's own trouble (overloaded,
/// timed out, a 5xx) rather than anything about the request, so the same
/// request is worth sending again.
bool benchmarkFailureIsTransient({int? httpStatus, String? error}) {
  if (httpStatus != null && _permanentStatuses.contains(httpStatus)) {
    return false;
  }
  if (httpStatus != null && _transientStatuses.contains(httpStatus)) {
    return true;
  }
  return error != null && _transientMessage.hasMatch(error);
}

/// Whether [acc] holds an error the upstream reported mid-stream that is
/// worth retrying.
bool benchmarkStreamFailedTransiently(ChatStreamAccumulator acc) =>
    acc.error != null &&
    benchmarkFailureIsTransient(
        httpStatus: acc.errorCode ?? acc.providerStatus, error: acc.error);

/// Restarts a request whose upstream failed on its own end: a dropped
/// connection, an idle timeout, or a 5xx/timeout error (in the response or
/// mid-stream). Each restart starts over, never joining two generated pages,
/// and waits out [backoff] first. [waitFor] may override a delay or return
/// null to give up. Request errors and completed model
/// responses are never retried. [failedTransiently] says whether a returned
/// result (an HTTP error status, say) is such a failure.
Future<T> retryBenchmarkStream<T>(
  ChatStreamAccumulator acc,
  Future<T> Function() request, {
  required bool Function() canRetry,
  required Future<void> Function() beforeRetry,
  bool Function(T result)? failedTransiently,
  void Function(int retry, Duration wait)? onRetry,
  Duration? Function(int attempt, Duration planned)? waitFor,
  List<Duration> backoff = kBenchmarkRetryBackoff,
}) async {
  bool interrupted() =>
      !acc.done &&
      (acc.error == null
          ? acc.finishReason == null ||
              acc.finishReason!.toLowerCase() == 'error'
          : benchmarkStreamFailedTransiently(acc));

  for (var attempt = 0;; attempt++) {
    Object? thrown;
    StackTrace? trace;
    late T result;
    try {
      result = await request();
      if (!(failedTransiently?.call(result) ?? false) &&
          !benchmarkStreamFailedTransiently(acc) &&
          !benchmarkEndedInProviderError(acc)) {
        return result;
      }
    } on IOException catch (e, s) {
      if (!interrupted()) rethrow;
      thrown = e;
      trace = s;
    } on TimeoutException catch (e, s) {
      if (e.message == kBenchmarkTotalTimeout || !interrupted()) rethrow;
      thrown = e;
      trace = s;
    }
    T giveUp() {
      if (thrown != null) Error.throwWithStackTrace(thrown, trace!);
      return result;
    }

    if (attempt >= backoff.length || !canRetry()) return giveUp();
    final planned = backoff[attempt];
    final wait = waitFor == null ? planned : waitFor(attempt, planned);
    if (wait == null) return giveUp();
    onRetry?.call(attempt + 1, wait);
    final until = DateTime.now().add(wait);
    while (canRetry() && DateTime.now().isBefore(until)) {
      final left = until.difference(DateTime.now());
      await Future<void>.delayed(left < const Duration(seconds: 1)
          ? left
          : const Duration(seconds: 1));
    }
    if (!canRetry()) return giveUp();
    await beforeRetry();
    if (!canRetry()) return giveUp();
    acc.reset();
  }
}

/// Whether the provider closed the stream with finish reason `error` but no
/// error message, before a complete page arrived. That is the provider's own
/// failure (free endpoints do it under load, often mid-reasoning), so the
/// run is worth starting over like a dropped connection.
bool benchmarkEndedInProviderError(ChatStreamAccumulator acc) {
  if (acc.error != null || acc.finishReason?.toLowerCase() != 'error') {
    return false;
  }
  final page = extractBenchmarkHtml(acc.content);
  return page == null || !benchmarkHtmlComplete(page);
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

/// What makes two runs the same contestant's test: the test and the entry's
/// name, ignoring case and spacing at the ends. The dashboard builds the same
/// key to tell which tests a model still lacks.
String benchmarkTestedKey(String kind, String name) =>
    '$kind|${name.trim().toLowerCase()}';

/// The most runs one multi-test request may queue.
const kBenchmarkMultiMaxRuns = 120;

/// The page in a model's [reply], or null when there is none. Prefers the
/// longest fenced block that holds a page (models fence despite being told
/// not to), else the span from `<!doctype`/`<html` to the last `</html>`,
/// or to the end of the reply when the closing tag never came.
String? extractBenchmarkHtml(String reply) {
  var text = reply.replaceAll(
      RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '');
  // Some providers drop the opening tag, so a draft page in the reasoning
  // ends at a bare </think> and the real answer follows it.
  final thinkEnd = text.toLowerCase().lastIndexOf('</think>');
  if (thinkEnd >= 0) text = text.substring(thinkEnd + '</think>'.length);
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

/// Instructions for a fresh attempt after the provider cut off a response.
/// A retry starts over rather than appending two independently generated pages.
/// [overthought] says the cut-off attempt spent its budget reasoning.
String benchmarkAutoCompactPrompt(String prompt, int attempt,
    {bool overthought = false}) {
  if (attempt <= 0) return prompt;
  final guidance = attempt == 1
      ? 'Make the implementation substantially shorter than usual.'
      : 'Make the implementation as compact as necessary to finish, '
          'simplifying details while retaining the core requirements.';
  final thinking = overthought
      ? '\nIt spent nearly all of that budget thinking and never finished '
          'the page. Keep your planning brief and start writing the HTML '
          'early; the page itself is what counts.'
      : '';
  return '''$prompt

The previous attempt reached the model's output limit before completing.$thinking
$guidance Use concise code, reuse functions and procedural structures, and
avoid comments, repeated markup and unnecessary explanation. Prioritize a
working, complete page ending with </html> within your output budget.''';
}

/// Whether a cut-off attempt spent most of its output reasoning instead of
/// writing the page. Hidden reasoning shows only as output tokens the
/// visible reply cannot account for (about 3.4 characters per token).
bool benchmarkReasoningAteBudget({
  required int contentChars,
  required int reasoningChars,
  required int outputTokens,
}) {
  if (contentChars == 0) return reasoningChars > 0 || outputTokens > 0;
  if (reasoningChars > contentChars) return true;
  return outputTokens > 0 && contentChars / 3.4 < outputTokens * 0.5;
}

const _kBenchmarkEffortLadder = ['minimal', 'low', 'medium', 'high', 'xhigh'];

/// The reasoning effort for compact retry [attempt] when the previous one
/// thought its whole budget away: at most medium on the first retry and low
/// on the second, always at least one step below [effort]. Null keeps
/// [effort] (the model's default, reasoning off, or already minimal).
String? benchmarkCompactRetryEffort(String? effort, int attempt) {
  final i = _kBenchmarkEffortLadder.indexOf(effort ?? '');
  if (i <= 0 || attempt <= 0) return null;
  final cap = attempt == 1 ? 2 : 1;
  return _kBenchmarkEffortLadder[i - 1 < cap ? i - 1 : cap];
}

/// Only a provider-reported output limit justifies a compact retry.
bool benchmarkWasTruncated(ChatStreamAccumulator acc) =>
    benchmarkGenerationResult(
      reply: acc.content,
      finishReason: acc.finishReason,
      nativeFinishReason: acc.nativeFinishReason,
      httpStatus: acc.errorCode ?? acc.providerStatus,
      error: acc.error,
    ).status ==
    'TRUNCATED';

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
  if ((error != null || (httpStatus != null && httpStatus != 200)) &&
      benchmarkFailureIsTransient(httpStatus: httpStatus, error: error)) {
    return (
      status: 'PROVIDER_ERROR',
      reason: error ?? 'Provider returned HTTP $httpStatus',
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
  // A filtered reply is cut off or replaced by the provider, so the page
  // cannot be trusted even when it happens to close.
  const filters = {
    'CONTENT_FILTER',
    'SAFETY',
    'PROHIBITED_CONTENT',
    'BLOCKLIST',
    'SPII',
    'RECITATION',
    'REFUSAL',
  };
  final nativeFinish = nativeFinishReason?.trim().toUpperCase();
  if (filters.contains(finish) || filters.contains(nativeFinish)) {
    return (
      status: 'CONTENT_FILTERED',
      reason: 'Blocked by the provider\'s content filter '
          '(${nativeFinishReason ?? finishReason}); the prompt was not '
          'answered, so retry or pick another provider',
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
  BenchmarkRateLimit? rateLimit;
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
    rateLimit = null;
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
      rateLimit = errorCode == HttpStatus.tooManyRequests
          ? BenchmarkRateLimit.fromError(err)
          : null;
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

/// An OpenRouter provider slug as its endpoints list tags it
/// (`deepinfra/fp8`, `sail-research`).
final kOpenRouterProviderPattern =
    RegExp(r'^[a-z0-9][a-z0-9._-]{0,60}(/[a-z0-9._-]{1,30})?$');

/// The providers OpenRouter serves [modelId] through, read from its
/// `GET /models/{id}/endpoints` reply: one row each, prices per million
/// tokens with any discount already applied, cheapest output first.
List<Map<String, Object?>> benchmarkProvidersFrom(Object? decoded) {
  final data = decoded is Map ? decoded['data'] : null;
  final endpoints = data is Map ? data['endpoints'] : null;
  if (endpoints is! List) return const [];
  double? perM(Object? v) {
    final d = v is num ? v.toDouble() : double.tryParse('$v');
    return d == null || d < 0 ? null : d * 1e6;
  }

  double? stat(Object? v) {
    if (v is num) return v.toDouble();
    if (v is Map && v['p50'] is num) return (v['p50'] as num).toDouble();
    return null;
  }

  final rows = <Map<String, Object?>>[];
  for (final e in endpoints) {
    if (e is! Map) continue;
    final tag = e['tag'];
    final pricing = e['pricing'];
    if (tag is! String || !kOpenRouterProviderPattern.hasMatch(tag)) continue;
    if (pricing is! Map) continue;
    final input = perM(pricing['prompt']), output = perM(pricing['completion']);
    if (input == null || output == null) continue;
    final discount = pricing['discount'] is num
        ? (pricing['discount'] as num).toDouble()
        : 0.0;
    final params = e['supported_parameters'];
    rows.add({
      'tag': tag,
      'name': e['provider_name'] is String ? e['provider_name'] : tag,
      'quantization':
          e['quantization'] is String && e['quantization'] != 'unknown'
              ? e['quantization']
              : null,
      'tier': e['service_tier'] is String ? e['service_tier'] : null,
      'input': input,
      'output': output,
      'cacheRead': perM(pricing['input_cache_read']),
      'discount': discount > 0 && discount < 1 ? discount : 0.0,
      'maxOutput': (e['max_completion_tokens'] as num?)?.toInt(),
      'context': (e['context_length'] as num?)?.toInt(),
      'uptime': stat(e['uptime_last_1d']) ?? stat(e['uptime_last_30m']),
      'latencyMs': stat(e['latency_last_30m']),
      'throughput': stat(e['throughput_last_30m']),
      'reasoning': params is List && params.contains('reasoning'),
      'down': e['status'] is num && (e['status'] as num) < 0,
    });
  }
  rows.sort((a, b) =>
      (a['output'] as double).compareTo(b['output'] as double) != 0
          ? (a['output'] as double).compareTo(b['output'] as double)
          : (a['input'] as double).compareTo(b['input'] as double));
  return rows;
}

/// OpenRouter's routing block pinning a request to [provider] alone, so a
/// run is never quietly served (and billed) by a different one.
Map<String, Object> benchmarkProviderRouting(String provider) => {
      'order': [provider],
      'allow_fallbacks': false,
    };

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
