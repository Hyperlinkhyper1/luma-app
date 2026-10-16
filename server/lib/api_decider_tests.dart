part of 'api.dart';

/// OpenRouter's decision models, refreshed at most every half hour for the
/// tab's model picker and for pricing runs whose provider sends no cost.
List<Map<String, dynamic>>? _deciderModels;
DateTime? _deciderModelsAt;

/// Models the picker offers when OpenRouter's list can't be fetched.
const _kDeciderFallbackModels = [
  'perplexity/pplx-decider-v1.2',
  'perplexity/pplx-decider-flash-v1.2',
];

/// The Add benchmark dialog's Decider test: the moderation suite in
/// `decider_test.dart` run against decision models on OpenRouter or
/// Perplexity, with the server's OpenRouter key or one pasted for the batch.
extension DeciderTestsApi on Api {
  /// The suite, whether it is the operator's own, and every run.
  Future<Response> _adminDeciderTestsState(Request request) async {
    String? suiteError;
    DeciderSuite? suite;
    try {
      suite = DeciderSuite.parse(deciderTests.suiteText);
    } on FormatException catch (e) {
      suiteError = e.message;
    }
    return jsonResponse(200, {
      'suite': deciderTests.suiteText,
      'customSuite': deciderTests.customSuite,
      'cases': suite?.cases.length ?? 0,
      'chance': double.parse((suite?.chancePercent ?? 0).toStringAsFixed(1)),
      'suiteHash': deciderSuiteHash(deciderTests.suiteText),
      if (suiteError != null) 'suiteError': suiteError,
      'serverKeys': [
        if (config.openRouterKeyConfigured) DeciderProvider.openrouter.name,
      ],
      'runs': [for (final r in deciderTests.runs) r.summaryJson()],
    });
  }

  /// Every model OpenRouter lists with decisions output, with its input
  /// price; output tokens are free on all of them.
  Future<List<Map<String, dynamic>>> _deciderModelList() async {
    final at = _deciderModelsAt;
    if (_deciderModels != null &&
        at != null &&
        DateTime.now().difference(at) < const Duration(minutes: 30)) {
      return _deciderModels!;
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(Uri.parse(
          'https://openrouter.ai/api/v1/models?output_modalities=decisions'));
      final res = await req.close().timeout(const Duration(seconds: 20));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != HttpStatus.ok) throw HttpException('${res.statusCode}');
      final data = (jsonDecode(body) as Map)['data'];
      final models = <Map<String, dynamic>>[];
      if (data is List) {
        for (final m in data) {
          if (m is! Map || m['id'] is! String) continue;
          // "~vendor/x-latest" ids are routers onto a dated model that is
          // already in the list, so running them would just repeat it.
          final id = m['id'] as String;
          if (id.startsWith('~') || id.endsWith('-latest')) continue;
          final outputs = m['architecture']?['output_modalities'];
          if (outputs is List && !outputs.contains('decisions')) continue;
          final prompt = double.tryParse('${m['pricing']?['prompt'] ?? ''}');
          models.add({
            'id': m['id'],
            'name': m['name'] is String ? m['name'] : m['id'],
            if (prompt != null) 'inputPerM': prompt * 1e6,
            if (m['context_length'] is num) 'context': m['context_length'],
          });
        }
      }
      models.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
      if (models.isNotEmpty) {
        _deciderModels = models;
        _deciderModelsAt = DateTime.now();
      }
    } catch (e) {
      stderr.writeln('[luma] decider model list: $e');
    } finally {
      client.close(force: true);
    }
    return _deciderModels ??
        [
          for (final id in _kDeciderFallbackModels) {'id': id, 'name': id},
        ];
  }

  Future<Response> _adminDeciderTestsModels(Request request) async =>
      jsonResponse(200, {'models': await _deciderModelList()});

  /// The results for the app's AI Usage → Tests → Decider test: each model's
  /// latest finished run on the current suite. Only scores and costs leave
  /// the server — no key hints, no per-case answers, no suite text.
  Future<Response> _deciderResults(Request request, StoredUser user) async {
    final hash = deciderSuiteHash(deciderTests.suiteText);
    var cases = 0;
    var chance = 0.0;
    try {
      final suite = DeciderSuite.parse(deciderTests.suiteText);
      cases = suite.cases.length;
      chance = suite.chancePercent;
    } on FormatException {
      // A broken saved suite still lets the app show the runs it has.
    }
    final seen = <String>{};
    final models = <Map<String, dynamic>>[];
    for (final run in deciderTests.runs) {
      if (run.status != 'done' || run.results.isEmpty || run.suite != hash) {
        continue;
      }
      if (!seen.add('${run.provider.name}|${run.model}')) continue;
      final s = run.summaryJson();
      models.add({
        'model': run.model,
        'provider': run.provider.name,
        'providerLabel': run.provider.label,
        'accuracy': s['accuracy'],
        'meanPTrue': s['meanPTrue'],
        'costUsd': run.costUsd,
        'costPer1k': run.costPer1k,
        'avgMs': s['avgMs'],
        'bySkill': s['bySkill'],
        'finishedAtMs': run.finishedAtMs ?? run.startedAtMs,
      });
    }
    models.sort((a, b) =>
        (b['accuracy'] as num).compareTo(a['accuracy'] as num));
    return Response(200,
        body: jsonEncode({
          'cases': cases,
          'chance': double.parse(chance.toStringAsFixed(1)),
          'models': models,
        }),
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache',
        });
  }

  Future<Response> _adminDeciderTestsRunDetail(Request request) async {
    final run = deciderTests.run(request.params['id'] ?? '');
    if (run == null) {
      return errorResponse(404, 'not_found', 'No run with that id.');
    }
    return jsonResponse(200, run.toJson());
  }

  /// Queues one run per posted model and works through them one at a time.
  /// A pasted `apiKey` is held in memory for this batch only and never
  /// written anywhere.
  Future<Response> _adminDeciderTestsStart(Request request) async {
    Map<String, dynamic> body;
    try {
      body = await Api._readJson(request);
    } on FormatException {
      return errorResponse(400, 'bad_request', 'Malformed request.');
    }
    final provider = DeciderProvider.parse(body['provider']);
    if (provider == null) {
      return errorResponse(400, 'bad_request', 'Choose a valid provider.');
    }
    final models = <String>{
      if (body['models'] case final List list)
        for (final m in list)
          if (m is String && m.trim().isNotEmpty) m.trim(),
    }.toList();
    if (models.isEmpty) {
      return errorResponse(400, 'bad_request', 'Pick at least one model.');
    }
    if (models.length > 40) {
      return errorResponse(400, 'bad_request', 'At most 40 models per batch.');
    }
    for (final m in models) {
      if (!isValidAiModelId(m)) {
        return errorResponse(400, 'bad_request', '"$m" is not a valid model ID.');
      }
    }
    final rawKey =
        body['apiKey'] is String ? (body['apiKey'] as String).trim() : '';
    final apiKey = rawKey.isEmpty ? null : rawKey;
    if (apiKey != null) {
      if (deciderKeyProblem(provider, apiKey) case final problem?) {
        return errorResponse(400, 'bad_key', problem);
      }
    }
    final key = apiKey ??
        (provider == DeciderProvider.openrouter ? config.openRouterApiKey : null);
    if (key == null || key.isEmpty) {
      return errorResponse(409, 'no_key',
          'The server has no ${provider.label} key. Paste one to run with it.');
    }
    if (deciderTests.busy) {
      return errorResponse(
          409, 'busy', 'A batch is already running. Stop it or wait for it.');
    }
    final DeciderSuite suite;
    try {
      suite = DeciderSuite.parse(deciderTests.suiteText);
    } on FormatException catch (e) {
      return errorResponse(
          400, 'bad_suite', 'Fix the suite first: ${e.message}');
    }
    final now = DateTime.now();
    final runs = [
      for (var i = 0; i < models.length; i++)
        DeciderRun(
          id: '${now.microsecondsSinceEpoch.toRadixString(36)}$i',
          provider: provider,
          model: models[i],
          ownKey: apiKey != null,
          keyHint: apiKey == null ? null : deciderKeyHint(apiKey),
          startedAtMs: now.millisecondsSinceEpoch,
          total: suite.cases.length,
          chance: suite.chancePercent,
          suite: deciderSuiteHash(deciderTests.suiteText),
        ),
    ];
    await deciderTests.addAll(runs);
    unawaited(_runDeciderBatch(runs, suite, key));
    return jsonResponse(200, {
      'ok': true,
      'runs': [for (final r in runs) r.summaryJson()],
      if (apiKey != null) 'keyHint': deciderKeyHint(apiKey),
    });
  }

  Future<void> _runDeciderBatch(
      List<DeciderRun> runs, DeciderSuite suite, String key) async {
    final prices = {
      for (final m in await _deciderModelList())
        if (m['inputPerM'] is num) m['id'] as String: (m['inputPerM'] as num).toDouble(),
    };
    for (final run in runs) {
      if (run.status != 'queued') continue;
      run.status = 'running';
      run.startedAtMs = DateTime.now().millisecondsSinceEpoch;
      await deciderTests.persist();
      final priceId = run.provider == DeciderProvider.perplexity &&
              !run.model.contains('/')
          ? 'perplexity/${run.model}'
          : run.model;
      var lastSave = DateTime.now();
      try {
        await runDeciderSuite(
          run,
          suite,
          (body) => _deciderCall(run.provider, key, body),
          pricePerMInput: prices[priceId],
          onProgress: () async {
            if (DateTime.now().difference(lastSave).inSeconds < 3) return;
            lastSave = DateTime.now();
            await deciderTests.persist();
          },
        );
        run.status = run.note != null
            ? 'failed'
            : (run.stopRequested ? 'stopped' : 'done');
      } catch (e) {
        final text = '$e'.replaceAll(key, '•••');
        stderr.writeln('[luma] decider test ${run.id} failed: $text');
        run.status = 'failed';
        run.note ??= text.length > 300 ? '${text.substring(0, 300)}…' : text;
      }
      run.finishedAtMs = DateTime.now().millisecondsSinceEpoch;
      await deciderTests.persist();
      await store.logActivity(
          'decider_test_run',
          '${run.provider.label} · ${run.model}: '
              '${run.accuracy.toStringAsFixed(1)}% over ${run.results.length}/'
              '${run.total} cases, \$${run.costUsd.toStringAsFixed(5)}'
              '${run.ownKey ? ' (own key)' : ''}'
              '${run.status == 'done' ? '' : ', ${run.status}'}');
      if (run.status == 'stopped') {
        for (final rest in runs.where((r) => r.status == 'queued')) {
          rest.status = 'stopped';
          rest.finishedAtMs = DateTime.now().millisecondsSinceEpoch;
        }
        await deciderTests.persist();
        break;
      }
    }
  }

  /// One decisions request, retried on rate limits and provider hiccups.
  Future<DeciderReply> _deciderCall(
      DeciderProvider provider, String key, Map<String, dynamic> body) async {
    String scrub(String s) {
      final flat = s.replaceAll(key, '•••').replaceAll(RegExp(r'\s+'), ' ').trim();
      return flat.length > 300 ? '${flat.substring(0, 300)}…' : flat;
    }

    final payload = jsonEncode(body);
    for (var attempt = 0;; attempt++) {
      int status;
      String text;
      String? retryAfter;
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      try {
        final req = await client.postUrl(Uri.parse(provider.endpoint));
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
        if (provider == DeciderProvider.openrouter) {
          req.headers.set('HTTP-Referer', config.publicUrl);
          req.headers.set('X-Title', 'luma');
        }
        req.headers.contentType = ContentType.json;
        req.add(utf8.encode(payload));
        final res = await req.close().timeout(const Duration(seconds: 90));
        status = res.statusCode;
        text = await res.transform(utf8.decoder).join();
        retryAfter = res.headers.value('retry-after');
      } on TimeoutException {
        status = HttpStatus.gatewayTimeout;
        text = 'Timed out.';
      } on IOException catch (e) {
        status = 0;
        text = '$e';
      } finally {
        client.close(force: true);
      }

      Object? decoded;
      try {
        decoded = jsonDecode(text);
      } catch (_) {}
      String? error;
      if (decoded is Map) {
        final e = decoded['error'];
        error = e is Map ? e['message']?.toString() : e?.toString();
      }

      if (status == HttpStatus.ok && decoded is Map) {
        final usage = decoded['usage'];
        final answers = decoded['answers'];
        return DeciderReply(
          answers: answers is Map ? answers : null,
          inputTokens: usage is Map && usage['input_tokens'] is num
              ? (usage['input_tokens'] as num).toInt()
              : 0,
          costUsd: usage is Map && usage['cost'] is num
              ? (usage['cost'] as num).toDouble()
              : null,
          error: answers is Map ? null : 'No answers in the reply.',
        );
      }
      final retryable = status == 429 ||
          status == 0 ||
          (status >= 500 && status != 501);
      if (retryable && attempt < 4) {
        final wait = int.tryParse(retryAfter ?? '') ?? (2 << attempt);
        await Future<void>.delayed(Duration(seconds: wait.clamp(1, 20)));
        continue;
      }
      final refused = status == 401 || status == 402 || status == 403;
      final badModel = (status == 400 || status == 404) &&
          (error ?? '').toLowerCase().contains('model');
      return DeciderReply(
        fatal: refused || badModel,
        error: scrub('HTTP $status${error == null ? '' : ': $error'}'
            '${status == 401 || status == 403 ? ' — ${provider.label} refused the key' : ''}'
            '${status == 402 ? ' — the ${provider.label} account is out of credit' : ''}'),
      );
    }
  }

  Future<Response> _adminDeciderTestsStop(Request request) async {
    final active = deciderTests.active;
    if (active.isEmpty) {
      return jsonResponse(200, {'ok': true, 'running': false});
    }
    for (final run in active) {
      run.stopRequested = true;
      if (run.status == 'queued') {
        run.status = 'stopped';
        run.finishedAtMs = DateTime.now().millisecondsSinceEpoch;
      }
    }
    await deciderTests.persist();
    return jsonResponse(200, {'ok': true, 'running': true});
  }

  /// Saves the operator's suite, or `{"reset": true}` for the built-in one.
  Future<Response> _adminDeciderTestsSuite(Request request) async {
    Map<String, dynamic> body;
    try {
      body = await Api._readJson(request, maxBytes: kDeciderTestMaxSuiteChars * 2);
    } on FormatException {
      return errorResponse(400, 'bad_request', 'Malformed request.');
    }
    try {
      if (body['reset'] == true) {
        await deciderTests.saveSuite(null);
      } else {
        final text = body['suite'];
        if (text is! String) {
          return errorResponse(400, 'bad_request', 'Send the suite.');
        }
        await deciderTests.saveSuite(text);
      }
    } on FormatException catch (e) {
      return errorResponse(400, 'bad_suite', e.message);
    }
    final suite = DeciderSuite.parse(deciderTests.suiteText);
    return jsonResponse(200, {
      'ok': true,
      'cases': suite.cases.length,
      'chance': double.parse(suite.chancePercent.toStringAsFixed(1)),
      'customSuite': deciderTests.customSuite,
      'suite': deciderTests.suiteText,
    });
  }

  Future<Response> _adminDeciderTestsDelete(Request request) async {
    final deleted = await deciderTests.delete(request.params['id'] ?? '');
    if (!deleted) {
      return errorResponse(404, 'not_found', 'No finished run with that id.');
    }
    return jsonResponse(200, {'ok': true});
  }

  /// The Decider test half of the Add benchmark dialog, shown by the
  /// switch in the dialog's header. Its own form, endpoints and runs.
  String _adminDeciderView() {
    final providerOptions = DeciderProvider.values.map((p) {
      final hasKey =
          p == DeciderProvider.openrouter && config.openRouterKeyConfigured;
      return '<option value="${p.name}">${Api._htmlEscape(p.label)}'
          '${hasKey ? '' : ' (paste a key)'}</option>';
    }).join();
    return '<style>$_deciderCss</style>'
        '<div id="dtView" class="dt-view" hidden>'
        '<section class="dt-sec">'
        '<div class="bg-step-head"><h3>Models</h3>'
        '<span id="dtPickCount" class="bg-step-hint">Loading models…</span></div>'
        '<div class="dt-desc">Every case hands the model a made-up platform '
        'rulebook, the facts about the author and the post, and asks which '
        'action the rules require. The answers turn on dates, sums, follower '
        'counts, quote marks and which rule outranks which — work a decision '
        'model has to do in one pass. The server checks each answer against '
        'the expected one; a checklist case only counts when every question '
        'is right. Runs use the server\'s OpenRouter key unless you paste '
        'one; a pasted key is used for this batch only and never saved.</div>'
        '<div class="dt-form">'
        '<div><label for="dtProvider">Provider</label>'
        '<select id="dtProvider">$providerOptions</select></div>'
        '<div><label for="dtKey">API key (optional on OpenRouter)</label>'
        '<input id="dtKey" name="dt-provider-key" type="password" '
        'autocomplete="new-password" data-1p-ignore data-lpignore="true" '
        'data-bwignore data-form-type="other" spellcheck="false" '
        'placeholder="Use the server\'s key"></div>'
        '<div><label for="dtExtra">Other model IDs</label>'
        '<input id="dtExtra" type="text" spellcheck="false" autocomplete="off" '
        'placeholder="comma-separated, e.g. typesafe/jev-latest"></div>'
        '</div>'
        '<div class="dt-pick-head">'
        '<label class="dt-hide-free"><input type="checkbox" id="dtHideFree"> Hide free models</label>'
        '<button type="button" class="btn btn-ghost btn-sm" id="dtPickTodo">Not run yet</button>'
        '<button type="button" class="btn btn-ghost btn-sm" id="dtPickDeciders">Perplexity Deciders</button>'
        '<button type="button" class="btn btn-ghost btn-sm" id="dtPickAll">All</button>'
        '<button type="button" class="btn btn-ghost btn-sm" id="dtPickNone">None</button></div>'
        '<div id="dtModels" class="dt-models"></div>'
        '<div id="dtProgress" class="bn-progress" hidden>'
        '<div class="bn-progress-head"><span id="dtProgressLabel"></span>'
        '<span id="dtProgressQueue" class="muted"></span></div>'
        '<div class="bn-bar" role="progressbar" aria-label="Decider test progress" '
        'aria-valuemin="0" aria-valuemax="100" aria-valuenow="0" id="dtBar">'
        '<div id="dtBarFill" class="bn-bar-fill"></div></div></div>'
        '</section>'
        '<section class="dt-sec">'
        '<div class="bg-step-head"><h3>Cost vs performance</h3>'
        '<select id="dtMetric" aria-label="Metric">'
        '<option value="accuracy">Accuracy</option>'
        '<option value="meanPTrue">Probability on the right answer</option>'
        '</select></div>'
        '<div class="dt-desc">Each dot is a model\'s latest finished run. Left '
        'to right is what 1,000 cases cost (log scale); up is how many it got '
        'right. The line links the models nothing else beats on both. The '
        'dashed line is random guessing; the dotted one is 50%, the ceiling '
        'this suite is built to hold the best model under.</div>'
        '<div id="dtChart" class="dt-chart"><div class="muted">No finished runs yet.</div></div>'
        '</section>'
        '<section class="dt-sec">'
        '<div class="bg-step-head"><h3>Runs</h3></div>'
        '<div class="dt-table">'
        '<table><thead><tr><th>When</th><th>Model</th><th>Accuracy</th>'
        '<th>P(right)</th><th>By skill</th><th>Cost</th><th>Per 1k cases</th>'
        '<th>Errors</th><th>Avg time</th><th></th></tr></thead>'
        '<tbody id="dtRuns"><tr><td colspan="10" class="muted">Loading…</td></tr>'
        '</tbody></table></div>'
        '</section>'
        '<details class="bg-prompt dt-suite"><summary>Suite '
        '<span id="dtSuiteBadge" class="badge"></span></summary>'
        '<div class="dt-suite-body">'
        '<div class="dt-desc"><code>policies</code> maps an id to a '
        '<code>title</code>, the <code>rules</code> text and its '
        '<code>actions</code> (name → meaning). Each case has an '
        '<code>id</code>, a <code>policy</code>, a <code>skill</code> tag, a '
        '<code>context</code> object and the <code>content</code>. A case with '
        'just an <code>expect</code> action asks which action applies. A case '
        'with <code>questions</code> (name → <code>type</code> choice, noul or '
        'score, <code>instructions</code>, <code>criteria</code>) needs an '
        '<code>expect</code> per question: an option name, true/false, or a '
        'level index. Up to $kDeciderTestMaxCases cases.</div>'
        '<textarea id="dtSuite" class="bn-input" spellcheck="false" aria-label="Decider suite JSON"></textarea>'
        '<div class="bg-prompt-foot">'
        '<span id="dtSuiteStatus" class="muted"></span><span>'
        '<button id="dtSuiteReset" type="button" class="btn btn-ghost btn-sm">Reset to built-in suite</button> '
        '<button id="dtSuiteSave" type="button" class="btn btn-primary btn-sm">Save suite</button>'
        '</span></div></div></details>'
        '</div>'
        '<div id="dtFoot" class="bn-dlg-foot" hidden>'
        '<span id="dtStatus" class="bn-foot-note" aria-live="polite"></span>'
        '<button type="button" class="btn btn-ghost" data-close>Close</button>'
        '<button id="dtStopBtn" type="button" class="btn btn-ghost" hidden>Stop</button>'
        '<button id="dtRunBtn" type="button" class="btn btn-primary">Run selected</button>'
        '</div>';
  }

  String get _adminDeciderScript => _deciderScript;
}

const _deciderCss = r'''
.bg-dialog.is-decider{width:min(1080px,calc(100vw - 32px))}
.bg-dialog.is-decider form{flex:none}
.bg-dialog.is-decider form .bg-body,.bg-dialog.is-decider form .bn-dlg-foot{display:none}
.bg-mode{display:inline-flex;gap:2px;margin-top:12px;padding:3px;border-radius:10px;background:#12101e;border:1px solid #241e36}
.bg-mode button{font:inherit;font-size:12.5px;font-weight:600;color:#9b94b3;background:none;border:0;border-radius:7px;padding:6px 12px;cursor:pointer}
.bg-mode button:hover{color:#ece8f7}
.bg-mode button[aria-selected=true]{background:#8a7ee0;color:#14111f}
.bg-mode button:focus-visible{outline:2px solid #8a7ee0;outline-offset:2px}
.dt-view{overflow:auto;padding:4px 22px 18px;display:flex;flex-direction:column;gap:22px;min-height:0;flex:1}
.dt-view[hidden],.bn-dlg-foot[hidden]{display:none}
.dt-desc{font-size:12.5px;color:#9b94b3;line-height:1.5;margin-bottom:10px}
.dt-table{overflow-x:auto}
.dt-table table{width:100%}
.dt-suite-body{padding:0 12px}
.dt-suite .badge{margin-left:4px}
.dt-form{display:grid;grid-template-columns:minmax(140px,.8fr) minmax(200px,1.4fr) minmax(220px,1.6fr);gap:10px;align-items:end;background:#12101e;border:1px solid #221c33;border-radius:12px;padding:12px 14px}
.dt-form label{display:block;font-size:11px;letter-spacing:.05em;text-transform:uppercase;color:#8d86a8;margin-bottom:6px}
.dt-form select,.dt-form input,#dtMetric{width:100%;background:#1a1530;color:#ece8f7;border:1px solid #2d2645;border-radius:9px;padding:8px 10px;font:13px inherit;outline:none;box-sizing:border-box}
#dtMetric{width:auto;margin-left:auto;padding:5px 8px;font-size:12px}
.dt-form input{font-family:ui-monospace,Consolas,monospace;font-size:12.5px}
.dt-form select:focus,.dt-form input:focus,.dt-suite textarea:focus{border-color:#8a7ee0}
.dt-pick-head{display:flex;justify-content:flex-end;align-items:center;gap:6px;margin:12px 0 8px;flex-wrap:wrap}
.dt-hide-free{margin-right:auto;display:inline-flex;align-items:center;gap:6px;font-size:12.5px;color:#c5bed9;cursor:pointer}
.dt-hide-free input{accent-color:#8a7ee0}
.dt-models{display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:6px;max-height:300px;overflow:auto;padding-right:4px}
.dt-model{display:flex;gap:8px;align-items:flex-start;background:#151122;border:1px solid #221c33;border-radius:9px;padding:7px 9px;cursor:pointer;font-size:12.5px}
.dt-model:hover{border-color:#3a3160}
.dt-model input{margin-top:2px;accent-color:#8a7ee0}
.dt-model code{font-size:11.5px;color:#c5bed9;overflow-wrap:anywhere}
.dt-model .muted{font-size:11px}
.dt-model>span{min-width:0;flex:1}
.dt-model.is-done{opacity:.72}
.dt-model-head{display:flex;align-items:baseline;justify-content:space-between;gap:6px}
.dt-tag{flex:none;font-size:10.5px;font-weight:650;padding:1px 7px;border-radius:99px;border:1px solid #352c55;background:#241d3d;color:#b9b0f5;white-space:nowrap}
.dt-tag.done{background:#16261b;border-color:#24382b;color:#9ad8a3}
.dt-tag.busy{background:#2d2614;border-color:#655025;color:#e8c37a}
.dt-chart{margin-top:10px}
.dt-chart svg{width:100%;height:auto;display:block}
.dt-chart text{font:11px ui-sans-serif,system-ui,sans-serif;fill:#a9a0c3}
.dt-chart .dt-axis{stroke:#2d2645}
.dt-chart .dt-grid{stroke:#1f1a33}
.dt-chart .dt-front{fill:none;stroke:#8a7ee0;stroke-width:1.5;opacity:.55}
.dt-chart .dt-chance{stroke:#e07e7e;stroke-dasharray:5 4;opacity:.7}
.dt-chart .dt-ceiling{stroke:#e0c87e;stroke-dasharray:2 4;opacity:.7}
.dt-chart .dt-label{fill:#ece8f7;font-size:11.5px}
.dt-chart circle{stroke:#0f0c1a;stroke-width:1.5}
.dt-chart circle.dt-direct{stroke:#fff;stroke-width:2}
.dt-legend{display:flex;flex-wrap:wrap;gap:6px 14px;margin-top:8px;font-size:12px;color:#c5bed9}
.dt-legend span{display:inline-flex;align-items:center;gap:6px}
.dt-legend i{width:10px;height:10px;border-radius:50%;display:inline-block}
.dt-legend i.dt-direct-key{border:2px solid #fff;box-sizing:border-box;background:transparent}
.dt-why{margin-top:4px;font-size:11.5px;color:#a9a0c3;max-width:420px}
.dt-score{font:600 20px ui-monospace,Consolas,monospace}
.dt-score.good{color:#7ee08a}.dt-score.mid{color:#e0c87e}.dt-score.bad{color:#e07e7e}
.dt-kinds{font-size:12px;color:#c5bed9;white-space:nowrap}
.dt-detail td{background:#151122}
.dt-detail table td{font-size:12px;vertical-align:top;overflow-wrap:anywhere}
.dt-suite textarea{display:block;width:100%;box-sizing:border-box;min-height:320px;max-height:50vh;resize:vertical;font:12px/1.5 ui-monospace,Consolas,monospace}
@media (max-width:900px){.dt-form{grid-template-columns:1fr}}
@media (max-width:700px){.dt-view{padding-left:14px;padding-right:14px}}
''';

/// The Decider test view in the Add benchmark dialog: model picker, batch runs, the cost/performance
/// chart, the results table and the suite editor.
const _deciderScript = r'''
(function () {
  const runBtn = document.getElementById('dtRunBtn');
  if (!runBtn) return;
  const stopBtn = document.getElementById('dtStopBtn');
  const provider = document.getElementById('dtProvider');
  const key = document.getElementById('dtKey');
  const extra = document.getElementById('dtExtra');
  const modelsBox = document.getElementById('dtModels');
  const pickCount = document.getElementById('dtPickCount');
  const status = document.getElementById('dtStatus');
  const rows = document.getElementById('dtRuns');
  const progress = document.getElementById('dtProgress');
  const progressLabel = document.getElementById('dtProgressLabel');
  const progressQueue = document.getElementById('dtProgressQueue');
  const bar = document.getElementById('dtBar');
  const barFill = document.getElementById('dtBarFill');
  const chart = document.getElementById('dtChart');
  const metric = document.getElementById('dtMetric');
  const suite = document.getElementById('dtSuite');
  const suiteStatus = document.getElementById('dtSuiteStatus');
  const open = new Set();
  let timer = null;
  let suiteLoaded = false;
  let lastState = null;
  let models = [];
  let keyTouched = false;
  key.addEventListener('keydown', () => { keyTouched = true; });

  // The Add benchmark dialog's header switch: scene benchmark or this test.
  const dlg = document.getElementById('bgDialog');
  const view = document.getElementById('dtView');
  const foot = document.getElementById('dtFoot');
  const sub = document.getElementById('bgSub');
  const sceneSub = sub ? sub.textContent : '';
  const modeBtns = dlg ? dlg.querySelectorAll('.bg-mode [data-mode]') : [];
  function setMode(mode) {
    const decider = mode === 'decider';
    if (dlg) dlg.classList.toggle('is-decider', decider);
    view.hidden = !decider;
    foot.hidden = !decider;
    modeBtns.forEach((b) => b.setAttribute('aria-selected', String(b.dataset.mode === mode)));
    if (sub) sub.textContent = decider
      ? 'Decision models work through a hard moderation suite; the server scores every answer and plots cost against accuracy. Separate from the scene benchmarks.'
      : sceneSub;
    try { localStorage.setItem('lumaBenchmarkMode', decider ? 'decider' : 'scene'); } catch (_) {}
    if (decider) load();
  }
  window.lumaBenchmarkMode = setMode;
  modeBtns.forEach((b) => b.addEventListener('click', () => setMode(b.dataset.mode)));
  key.addEventListener('paste', () => { keyTouched = true; });

  function esc(v) {
    return String(v == null ? '' : v).replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    })[c]);
  }
  function scoreClass(s) { return s >= 50 ? 'good' : s >= 30 ? 'mid' : 'bad'; }
  function money(v) {
    if (!v) return '$0';
    if (v >= 1) return '$' + v.toFixed(2);
    if (v >= 0.01) return '$' + v.toFixed(3);
    return '$' + v.toPrecision(2);
  }
  function json(r) {
    return r.text().then((text) => {
      if (r.redirected && /\/admin\/login/.test(r.url)) {
        return { message: 'Your admin session expired. Reload and sign in again.' };
      }
      try { return JSON.parse(text); } catch (_) {
        return { message: 'The server answered with HTTP ' + r.status + '.' };
      }
    });
  }
  function post(url, body) {
    return fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body || {}),
    }).then(json);
  }

  function selected() {
    const ids = Array.from(modelsBox.querySelectorAll('input:checked')).map((i) => i.value);
    extra.value.split(',').map((s) => s.trim()).filter(Boolean).forEach((m) => {
      if (!ids.includes(m)) ids.push(m);
    });
    return ids;
  }
  // Where each model stands on the chosen provider: its latest finished
  // run, or that it is queued or running now. No entry means never run.
  function standing() {
    const out = new Map();
    ((lastState && lastState.runs) || []).forEach((r) => {
      if (r.provider !== provider.value || !current(r)) return;
      const id = r.provider === 'perplexity' && r.model.indexOf('/') < 0 ? 'perplexity/' + r.model : r.model;
      const had = out.get(id);
      if (r.status === 'running' || r.status === 'queued') out.set(id, { busy: true });
      else if (r.status === 'done' && r.done && !had) out.set(id, { run: r });
    });
    return out;
  }
  const hideFree = document.getElementById('dtHideFree');
  try { hideFree.checked = localStorage.getItem('lumaDeciderHideFree') === '1'; } catch (_) {}
  function isFree(m) { return m.inputPerM === 0 || /:free$/.test(m.id); }
  function visibleModels() {
    return models.filter((m) => (provider.value !== 'perplexity' || /^perplexity\//.test(m.id))
      && !(hideFree.checked && isFree(m)));
  }
  hideFree.addEventListener('change', () => {
    try { localStorage.setItem('lumaDeciderHideFree', hideFree.checked ? '1' : '0'); } catch (_) {}
    renderModels();
  });
  function updateCount() {
    const n = selected().length;
    const st = standing();
    const list = visibleModels();
    const todo = list.filter((m) => !st.has(m.id)).length;
    pickCount.textContent = list.length + ' decision models · ' + todo + ' not run yet · ' + n + ' selected';
  }
  let rendered = false;
  function renderModels() {
    const was = new Set(Array.from(modelsBox.querySelectorAll('input:checked')).map((i) => i.value));
    const st = standing();
    const list = visibleModels().slice().sort((x, y) =>
      (st.has(x.id) ? 1 : 0) - (st.has(y.id) ? 1 : 0) || x.id.localeCompare(y.id));
    modelsBox.innerHTML = list.map((m) => {
      const s = st.get(m.id);
      const checked = rendered ? was.has(m.id) : !s && /^perplexity\/pplx-decider-(flash-)?v1\.2$/.test(m.id);
      const tag = !s ? '<span class="dt-tag todo">Not run yet</span>'
        : s.busy ? '<span class="dt-tag busy">Running</span>'
        : '<span class="dt-tag done">' + s.run.accuracy.toFixed(1) + '% · ' + esc(new Date(s.run.startedAtMs).toLocaleDateString()) + '</span>';
      return '<label class="dt-model' + (s ? ' is-done' : '') + '">'
        + '<input type="checkbox" value="' + esc(m.id) + '"' + (checked ? ' checked' : '') + '>'
        + '<span><div class="dt-model-head"><span>' + esc(m.name) + '</span>' + tag + '</div><code>' + esc(m.id) + '</code>'
        + '<div class="muted">' + (m.inputPerM == null ? 'price unknown'
          : m.inputPerM === 0 ? 'free' : money(m.inputPerM) + ' / M input · output free')
        + (m.context ? ' · ' + Math.round(m.context / 1024) + 'k ctx' : '') + '</div></span></label>';
    }).join('');
    rendered = list.length > 0 && !!lastState;
    updateCount();
  }
  modelsBox.addEventListener('change', updateCount);
  extra.addEventListener('input', updateCount);
  provider.addEventListener('change', () => { rendered = false; renderModels(); });
  function pick(test) {
    modelsBox.querySelectorAll('input').forEach((i) => { i.checked = test(i.value); });
    updateCount();
  }
  document.getElementById('dtPickAll').addEventListener('click', () => pick(() => true));
  document.getElementById('dtPickNone').addEventListener('click', () => pick(() => false));
  document.getElementById('dtPickTodo').addEventListener('click', () => {
    const st = standing();
    pick((id) => !st.has(id));
  });
  document.getElementById('dtPickDeciders').addEventListener('click',
    () => pick((id) => /^perplexity\/pplx-decider/.test(id)));

  fetch('/admin/decider-tests/models').then(json).then((j) => {
    models = j.models || [];
    renderModels();
  }).catch(() => { pickCount.textContent = 'Could not load the model list.'; });

  // Runs made on an older or edited suite don't compare with current ones:
  // they drop off the chart and their models count as not run yet.
  function current(r) { return !!lastState && r.suite === lastState.suiteHash; }

  // Dot colours follow the company's logo. Companies not listed get a
  // steady colour of their own from their name.
  const BRAND = {
    perplexity: '#20b8cd', openai: '#10a37f', cloudflare: '#f38020', microsoft: '#00a4ef',
    google: '#4285f4', anthropic: '#d97757', mistralai: '#fa520f', 'meta-llama': '#0668e1',
    meta: '#0668e1', nvidia: '#76b900', amazon: '#ff9900', ibm: '#0f62fe', upstage: '#805cfb',
    togethercomputer: '#0f6fff', 'x-ai': '#e7e7e7', deepseek: '#4d6bfe', qwen: '#615ced',
  };
  function vendorOf(id) { return id.indexOf('/') < 0 ? 'perplexity' : id.split('/')[0].replace(/^~/, ''); }
  function colorOf(id) {
    const v = vendorOf(id);
    if (BRAND[v]) return BRAND[v];
    let h = 0;
    for (const ch of v) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
    return 'hsl(' + (h % 360) + ',62%,64%)';
  }

  // The latest finished run per provider and model on the current suite.
  function latestPoints(runs) {
    const seen = new Map();
    runs.forEach((r) => {
      if (r.status !== 'done' || !r.done || !current(r)) return;
      const k = r.provider + '|' + r.model;
      if (!seen.has(k)) seen.set(k, r);
    });
    return Array.from(seen.values());
  }

  function renderChart(state) {
    const pts = latestPoints(state.runs || []);
    if (!pts.length) {
      chart.innerHTML = '<div class="muted">No finished runs yet. Pick models and press Run selected.</div>';
      return;
    }
    const key = metric.value;
    const W = 820, H = 400, L = 56, R = 28, T = 18, B = 50;
    const costs = pts.map((p) => p.costPer1k).filter((c) => c > 0);
    let lo = costs.length ? Math.floor(Math.log10(Math.min(...costs))) : -4;
    let hi = costs.length ? Math.ceil(Math.log10(Math.max(...costs))) : -2;
    if (hi - lo < 2) { lo -= 1; hi += 1; }
    const freeX = L + 12;
    const x = (c) => c > 0 ? L + 44 + (Math.log10(c) - lo) / (hi - lo) * (W - L - R - 44) : freeX;
    const y = (v) => T + (1 - v / 100) * (H - T - B);
    let svg = '<svg viewBox="0 0 ' + W + ' ' + H + '" role="img" aria-label="Cost per 1,000 cases against ' + (key === 'accuracy' ? 'accuracy' : 'probability on the right answer') + '">';
    for (let v = 0; v <= 100; v += 20) {
      svg += '<line class="dt-grid" x1="' + L + '" x2="' + (W - R) + '" y1="' + y(v) + '" y2="' + y(v) + '"/>'
        + '<text x="' + (L - 8) + '" y="' + (y(v) + 4) + '" text-anchor="end">' + v + '%</text>';
    }
    for (let e = lo; e <= hi; e++) {
      const c = Math.pow(10, e);
      svg += '<line class="dt-grid" x1="' + x(c) + '" x2="' + x(c) + '" y1="' + T + '" y2="' + (H - B) + '"/>'
        + '<text x="' + x(c) + '" y="' + (H - B + 16) + '" text-anchor="middle">' + money(c) + '</text>';
    }
    if (pts.some((p) => !(p.costPer1k > 0))) {
      svg += '<text x="' + freeX + '" y="' + (H - B + 16) + '" text-anchor="middle">free</text>';
    }
    svg += '<line class="dt-axis" x1="' + L + '" x2="' + (W - R) + '" y1="' + (H - B) + '" y2="' + (H - B) + '"/>'
      + '<line class="dt-axis" x1="' + L + '" x2="' + L + '" y1="' + T + '" y2="' + (H - B) + '"/>'
      + '<text x="' + ((L + W - R) / 2) + '" y="' + (H - 10) + '" text-anchor="middle">Cost per 1,000 cases (log scale)</text>';
    const chance = state.chance || 0;
    svg += '<line class="dt-ceiling" x1="' + L + '" x2="' + (W - R) + '" y1="' + y(50) + '" y2="' + y(50) + '"/>'
      + '<text x="' + (W - R) + '" y="' + (y(50) - 5) + '" text-anchor="end">50% ceiling</text>';
    if (key === 'accuracy' && chance > 0) {
      svg += '<line class="dt-chance" x1="' + L + '" x2="' + (W - R) + '" y1="' + y(chance) + '" y2="' + y(chance) + '"/>'
        + '<text x="' + (W - R) + '" y="' + (y(chance) - 5) + '" text-anchor="end">guessing ' + chance.toFixed(1) + '%</text>';
    }
    const sorted = pts.slice().sort((a, b) => (a.costPer1k || 0) - (b.costPer1k || 0) || b[key] - a[key]);
    const front = [];
    sorted.forEach((p) => { if (!front.length || p[key] > front[front.length - 1][key]) front.push(p); });
    if (front.length > 1) {
      svg += '<polyline class="dt-front" points="' + front.map((p) => x(p.costPer1k) + ',' + y(p[key])).join(' ') + '"/>';
    }
    const placed = [];
    sorted.forEach((p) => {
      const px = x(p.costPer1k), py = y(p[key]);
      const color = colorOf(p.model);
      const name = p.model.replace(/^[^/]+\//, '') + (p.provider === 'perplexity' ? ' (direct)' : '');
      let ly = py - 9;
      while (placed.some((q) => Math.abs(q.y - ly) < 13 && Math.abs(q.x - px) < 150)) ly += 13;
      placed.push({ x: px, y: ly });
      const anchor = px > W - 190 ? 'end' : 'start';
      svg += '<g><title>' + esc(p.model) + ' · ' + esc(p.providerLabel) + '\n'
        + 'Accuracy ' + p.accuracy.toFixed(1) + '% · P(right) ' + p.meanPTrue.toFixed(1) + '%\n'
        + money(p.costPer1k) + ' per 1,000 cases · run cost ' + money(p.costUsd) + '</title>'
        + '<circle cx="' + px + '" cy="' + py + '" r="' + (front.includes(p) ? 7 : 6) + '" fill="' + color + '"'
        + (p.provider === 'perplexity' ? ' class="dt-direct"' : '') + '/></g>'
        + '<text class="dt-label" x="' + (px + (anchor === 'end' ? -9 : 9)) + '" y="' + ly + '" text-anchor="' + anchor + '">'
        + esc(name) + ' · ' + p[key].toFixed(1) + '%</text>';
    });
    const vendors = Array.from(new Set(sorted.map((p) => vendorOf(p.model)))).sort();
    chart.innerHTML = svg + '</svg><div class="dt-legend">' + vendors.map((v) =>
      '<span><i style="background:' + colorOf(v + '/x') + '"></i>' + esc(v) + '</span>').join('')
      + (sorted.some((p) => p.provider === 'perplexity') ? '<span><i class="dt-direct-key"></i>white ring: Perplexity direct</span>' : '')
      + '</div>';
  }
  metric.addEventListener('change', () => { if (lastState) renderChart(lastState); });

  function render(state) {
    lastState = state;
    if (models.length) renderModels();
    const runs = state.runs || [];
    if (!runs.length) {
      rows.innerHTML = '<tr><td colspan="10" class="muted">No runs yet.</td></tr>';
    } else {
      rows.innerHTML = runs.map((r) => {
        const skills = Object.entries(r.bySkill || {}).sort((a, b) => a[0].localeCompare(b[0]))
          .map(([k, v]) => esc(k) + ' <span class="' + scoreClass(v.score) + '">' + Math.round(v.score) + '%</span> <span class="muted">(' + v.n + ')</span>').join('<br>');
        const badge = r.status === 'running'
          ? '<span class="badge warn">running ' + r.done + '/' + r.total + '</span>'
          : r.status === 'queued' ? '<span class="badge">queued</span>'
          : r.status === 'done' ? (current(r) ? '' : '<span class="badge" title="Scored on an older or edited suite; not on the chart">older suite</span>')
          : '<span class="badge err">' + esc(r.status) + ' at ' + r.done + '/' + r.total + '</span>'
            + (r.note ? '<div class="muted" style="font-size:11px;color:#e07e7e;max-width:340px">' + esc(r.note) + '</div>' : '');
        return '<tr data-run="' + esc(r.id) + '">'
          + '<td class="nowrap">' + esc(new Date(r.startedAtMs).toLocaleString()) + '</td>'
          + '<td><strong>' + esc(r.model) + '</strong><div class="muted" style="font-size:11px">' + esc(r.providerLabel)
          + (r.ownKey ? ' · own key' + (r.keyHint ? ' <code>' + esc(r.keyHint) + '</code>' : '') : '') + '</div>' + badge + '</td>'
          + '<td><span class="dt-score ' + scoreClass(r.accuracy) + '">' + r.accuracy.toFixed(1) + '%</span></td>'
          + '<td>' + r.meanPTrue.toFixed(1) + '%</td>'
          + '<td class="dt-kinds">' + (skills || '—') + '</td>'
          + '<td>' + money(r.costUsd) + '<div class="muted" style="font-size:11px">' + (r.inputTokens || 0).toLocaleString() + ' tok</div></td>'
          + '<td>' + money(r.costPer1k) + '</td>'
          + '<td>' + r.errors + '</td>'
          + '<td>' + (r.avgMs / 1000).toFixed(1) + ' s</td>'
          + '<td class="actions-cell nowrap"><button type="button" class="btn btn-ghost btn-sm dt-detail-btn">'
          + (open.has(r.id) ? 'Hide' : 'Details') + '</button> '
          + (r.status === 'running' || r.status === 'queued' ? '' : '<button type="button" class="btn btn-ghost btn-sm dt-del-btn">Delete</button>')
          + '</td></tr>'
          + (open.has(r.id) ? '<tr class="dt-detail" data-detail="' + esc(r.id) + '"><td colspan="10" class="muted">Loading…</td></tr>' : '');
      }).join('');
      open.forEach(loadDetail);
    }
    renderChart(state);
    const running = runs.find((r) => r.status === 'running');
    const queued = runs.filter((r) => r.status === 'queued').length;
    const busy = !!running || queued > 0;
    runBtn.disabled = busy;
    stopBtn.hidden = !busy;
    progress.hidden = !running;
    if (running) {
      const pct = running.total ? Math.round(running.done / running.total * 100) : 0;
      progressLabel.textContent = running.model + ': ' + running.done + ' of ' + running.total + ' cases';
      progressQueue.textContent = queued ? queued + ' more queued' : '';
      bar.setAttribute('aria-valuenow', String(pct));
      barFill.style.width = pct + '%';
    }
    if (!suiteLoaded) { suite.value = state.suite || ''; suiteLoaded = true; }
    const badgeEl = document.getElementById('dtSuiteBadge');
    badgeEl.className = 'badge ' + (state.suiteError ? 'err' : state.customSuite ? 'ok' : 'warn');
    badgeEl.textContent = state.suiteError ? 'needs fixing'
      : state.cases + ' cases' + (state.customSuite ? '' : ' · built-in');
    suiteStatus.textContent = state.suiteError
      ? 'The saved suite has a problem: ' + state.suiteError
      : state.cases + ' cases, guessing scores ' + state.chance + '%';
    return busy;
  }

  function loadDetail(id) {
    fetch('/admin/decider-tests/runs/' + encodeURIComponent(id)).then(json).then((run) => {
      const cell = rows.querySelector('tr[data-detail="' + CSS.escape(id) + '"] td');
      if (!cell || !run.results) return;
      cell.classList.remove('muted');
      const results = run.results.slice().sort((a, b) => a.policy.localeCompare(b.policy) || a.id.localeCompare(b.id));
      cell.innerHTML = '<table><thead><tr><th>Case</th><th>Policy</th><th>Skill</th><th>Expected</th>'
        + '<th>Model said</th><th>Result</th><th>P(right)</th><th>Time</th></tr></thead><tbody>'
        + results.map((c) => '<tr><td class="nowrap">' + esc(c.id) + '</td>'
          + '<td>' + esc(c.policy) + '</td><td>' + esc(c.skill) + '</td>'
          + '<td>' + esc(c.expected) + (!c.right && c.why ? '<div class="dt-why">' + esc(c.why) + '</div>' : '') + '</td>'
          + '<td>' + esc(c.got) + (c.error ? '<div class="badge err">' + esc(c.error) + '</div>' : '') + '</td>'
          + '<td><span class="dt-score ' + (c.right ? 'good' : 'bad') + '" style="font-size:13px">' + (c.right ? '✓' : '✗') + '</span></td>'
          + '<td>' + Math.round(c.pTrue * 100) + '%</td>'
          + '<td>' + (c.ms / 1000).toFixed(1) + ' s</td></tr>').join('')
        + '</tbody></table>';
    });
  }

  function load() {
    fetch('/admin/decider-tests').then(json).then((state) => {
      if (!state.runs) { status.textContent = state.message || 'Could not load the decider test.'; return; }
      const busy = render(state);
      clearTimeout(timer);
      if (busy) timer = setTimeout(load, 2500);
    }).catch(() => { status.textContent = 'Could not load the decider test.'; });
  }

  rows.addEventListener('click', (event) => {
    const tr = event.target.closest('tr[data-run]');
    if (!tr) return;
    const id = tr.dataset.run;
    if (event.target.closest('.dt-detail-btn')) {
      if (open.has(id)) open.delete(id); else open.add(id);
      load();
    } else if (event.target.closest('.dt-del-btn')) {
      if (!confirm('Delete this run?')) return;
      open.delete(id);
      post('/admin/decider-tests/runs/' + encodeURIComponent(id) + '/delete').then(load);
    }
  });

  runBtn.addEventListener('click', () => {
    const ids = selected();
    if (!ids.length) { status.textContent = 'Pick at least one model.'; return; }
    runBtn.disabled = true;
    status.textContent = 'Starting…';
    if (!keyTouched) key.value = '';
    post('/admin/decider-tests/run', {
      provider: provider.value,
      models: ids,
      apiKey: keyTouched ? key.value.trim() : '',
    }).then((j) => {
      if (!j.ok) {
        status.textContent = j.message || 'Could not start the test.';
        runBtn.disabled = false;
        return;
      }
      key.value = '';
      keyTouched = false;
      status.textContent = 'Queued ' + j.runs.length + ' model' + (j.runs.length === 1 ? '' : 's')
        + ' through ' + j.runs[0].total + ' cases'
        + (j.keyHint ? ' with key ' + j.keyHint : ' with the server\'s key') + '…';
      load();
    }).catch(() => { status.textContent = 'Could not start the test.'; runBtn.disabled = false; });
  });

  stopBtn.addEventListener('click', () => {
    stopBtn.disabled = true;
    post('/admin/decider-tests/stop').then(() => {
      status.textContent = 'Stopping after the cases already in flight…';
      stopBtn.disabled = false;
      load();
    });
  });

  document.getElementById('dtSuiteSave').addEventListener('click', () => {
    suiteStatus.textContent = 'Saving…';
    post('/admin/decider-tests/suite', { suite: suite.value }).then((j) => {
      suiteStatus.textContent = j.ok ? 'Saved — ' + j.cases + ' cases, guessing scores ' + j.chance + '%.' : (j.message || 'Could not save.');
      if (j.ok) load();
    });
  });
  document.getElementById('dtSuiteReset').addEventListener('click', () => {
    if (!confirm('Replace your suite with the built-in one?')) return;
    post('/admin/decider-tests/suite', { reset: true }).then((j) => {
      if (j.ok) suite.value = j.suite;
      suiteStatus.textContent = j.ok ? 'Back to the built-in suite — ' + j.cases + ' cases.' : (j.message || 'Could not reset.');
      if (j.ok) load();
    });
  });

  let saved = 'scene';
  try { saved = localStorage.getItem('lumaBenchmarkMode') || 'scene'; } catch (_) {}
  if (saved === 'decider') setMode('decider'); else load();
})();
''';
