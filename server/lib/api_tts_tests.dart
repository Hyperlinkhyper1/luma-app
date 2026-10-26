part of 'api.dart';

/// OpenRouter's speech models with their voices and prices, refreshed at
/// most every half hour.
List<Map<String, dynamic>>? _ttsModels;
DateTime? _ttsModelsAt;

const _kTtsSpeechUrl = 'https://openrouter.ai/api/v1/audio/speech';

/// The Add benchmark dialog's Text to Speech mode: every speech model on
/// OpenRouter reads the four scripts in `tts_test.dart`, and the clips land
/// in AI Usage → Tests → Text to Speech with what each cost and took.
extension TtsTestsApi on Api {
  Future<Response> _adminTtsTestsState(Request request) async =>
      jsonResponse(200, {
        'tests': [for (final t in kTtsTests) t.toJson()],
        'scripts': kTtsScriptHash,
        'serverKey': config.openRouterKeyConfigured,
        'runs': [for (final r in ttsTests.runs) r.summaryJson()],
      });

  Future<List<Map<String, dynamic>>> _ttsModelList() async {
    final at = _ttsModelsAt;
    if (_ttsModels != null &&
        at != null &&
        DateTime.now().difference(at) < const Duration(minutes: 30)) {
      return _ttsModels!;
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(Uri.parse(
          'https://openrouter.ai/api/v1/models?output_modalities=speech'));
      final res = await req.close().timeout(const Duration(seconds: 20));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != HttpStatus.ok) throw HttpException('${res.statusCode}');
      final data = (jsonDecode(body) as Map)['data'];
      final models = <Map<String, dynamic>>[];
      if (data is List) {
        for (final m in data) {
          if (m is! Map || m['id'] is! String) continue;
          final id = m['id'] as String;
          if (id.startsWith('~') || id.endsWith('-latest')) continue;
          final voices = [
            if (m['supported_voices'] case final List list)
              for (final v in list)
                if (v is String) v,
          ];
          final prompt = double.tryParse('${m['pricing']?['prompt'] ?? ''}');
          final completion =
              double.tryParse('${m['pricing']?['completion'] ?? ''}');
          models.add({
            'id': id,
            'name': m['name'] is String ? m['name'] : id,
            'voices': voices,
            'femaleVoice': guessTtsVoice(voices, 'female'),
            'maleVoice': guessTtsVoice(voices, 'male'),
            if (prompt != null) 'prompt': prompt,
            if (completion != null) 'completion': completion,
          });
        }
      }
      models.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
      if (models.isNotEmpty) {
        _ttsModels = models;
        _ttsModelsAt = DateTime.now();
      }
    } catch (e) {
      stderr.writeln('[luma] tts model list: $e');
    }
    return _ttsModels ?? const [];
  }

  Future<Response> _adminTtsTestsModels(Request request) async {
    final chars = kTtsTests.fold<int>(0, (n, t) => n + t.text.length);
    return jsonResponse(200, {'models': await _ttsModelList(), 'chars': chars});
  }

  /// Queues one run per posted `{id, femaleVoice, maleVoice}` and works
  /// through them one at a time. A pasted `apiKey` is held in memory for
  /// this batch only.
  Future<Response> _adminTtsTestsStart(Request request) async {
    Map<String, dynamic> body;
    try {
      body = await Api._readJson(request);
    } on FormatException {
      return errorResponse(400, 'bad_request', 'Malformed request.');
    }
    String? voice(Object? v) {
      if (v is! String) return null;
      final s = v.trim();
      return s.isEmpty || s.length > 120 ? null : s;
    }

    final picks = <({String id, String? female, String? male})>[];
    final seen = <String>{};
    if (body['models'] case final List list) {
      for (final m in list) {
        if (m is! Map || m['id'] is! String) continue;
        final id = (m['id'] as String).trim();
        if (!isValidAiModelId(id)) {
          return errorResponse(400, 'bad_request', '"$id" is not a valid model ID.');
        }
        if (!seen.add(id)) continue;
        picks.add((id: id, female: voice(m['femaleVoice']), male: voice(m['maleVoice'])));
      }
    }
    if (picks.isEmpty) {
      return errorResponse(400, 'bad_request', 'Pick at least one model.');
    }
    if (picks.length > kTtsMaxModelsPerBatch) {
      return errorResponse(400, 'bad_request',
          'At most $kTtsMaxModelsPerBatch models per batch.');
    }
    final rawKey =
        body['apiKey'] is String ? (body['apiKey'] as String).trim() : '';
    final apiKey = rawKey.isEmpty ? null : rawKey;
    if (apiKey != null) {
      if (deciderKeyProblem(DeciderProvider.openrouter, apiKey)
          case final problem?) {
        return errorResponse(400, 'bad_key', problem);
      }
    }
    final key = apiKey ?? config.openRouterApiKey;
    if (key == null || key.isEmpty) {
      return errorResponse(409, 'no_key',
          'The server has no OpenRouter key. Paste one to run with it.');
    }
    if (ttsTests.busy) {
      return errorResponse(
          409, 'busy', 'A batch is already running. Stop it or wait for it.');
    }
    final now = DateTime.now();
    final runs = [
      for (var i = 0; i < picks.length; i++)
        TtsRun(
          id: '${now.microsecondsSinceEpoch.toRadixString(36)}$i',
          model: picks[i].id,
          femaleVoice: picks[i].female,
          maleVoice: picks[i].male,
          startedAtMs: now.millisecondsSinceEpoch,
          scripts: kTtsScriptHash,
          ownKey: apiKey != null,
          keyHint: apiKey == null ? null : deciderKeyHint(apiKey),
        ),
    ];
    await ttsTests.addAll(runs);
    unawaited(_runTtsBatch(runs, key));
    return jsonResponse(200, {
      'ok': true,
      'runs': [for (final r in runs) r.summaryJson()],
      if (apiKey != null) 'keyHint': deciderKeyHint(apiKey),
    });
  }

  Future<void> _runTtsBatch(List<TtsRun> runs, String key) async {
    final prices = {
      for (final m in await _ttsModelList())
        m['id'] as String: {
          if (m['prompt'] is num) 'prompt': (m['prompt'] as num).toDouble(),
          if (m['completion'] is num)
            'completion': (m['completion'] as num).toDouble(),
        },
    };
    for (final run in runs) {
      if (run.status != 'queued') continue;
      run.status = 'running';
      run.startedAtMs = DateTime.now().millisecondsSinceEpoch;
      await ttsTests.persist();
      try {
        await runTtsModel(
          run,
          speak: (body) => _ttsSpeak(key, body),
          cost: (id) => _ttsGenerationCost(key, id),
          saveAudio: (clip, bytes) => ttsTests.saveAudio(run, clip, bytes),
          price: prices[run.model],
          onProgress: ttsTests.persist,
        );
        run.status = run.stopRequested
            ? 'stopped'
            : (run.okClips == 0 ? 'failed' : 'done');
      } catch (e) {
        final text = '$e'.replaceAll(key, '•••');
        stderr.writeln('[luma] tts test ${run.id} failed: $text');
        run.status = 'failed';
        run.note ??= text.length > 300 ? '${text.substring(0, 300)}…' : text;
      }
      run.finishedAtMs = DateTime.now().millisecondsSinceEpoch;
      await ttsTests.persist();
      await store.logActivity(
          'tts_test_run',
          '${run.model}: ${run.okClips}/${kTtsTests.length} clips, '
              '\$${run.costUsd.toStringAsFixed(5)} in '
              '${(run.totalMs / 1000).toStringAsFixed(1)} s'
              '${run.ownKey ? ' (own key)' : ''}'
              '${run.status == 'done' ? '' : ', ${run.status}'}');
      if (run.status == 'stopped') {
        for (final rest in runs.where((r) => r.status == 'queued')) {
          rest.status = 'stopped';
          rest.finishedAtMs = DateTime.now().millisecondsSinceEpoch;
        }
        await ttsTests.persist();
        break;
      }
    }
  }

  /// One speech request, retried on rate limits and provider hiccups. The
  /// reply is raw audio on success and a JSON error otherwise.
  Future<TtsReply> _ttsSpeak(String key, Map<String, dynamic> body) async {
    String scrub(String s) {
      final flat = s.replaceAll(key, '•••').replaceAll(RegExp(r'\s+'), ' ').trim();
      return flat.length > 300 ? '${flat.substring(0, 300)}…' : flat;
    }

    final payload = utf8.encode(jsonEncode(body));
    for (var attempt = 0;; attempt++) {
      int status;
      List<int> bytes = const [];
      String? contentType;
      String? generationId;
      String? retryAfter;
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      try {
        final req = await client.postUrl(Uri.parse(_kTtsSpeechUrl));
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
        req.headers.set('HTTP-Referer', config.publicUrl);
        req.headers.set('X-Title', 'luma');
        req.headers.contentType = ContentType.json;
        req.add(payload);
        final res = await req.close().timeout(const Duration(seconds: 60));
        status = res.statusCode;
        contentType = res.headers.value(HttpHeaders.contentTypeHeader);
        generationId = res.headers.value('x-generation-id');
        retryAfter = res.headers.value('retry-after');
        final builder = BytesBuilder(copy: false);
        await for (final chunk in res.timeout(const Duration(seconds: 180))) {
          builder.add(chunk);
          if (builder.length > 40 << 20) {
            throw const HttpException('The clip passed 40 MB.');
          }
        }
        bytes = builder.takeBytes();
      } on TimeoutException {
        status = HttpStatus.gatewayTimeout;
        bytes = utf8.encode('Timed out.');
      } on IOException catch (e) {
        status = 0;
        bytes = utf8.encode('$e');
      } finally {
        client.close(force: true);
      }

      final isJson = (contentType ?? '').contains('json');
      if (status == HttpStatus.ok && !isJson && bytes.isNotEmpty) {
        return TtsReply(
            audio: bytes, contentType: contentType, generationId: generationId);
      }
      final text = utf8.decode(bytes, allowMalformed: true);
      String? error;
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map) {
          final e = decoded['error'];
          error = e is Map ? e['message']?.toString() : e?.toString();
        }
      } catch (_) {
        error = text.isEmpty ? null : text;
      }
      final retryable =
          status == 429 || status == 0 || (status >= 500 && status != 501);
      if (retryable && attempt < 4) {
        final wait = int.tryParse(retryAfter ?? '') ?? (2 << attempt);
        await Future<void>.delayed(Duration(seconds: wait.clamp(1, 20)));
        continue;
      }
      return TtsReply(
        status: status,
        fatal: status == 401 || status == 402 || status == 403,
        error: scrub('HTTP $status${error == null ? '' : ': $error'}'
            '${status == 401 || status == 403 ? ' — OpenRouter refused the key' : ''}'
            '${status == 402 ? ' — the OpenRouter account is out of credit' : ''}'),
      );
    }
  }

  /// What OpenRouter billed for one generation. Its stats lag the reply by
  /// a moment, so a 404 is retried a few times before giving up.
  Future<double?> _ttsGenerationCost(String key, String id) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      await Future<void>.delayed(Duration(milliseconds: 800 * (attempt + 1)));
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      try {
        final req = await client.getUrl(Uri.parse(
            'https://openrouter.ai/api/v1/generation?id=${Uri.encodeQueryComponent(id)}'));
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
        final res = await req.close().timeout(const Duration(seconds: 15));
        final body = await res.transform(utf8.decoder).join();
        if (res.statusCode == HttpStatus.ok) {
          final data = (jsonDecode(body) as Map)['data'];
          final cost = data is Map ? data['total_cost'] ?? data['usage'] : null;
          if (cost is num) return cost.toDouble();
          return null;
        }
        if (res.statusCode != HttpStatus.notFound) return null;
      } catch (_) {
        // Fall through to the next attempt; the list price covers a miss.
      } finally {
        client.close(force: true);
      }
    }
    return null;
  }

  Future<Response> _adminTtsTestsStop(Request request) async {
    final active = ttsTests.active;
    for (final run in active) {
      run.stopRequested = true;
      if (run.status == 'queued') {
        run.status = 'stopped';
        run.finishedAtMs = DateTime.now().millisecondsSinceEpoch;
      }
    }
    if (active.isNotEmpty) await ttsTests.persist();
    return jsonResponse(200, {'ok': true, 'running': active.isNotEmpty});
  }

  Future<Response> _adminTtsTestsDelete(Request request) async {
    final deleted = await ttsTests.delete(request.params['id'] ?? '');
    if (!deleted) {
      return errorResponse(404, 'not_found', 'No finished run with that id.');
    }
    return jsonResponse(200, {'ok': true});
  }

  /// One clip's audio, for the dashboard and (through [_ttsAppAudio]) the
  /// app.
  Future<Response> _ttsAudio(Request request) async {
    final run = ttsTests.run(request.params['id'] ?? '');
    final clip = run?.clip(request.params['test'] ?? '');
    final format = clip?.format;
    if (run == null || clip == null || format == null) {
      return errorResponse(404, 'not_found', 'No such clip.');
    }
    final file = ttsTests.audioFile(run.id, clip.test, format);
    if (file == null || !await file.exists()) {
      return errorResponse(404, 'not_found', 'No such clip.');
    }
    return Response.ok(file.openRead(), headers: {
      'Content-Type': format == 'wav' ? 'audio/wav' : 'audio/mpeg',
      'Content-Length': '${await file.length()}',
      'Cache-Control': 'private, max-age=31536000, immutable',
    });
  }

  Future<Response> _adminTtsTestsAudio(Request request) => _ttsAudio(request);

  Future<Response> _ttsAppAudio(Request request, StoredUser user) =>
      _ttsAudio(request);

  /// The app's AI Usage → Tests → Text to Speech: each model's latest
  /// finished run on today's scripts, with every clip's cost and timing.
  /// Never key hints.
  Future<Response> _ttsResults(Request request, StoredUser user) async {
    final seen = <String>{};
    var otherScripts = 0;
    final models = <Map<String, dynamic>>[];
    for (final run in ttsTests.runs) {
      if (run.status != 'done' || run.okClips == 0) continue;
      if (run.scripts != kTtsScriptHash) {
        otherScripts++;
        continue;
      }
      if (!seen.add(run.model)) continue;
      models.add({
        'runId': run.id,
        'model': run.model,
        'femaleVoice': run.femaleVoice,
        'maleVoice': run.maleVoice,
        'costUsd': run.costUsd,
        'costEstimated': run.costEstimated,
        'totalMs': run.totalMs,
        'finishedAtMs': run.finishedAtMs ?? run.startedAtMs,
        'clips': [
          for (final c in run.clips)
            {
              'test': c.test,
              'voice': c.voice,
              'ok': c.ok,
              'ms': c.ms,
              if (c.seconds != null) 'seconds': c.seconds,
              if (c.costUsd != null) 'costUsd': c.costUsd,
              if (c.format != null) 'format': c.format,
            },
        ],
      });
    }
    models.sort((a, b) => (a['model'] as String).compareTo(b['model'] as String));
    return Response(200,
        body: jsonEncode({
          'scripts': kTtsScriptHash,
          'tests': [
            for (final t in kTtsTests)
              {'id': t.id, 'voice': t.voice, 'text': t.text},
          ],
          'models': models,
          'hidden': {'otherScripts': otherScripts},
        }),
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache',
        });
  }

  /// The Text to Speech half of the Add benchmark dialog.
  String _adminTtsView() {
    final scripts = kTtsTests
        .map((t) => '<div class="tt-script"><div class="tt-script-head">'
            '<strong>${Api._htmlEscape(t.title)}</strong>'
            '<span class="dt-tag">${t.voice == 'female' ? 'Woman' : 'Man'}</span></div>'
            '<div class="muted tt-instr">${Api._htmlEscape(t.instructions)}</div>'
            '<pre class="tt-text">${Api._htmlEscape(t.text)}</pre></div>')
        .join();
    return '<style>$_ttsCss</style>'
        '<div id="ttView" class="dt-view" hidden>'
        '<section class="dt-sec">'
        '<div class="bg-step-head"><h3>Speech models</h3>'
        '<span id="ttPickCount" class="bg-step-hint">Loading models…</span></div>'
        '<div class="dt-desc">Every model reads the same four scripts below: a '
        'train station announcement and a poem in a woman\'s voice, the same '
        'poem and a speech in a man\'s. Pick each model\'s two voices; luma '
        'guesses them from the voice names. Every clip is saved with what '
        'OpenRouter billed and how long it took, and finished runs show up in '
        'the app under AI Usage → Tests → Text to Speech. Runs use the '
        'server\'s OpenRouter key unless you paste one for this batch.</div>'
        '<div class="dt-form tt-form">'
        '<div><label for="ttKey">OpenRouter key (optional)</label>'
        '<input id="ttKey" name="tt-provider-key" type="password" '
        'autocomplete="new-password" data-1p-ignore data-lpignore="true" '
        'data-bwignore data-form-type="other" spellcheck="false" '
        'placeholder="Use the server\'s key"></div>'
        '<div><label for="ttSearch">Filter</label>'
        '<input id="ttSearch" type="search" spellcheck="false" autocomplete="off" '
        'placeholder="e.g. elevenlabs"></div>'
        '</div>'
        '<div class="dt-pick-head">'
        '<label class="dt-hide-free"><input type="checkbox" id="ttHideFree"> Hide free models</label>'
        '<button type="button" class="btn btn-ghost btn-sm" id="ttPickTodo">Not run yet</button>'
        '<button type="button" class="btn btn-ghost btn-sm" id="ttPickAll">All</button>'
        '<button type="button" class="btn btn-ghost btn-sm" id="ttPickNone">None</button></div>'
        '<div id="ttModels" class="dt-models tt-models"></div>'
        '<div id="ttProgress" class="bn-progress" hidden>'
        '<div class="bn-progress-head"><span id="ttProgressLabel"></span>'
        '<span id="ttProgressQueue" class="muted"></span></div>'
        '<div class="bn-bar" role="progressbar" aria-label="Text to speech progress" '
        'aria-valuemin="0" aria-valuemax="100" aria-valuenow="0" id="ttBar">'
        '<div id="ttBarFill" class="bn-bar-fill"></div></div></div>'
        '</section>'
        '<section class="dt-sec">'
        '<div class="bg-step-head"><h3>Runs</h3></div>'
        '<div id="ttRuns" class="tt-runs"><div class="muted">Loading…</div></div>'
        '</section>'
        '<details class="bg-prompt dt-suite"><summary>The four scripts '
        '<span class="badge">same text for every model</span></summary>'
        '<div class="dt-suite-body">$scripts</div></details>'
        '</div>'
        '<div id="ttFoot" class="bn-dlg-foot" hidden>'
        '<span id="ttStatus" class="bn-foot-note" aria-live="polite"></span>'
        '<button type="button" class="btn btn-ghost" data-close>Close</button>'
        '<button id="ttStopBtn" type="button" class="btn btn-ghost" hidden>Stop</button>'
        '<button id="ttRunBtn" type="button" class="btn btn-primary">Run selected</button>'
        '</div>';
  }

  String get _adminTtsScript => _ttsScript;
}

const _ttsCss = r'''
.tt-form{grid-template-columns:minmax(220px,1fr) minmax(220px,1fr)}
.tt-models{grid-template-columns:repeat(auto-fill,minmax(300px,1fr));max-height:360px}
.tt-voices{display:grid;grid-template-columns:1fr 1fr;gap:6px;margin-top:6px}
.tt-voices label{font-size:10.5px;letter-spacing:.04em;text-transform:uppercase;color:#8d86a8;display:block;margin-bottom:2px}
.tt-voices select,.tt-voices input{width:100%;box-sizing:border-box;background:#1a1530;color:#ece8f7;border:1px solid #2d2645;border-radius:7px;padding:4px 6px;font:12px ui-monospace,Consolas,monospace}
.tt-runs{display:flex;flex-direction:column;gap:10px}
.tt-run{background:#151122;border:1px solid #221c33;border-radius:12px;padding:12px 14px}
.tt-run-head{display:flex;flex-wrap:wrap;align-items:baseline;gap:6px 14px}
.tt-run-head strong{font-size:13.5px}
.tt-run-head .tt-meta{font-size:12px;color:#a9a0c3;font-variant-numeric:tabular-nums}
.tt-run-head .actions-cell{margin-left:auto}
.tt-clips{display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:8px;margin-top:10px}
.tt-clip{background:#12101e;border:1px solid #221c33;border-radius:9px;padding:8px 10px;font-size:12px}
.tt-clip-head{display:flex;justify-content:space-between;gap:6px;margin-bottom:6px;color:#c5bed9}
.tt-clip audio{width:100%;height:32px}
.tt-clip .tt-meta{color:#9b94b3;margin-top:4px;font-variant-numeric:tabular-nums}
.tt-clip .tt-err{color:#e07e7e;overflow-wrap:anywhere}
.tt-script{padding:10px 0;border-bottom:1px solid #221c33}
.tt-script-head{display:flex;gap:8px;align-items:center}
.tt-instr{font-size:12px;margin:4px 0}
.tt-text{white-space:pre-wrap;font:12.5px/1.5 ui-sans-serif,system-ui,sans-serif;color:#ece8f7;margin:0}
@media (max-width:900px){.tt-form{grid-template-columns:1fr}}
''';

/// The Text to Speech view: model + voice picker, batch runs, and every
/// run's four clips to listen to with their cost and timing.
const _ttsScript = r'''
(function () {
  const runBtn = document.getElementById('ttRunBtn');
  if (!runBtn) return;
  const stopBtn = document.getElementById('ttStopBtn');
  const key = document.getElementById('ttKey');
  const search = document.getElementById('ttSearch');
  const modelsBox = document.getElementById('ttModels');
  const pickCount = document.getElementById('ttPickCount');
  const status = document.getElementById('ttStatus');
  const runsBox = document.getElementById('ttRuns');
  const progress = document.getElementById('ttProgress');
  const progressLabel = document.getElementById('ttProgressLabel');
  const progressQueue = document.getElementById('ttProgressQueue');
  const bar = document.getElementById('ttBar');
  const barFill = document.getElementById('ttBarFill');
  const hideFree = document.getElementById('ttHideFree');
  let models = [];
  let chars = 0;
  let lastState = null;
  let timer = null;
  let keyTouched = false;
  let loaded = false;
  const choice = new Map();
  key.addEventListener('keydown', () => { keyTouched = true; });
  key.addEventListener('paste', () => { keyTouched = true; });

  function esc(v) {
    return String(v == null ? '' : v).replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    })[c]);
  }
  function money(v) {
    if (v == null) return '—';
    if (!v) return '$0';
    if (v >= 1) return '$' + v.toFixed(2);
    if (v >= 0.01) return '$' + v.toFixed(3);
    return '$' + v.toPrecision(2);
  }
  function secs(ms) { return (ms / 1000).toFixed(1) + ' s'; }
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

  // A model's latest finished run on today's scripts, or that it is busy.
  function standing() {
    const out = new Map();
    ((lastState && lastState.runs) || []).forEach((r) => {
      if (!r.current) return;
      if (r.status === 'running' || r.status === 'queued') out.set(r.model, { busy: true });
      else if (r.status === 'done' && !out.has(r.model)) out.set(r.model, { run: r });
    });
    return out;
  }
  try { hideFree.checked = localStorage.getItem('lumaTtsHideFree') === '1'; } catch (_) {}
  function isFree(m) { return /:free$/.test(m.id) || (m.prompt === 0 && m.completion === 0); }
  function estimate(m) {
    if (m.prompt == null) return null;
    return m.prompt > 0 ? m.prompt * chars : null;
  }
  function visible() {
    const q = search.value.trim().toLowerCase();
    return models.filter((m) => !(hideFree.checked && isFree(m))
      && (!q || m.id.toLowerCase().includes(q) || String(m.name).toLowerCase().includes(q)));
  }
  function remember() {
    modelsBox.querySelectorAll('.dt-model').forEach((card) => {
      const id = card.dataset.id;
      const box = card.querySelector('input[type=checkbox]');
      const f = card.querySelector('[data-voice=female]');
      const m = card.querySelector('[data-voice=male]');
      choice.set(id, { on: box.checked, female: f.value, male: m.value });
    });
  }
  function voiceField(m, gender, value) {
    const label = gender === 'female' ? 'Woman voice' : 'Man voice';
    if (!m.voices.length) {
      return '<div><label>' + label + '</label><input data-voice="' + gender + '" value="' + esc(value || '')
        + '" placeholder="provider default" spellcheck="false"></div>';
    }
    return '<div><label>' + label + '</label><select data-voice="' + gender + '">'
      + m.voices.map((v) => '<option' + (v === value ? ' selected' : '') + '>' + esc(v) + '</option>').join('')
      + '</select></div>';
  }
  function renderModels() {
    if (loaded) remember();
    const st = standing();
    const list = visible().slice().sort((a, b) =>
      (st.has(a.id) ? 1 : 0) - (st.has(b.id) ? 1 : 0) || a.id.localeCompare(b.id));
    modelsBox.innerHTML = list.map((m) => {
      const s = st.get(m.id);
      const c = choice.get(m.id) || { on: false, female: m.femaleVoice, male: m.maleVoice };
      const tag = !s ? '<span class="dt-tag todo">Not run yet</span>'
        : s.busy ? '<span class="dt-tag busy">Running</span>'
        : '<span class="dt-tag done">' + money(s.run.costUsd) + ' · ' + esc(new Date(s.run.startedAtMs).toLocaleDateString()) + '</span>';
      const est = estimate(m);
      return '<div class="dt-model' + (s ? ' is-done' : '') + '" data-id="' + esc(m.id) + '">'
        + '<input type="checkbox" aria-label="Run ' + esc(m.id) + '"' + (c.on ? ' checked' : '') + '>'
        + '<span><div class="dt-model-head"><span>' + esc(m.name) + '</span>' + tag + '</div><code>' + esc(m.id) + '</code>'
        + '<div class="muted">' + (isFree(m) ? 'free' : est != null ? '≈ ' + money(est) + ' for all four' : 'priced per second of audio')
        + ' · ' + (m.voices.length ? m.voices.length + ' voices' : 'no voice list') + '</div>'
        + '<div class="tt-voices">' + voiceField(m, 'female', c.female) + voiceField(m, 'male', c.male) + '</div>'
        + '</span></div>';
    }).join('') || '<div class="muted">No speech models match.</div>';
    loaded = true;
    updateCount();
  }
  function selected() {
    remember();
    return Array.from(choice.entries()).filter(([, c]) => c.on)
      .map(([id, c]) => ({ id: id, femaleVoice: c.female, maleVoice: c.male }));
  }
  function updateCount() {
    const st = standing();
    const list = visible();
    const n = Array.from(modelsBox.querySelectorAll('input[type=checkbox]:checked')).length;
    pickCount.textContent = list.length + ' speech models · '
      + list.filter((m) => !st.has(m.id)).length + ' not run yet · ' + n + ' selected';
  }
  modelsBox.addEventListener('change', updateCount);
  modelsBox.addEventListener('click', (e) => {
    const card = e.target.closest('.dt-model');
    if (!card || e.target.closest('select,input,label')) return;
    const box = card.querySelector('input[type=checkbox]');
    box.checked = !box.checked;
    updateCount();
  });
  search.addEventListener('input', renderModels);
  hideFree.addEventListener('change', () => {
    try { localStorage.setItem('lumaTtsHideFree', hideFree.checked ? '1' : '0'); } catch (_) {}
    renderModels();
  });
  function pick(test) {
    modelsBox.querySelectorAll('.dt-model').forEach((card) => {
      card.querySelector('input[type=checkbox]').checked = test(card.dataset.id);
    });
    updateCount();
  }
  document.getElementById('ttPickAll').addEventListener('click', () => pick(() => true));
  document.getElementById('ttPickNone').addEventListener('click', () => pick(() => false));
  document.getElementById('ttPickTodo').addEventListener('click', () => {
    const st = standing();
    pick((id) => !st.has(id));
  });

  function render(state) {
    lastState = state;
    if (models.length) renderModels();
    const tests = state.tests || [];
    const runs = state.runs || [];
    if (!runs.length) {
      runsBox.innerHTML = '<div class="muted">No runs yet. Pick models and press Run selected.</div>';
    } else {
      runsBox.innerHTML = runs.map((r) => {
        const badge = r.status === 'running' ? '<span class="badge warn">running ' + r.done + '/' + r.total + '</span>'
          : r.status === 'queued' ? '<span class="badge">queued</span>'
          : r.status === 'done' ? (r.current ? '' : '<span class="badge" title="Read older scripts; not shown in the app">older scripts</span>')
          : '<span class="badge err">' + esc(r.status) + '</span>';
        const clips = tests.map((t) => {
          const c = (r.clips || []).find((x) => x.test === t.id);
          if (!c) return '<div class="tt-clip"><div class="tt-clip-head"><span>' + esc(t.title) + '</span></div><div class="muted">' + (r.status === 'running' || r.status === 'queued' ? 'Waiting…' : 'Not read') + '</div></div>';
          return '<div class="tt-clip"><div class="tt-clip-head"><span>' + esc(t.title) + '</span><code>' + esc(c.voice || 'default') + '</code></div>'
            + (c.format ? '<audio controls preload="none" src="/admin/tts-tests/audio/' + encodeURIComponent(r.id) + '/' + encodeURIComponent(t.id) + '"></audio>' : '<div class="tt-err">' + esc(c.error || 'Failed') + '</div>')
            + '<div class="tt-meta">' + money(c.costUsd) + (c.costEstimated ? ' (list price)' : '') + ' · made in ' + secs(c.ms)
            + (c.seconds ? ' · plays ' + c.seconds.toFixed(1) + ' s' : '') + '</div></div>';
        }).join('');
        return '<div class="tt-run" data-run="' + esc(r.id) + '"><div class="tt-run-head">'
          + '<strong>' + esc(r.model) + '</strong>' + badge
          + '<span class="tt-meta">' + esc(new Date(r.startedAtMs).toLocaleString())
          + ' · ' + money(r.costUsd) + ' total · ' + secs(r.totalMs || 0)
          + (r.ownKey ? ' · own key' + (r.keyHint ? ' <code>' + esc(r.keyHint) + '</code>' : '') : '') + '</span>'
          + '<span class="actions-cell">' + (r.status === 'running' || r.status === 'queued' ? ''
            : '<button type="button" class="btn btn-ghost btn-sm tt-del-btn">Delete</button>') + '</span></div>'
          + (r.note ? '<div class="tt-err" style="font-size:12px;color:#e07e7e;margin-top:4px">' + esc(r.note) + '</div>' : '')
          + '<div class="tt-clips">' + clips + '</div></div>';
      }).join('');
    }
    const running = runs.find((r) => r.status === 'running');
    const queued = runs.filter((r) => r.status === 'queued').length;
    const busy = !!running || queued > 0;
    runBtn.disabled = busy;
    stopBtn.hidden = !busy;
    progress.hidden = !running;
    if (running) {
      const pct = Math.round(running.done / running.total * 100);
      progressLabel.textContent = running.model + ': ' + running.done + ' of ' + running.total + ' clips';
      progressQueue.textContent = queued ? queued + ' more queued' : '';
      bar.setAttribute('aria-valuenow', String(pct));
      barFill.style.width = pct + '%';
    }
    return busy;
  }

  // Re-rendering mid-playback would cut a clip off, so the poll only
  // redraws while a batch runs.
  function load() {
    fetch('/admin/tts-tests').then(json).then((state) => {
      if (!state.runs) { status.textContent = state.message || 'Could not load the TTS test.'; return; }
      const busy = render(state);
      clearTimeout(timer);
      if (busy) timer = setTimeout(load, 3000);
    }).catch(() => { status.textContent = 'Could not load the TTS test.'; });
  }
  let modelsLoaded = false;
  function open() {
    load();
    if (modelsLoaded) return;
    modelsLoaded = true;
    fetch('/admin/tts-tests/models').then(json).then((j) => {
      models = j.models || [];
      chars = j.chars || 0;
      if (!models.length) pickCount.textContent = 'Could not load the speech models from OpenRouter.';
      else renderModels();
    }).catch(() => { pickCount.textContent = 'Could not load the model list.'; modelsLoaded = false; });
  }
  document.addEventListener('luma-benchmark-mode', (e) => { if (e.detail === 'tts') open(); });

  runsBox.addEventListener('click', (event) => {
    const btn = event.target.closest('.tt-del-btn');
    if (!btn) return;
    const id = btn.closest('[data-run]').dataset.run;
    if (!confirm('Delete this run and its clips?')) return;
    post('/admin/tts-tests/runs/' + encodeURIComponent(id) + '/delete').then(load);
  });

  runBtn.addEventListener('click', () => {
    const picks = selected();
    if (!picks.length) { status.textContent = 'Pick at least one model.'; return; }
    runBtn.disabled = true;
    status.textContent = 'Starting…';
    if (!keyTouched) key.value = '';
    post('/admin/tts-tests/run', {
      models: picks,
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
        + (j.keyHint ? ' with key ' + j.keyHint : ' with the server\'s key') + '…';
      load();
    }).catch(() => { status.textContent = 'Could not start the test.'; runBtn.disabled = false; });
  });

  stopBtn.addEventListener('click', () => {
    stopBtn.disabled = true;
    post('/admin/tts-tests/stop').then(() => {
      status.textContent = 'Stopping after the clip in flight…';
      stopBtn.disabled = false;
      load();
    });
  });
})();
''';
