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
    benchmarkRepairStarting = true;
    try {
      final price = await _repairPrice(route);
      if (!completeRepairPrice(price)) {
        return errorResponse(409, 'unknown_price',
            'Both input and output prices must be known. Refresh model data or choose another model.');
      }
      await benchmarkRepairSettings.save(route, price!, limit.toDouble());
      return jsonResponse(
          200, {'saved': true, 'acceptedPrice': price.toJson()});
    } finally {
      benchmarkRepairStarting = false;
    }
  }

  /// Everything a repair needs before its one model call: the chosen model,
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
    if (scene == null || scene.bytes.length > 200000) {
      throw _RepairRefusal('source_size',
          'No HTML source, or the source is over the 200 kB repair limit.');
    }
    final entry = matches.first;
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
    final failures = previewRenders.status.items
        .where((i) => i.id == id && i.state == 'failed');
    benchmarkRepairStarting = true;
    try {
      final plan =
          await _planRepair(id, failures.isEmpty ? null : failures.first.detail);
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
  /// [BenchmarkRepairAll.workers] at a time, each with the one model call a
  /// single repair gets.
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
    final failed = [
      for (final i in previewRenders.status.items)
        if (i.state == 'failed' &&
            i.detail.trim().isNotEmpty &&
            !i.id.startsWith('cathedral_'))
          (id: i.id, diagnostic: i.detail),
    ];
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
      final source = utf8.decode(scene.bytes);
      final messages = [
        {'role': 'system', 'content': benchmarkRepairInstructions},
        {
          'role': 'user',
          'content': jsonEncode({'renderError': diagnostic, 'html': source})
        },
      ];
      final maxTokens =
          repairOutputLimit(jsonEncode(messages), accepted, limit);
      final body = <String, dynamic>{
        'model': route.model,
        'messages': messages,
        'max_tokens': maxTokens,
        'stream': true,
        'stream_options': {'include_usage': true},
        if (route.upstream == AiUpstream.openrouter)
          'provider': {
            'max_price': {
              'prompt': accepted.input,
              'completion': accepted.output
            },
            'require_parameters': true,
          },
      };
      job.detail = 'Repairing the render error (one model call)…';
      final acc = ChatStreamAccumulator();
      try {
        await _callRepairModel(route, body, acc);
      } finally {
        job.costUsd = acc.usage.costUsd;
        if (acc.usage.totalTokens > 0 || acc.usage.costUsd != null) {
          await aiUsage.recordCall(ownerId,
              feature: 'Benchmark render repair',
              upstream: route.upstream.label,
              model: route.model,
              usage: acc.usage,
              includeInUsage: true);
        }
      }
      if (acc.usage.costUsd != null && acc.usage.costUsd! > limit) {
        throw StateError(
            'Price guard: the provider reported a cost above the repair limit. Usage was recorded; the live test was kept.');
      }
      if (acc.error != null || acc.finishReason == 'length' || !acc.done) {
        throw StateError(acc.error ??
            'The repair reply was incomplete; the live test was kept.');
      }
      final repaired = applyBenchmarkRepair(source, acc.content);
      final bytes = utf8.encode(repaired);
      job.detail = 'Checking the repaired test in the banner renderer…';
      final renderError = await previewRenders.validateRepair(job.id, bytes);
      if (renderError != null)
        throw StateError(
            'Repair did not render: $renderError. The live test was kept.');
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
          'Minimal repair saved; original backed up. Banner: ${published['render'] ?? 'queued'}.'
          '${published['github'] == 'failed' ? ' GitHub: ${published['githubError']}' : ''}');
    } catch (e) {
      job.finish('failed', '$e');
    }
  }

  /// Exactly one request, with no automatic retry, fallback, tools or chat history.
  Future<void> _callRepairModel(AiModeRoute route, Map<String, dynamic> body,
      ChatStreamAccumulator acc) async {
    if (benchmarkRepairCall != null) {
      return benchmarkRepairCall!(route, body, acc);
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    final deadline =
        Timer(const Duration(minutes: 5), () => client.close(force: true));
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
        throw HttpException(
            'Repair provider returned HTTP ${res.statusCode}. No automatic retry.');
      }
      await for (final line
          in res.transform(utf8.decoder).transform(const LineSplitter())) {
        acc.addLine(line);
        if (acc.contentChars > 100000)
          throw const FormatException('Repair reply too large.');
        if (acc.done) break;
      }
    } finally {
      deadline.cancel();
      client.close(force: true);
    }
  }
}
