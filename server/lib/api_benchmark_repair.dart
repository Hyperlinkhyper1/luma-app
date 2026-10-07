part of 'api.dart';

/// Why a scene cannot be repaired right now, in words for the dashboard.
class _RepairRefusal implements Exception {
  _RepairRefusal(this.code, this.message);
  final String code;
  final String message;
}

typedef _RepairPlan = ({
  BenchmarkRepairJob job,
  AiModeRoute route,
  String ownerId,
  Map<String, dynamic> entry,
  ({List<int> bytes, String etag}) scene,
  String diagnostic,
});

extension BenchmarkRepairApi on Api {
  Future<AiPrice?> _repairPrice(AiModeRoute route) async {
    if (benchmarkRepairPrice != null) return benchmarkRepairPrice!(route);
    if (route.upstream != AiUpstream.openrouter)
      return priceFor(aiCatalog, route);
    final fetcher = AiCatalogFetcher();
    try {
      final endpoint =
          cheapestEndpoint(await fetcher.fetchOpenRouterEndpoints(route.model));
      return endpoint == null ? null : AiPrice.ofEndpoint(endpoint);
    } catch (_) {
      return null;
    } finally {
      fetcher.close();
    }
  }

  Future<Response> _adminRepairSettings(Request request) async {
    return jsonResponse(200, {
      'route': benchmarkRepairSettings.route?.toJson(),
      'acceptedPrice': benchmarkRepairSettings.acceptedPrice?.toJson(),
      'maxCostUsd': benchmarkRepairSettings.maxCostUsd,
      'maxOutputTokens': benchmarkRepairSettings.maxOutputTokens,
      'owner': benchmarkRepairOwner,
      'keys': [
        for (final key in config.configuredAiUpstreams)
          {'upstream': key.name, 'label': key.label}
      ],
      'models': {
        'openrouter': [
          for (final m in aiCatalog.routingModels)
            if (!m.id.endsWith(':batch') &&
                (m.outputModalities.isEmpty ||
                    m.outputModalities.contains('text')))
              m.id
        ],
        'google': await _googleModelIdsForSuggestions(),
        'mistral': await _mistralModelIdsForSuggestions(),
      },
    });
  }

  Future<Response> _adminRepairSettingsSave(Request request) async {
    if (!_sameOrigin(request))
      return errorResponse(403, 'bad_origin', 'Cross-origin request rejected.');
    if (benchmarkRepairStarting ||
        benchmarkRepairAll.running ||
        benchmarkRepairJobs.values.any((j) => j.state == 'running')) {
      return errorResponse(409, 'repair_running',
          'Wait for the repair to finish before changing settings.');
    }
    final body = await Api._readJson(request);
    final rawRoute = body['route'];
    final route = rawRoute is Map &&
            rawRoute['upstream'] is String &&
            rawRoute['model'] is String
        ? AiModeRoute.fromJson(rawRoute)
        : null;
    final limit = body['maxCostUsd'];
    if (route == null ||
        route.model.endsWith(':batch') ||
        !config.configuredAiUpstreams.contains(route.upstream) ||
        limit is! num ||
        !BenchmarkRepairSettings.validLimit(limit.toDouble())) {
      return errorResponse(400, 'bad_settings',
          r'Choose a server key, a chat model and a limit above $0 and at most $10.');
    }
    if (benchmarkRepairStarting ||
        benchmarkRepairJobs.values.any((j) => j.state == 'running')) {
      return errorResponse(409, 'repair_running',
          'Wait for the current settings update or repair.');
    }
    final rawTokens = body['maxOutputTokens'];
    final int? tokens = rawTokens == null
        ? kRepairMaxOutputTokens
        : rawTokens is num && rawTokens == rawTokens.toInt()
            ? rawTokens.toInt()
            : null;
    if (tokens == null || !BenchmarkRepairSettings.validOutputTokens(tokens)) {
      return errorResponse(400, 'bad_settings',
          'The maximum output tokens must be a whole number from 512 to 200000.');
    }
    benchmarkRepairStarting = true;
    try {
      final price = await _repairPrice(route);
      if (!completeRepairPrice(price)) {
        return errorResponse(409, 'unknown_price',
            'Both input and output prices must be known. Refresh model data or choose another model.');
      }
      await benchmarkRepairSettings.save(
          route, price!, limit.toDouble(), tokens);
      return jsonResponse(
          200, {'saved': true, 'acceptedPrice': price.toJson()});
    } finally {
      benchmarkRepairStarting = false;
    }
  }

  /// Everything a repair needs before its first model call: the chosen model,
  /// the usage account, the test's entry and source, and a job to report on.
  /// Throws [_RepairRefusal] when this scene cannot be repaired.
  Future<_RepairPlan> _planRepair(String id, String? diagnostic) async {
    final route = benchmarkRepairSettings.route;
    if (route == null ||
        !config.configuredAiUpstreams.contains(route.upstream)) {
      throw _RepairRefusal(
          'no_model', 'Choose a repair model using the cog first.');
    }
    final ownerId = store.userIdByEmail[benchmarkRepairOwner];
    if (ownerId == null) {
      throw _RepairRefusal('no_owner',
          'The usage account $benchmarkRepairOwner does not exist on this server.');
    }
    if (diagnostic == null || diagnostic.trim().isEmpty) {
      throw _RepairRefusal('no_error',
          'Render this scene first; repairs require a recorded render error.');
    }
    final entries = await aiBenchmarks.editableEntries();
    final matches = entries.where((e) => e['id'] == id);
    if (matches.isEmpty ||
        AiBenchmarkStore.extForKind(matches.first['kind'] as String) !=
            'html') {
      throw _RepairRefusal('unsupported',
          'Only HTML render errors can be repaired. Binary GLB files require a source repair.');
    }
    final scene = await aiBenchmarks.readScene(id);
    if (scene == null) {
      throw _RepairRefusal(
          'source_size', 'There is no HTML source for this test.');
    }
    if (scene.bytes.length > 200000) {
      throw _RepairRefusal(
          'source_size',
          'The source is ${(scene.bytes.length / 1000).round()} kB, over the '
              '200 kB limit for model repairs: it would not fit a model\'s '
              'context along with the fix.');
    }
    final entry = matches.first;
    final syntax = await previewRenders.findSyntaxError(scene.bytes);
    if (syntax != null) {
      diagnostic = 'Syntax error at line ${syntax.line}:${syntax.column}: '
          '${syntax.message}. The renderer reported: $diagnostic';
    }
    diagnostic = explainRenderError(utf8.decode(scene.bytes), diagnostic);
    final job = BenchmarkRepairJob(id,
        name: entry['model'] as String? ?? id,
        kind: entry['kind'] as String? ?? '');
    return (
      job: job,
      route: route,
      ownerId: ownerId,
      entry: entry,
      scene: scene,
      diagnostic: diagnostic,
    );
  }

  void _registerRepairJob(BenchmarkRepairJob job) {
    if (benchmarkRepairJobs.length >= 100) {
      final settled = benchmarkRepairJobs.entries
          .where((e) => e.value.state != 'running')
          .map((e) => e.key)
          .firstOrNull;
      benchmarkRepairJobs.remove(settled ?? benchmarkRepairJobs.keys.first);
    }
    benchmarkRepairJobs[job.id] = job;
  }

  Future<Response> _adminRepairStart(Request request) async {
    if (!_sameOrigin(request))
      return errorResponse(403, 'bad_origin', 'Cross-origin request rejected.');
    final id = request.params['id']!;
    if (!AiBenchmarkStore.idPattern.hasMatch(id)) {
      return errorResponse(400, 'bad_id', 'Invalid scene id.');
    }
    if (benchmarkRepairStarting ||
        benchmarkRepairAll.running ||
        previewRenders.status.running ||
        benchmarkRepairJobs.values.any((j) => j.state == 'running')) {
      return errorResponse(
          409, 'busy', 'Wait for the current render or repair to finish.');
    }
    benchmarkRepairStarting = true;
    try {
      final plan = await _planRepair(id, previewRenders.failureFor(id));
      _registerRepairJob(plan.job);
      unawaited(_runRepair(plan.job, plan.route, plan.ownerId, plan.entry,
          plan.scene, plan.diagnostic));
      return jsonResponse(202, {'started': true, 'job': plan.job.toJson()});
    } on _RepairRefusal catch (e) {
      return errorResponse(409, e.code, e.message);
    } finally {
      benchmarkRepairStarting = false;
    }
  }

  /// Repairs every scene that failed in the last render,
  /// [BenchmarkRepairAll.workers] at a time, each with the attempts (and the
  /// per-scene cost limit) a single repair gets.
  Future<Response> _adminRepairAll(Request request) async {
    if (!_sameOrigin(request))
      return errorResponse(403, 'bad_origin', 'Cross-origin request rejected.');
    if (benchmarkRepairStarting ||
        benchmarkRepairAll.running ||
        previewRenders.status.running ||
        benchmarkRepairJobs.values.any((j) => j.state == 'running')) {
      return errorResponse(
          409, 'busy', 'Wait for the current render or repair to finish.');
    }
    final route = benchmarkRepairSettings.route;
    if (route == null ||
        !config.configuredAiUpstreams.contains(route.upstream)) {
      return errorResponse(
          409, 'no_model', 'Choose a repair model using the cog first.');
    }
    final failed = await _repairableFailures();
    if (failed.isEmpty) {
      return errorResponse(409, 'no_failures',
          'No failed scenes to repair. Render the banners first; repairs need a recorded render error.');
    }
    benchmarkRepairAll.begin(failed);
    unawaited(_runRepairAll());
    return jsonResponse(202, {
      'started': true,
      'count': failed.length,
      'workers': BenchmarkRepairAll.workers,
    });
  }

  /// Scenes whose last render failed and that a repair can try: every
  /// recorded render error, not only the last job's, since repaired scenes
  /// re-render and replace that job's list.
  Future<List<({String id, String diagnostic})>> _repairableFailures() async {
    final recorded = await previewRenders.recordedFailures();
    return [
      for (final e in recorded.entries)
        if (e.value.trim().isNotEmpty && !e.key.startsWith('cathedral_'))
          (id: e.key, diagnostic: e.value),
    ];
  }

  Future<void> _runRepairAll() async {
    final all = benchmarkRepairAll;
    Future<void> worker() async {
      while (!all.stopped && all.queue.isNotEmpty) {
        final next = all.queue.removeAt(0);
        try {
          final plan = await _planRepair(next.id, next.diagnostic);
          _registerRepairJob(plan.job);
          await _runRepair(plan.job, plan.route, plan.ownerId, plan.entry,
              plan.scene, plan.diagnostic);
        } on _RepairRefusal catch (e) {
          _registerRepairJob(
              BenchmarkRepairJob(next.id)..finish('failed', e.message));
        } catch (e) {
          _registerRepairJob(
              BenchmarkRepairJob(next.id)..finish('failed', '$e'));
        }
      }
    }

    try {
      await Future.wait([
        for (var i = 0; i < BenchmarkRepairAll.workers; i++) worker(),
      ]);
    } finally {
      all.end();
    }
  }

  /// Stops queuing more repairs. The ones already calling the model finish:
  /// a request that is under way can't be taken back, and is billed.
  Response _adminRepairAllStop(Request request) {
    if (!_sameOrigin(request))
      return errorResponse(403, 'bad_origin', 'Cross-origin request rejected.');
    final all = benchmarkRepairAll;
    if (!all.running) return jsonResponse(200, {'stopped': false});
    all.stopped = true;
    all.queue.clear();
    return jsonResponse(200, {'stopped': true});
  }

  /// Clears finished repair cards (and a finished run's summary).
  Response _adminRepairAllDismiss(Request request) {
    if (!_sameOrigin(request))
      return errorResponse(403, 'bad_origin', 'Cross-origin request rejected.');
    benchmarkRepairJobs.removeWhere((_, j) => j.state != 'running');
    if (!benchmarkRepairAll.running) benchmarkRepairAll.reset();
    return jsonResponse(200, {'dismissed': true});
  }

  Future<void> _runRepair(
      BenchmarkRepairJob job,
      AiModeRoute route,
      String ownerId,
      Map<String, dynamic> entry,
      ({List<int> bytes, String etag}) scene,
      String diagnostic) async {
    final accepted = benchmarkRepairSettings.acceptedPrice;
    final limit = benchmarkRepairSettings.maxCostUsd;
    try {
      final current = await _repairPrice(route);
      if (!completeRepairPrice(accepted) || !completeRepairPrice(current)) {
        throw StateError(
            'Price guard: current pricing is unavailable. No model call was made.');
      }
      if (current!.risesAbove(accepted!)) {
        throw StateError(
            'Price guard: the model price increased. Review and save settings to accept the current price.');
      }
      final original = utf8.decode(scene.bytes);

      // Each attempt edits what the last one left, and is told what is still
      // wrong with it, so a fix that trades one error for another (a
      // duplicate declaration, a typo in new code) gets another go at it.
      // The cost limit covers the whole scene, not each call.
      var base = original;
      var error = diagnostic;
      int? focus;
      final tried = <String>[];
      var spent = 0.0;
      var modelAttempts = 0;
      String? automatic;
      List<int>? fixed;

      // Some errors have one known cure; try it before paying for a model.
      if (knownRepair(base, error) case final known?) {
        final bytes = utf8.encode(known.source);
        job.detail = '${known.what}; checking it in the banner renderer…';
        final problem = await previewRenders.findSyntaxError(bytes) != null
            ? 'it has a syntax error'
            : await previewRenders.validateRepair(job.id, bytes);
        if (problem == null) {
          fixed = bytes;
          automatic = known.what;
        } else {
          base = known.source;
          error = problem;
          tried.add('Automatic fix (${known.what}) was applied and the page '
              'now fails with: $problem');
        }
      }
      for (var attempt = 1;
          attempt <= kRepairMaxAttempts && fixed == null;
          attempt++) {
        final messages = [
          {'role': 'system', 'content': benchmarkRepairInstructions},
          {
            'role': 'user',
            'content': jsonEncode({
              'renderError': error,
              if (attempt > 1) 'originalError': diagnostic,
              if (tried.isNotEmpty) 'previousAttempts': tried,
              if (errorLineOf(error) ?? focus case final line?) ...{
                'errorLine': line,
                'errorLines': errorLinesOf(base, line, radius: 25),
              },
              'html': base,
            })
          },
        ];
        modelAttempts = attempt;
        final remaining = limit - spent;
        late final int maxTokens;
        try {
          if (remaining <= 0) throw ArgumentError('Spent.');
          maxTokens = repairOutputLimit(jsonEncode(messages), accepted,
              remaining, benchmarkRepairSettings.maxOutputTokens);
        } on ArgumentError {
          if (attempt == 1) rethrow;
          throw StateError('Gave up after ${attempt - 1} '
              'attempt${attempt == 2 ? '' : 's'}: the \$${limit.toStringAsFixed(2)} '
              'cost limit is used up. Last problem: ${tried.last} '
              'The live test was kept.');
        }
        final body = <String, dynamic>{
          'model': route.model,
          'messages': messages,
          'max_tokens': maxTokens,
          'stream': true,
          'stream_options': {'include_usage': true},
          ..._repairReasoning(route),
          if (route.upstream == AiUpstream.openrouter)
            'provider': {
              'max_price': {
                'prompt': accepted.input,
                'completion': accepted.output
              },
            },
        };
        job.detail = attempt == 1
            ? 'Repairing the render error…'
            : 'Attempt $attempt of $kRepairMaxAttempts: fixing what the last '
                'attempt left…';
        late ChatStreamAccumulator acc;
        for (var retry = 0;; retry++) {
          acc = ChatStreamAccumulator();
          Object? thrown;
          StackTrace? trace;
          try {
            await _callRepairModel(route, body, acc);
          } catch (e, st) {
            thrown = e;
            trace = st;
          } finally {
            spent += acc.usage.costUsd ?? 0;
            job.costUsd = spent;
            if (acc.usage.totalTokens > 0 || acc.usage.costUsd != null) {
              await aiUsage.recordCall(ownerId,
                  feature: 'Benchmark render repair',
                  upstream: route.upstream.label,
                  model: route.model,
                  usage: acc.usage,
                  includeInUsage: true);
            }
          }
          if (!_providerWasBusy(acc, thrown, accepted)) {
            if (thrown != null) Error.throwWithStackTrace(thrown, trace!);
            break;
          }
          final why = thrown == null
              ? _incompleteReason(acc, maxTokens)
              : thrown is StateError
                  ? thrown.message
                  : '$thrown';
          if (retry >= kRepairBusyRetries) {
            const kept = 'The live test was kept.';
            throw StateError('The provider stayed busy through '
                '${retry + 1} tries. Last: $why'
                '${why.contains(kept) ? '' : ' $kept'}');
          }
          final wait = benchmarkRepairBusyBackoff(retry);
          job.detail = 'The provider is busy; trying again in '
              '${wait.inSeconds}s (${retry + 1} of $kRepairBusyRetries)…';
          await Future<void>.delayed(wait);
        }
        if (spent > limit) {
          throw StateError(
              'Price guard: the provider reported a cost above the repair limit. Usage was recorded; the live test was kept.');
        }
        if (acc.error != null ||
            acc.finishReason == 'length' ||
            !acc.done ||
            acc.content.trim().isEmpty) {
          throw StateError(_incompleteReason(acc, maxTokens));
        }

        String? problem;
        String? candidate;
        try {
          candidate = applyBenchmarkRepair(base, acc.content);
        } on FormatException catch (e) {
          problem = e.message.startsWith('Your reply was not valid JSON')
              ? e.message
              : 'Your reply could not be applied: ${e.message} Copy '
                  'before exactly from html, or use a startLine/endLine edit.';
          focus = nearestLineOf(base, acc.content) ?? focus;
        }
        if (candidate != null) {
          final bytes = utf8.encode(candidate);
          if (await previewRenders.findSyntaxError(bytes) case final broken?) {
            problem = 'Syntax error at line ${broken.line}:${broken.column}: '
                '${broken.message}.';
            base = candidate;
            error = explainRenderError(candidate, problem);
            focus = null;
          } else {
            job.detail = attempt == 1
                ? 'Checking the repaired test in the banner renderer…'
                : 'Attempt $attempt of $kRepairMaxAttempts: checking it in '
                    'the banner renderer…';
            final renderError =
                await previewRenders.validateRepair(job.id, bytes);
            if (renderError == null) {
              fixed = bytes;
            } else {
              problem = 'It did not render: $renderError';
              base = candidate;
              error = explainRenderError(candidate, renderError);
              focus = null;
            }
          }
        }
        if (fixed == null) {
          tried.add('Attempt $attempt: $problem');
          if (attempt == kRepairMaxAttempts) {
            throw StateError('Gave up after $kRepairMaxAttempts attempts. '
                'Last problem: $problem The live test was kept.');
          }
        }
      }

      final bytes = fixed!;
      final latest = await aiBenchmarks.readScene(job.id);
      if (latest?.etag != scene.etag) {
        throw StateError(
            'The source changed during repair; the newer test was kept.');
      }
      final backup = File(
          '${config.dataDir}/benchmark_repairs/${job.id}/${DateTime.now().microsecondsSinceEpoch}.html');
      await backup.parent.create(recursive: true);
      await backup.writeAsBytes(scene.bytes, flush: true);
      await aiBenchmarks.saveUpload(
          kind: entry['kind'] as String,
          id: job.id,
          model: entry['model'] as String,
          vendor: entry['vendor'] as String? ?? '',
          description: entry['description'] as String? ?? '',
          bytes: bytes);
      final published = await _publishBenchmarkScene(entry,
          kind: entry['kind'] as String, id: job.id, bytes: bytes);
      job.finish(
          'done',
          'Repaired${automatic == null ? '' : ' automatically ($automatic)'}'
              '${modelAttempts == 0 ? '' : ' on attempt $modelAttempts'}; '
              'original backed up. Banner: ${published['render'] ?? 'queued'}.'
              '${published['github'] == 'failed' ? ' GitHub: ${published['githubError']}' : ''}');
    } catch (e) {
      job.finish(
          'failed',
          switch (e) {
            StateError(:final message) => message,
            FormatException(:final message) =>
              '$message The live test was kept.',
            _ => '$e',
          });
    }
  }

  /// The reasoning setting for a repair's request, spelled the way the
  /// upstream wants it. Left unset a reasoning model thinks for as long as it
  /// likes, which is what made repairs slow and cut off.
  Map<String, dynamic> _repairReasoning(AiModeRoute route) {
    final effort = route.reasoningEffort ?? kRepairDefaultEffort;
    if (route.upstream == AiUpstream.openrouter) {
      return {
        'reasoning': effort == 'none' ? {'enabled': false} : {'effort': effort},
      };
    }
    return {'reasoning_effort': effort};
  }

  /// Why a reply can't be used, in terms of what to change about it.
  String _incompleteReason(ChatStreamAccumulator acc, int maxTokens) {
    const kept = 'The live test was kept.';
    final error = acc.error;
    if (error != null) return '$error. $kept';
    final thought = acc.reasoningChars > 0
        ? ' (${acc.reasoningChars} characters went on reasoning)'
        : '';
    if (acc.finishReason == 'length') {
      return 'The model ran out of its $maxTokens output tokens before it '
          'finished$thought. $kept';
    }
    if (acc.content.trim().isEmpty) {
      return 'The model returned no answer$thought'
          '${acc.finishReason == null ? '' : ' (finish: ${acc.finishReason})'}. '
          '$kept';
    }
    return 'The reply stream ended before it was complete. $kept';
  }

  /// Exactly one request, with no automatic retry, fallback, tools or chat history.
  Future<void> _callRepairModel(AiModeRoute route, Map<String, dynamic> body,
      ChatStreamAccumulator acc) async {
    if (benchmarkRepairCall != null) {
      return benchmarkRepairCall!(route, body, acc);
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    RepairTimeout? cutOff;
    void cut(RepairTimeout why) {
      cutOff ??= why;
      client.close(force: true);
    }

    final deadline = Timer(
        kRepairCallDeadline,
        () => cut(RepairTimeout(
            'The model took longer than ${kRepairCallDeadline.inMinutes} '
            'minutes to answer, so the call was stopped.',
            idle: false)));
    Timer? idle;
    void stillAlive() {
      idle?.cancel();
      idle = Timer(
          kRepairIdleTimeout,
          () => cut(RepairTimeout(
              'The provider sent nothing for '
              '${kRepairIdleTimeout.inMinutes} minutes, so the call was '
              'stopped.',
              idle: true)));
    }

    stillAlive();
    try {
      final req = await client.postUrl(Uri.parse(route.upstream.endpoint));
      req.headers.set(HttpHeaders.authorizationHeader,
          'Bearer ${config.aiUpstreamKey(route.upstream)}');
      req.headers.contentType = ContentType.json;
      req.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
      if (route.upstream == AiUpstream.openrouter) {
        req.headers.set('HTTP-Referer', config.publicUrl);
        req.headers.set('X-Title', 'luma');
      }
      req.add(utf8.encode(jsonEncode(body)));
      final res = await req.close();
      if (res.statusCode != HttpStatus.ok) {
        throw RepairHttpStatus(res.statusCode, await _errorMessageOf(res));
      }
      await for (final line
          in res.transform(utf8.decoder).transform(const LineSplitter())) {
        stillAlive();
        acc.addLine(line);
        final problem = repairStreamProblem(acc,
            reasoningBudget: (body['max_tokens'] as int) * 3);
        if (problem != null) throw StateError(problem);
        if (acc.done) break;
      }
    } on IOException {
      if (cutOff case final why?) throw why;
      rethrow;
    } finally {
      deadline.cancel();
      idle?.cancel();
      client.close(force: true);
    }
  }

  /// The provider's own words for a failed request, when it gave any.
  Future<String?> _errorMessageOf(HttpClientResponse res) async {
    try {
      final text = await res
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(text);
      final error = decoded is Map ? decoded['error'] : null;
      final message = error is Map ? error['message'] : error;
      if (message is String && message.isNotEmpty) {
        return message.length > 300 ? message.substring(0, 300) : message;
      }
    } catch (_) {
      // A body that isn't JSON says nothing more than the status does.
    }
    return null;
  }

  /// Whether a failed call can simply be sent again. Only when the provider
  /// was busy or dropped the line before anything came back: nothing was
  /// billed, and little time was lost. A free model is also re-sent after an
  /// explicit "overloaded", but not after it reasoned for minutes and then
  /// failed, since that would only repeat the wait.
  bool _providerWasBusy(
      ChatStreamAccumulator acc, Object? thrown, AiPrice accepted) {
    final nothingBack = acc.contentChars == 0 &&
        acc.reasoningChars == 0 &&
        (acc.usage.costUsd ?? 0) == 0;
    final free = accepted.input == 0 && accepted.output == 0;
    if (!nothingBack) {
      return free &&
          switch (thrown) {
            RepairHttpStatus(:final busy) => busy,
            null => acc.error != null &&
                busyProviderError(acc.error, acc.errorCode) &&
                acc.reasoningChars < 2000,
            _ => false,
          };
    }
    return switch (thrown) {
      RepairHttpStatus(:final busy) => busy,
      RepairTimeout(:final idle) => idle,
      IOException() => true,
      null => acc.error != null
          ? busyProviderError(acc.error, acc.errorCode)
          : acc.finishReason == 'error' || !acc.done,
      _ => false,
    };
  }
}
