part of 'api.dart';

/// One "Add benchmark" run: a model writing one test's scene on one of the
/// server's keys, from the request to the saved roster entry. Held in
/// memory only; a server restart drops runs in flight.
class BenchmarkGenJob {
  BenchmarkGenJob({
    required this.id,
    required this.kind,
    required this.sceneId,
    required this.name,
    required this.vendor,
    required this.route,
    required this.prompt,
    required this.maxTokens,
    required this.startedAtMs,
    this.batchId,
  });

  /// Rebuilds a batch run saved by [toState] after a restart.
  static BenchmarkGenJob? fromState(Map<String, dynamic> j) {
    final upstream = AiUpstream.parse(j['upstream'] as String?);
    final batchId = j['batchId'];
    if (upstream == null || batchId is! String || batchId.isEmpty) return null;
    final effort = j['effort'] as String? ?? '';
    return BenchmarkGenJob(
      id: j['id'] as String,
      kind: j['kind'] as String,
      sceneId: j['sceneId'] as String,
      name: j['name'] as String,
      vendor: j['vendor'] as String? ?? '',
      route: AiModeRoute(upstream, j['model'] as String,
          reasoningEffort: effort.isEmpty ? null : effort),
      prompt: '',
      maxTokens: (j['maxTokens'] as num?)?.toInt() ?? 0,
      startedAtMs: (j['startedAtMs'] as num).toInt(),
      batchId: batchId,
    );
  }

  final String id;
  final String kind;
  final String sceneId;
  final String name;
  final String vendor;
  final AiModeRoute route;
  final String prompt;
  final int maxTokens;
  final int startedAtMs;

  /// Runs through OpenRouter's Batch API: half price, no stream, done
  /// within 24 hours.
  bool get batch => isBenchmarkBatchModel(route.upstream, route.model);

  /// OpenRouter's id once the batch is submitted, and its last status.
  String? batchId;
  String? batchStatus;

  /// running · done · failed · stopped
  String status = 'running';

  /// connecting · thinking · writing · saving while streaming; a batch is
  /// submitting · queued · generating · saving.
  String phase = 'connecting';
  int? finishedAtMs;
  int chars = 0;
  int reasoningChars = 0;
  int tokens = 0;
  String? finishReason;
  String? error;
  Map<String, Object> publish = const {};
  bool hasOutput = false;
  bool stopRequested = false;
  HttpClient? client;

  /// Cuts a batch's wait between polls short, so Stop lands at once.
  Completer<void>? wake;

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind,
        'kindLabel': kBenchmarkPrompts[kind]?.label ?? kind,
        'sceneId': sceneId,
        'name': name,
        'vendor': vendor,
        'upstream': route.upstream.name,
        'upstreamLabel': route.upstream.label,
        'model': route.model,
        'effort': route.reasoningEffort ?? '',
        'maxTokens': maxTokens,
        'status': status,
        'phase': phase,
        'startedAtMs': startedAtMs,
        'finishedAtMs': finishedAtMs,
        'chars': chars,
        'reasoningChars': reasoningChars,
        'tokens': tokens,
        'finishReason': finishReason,
        'error': error,
        'hasOutput': hasOutput,
        'batch': batch,
        'batchStatus': batchStatus,
        ...publish,
      };

  Map<String, Object?> toState() => {
        'id': id,
        'kind': kind,
        'sceneId': sceneId,
        'name': name,
        'vendor': vendor,
        'upstream': route.upstream.name,
        'model': route.model,
        'effort': route.reasoningEffort ?? '',
        'maxTokens': maxTokens,
        'startedAtMs': startedAtMs,
        'batchId': batchId,
      };
}

final _benchmarkGenJobs = <BenchmarkGenJob>[];

extension BenchmarkGenerateApi on Api {
  static const _maxRunning = 3;
  static const _maxBatches = 10;
  static const _keepJobs = 20;
  static const _defaultMaxTokens = 64000;
  static const _maxPromptChars = 200000;

  /// No bytes for this long and the upstream is taken to have hung. Thinking
  /// models stay quiet a while before the first token, but streaming
  /// upstreams send keep-alives or reasoning chunks well inside this.
  static const _idleTimeout = Duration(minutes: 8);
  static const _totalTimeout = Duration(minutes: 90);

  /// OpenRouter's completion window is 24 h; a little slack before giving up.
  static const _batchTimeout = Duration(hours: 26);
  static const _batchPollEvery = Duration(seconds: 30);
  static const _openRouterApi = 'https://openrouter.ai/api/v1';

  String get _genOutputDir => '${config.dataDir}/benchmark_runs';
  File get _batchStateFile => File('$_genOutputDir/batches.json');

  /// Picks back up the batches that were still out when the server last
  /// stopped. A batch keeps running at OpenRouter either way; without this
  /// its scene would be paid for and never added.
  Future<void> resumeBenchmarkBatches() async {
    List<dynamic> saved;
    try {
      if (!await _batchStateFile.exists()) return;
      saved = jsonDecode(await _batchStateFile.readAsString()) as List;
    } catch (e) {
      stderr.writeln('[luma] could not read pending benchmark batches: $e');
      return;
    }
    for (final raw in saved) {
      if (raw is! Map<String, dynamic>) continue;
      final BenchmarkGenJob? job;
      try {
        job = BenchmarkGenJob.fromState(raw);
      } catch (_) {
        continue;
      }
      if (job == null || _benchmarkGenJobs.any((j) => j.id == job!.id)) {
        continue;
      }
      job.phase = 'queued';
      _benchmarkGenJobs.add(job);
      unawaited(_runBenchmarkGen(job));
    }
  }

  Future<void> _saveBenchmarkBatches() async {
    final pending = [
      for (final j in _benchmarkGenJobs)
        if (j.batch && j.status == 'running' && j.batchId != null) j.toState(),
    ];
    try {
      await Directory(_genOutputDir).create(recursive: true);
      await _batchStateFile.writeAsString(jsonEncode(pending), flush: true);
    } on FileSystemException catch (e) {
      stderr.writeln('[luma] could not save pending benchmark batches: $e');
    }
  }

  /// Everything the dialog needs: the tests with their default prompts, the
  /// server's keys, the efforts, and every recent run.
  Future<Response> _adminBenchmarkGenState(Request request) async {
    final configured = config.configuredAiUpstreams;
    return jsonResponse(200, {
      'tests': [
        for (final e in kBenchmarkPrompts.entries)
          {
            'kind': e.key,
            'label': e.value.label,
            'prompt': benchmarkPromptFor(e.key),
          },
      ],
      'keys': [
        for (final u in AiUpstream.values)
          {
            'upstream': u.name,
            'label': u.label,
            'configured': configured.contains(u),
          },
      ],
      'efforts': [
        for (final e in kBenchmarkEfforts.entries)
          {'value': e.key, 'label': e.key.isEmpty ? "Model's default" : e.key},
      ],
      'defaultMaxTokens': _defaultMaxTokens,
      'github': benchmarkGithub.enabled,
      'jobs': [for (final j in _benchmarkGenJobs.reversed) j.toJson()],
    });
  }

  /// Starts a run. The scene id is picked here, never by the client, so a
  /// run can only ever add a new contestant.
  Future<Response> _adminBenchmarkGenStart(Request request) async {
    if (!_sameOrigin(request)) {
      return errorResponse(403, 'bad_origin', 'Cross-origin request rejected.');
    }
    Map<String, dynamic> body;
    try {
      body = await Api._readJson(request);
    } on FormatException {
      return errorResponse(400, 'bad_request', 'Malformed request.');
    }
    String str(String k) => body[k] is String ? (body[k] as String).trim() : '';

    final upstream = AiUpstream.parse(str('upstream'));
    if (upstream == null) {
      return errorResponse(
          400, 'bad_request', 'Pick one of the server\'s keys.');
    }
    if (!config.configuredAiUpstreams.contains(upstream)) {
      return errorResponse(409, 'no_key',
          'The server has no ${upstream.label} key. Set it in the server\'s environment first.');
    }
    final model = str('model');
    if (!isValidAiModelId(model)) {
      return errorResponse(400, 'bad_request', 'Pick a model.');
    }
    final effort = str('effort');
    if (!kBenchmarkEfforts.containsKey(effort)) {
      return errorResponse(
          400, 'bad_request', 'Pick a valid reasoning effort.');
    }
    final kind = str('kind');
    if (!kBenchmarkPrompts.containsKey(kind)) {
      return errorResponse(400, 'bad_request', 'Pick a test.');
    }
    final name = str('name');
    if (name.isEmpty || name.length > 80) {
      return errorResponse(
          400, 'bad_request', 'Give the entry a name (up to 80 characters).');
    }
    final vendor = str('vendor');
    if (!AiBenchmarkStore.vendorPattern.hasMatch(vendor)) {
      return errorResponse(400, 'bad_request', 'Unknown company "$vendor".');
    }
    var prompt = body['prompt'] is String ? body['prompt'] as String : '';
    if (prompt.trim().isEmpty) prompt = benchmarkPromptFor(kind);
    if (prompt.length > _maxPromptChars) {
      return errorResponse(400, 'bad_request',
          'Keep the prompt under ${_maxPromptChars ~/ 1000}k characters.');
    }
    final rawMax = body['maxTokens'];
    final maxTokens =
        rawMax is num ? rawMax.toInt().clamp(1000, 256000) : _defaultMaxTokens;
    // Batches only sit and wait at OpenRouter, so they get their own cap.
    final batch = isBenchmarkBatchModel(upstream, model);
    final running = _benchmarkGenJobs
        .where((j) => j.status == 'running' && j.batch == batch)
        .length;
    if (running >= (batch ? _maxBatches : _maxRunning)) {
      return errorResponse(
          409,
          'busy',
          batch
              ? 'Already $_maxBatches batches waiting. Wait for one to finish.'
              : 'Already $_maxRunning runs going. Wait for one to finish.');
    }

    final taken = {
      for (final e in await aiBenchmarks.editableEntries()) e['id'] as String,
      for (final j in _benchmarkGenJobs)
        if (j.status == 'running') j.sceneId,
    };
    final job = BenchmarkGenJob(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      kind: kind,
      sceneId: benchmarkSceneId(kind, name, effort, taken),
      name: name,
      vendor: vendor,
      route: AiModeRoute(upstream, model,
          reasoningEffort: effort.isEmpty ? null : effort),
      prompt: prompt,
      maxTokens: maxTokens,
      startedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    _benchmarkGenJobs.add(job);
    await _pruneBenchmarkGenJobs();
    unawaited(_runBenchmarkGen(job));
    return jsonResponse(200, job.toJson());
  }

  Future<Response> _adminBenchmarkGenStop(Request request) async {
    final job = _findBenchmarkGenJob(request);
    if (job == null || job.status != 'running') {
      return errorResponse(404, 'not_found', 'No running run with that id.');
    }
    job.stopRequested = true;
    job.client?.close(force: true);
    job.wake?.complete();
    job.wake = null;
    return jsonResponse(200, {'ok': true});
  }

  Future<Response> _adminBenchmarkGenDismiss(Request request) async {
    final job = _findBenchmarkGenJob(request);
    if (job == null || job.status == 'running') {
      return errorResponse(404, 'not_found', 'No finished run with that id.');
    }
    _benchmarkGenJobs.remove(job);
    await _deleteBenchmarkGenOutput(job);
    return jsonResponse(200, {'ok': true});
  }

  /// The model's raw reply, for working out why a run failed. Plain text,
  /// so a reply that is a page is shown, never run.
  Future<Response> _adminBenchmarkGenOutput(Request request) async {
    final job = _findBenchmarkGenJob(request);
    final file = job == null ? null : File('$_genOutputDir/${job.id}.txt');
    if (file == null || !await file.exists()) {
      return errorResponse(404, 'not_found', 'No saved reply for that run.');
    }
    return Response(200, body: file.openRead(), headers: {
      'Content-Type': 'text/plain; charset=utf-8',
      'Content-Security-Policy': 'sandbox',
      'X-Content-Type-Options': 'nosniff',
      'Cache-Control': 'no-store',
    });
  }

  BenchmarkGenJob? _findBenchmarkGenJob(Request request) {
    final id = request.params['id'];
    for (final j in _benchmarkGenJobs) {
      if (j.id == id) return j;
    }
    return null;
  }

  Future<void> _pruneBenchmarkGenJobs() async {
    while (_benchmarkGenJobs.length > _keepJobs) {
      final old = _benchmarkGenJobs.firstWhere((j) => j.status != 'running',
          orElse: () => _benchmarkGenJobs.first);
      if (old.status == 'running') break;
      _benchmarkGenJobs.remove(old);
      await _deleteBenchmarkGenOutput(old);
    }
  }

  Future<void> _deleteBenchmarkGenOutput(BenchmarkGenJob job) async {
    try {
      await File('$_genOutputDir/${job.id}.txt').delete();
    } on FileSystemException {
      // Never saved, or already gone.
    }
  }

  Future<void> _runBenchmarkGen(BenchmarkGenJob job) async {
    final acc = ChatStreamAccumulator();
    try {
      if (job.batch) {
        await _runBenchmarkBatch(job, acc);
      } else {
        await _runBenchmarkStream(job, acc);
      }
    } on TimeoutException {
      await _saveBenchmarkGenOutput(job, acc.content);
      job.status = job.stopRequested ? 'stopped' : 'failed';
      job.error ??= job.stopRequested
          ? null
          : job.batch
              ? 'The batch still wasn\'t done after '
                  '${_batchTimeout.inHours} hours.'
              : 'The upstream went quiet for ${_idleTimeout.inMinutes} '
                  'minutes, or the run passed ${_totalTimeout.inMinutes} '
                  'minutes.';
    } catch (e) {
      await _saveBenchmarkGenOutput(job, acc.content);
      job.status = job.stopRequested ? 'stopped' : 'failed';
      if (!job.stopRequested) job.error = '$e';
    } finally {
      job.client?.close(force: true);
      job.client = null;
      job.finishedAtMs = DateTime.now().millisecondsSinceEpoch;
      job.chars = acc.contentChars;
      job.reasoningChars = acc.reasoningChars;
      job.tokens = acc.tokens;
      job.finishReason = acc.finishReason;
      try {
        await recordBenchmarkGenerationUsage(
            aiUsage, store.userIdByEmail, job.route, acc.usage);
      } catch (error) {
        stderr.writeln('[luma] benchmark usage recording failed: $error');
      }
      if (job.batch) await _saveBenchmarkBatches();
    }
    final mins =
        ((job.finishedAtMs! - job.startedAtMs) / 60000).toStringAsFixed(1);
    await store.logActivity(
        'benchmark_generate',
        '${job.route.upstream.label} · ${job.route.model}'
            '${job.batchId == null ? '' : ' (batch ${job.batchId})'} '
            '→ ${job.sceneId}: '
            '${job.status}${job.error == null ? '' : ' (${job.error})'}, '
            '$mins min, ${job.tokens} tokens');
  }

  Future<void> _runBenchmarkStream(
      BenchmarkGenJob job, ChatStreamAccumulator acc) async {
    var (status, errorBody) =
        await _streamBenchmarkGen(job, acc, withMaxTokens: true);
    // Some models cap output below what was asked and refuse the request
    // outright; their own maximum is the next best thing.
    if (status == HttpStatus.badRequest &&
        acc.contentChars == 0 &&
        RegExp(r'max[_ ]?(output[_ ]?)?tokens|max_completion',
                caseSensitive: false)
            .hasMatch(errorBody) &&
        !job.stopRequested) {
      (status, errorBody) =
          await _streamBenchmarkGen(job, acc, withMaxTokens: false);
    }
    await _saveBenchmarkGenOutput(job, acc.content);
    if (job.stopRequested) {
      job.status = 'stopped';
    } else if (status != HttpStatus.ok) {
      job.status = 'failed';
      job.error = _benchmarkUpstreamError(job, status, errorBody);
    } else if (acc.error != null && acc.contentChars == 0) {
      job.status = 'failed';
      job.error = acc.error;
    } else {
      await _finishBenchmarkGen(job, acc);
    }
  }

  /// The chat completion body for [job]'s one request, streamed or, for a
  /// batch, not.
  Map<String, dynamic> _benchmarkRequestBody(BenchmarkGenJob job,
      {required bool stream, required bool withMaxTokens}) {
    final route = job.route;
    final effort = route.reasoningEffort;
    return {
      if (stream) 'model': route.model,
      'messages': [
        {'role': 'user', 'content': job.prompt},
      ],
      if (stream) 'stream': true,
      if (stream) 'stream_options': {'include_usage': true},
      if (withMaxTokens) 'max_tokens': job.maxTokens,
      if (effort != null && route.upstream == AiUpstream.openrouter)
        'reasoning': effort == 'none' ? {'enabled': false} : {'effort': effort},
      if (effort != null && route.upstream != AiUpstream.openrouter)
        'reasoning_effort': effort,
    };
  }

  /// Submits [job] as a one-request OpenRouter batch, or picks up the one
  /// it already has, then polls until it ends and reads the reply out of
  /// it. Nothing streams, so progress is only ever the batch's status.
  Future<void> _runBenchmarkBatch(
      BenchmarkGenJob job, ChatStreamAccumulator acc) async {
    final deadline =
        DateTime.fromMillisecondsSinceEpoch(job.startedAtMs).add(_batchTimeout);
    if (job.batchId == null) {
      job.phase = 'submitting';
      // OpenRouter stream-parses the submit and wants `requests` last.
      final (status, body) =
          await _openRouterBatchCall(job, 'POST', '/batches', body: {
        'endpoint': '/v1/chat/completions',
        'model': benchmarkBatchBaseModel(job.route.model),
        'requests': [
          {
            'custom_id': job.sceneId,
            'body':
                _benchmarkRequestBody(job, stream: false, withMaxTokens: true),
          },
        ],
      });
      final id = body is Map ? body['id'] : null;
      if ((status != HttpStatus.ok && status != HttpStatus.accepted) ||
          id is! String ||
          id.isEmpty) {
        job.status = 'failed';
        job.error = _benchmarkUpstreamError(
            job, status, body is String ? body : jsonEncode(body));
        return;
      }
      job.batchId = id;
      job.batchStatus = (body as Map)['status'] as String?;
      await _saveBenchmarkBatches();
    }
    job.phase = 'queued';
    var misses = 0;
    while (!job.stopRequested) {
      if (DateTime.now().isAfter(deadline)) throw TimeoutException('batch');
      final (status, body) =
          await _openRouterBatchCall(job, 'GET', '/batches/${job.batchId}');
      if (job.stopRequested) break;
      if (status == HttpStatus.ok && body is Map) {
        misses = 0;
        final s = body['status'];
        if (s is String) job.batchStatus = s;
        job.phase = s == 'validating' ? 'queued' : 'generating';
        if (kBenchmarkBatchTerminal.contains(s)) {
          final why = readBenchmarkBatch(body, acc) ??
              (acc.contentChars == 0 ? acc.error : null);
          job.chars = acc.contentChars;
          job.reasoningChars = acc.reasoningChars;
          job.tokens = acc.tokens;
          await _saveBenchmarkGenOutput(job, acc.content);
          if (why != null && acc.contentChars == 0) {
            job.status = 'failed';
            job.error = why;
          } else {
            await _finishBenchmarkGen(job, acc);
          }
          // The reply is saved here now; OpenRouter needn't keep a copy.
          unawaited(
              _openRouterBatchCall(job, 'DELETE', '/batches/${job.batchId}')
                  .then((_) {}, onError: (_) {}));
          return;
        }
      } else if (status == HttpStatus.notFound ||
          status == HttpStatus.gone ||
          status == HttpStatus.unauthorized ||
          status == HttpStatus.forbidden) {
        job.status = 'failed';
        job.error = _benchmarkUpstreamError(
            job, status, body is String ? body : jsonEncode(body));
        return;
      } else if (++misses >= 20) {
        // Ten minutes of OpenRouter not answering: say so, keep waiting.
        stderr.writeln('[luma] benchmark batch ${job.batchId}: '
            '$misses polls failed (last HTTP $status)');
        misses = 0;
      }
      final wake = job.wake = Completer<void>();
      await Future.any([wake.future, Future<void>.delayed(_batchPollEvery)]);
      job.wake = null;
    }
    job.status = 'stopped';
  }

  /// One call to OpenRouter's Batch API on the server's key. Returns the
  /// status and the decoded JSON, or the raw text when it isn't JSON; a
  /// network failure comes back as status 0.
  Future<(int, Object?)> _openRouterBatchCall(
      BenchmarkGenJob job, String method, String path,
      {Map<String, dynamic>? body}) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final req = await client
          .openUrl(method, Uri.parse('$_openRouterApi$path'))
          .timeout(const Duration(seconds: 30));
      req.headers
        ..set(HttpHeaders.authorizationHeader,
            'Bearer ${config.aiUpstreamKey(AiUpstream.openrouter)}')
        ..set('HTTP-Referer', config.publicUrl)
        ..set('X-Title', 'luma');
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.add(utf8.encode(jsonEncode(body)));
      }
      final res = await req.close().timeout(const Duration(seconds: 60));
      final text = await res
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(minutes: 2));
      try {
        return (res.statusCode, jsonDecode(text));
      } on FormatException {
        return (
          res.statusCode,
          text.length > 4000 ? text.substring(0, 4000) : text
        );
      }
    } on TimeoutException {
      return (0, 'OpenRouter did not answer in time.');
    } on IOException catch (e) {
      return (0, '$e');
    } finally {
      client.close(force: true);
    }
  }

  /// One streamed request. Returns the HTTP status and, when it isn't 200,
  /// the error body. Chunks land in [acc] as they arrive.
  Future<(int, String)> _streamBenchmarkGen(
      BenchmarkGenJob job, ChatStreamAccumulator acc,
      {required bool withMaxTokens}) async {
    final route = job.route;
    final body =
        _benchmarkRequestBody(job, stream: true, withMaxTokens: withMaxTokens);
    job.client?.close(force: true);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    job.client = client;
    job.phase = 'connecting';
    final deadline =
        DateTime.fromMillisecondsSinceEpoch(job.startedAtMs).add(_totalTimeout);
    final req = await client.postUrl(Uri.parse(route.upstream.endpoint));
    req.headers
      ..set(HttpHeaders.authorizationHeader,
          'Bearer ${config.aiUpstreamKey(route.upstream)}')
      ..set(HttpHeaders.acceptHeader, 'text/event-stream');
    if (route.upstream == AiUpstream.openrouter) {
      req.headers
        ..set('HTTP-Referer', config.publicUrl)
        ..set('X-Title', 'luma');
    }
    req.headers.contentType = ContentType.json;
    req.add(utf8.encode(jsonEncode(body)));
    final res = await req.close().timeout(_idleTimeout);
    if (res.statusCode != HttpStatus.ok) {
      final text = await res
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 30), onTimeout: () => '');
      return (
        res.statusCode,
        text.length > 4000 ? text.substring(0, 4000) : text
      );
    }
    job.phase = 'thinking';
    await for (final line in res
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .timeout(_idleTimeout)) {
      acc.addLine(line);
      job.chars = acc.contentChars;
      job.reasoningChars = acc.reasoningChars;
      job.tokens = acc.tokens;
      if (acc.contentChars > 0) job.phase = 'writing';
      if (acc.done || job.stopRequested) break;
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException('total');
      }
    }
    return (HttpStatus.ok, '');
  }

  String _benchmarkUpstreamError(BenchmarkGenJob job, int status, String body) {
    String? message;
    try {
      final decoded = jsonDecode(body);
      final err =
          decoded is List && decoded.isNotEmpty ? decoded.first : decoded;
      final e = err is Map ? err['error'] ?? err['message'] : null;
      message = e is Map ? '${e['message'] ?? e}' : e?.toString();
    } catch (_) {
      message = body.trim().isEmpty ? null : body.trim();
    }
    final flat = (message ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    final short = flat.length > 300 ? '${flat.substring(0, 300)}…' : flat;
    final refused =
        status == HttpStatus.unauthorized || status == HttpStatus.forbidden;
    return 'HTTP $status${short.isEmpty ? '' : ': $short'}'
        '${refused ? ' — ${job.route.upstream.label} refused the server\'s key' : ''}';
  }

  /// Pulls the page out of the reply and adds it to the roster exactly like
  /// an upload: stored, committed to GitHub when configured, banner queued.
  Future<void> _finishBenchmarkGen(
      BenchmarkGenJob job, ChatStreamAccumulator acc) async {
    job.phase = 'saving';
    final page = extractBenchmarkHtml(acc.content);
    if (page == null) {
      job.status = 'failed';
      job.error = acc.contentChars == 0
          ? 'The model answered with no text'
              '${acc.finishReason == null ? '' : ' (finish: ${acc.finishReason})'}.'
          : 'The reply holds no HTML page. Open the reply to see what came back.';
      return;
    }
    if (acc.finishReason == 'length' || !benchmarkHtmlComplete(page)) {
      job.status = 'failed';
      job.error = acc.finishReason == 'length'
          ? 'The model hit its output limit (${job.maxTokens} tokens asked) '
              'before finishing the page. Try a higher limit or lower effort.'
          : 'The page stops before </html>: the reply was cut off.';
      return;
    }
    final effort = job.route.reasoningEffort;
    var model = job.route.model;
    if (model.length > 120) model = '${model.substring(0, 120)}…';
    final description = 'Generated from the admin dashboard: '
        '${job.route.upstream.label} · $model'
        '${effort == null ? '' : ' · $effort reasoning'}'
        '${job.batch ? ' · batch' : ''}.';
    final bytes = utf8.encode(page);
    final Map<String, dynamic> entry;
    try {
      entry = await aiBenchmarks.saveUpload(
        kind: job.kind,
        id: job.sceneId,
        model: job.name,
        vendor: job.vendor,
        description: description,
        bytes: bytes,
      );
    } on ArgumentError catch (e) {
      job.status = 'failed';
      job.error = '${e.message}';
      return;
    }
    job.publish = await _publishBenchmarkScene(entry,
        kind: job.kind, id: job.sceneId, bytes: bytes);
    job.status = 'done';
  }

  Future<void> _saveBenchmarkGenOutput(BenchmarkGenJob job, String text) async {
    if (text.isEmpty) return;
    try {
      final dir = Directory(_genOutputDir);
      await dir.create(recursive: true);
      await File('${dir.path}/${job.id}.txt').writeAsString(text, flush: true);
      job.hasOutput = true;
    } on FileSystemException catch (e) {
      stderr.writeln('[luma] could not save benchmark reply ${job.id}: $e');
    }
  }
}

/// The "Add benchmark" dialog: key → model → test → entry, top to bottom.
/// The script fills the key, model and test lists from
/// `/admin/benchmarks/generate` and the Assistant tab's model data.
String _bgDialogHtml() => '<dialog id="bgDialog" class="bn-dialog bg-dialog" '
    'aria-labelledby="bgTitle">'
    '<form id="bgForm" novalidate>'
    '<div class="bn-dlg-head"><div><h2 id="bgTitle">Add a benchmark</h2>'
    '<div class="bn-dlg-sub">A model on one of the server\'s keys writes the '
    'scene from the test\'s prompt. It is added as a new entry; existing '
    'entries are never touched.</div></div>'
    '<button type="button" class="bn-icon-btn" data-close aria-label="Close">'
    '${Api._bnCloseIcon}</button></div>'
    '<div class="bg-body">'
    '<section class="bg-step" aria-labelledby="bgStep1">'
    '<div class="bg-step-head"><span class="bg-num" aria-hidden="true">1</span>'
    '<h3 id="bgStep1">API key</h3>'
    '<span class="bg-step-hint">The server\'s own keys</span></div>'
    '<div id="bgKeys" class="bg-keys" role="radiogroup" '
    'aria-labelledby="bgStep1"><div class="muted">Loading keys…</div></div>'
    '</section>'
    '<section class="bg-step" aria-labelledby="bgStep2">'
    '<div class="bg-step-head"><span class="bg-num" aria-hidden="true">2</span>'
    '<h3 id="bgStep2">Model</h3>'
    '<span id="bgModelCount" class="bg-step-hint"></span></div>'
    '<div class="bg-model-tools">'
    '<input id="bgSearch" class="bn-input" type="search" '
    'placeholder="Search name or model ID" aria-label="Search models" '
    'autocomplete="off">'
    '<label class="bg-inline"><span>Reasoning</span>'
    '<select id="bgEffort" class="bn-input"></select></label>'
    '<label class="bg-inline bg-batch" title="OpenRouter\'s batch variants '
    'cost half as much but run asynchronously and can take up to 24 hours.">'
    '<input id="bgBatch" type="checkbox"><span>Batch</span>'
    '<span class="bg-batch-note">½ price · up to 24 h</span></label>'
    '</div>'
    '<div id="bgModels" class="bg-models" role="listbox" '
    'aria-labelledby="bgStep2"></div>'
    '<label class="bm-field" style="margin-top:10px"><span>Model ID '
    '<span class="muted">(pick above, or type one the list doesn\'t have)'
    '</span></span>'
    '<input id="bgModelId" class="bn-input" maxlength="200" '
    'spellcheck="false" autocomplete="off" placeholder="vendor/model-name">'
    '</label>'
    '</section>'
    '<section class="bg-step" aria-labelledby="bgStep3">'
    '<div class="bg-step-head"><span class="bg-num" aria-hidden="true">3</span>'
    '<h3 id="bgStep3">Test</h3>'
    '<span class="bg-step-hint">Picks the prompt</span></div>'
    '<div id="bgTests" class="bg-tests" role="radiogroup" '
    'aria-labelledby="bgStep3"></div>'
    '<details class="bg-prompt"><summary>Prompt '
    '<span id="bgPromptNote" class="muted"></span></summary>'
    '<textarea id="bgPrompt" class="bn-input bm-paste" spellcheck="false" '
    'aria-label="Prompt sent to the model"></textarea>'
    '<div class="bg-prompt-foot"><span class="muted">Edits apply to this '
    'run only.</span><button id="bgPromptReset" type="button" '
    'class="btn btn-ghost btn-sm">Restore default</button></div>'
    '</details>'
    '</section>'
    '<section class="bg-step" aria-labelledby="bgStep4">'
    '<div class="bg-step-head"><span class="bg-num" aria-hidden="true">4</span>'
    '<h3 id="bgStep4">Entry</h3>'
    '<span class="bg-step-hint">Filled in for you</span></div>'
    '<div class="bm-grid bg-entry">'
    '<label class="bm-field bm-wide"><span>Shows up as</span>'
    '<input id="bgName" class="bn-input" maxlength="80" autocomplete="off" '
    'placeholder="Sonnet 5.5 (High)"></label>'
    '<label class="bm-field"><span>Company</span>'
    '<select id="bgVendor" class="bn-input">'
    '${Api._bmOptions(Api._bmVendors)}</select></label>'
    '<label class="bm-field"><span>Max output tokens</span>'
    '<input id="bgMaxTokens" class="bn-input" type="number" min="1000" '
    'max="256000" step="1000" inputmode="numeric"></label>'
    '</div>'
    '<div class="bg-preview" aria-live="polite"><span class="muted">New entry'
    '</span> <strong id="bgPreviewName">—</strong> <span id="bgPreviewVendor" '
    'class="muted"></span><code id="bgPreviewId"></code></div>'
    '</section>'
    '</div>'
    '<div class="bn-dlg-foot">'
    '<span id="bgStatus" class="bn-foot-note" aria-live="polite"></span>'
    '<button type="button" class="btn btn-ghost" data-close>Cancel</button>'
    '<button id="bgStart" type="submit" class="btn btn-primary">Start run'
    '</button></div>'
    '</form></dialog>';

const _bgCss = r'''
.bg-dialog{width:min(820px,calc(100vw - 32px))}
.bg-dialog form{display:flex;flex-direction:column;min-height:0;flex:1}
.bg-body{overflow:auto;padding:4px 22px 18px;display:flex;flex-direction:column;gap:22px;min-height:0}
.bg-step-head{display:flex;align-items:center;gap:10px;margin-bottom:10px}
.bg-step-head h3{margin:0;font-size:14px;font-weight:650;color:#ece8f7}
.bg-step-hint{margin-left:auto;font-size:12px;color:#8d86a8}
.bg-num{width:24px;height:24px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;font-size:12px;font-weight:700;background:#241d3d;color:#b9b0f5;border:1px solid #352c55;flex:none;font-variant-numeric:tabular-nums;transition:background .2s,color .2s}
.bg-step.is-done .bg-num{background:#8a7ee0;color:#14111f;border-color:#8a7ee0}
.bg-keys,.bg-tests{display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:10px}
.bg-opt{position:relative;display:flex;flex-direction:column;gap:3px;text-align:left;padding:12px 14px;min-height:56px;border-radius:12px;background:#12101e;border:1px solid #241e36;color:#ece8f7;font:inherit;cursor:pointer;transition:border-color .15s,background .15s}
.bg-opt:hover:not(:disabled){border-color:#3a3160;background:#161228}
.bg-opt:focus-visible{outline:2px solid #8a7ee0;outline-offset:2px}
.bg-opt[aria-checked=true],.bg-opt[aria-selected=true]{border-color:#8a7ee0;background:#1a1530;box-shadow:inset 0 0 0 1px #8a7ee0}
.bg-opt:disabled{opacity:.5;cursor:not-allowed}
.bg-opt-title{font-weight:600;font-size:13.5px;display:flex;align-items:center;gap:8px}
.bg-opt-sub{font-size:12px;color:#9b94b3}
.bg-dot{width:7px;height:7px;border-radius:50%;background:#e07e7e;flex:none}
.bg-dot.ok{background:#7ee08a}
.bg-model-tools{display:flex;gap:10px;flex-wrap:wrap;align-items:center;margin-bottom:10px}
.bg-model-tools .bn-input[type=search]{flex:1 1 240px}
.bg-inline{display:inline-flex;align-items:center;gap:8px;font-size:12.5px;color:#9b94b3}
.bg-inline .bn-input{min-width:150px;flex:none}
.bg-batch{cursor:pointer;padding:6px 10px;border-radius:9px;border:1px solid #241e36;background:#12101e;user-select:none}
.bg-batch:has(input:checked){border-color:#8a7ee0;background:#1a1530;color:#ece8f7}
.bg-batch:has(input:disabled){opacity:.5;cursor:not-allowed}
.bg-batch input{margin:0;accent-color:#8a7ee0}
.bg-batch-note{font-size:11.5px;color:#8d86a8}
.bg-models{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));grid-auto-rows:max-content;gap:8px;max-height:260px;overflow:auto;padding:2px}
.bg-models .bg-opt{min-height:0;padding:10px 12px}
.bg-model-id{font:11px ui-monospace,Consolas,monospace;color:#a9a0c3;overflow-wrap:anywhere}
.bg-model-stats{display:flex;flex-wrap:wrap;gap:4px 10px;font-size:11.5px;color:#c5bed9;margin-top:3px;font-variant-numeric:tabular-nums}
.bg-model-stats b{color:#ece8f7;font-weight:600}
.bg-empty{grid-column:1/-1;color:#8d86a8;font-size:12.5px;padding:14px 4px}
.bg-prompt{margin-top:10px;background:#12101e;border:1px solid #241e36;border-radius:10px}
.bg-prompt>summary{cursor:pointer;padding:10px 12px;font-size:12.5px;color:#c5bed9;font-weight:600;list-style:none;display:flex;gap:8px;align-items:center}
.bg-prompt>summary::-webkit-details-marker{display:none}
.bg-prompt>summary::before{content:"\25B8";color:#8d86a8;transition:transform .15s}
.bg-prompt[open]>summary::before{transform:rotate(90deg)}
.bg-prompt>summary:focus-visible{outline:2px solid #8a7ee0;outline-offset:-2px;border-radius:10px}
.bg-prompt textarea{display:block;width:calc(100% - 24px);margin:0 12px;min-height:220px;max-height:46vh;white-space:pre-wrap}
.bg-prompt-foot{display:flex;justify-content:space-between;align-items:center;gap:8px;padding:8px 12px 10px;font-size:12px}
.bg-entry{padding:0}
.bg-preview{margin-top:12px;background:#12101e;border:1px solid #241e36;border-radius:9px;padding:10px 12px;font-size:13.5px;display:flex;flex-wrap:wrap;gap:6px;align-items:baseline}
.bg-preview code{margin-left:auto;font-size:11.5px;color:#8d86a8}
.bg-runs{display:flex;flex-direction:column;gap:8px;margin-top:12px}
.bg-runs:empty{display:none}
.bg-run{background:#12101e;border:1px solid #241e36;border-radius:12px;padding:12px 14px;display:grid;grid-template-columns:minmax(0,1fr) auto;gap:6px 12px;align-items:start}
.bg-run.is-failed{border-color:#3a2430}
.bg-run.is-done{border-color:#24382b}
.bg-run-name{font-weight:600;font-size:13.5px;display:flex;flex-wrap:wrap;align-items:center;gap:6px}
.bg-run-name .badge:not(.ok):not(.warn):not(.err){background:#1f1a33;color:#b4addc}
.bg-run-meta{font-size:12px;color:#9b94b3;overflow-wrap:anywhere}
.bg-run-meta code{font-size:11.5px}
.bg-run-actions{display:flex;gap:6px;flex-wrap:wrap;justify-content:flex-end}
.bg-run-actions a.btn{text-decoration:none}
.bg-run-line{grid-column:1/-1;font-size:12.5px;color:#c5bed9;font-variant-numeric:tabular-nums}
.bg-run-err{grid-column:1/-1;font-size:12.5px;color:#ec9a9a;overflow-wrap:anywhere}
.bg-bar{grid-column:1/-1;position:relative;height:4px;border-radius:99px;background:#241f38;overflow:hidden}
.bg-bar::after{content:"";position:absolute;inset:0;width:35%;border-radius:99px;background:linear-gradient(90deg,#8a7ee0,#a89bf0);animation:bg-slide 1.4s ease-in-out infinite}
@keyframes bg-slide{from{transform:translateX(-100%)}to{transform:translateX(290%)}}
@media (prefers-reduced-motion:reduce){.bg-bar::after{animation:none;width:100%;opacity:.5}}
@media (max-width:700px){.bg-body{padding-left:14px;padding-right:14px}.bg-run{grid-template-columns:1fr}.bg-run-actions{justify-content:flex-start}.bg-preview code{margin-left:0}}
''';

/// Drives the dialog and the runs list under the scenes card. Polls the
/// run list every 2 s while a run is going; a reload picks it back up.
const _bgScript = r'''
(function () {
  const $ = (id) => document.getElementById(id);
  const openBtn = $('bgOpenBtn'), dlg = $('bgDialog');
  if (!openBtn || !dlg || typeof dlg.showModal !== 'function') return;
  const keysBox = $('bgKeys'), modelsBox = $('bgModels'), testsBox = $('bgTests');
  const search = $('bgSearch'), effort = $('bgEffort'), modelId = $('bgModelId');
  const prompt = $('bgPrompt'), promptNote = $('bgPromptNote');
  const nameBox = $('bgName'), vendor = $('bgVendor'), maxTokens = $('bgMaxTokens');
  const status = $('bgStatus'), start = $('bgStart'), runsBox = $('bgRuns');
  const batchBox = $('bgBatch');
  const BATCH = ':batch';
  const pickerData = $('aiPickerData');
  const allModels = pickerData ? JSON.parse(pickerData.textContent) : [];
  const EFFORT_LABEL = { '': "Model's default", none: 'Off', minimal: 'Minimal', low: 'Low',
    medium: 'Medium', high: 'High', xhigh: 'Xhigh' };
  const ENTRY_EFFORT = { minimal: 'Minimal', low: 'Low', medium: 'Medium', high: 'High', xhigh: 'Xhigh' };
  let state = null, key = '', model = null, kind = '';
  let nameEdited = false, vendorEdited = false, maxEdited = false;
  let timer = null;

  function esc(v) {
    return String(v == null ? '' : v).replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
  }
  function json(r) {
    return r.text().then((t) => {
      if (r.redirected && /\/admin\/login/.test(r.url)) return { message: 'Your admin session expired. Reload and sign in again.' };
      try { return JSON.parse(t); } catch (_) { return { message: 'The server answered with HTTP ' + r.status + '.' }; }
    });
  }
  function post(url, body) {
    return fetch(url, { method: 'POST', credentials: 'same-origin',
      headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body || {}) }).then(json);
  }
  function kfmt(n) { return n >= 1000 ? (n / 1000).toFixed(n >= 100000 ? 0 : 1).replace(/\.0$/, '') + 'k' : String(n); }
  function price(p) { return p == null ? null : '$' + (p < 1 ? +p.toFixed(3) : p.toFixed(2)); }
  function elapsed(ms) {
    const s = Math.max(0, Math.round(ms / 1000));
    return s < 60 ? s + 's' : Math.floor(s / 60) + 'm ' + String(s % 60).padStart(2, '0') + 's';
  }
  function slug(s) {
    return s.toLowerCase().replace(/\([^)]*\)/g, ' ').replace(/\./g, '')
      .replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
  }

  function radio(box, value) {
    const items = [...box.querySelectorAll('[role=radio]')];
    const focusable = items.find((b) => b.dataset.value === value) || items.find((b) => !b.disabled);
    items.forEach((b) => {
      b.setAttribute('aria-checked', b.dataset.value === value ? 'true' : 'false');
      b.tabIndex = b === focusable ? 0 : -1;
    });
  }
  function radioKeys(box, pick) {
    box.addEventListener('keydown', (e) => {
      if (!/^Arrow(Left|Right|Up|Down)$/.test(e.key)) return;
      const items = [...box.querySelectorAll('[role=radio]:not(:disabled)')];
      const at = items.indexOf(document.activeElement);
      if (at < 0) return;
      e.preventDefault();
      const next = items[(at + (/Right|Down/.test(e.key) ? 1 : items.length - 1)) % items.length];
      next.focus();
      pick(next.dataset.value);
    });
    box.addEventListener('click', (e) => {
      const b = e.target.closest('[role=radio]');
      if (b && !b.disabled) pick(b.dataset.value);
    });
  }

  function modelsFor(upstream) { return allModels.filter((m) => m.upstream === upstream); }
  function isBatch(id) { return key === 'openrouter' && id.endsWith(BATCH); }
  // Only OpenRouter has batch variants; elsewhere the toggle is off and locked.
  function syncBatchBox() {
    const can = key === 'openrouter' && modelsFor(key).some((m) => m.id.endsWith(BATCH));
    batchBox.disabled = !can && !isBatch(modelId.value.trim());
    if (key !== 'openrouter') batchBox.checked = false;
    start.textContent = batchBox.checked ? 'Submit batch' : 'Start run';
  }
  function labelOf(u) { const k = state && state.keys.find((x) => x.upstream === u); return k ? k.label : u; }
  function renderKeys() {
    keysBox.innerHTML = state.keys.map((k) => '<button type="button" role="radio" class="bg-opt" data-value="' + esc(k.upstream) + '"'
      + (k.configured ? '' : ' disabled') + ' aria-checked="false">'
      + '<span class="bg-opt-title"><span class="bg-dot' + (k.configured ? ' ok' : '') + '"></span>' + esc(k.label) + '</span>'
      + '<span class="bg-opt-sub">' + (k.configured ? modelsFor(k.upstream).length + ' models listed' : 'No key on the server') + '</span>'
      + '</button>').join('');
    radio(keysBox, key);
  }
  function renderTests() {
    testsBox.innerHTML = state.tests.map((t) => '<button type="button" role="radio" class="bg-opt" data-value="' + esc(t.kind) + '" aria-checked="false">'
      + '<span class="bg-opt-title">' + esc(t.label) + '</span>'
      + '<span class="bg-opt-sub">' + kfmt(t.prompt.length) + ' character prompt</span></button>').join('');
    radio(testsBox, kind);
  }
  function renderModels() {
    const q = search.value.trim().toLowerCase();
    const list = modelsFor(key).filter((m) => isBatch(m.id) === batchBox.checked)
      .filter((m) => !q || (m.id + ' ' + (m.name || '')).toLowerCase().includes(q))
      .sort((a, b) => (b.intelligence || 0) - (a.intelligence || 0) || (a.name || a.id).localeCompare(b.name || b.id));
    $('bgModelCount').textContent = key ? list.length + (batchBox.checked ? ' batch models' : '') + ' on ' + labelOf(key) : '';
    if (!key) { modelsBox.innerHTML = '<div class="bg-empty">Pick a key first.</div>'; return; }
    if (!list.length) {
      modelsBox.innerHTML = '<div class="bg-empty">' + (q ? 'No model matches “' + esc(q) + '”. Type its ID below instead.'
        : batchBox.checked ? 'No batch models listed for this key. Refresh model data on the Maintenance tab, or type an ID ending in :batch below.'
        : 'No models listed for this key. Refresh model data on the Maintenance tab, or type an ID below.') + '</div>';
      return;
    }
    modelsBox.innerHTML = list.slice(0, 240).map((m) => {
      const stats = [];
      if (m.intelligence != null) stats.push('<span>Intel <b>' + Math.round(m.intelligence) + '</b></span>');
      if (m.maxOutput) stats.push('<span>Out <b>' + kfmt(m.maxOutput) + '</b></span>');
      if (price(m.output)) stats.push('<span><b>' + price(m.input) + '</b> / <b>' + price(m.output) + '</b> per M</span>');
      return '<button type="button" role="option" class="bg-opt" data-id="' + esc(m.id) + '" aria-selected="'
        + (model && model.id === m.id ? 'true' : 'false') + '">'
        + '<span class="bg-opt-title">' + esc(m.name || m.id) + '</span>'
        + '<span class="bg-model-id">' + esc(m.id) + '</span>'
        + (stats.length ? '<span class="bg-model-stats">' + stats.join('') + '</span>' : '') + '</button>';
    }).join('');
  }

  function pickKey(u) {
    if (key === u) return;
    key = u;
    radio(keysBox, u);
    model = null;
    modelId.value = '';
    search.value = '';
    syncBatchBox();
    renderModels();
    autofill();
  }
  // Flipping Batch keeps the same model where it has the other variant.
  function toggleBatch() {
    const id = modelId.value.trim();
    if (id) {
      const other = batchBox.checked ? (id.endsWith(BATCH) ? id : id + BATCH)
        : (id.endsWith(BATCH) ? id.slice(0, -BATCH.length) : id);
      if (modelsFor(key).some((m) => m.id === other)) pickModel(other);
      else { model = null; modelId.value = ''; }
    }
    syncBatchBox();
    renderModels();
    autofill();
  }
  function pickModel(id) {
    model = modelsFor(key).find((m) => m.id === id) || null;
    modelId.value = id;
    modelsBox.querySelectorAll('[role=option]').forEach((b) =>
      b.setAttribute('aria-selected', b.dataset.id === id ? 'true' : 'false'));
    autofill();
  }
  function pickTest(k) {
    kind = k;
    radio(testsBox, k);
    const t = state.tests.find((x) => x.kind === k);
    prompt.value = t ? t.prompt : '';
    promptNote.textContent = t ? '· default for ' + t.label : '';
    autofill();
  }

  function entryName() {
    let base = model && model.name ? model.name : modelId.value.trim().split('/').pop();
    if (!base) return '';
    const colon = base.indexOf(': ');
    if (colon > 0 && colon < 30) base = base.slice(colon + 2).trim();
    base = base.replace(/\s*\(batch\)$/i, '').replace(/:batch$/, '');
    const e = ENTRY_EFFORT[effort.value];
    return (e ? base + ' (' + e + ')' : base).slice(0, 80);
  }
  function entryVendor() {
    const id = modelId.value.trim();
    const v = key === 'google' ? 'google' : key === 'mistral' ? 'mistralai'
      : id.includes('/') ? id.slice(0, id.indexOf('/')) : '';
    return [...vendor.options].some((o) => o.value === v) ? v : '';
  }
  function autofill() {
    if (!nameEdited) nameBox.value = entryName();
    if (!vendorEdited) vendor.value = entryVendor();
    if (!maxEdited) {
      const def = state ? state.defaultMaxTokens : 64000;
      maxTokens.value = model && model.maxOutput ? Math.min(model.maxOutput, def) : def;
    }
    preview();
  }
  function preview() {
    const n = nameBox.value.trim();
    $('bgPreviewName').textContent = n || '—';
    $('bgPreviewVendor').textContent = vendor.value ? 'by ' + vendor.options[vendor.selectedIndex].text : '';
    const e = ENTRY_EFFORT[effort.value] ? effort.value : '';
    const s = slug(n);
    $('bgPreviewId').textContent = kind && s ? [kind, s, e].filter(Boolean).join('_') : '';
    $('bgStep1').closest('.bg-step').classList.toggle('is-done', !!key);
    $('bgStep2').closest('.bg-step').classList.toggle('is-done', !!modelId.value.trim());
    $('bgStep3').closest('.bg-step').classList.toggle('is-done', !!kind);
    $('bgStep4').closest('.bg-step').classList.toggle('is-done', !!n);
  }

  radioKeys(keysBox, pickKey);
  radioKeys(testsBox, pickTest);
  modelsBox.addEventListener('click', (e) => {
    const b = e.target.closest('[role=option]');
    if (b) pickModel(b.dataset.id);
  });
  search.addEventListener('input', renderModels);
  effort.addEventListener('change', autofill);
  batchBox.addEventListener('change', toggleBatch);
  modelId.addEventListener('input', () => {
    const id = modelId.value.trim();
    if (key === 'openrouter' && isBatch(id) !== batchBox.checked) {
      batchBox.checked = isBatch(id);
      syncBatchBox();
      renderModels();
    }
    model = modelsFor(key).find((m) => m.id === id) || null;
    modelsBox.querySelectorAll('[role=option]').forEach((b) =>
      b.setAttribute('aria-selected', model && b.dataset.id === id ? 'true' : 'false'));
    autofill();
  });
  nameBox.addEventListener('input', () => { nameEdited = nameBox.value.trim() !== ''; preview(); });
  vendor.addEventListener('change', () => { vendorEdited = true; preview(); });
  maxTokens.addEventListener('input', () => { maxEdited = true; });
  $('bgPromptReset').addEventListener('click', () => { if (kind) pickTest(kind); });
  dlg.addEventListener('click', (e) => {
    if (e.target.closest('[data-close]') || e.target === dlg) dlg.close();
  });

  openBtn.addEventListener('click', () => {
    status.textContent = '';
    start.disabled = false;
    dlg.showModal();
    fetch('/admin/benchmarks/generate', { credentials: 'same-origin' }).then(json).then((s) => {
      if (!s.tests) throw new Error(s.message || 'Could not load the keys and tests.');
      state = s;
      renderRuns(s.jobs);
      if (!effort.options.length) {
        effort.innerHTML = s.efforts.map((e) => '<option value="' + esc(e.value) + '">'
          + esc(EFFORT_LABEL[e.value] || e.label) + '</option>').join('');
      }
      renderKeys();
      renderTests();
      const usable = s.keys.filter((k) => k.configured);
      if (!usable.some((k) => k.upstream === key)) key = '';
      if (!key && usable.length) pickKey(usable[0].upstream);
      else { syncBatchBox(); renderModels(); }
      if (!usable.length) {
        status.textContent = 'The server has no AI keys set. Add one to its environment first.';
        start.disabled = true;
      } else if (!s.github) {
        status.textContent = 'GitHub is not set up, so the scene only goes live on this server.';
      }
      if (!kind || !s.tests.some((t) => t.kind === kind)) pickTest(s.tests[0].kind);
      search.focus();
    }).catch((e) => { status.textContent = e.message || 'Could not load the keys and tests.'; });
  });

  $('bgForm').addEventListener('submit', (e) => {
    e.preventDefault();
    const id = modelId.value.trim();
    if (!key) { status.textContent = 'Pick an API key.'; return; }
    if (!id) { status.textContent = 'Pick a model.'; search.focus(); return; }
    if (!kind) { status.textContent = 'Pick a test.'; return; }
    if (!nameBox.value.trim()) { status.textContent = 'Give the entry a name.'; nameBox.focus(); return; }
    const t = state.tests.find((x) => x.kind === kind);
    start.disabled = true;
    status.textContent = 'Starting…';
    post('/admin/benchmarks/generate', {
      upstream: key, model: id, effort: effort.value, kind: kind,
      name: nameBox.value.trim(), vendor: vendor.value,
      maxTokens: Number(maxTokens.value) || undefined,
      prompt: t && prompt.value === t.prompt ? '' : prompt.value,
    }).then((j) => {
      start.disabled = false;
      if (!j.id) { status.textContent = j.message || 'Could not start the run.'; return; }
      nameEdited = vendorEdited = maxEdited = false;
      dlg.close();
      poll();
    }).catch(() => { start.disabled = false; status.textContent = 'Could not start the run (network error).'; });
  });

  const PHASE = { connecting: 'Connecting', thinking: 'Thinking', writing: 'Writing', saving: 'Saving',
    submitting: 'Submitting', queued: 'Queued', generating: 'In batch' };
  function renderRuns(jobs) {
    runsBox.innerHTML = (jobs || []).map((j) => {
      const running = j.status === 'running';
      const took = elapsed((j.finishedAtMs || Date.now()) - j.startedAtMs);
      const badge = running ? '<span class="badge warn">' + esc(PHASE[j.phase] || 'Running') + '</span>'
        : j.status === 'done' ? '<span class="badge ok">Added</span>'
        : j.status === 'stopped' ? '<span class="badge">Stopped</span>'
        : '<span class="badge err">Failed</span>';
      const bits = [];
      if (j.chars) bits.push(kfmt(j.chars) + ' characters written');
      else if (j.reasoningChars) bits.push(kfmt(j.reasoningChars) + ' characters of reasoning');
      if (j.tokens) bits.push(kfmt(j.tokens) + ' tokens');
      if (j.batch && running) bits.push('OpenRouter batch ' + (j.batchStatus || 'not submitted yet').replace(/_/g, ' '));
      bits.push(took);
      let pub = '';
      if (j.status === 'done') {
        pub = j.github === 'committed' ? ' · committed to GitHub'
          : j.github === 'failed' ? ' · GitHub commit failed: ' + (j.githubError || '')
          : ' · not pushed (no GitHub token)';
        if (j.render === 'started') pub += ' · banner rendering';
        else if (j.render === 'queued') pub += ' · banner queued';
      }
      const actions = [];
      if (running) actions.push('<button type="button" class="btn btn-ghost btn-sm" data-act="stop"' + (j.batch ? ' data-batch="1"' : '') + '>Stop</button>');
      if (j.commitUrl) actions.push('<a class="btn btn-ghost btn-sm" href="' + esc(j.commitUrl) + '" target="_blank" rel="noopener">Commit</a>');
      if (j.hasOutput) actions.push('<a class="btn btn-ghost btn-sm" href="/admin/benchmarks/generate/' + encodeURIComponent(j.id) + '/output" target="_blank" rel="noopener">Reply</a>');
      if (!running) actions.push('<button type="button" class="btn btn-ghost btn-sm" data-act="dismiss" aria-label="Dismiss this run">Dismiss</button>');
      return '<div class="bg-run is-' + esc(j.status) + '" data-id="' + esc(j.id) + '">'
        + '<div><div class="bg-run-name">' + esc(j.name) + ' <span class="badge">' + esc(j.kindLabel) + '</span>'
        + (j.batch ? '<span class="badge">Batch</span>' : '') + badge + '</div>'
        + '<div class="bg-run-meta">' + esc(j.upstreamLabel) + ' · <code>' + esc(j.model) + '</code>'
        + (j.effort ? ' · ' + esc(EFFORT_LABEL[j.effort] || j.effort) + ' reasoning' : '')
        + ' → <code>' + esc(j.sceneId) + '</code></div></div>'
        + '<div class="bg-run-actions">' + actions.join('') + '</div>'
        + (running ? '<div class="bg-bar" role="progressbar" aria-label="' + esc(j.name) + ' is running"></div>' : '')
        + '<div class="bg-run-line">' + esc(bits.join(' · ') + pub) + '</div>'
        + (j.error ? '<div class="bg-run-err">' + esc(j.error) + '</div>' : '')
        + '</div>';
    }).join('');
    return (jobs || []).some((j) => j.status === 'running');
  }
  runsBox.addEventListener('click', (e) => {
    const b = e.target.closest('button[data-act]');
    if (!b) return;
    const id = b.closest('.bg-run').dataset.id;
    if (b.dataset.act === 'stop' && !confirm(b.dataset.batch
      ? 'Stop waiting for this batch? OpenRouter can\'t cancel a submitted batch, so it still runs and is billed; luma just won\'t add its scene.'
      : 'Stop this run? What the model wrote so far is kept as its reply, but no entry is added.')) return;
    b.disabled = true;
    post('/admin/benchmarks/generate/' + encodeURIComponent(id) + '/' + b.dataset.act).then(poll);
  });
  function poll() {
    clearTimeout(timer);
    fetch('/admin/benchmarks/generate', { credentials: 'same-origin' }).then(json).then((s) => {
      if (!s.jobs) return;
      if (renderRuns(s.jobs)) timer = setTimeout(poll, 2000);
    }).catch(() => { timer = setTimeout(poll, 8000); });
  }
  poll();
})();
''';
