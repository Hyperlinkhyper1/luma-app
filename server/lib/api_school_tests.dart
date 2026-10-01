part of 'api.dart';

/// The admin dashboard's Tests tab: the school test (see `school_test.dart`)
/// run against any provider and model, with the server's key or one pasted
/// for that run only.
extension SchoolTestsApi on Api {
  static const _maxTokens = 4096;

  static final _keyPattern = RegExp(r'^[\x21-\x7e]{8,400}$');

  /// The suite, whether it is the operator's own, and every run.
  Future<Response> _adminSchoolTestsState(Request request) async {
    String? suiteError;
    var caseCount = 0;
    try {
      caseCount = SchoolTestSuite.parse(schoolTests.suiteText).cases.length;
    } on FormatException catch (e) {
      suiteError = e.message;
    }
    return jsonResponse(200, {
      'suite': schoolTests.suiteText,
      'customSuite': schoolTests.customSuite,
      'cases': caseCount,
      if (suiteError != null) 'suiteError': suiteError,
      'running': schoolTests.running?.id,
      'runs': [for (final r in schoolTests.runs) r.summaryJson()],
    });
  }

  /// One run with every case's result.
  Future<Response> _adminSchoolTestsRunDetail(Request request) async {
    final run = schoolTests.run(request.params['id'] ?? '');
    if (run == null) {
      return errorResponse(404, 'not_found', 'No run with that id.');
    }
    return jsonResponse(200, run.toJson());
  }

  /// Starts a run of the saved suite against the posted provider and model.
  /// A pasted `apiKey` is used for this run's calls and nothing else: it is
  /// held in memory until the run ends and never written anywhere.
  Future<Response> _adminSchoolTestsStart(Request request) async {
    Map<String, dynamic> body;
    try {
      body = await Api._readJson(request);
    } on FormatException {
      return errorResponse(400, 'bad_request', 'Malformed request.');
    }
    final upstream = AiUpstream.parse(
        body['upstream'] is String ? body['upstream'] as String : null);
    if (upstream == null) {
      return errorResponse(400, 'bad_request', 'Choose a valid provider.');
    }
    final model =
        body['model'] is String ? (body['model'] as String).trim() : '';
    if (!isValidAiModelId(model)) {
      return errorResponse(400, 'bad_request', 'Enter a valid model ID.');
    }
    final effort = body['reasoningEffort'] ?? '';
    if (effort is! String || !kAiReasoningEfforts.contains(effort)) {
      return errorResponse(
          400, 'bad_request', 'Choose a valid reasoning effort.');
    }
    final rawKey =
        body['apiKey'] is String ? (body['apiKey'] as String).trim() : '';
    final apiKey = rawKey.isEmpty ? null : rawKey;
    if (apiKey != null && !_keyPattern.hasMatch(apiKey)) {
      return errorResponse(400, 'bad_request',
          'That API key does not look right — paste it without spaces.');
    }
    if (apiKey == null && !config.configuredAiUpstreams.contains(upstream)) {
      return errorResponse(409, 'no_key',
          'The server has no ${upstream.label} key. Paste one to run the test with it.');
    }
    if (schoolTests.running != null) {
      return errorResponse(
          409, 'busy', 'A test is already running. Stop it or wait for it.');
    }
    final SchoolTestSuite suite;
    try {
      suite = SchoolTestSuite.parse(schoolTests.suiteText);
    } on FormatException catch (e) {
      return errorResponse(
          400, 'bad_suite', 'Fix the test prompts first: ${e.message}');
    }
    final route = AiModeRoute(upstream, model,
        reasoningEffort: effort.isEmpty ? null : effort);
    final now = DateTime.now().millisecondsSinceEpoch;
    final run = SchoolTestRun(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      route: route,
      ownKey: apiKey != null,
      startedAtMs: now,
      total: suite.cases.length,
    );
    await schoolTests.add(run);
    unawaited(_runSchoolTest(run, suite, apiKey));
    return jsonResponse(200, run.summaryJson());
  }

  Future<void> _runSchoolTest(
      SchoolTestRun run, SchoolTestSuite suite, String? apiKey) async {
    String scrub(String s) {
      final clean = apiKey == null ? s : s.replaceAll(apiKey, '•••');
      final flat = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
      return flat.length > 300 ? '${flat.substring(0, 300)}…' : flat;
    }

    Future<SchoolTestReply> call(List<Map<String, String>> messages,
        {required double temperature}) async {
      final upstreamBody = Api._aiUpstreamBody({
        'messages': messages,
        'max_tokens': _maxTokens,
        'temperature': temperature,
      }, run.route);
      final (status, responseBody) =
          await _callAiUpstream(run.route, upstreamBody, apiKey: apiKey);
      var tokens = 0;
      String? content;
      String? error;
      try {
        final decoded = jsonDecode(responseBody);
        if (decoded is Map) {
          tokens = (decoded['usage']?['total_tokens'] as num?)?.toInt() ?? 0;
          content = decoded['choices']?[0]?['message']?['content'] as String?;
          final upstreamError = decoded['error'];
          if (upstreamError is Map) {
            error = upstreamError['message']?.toString();
          } else if (upstreamError is String) {
            error = upstreamError;
          }
        }
      } catch (_) {}
      if (status != HttpStatus.ok) {
        return SchoolTestReply(
            tokens: tokens,
            error: scrub('HTTP $status${error == null ? '' : ': $error'}'));
      }
      return SchoolTestReply(
          content: content,
          tokens: tokens,
          error: content == null ? 'Empty reply.' : null);
    }

    var lastSave = DateTime.now();
    try {
      await runSchoolTestSuite(
        run,
        suite,
        classroomConfig.config.effectiveInstructions,
        call,
        onProgress: () async {
          if (DateTime.now().difference(lastSave).inSeconds < 3) return;
          lastSave = DateTime.now();
          await schoolTests.persist();
        },
      );
      run.status = run.stopRequested ? 'stopped' : 'done';
    } catch (e) {
      stderr.writeln('[luma] school test ${run.id} failed: ${scrub('$e')}');
      run.status = 'stopped';
    }
    run.finishedAtMs = DateTime.now().millisecondsSinceEpoch;
    await schoolTests.persist();
    await store.logActivity(
        'school_test_run',
        '${run.route.upstream.label} · ${run.route.model}: '
            '${run.score.toStringAsFixed(1)}% over ${run.results.length}/'
            '${run.total} cases${run.ownKey ? ' (own key)' : ''}'
            '${run.status == 'stopped' ? ', stopped' : ''}');
  }

  Future<Response> _adminSchoolTestsStop(Request request) async {
    final run = schoolTests.running;
    if (run == null) return jsonResponse(200, {'ok': true, 'running': false});
    run.stopRequested = true;
    return jsonResponse(200, {'ok': true, 'running': true, 'id': run.id});
  }

  /// Saves the operator's cases, or `{"reset": true}` for the starter set.
  Future<Response> _adminSchoolTestsSuite(Request request) async {
    Map<String, dynamic> body;
    try {
      body = await Api._readJson(request);
    } on FormatException {
      return errorResponse(400, 'bad_request', 'Malformed request.');
    }
    try {
      if (body['reset'] == true) {
        await schoolTests.saveSuite(null);
      } else {
        final text = body['suite'];
        if (text is! String) {
          return errorResponse(400, 'bad_request', 'Send the test prompts.');
        }
        await schoolTests.saveSuite(text);
      }
    } on FormatException catch (e) {
      return errorResponse(400, 'bad_suite', e.message);
    }
    return jsonResponse(200, {
      'ok': true,
      'cases': SchoolTestSuite.parse(schoolTests.suiteText).cases.length,
      'customSuite': schoolTests.customSuite,
      'suite': schoolTests.suiteText,
    });
  }

  Future<Response> _adminSchoolTestsDelete(Request request) async {
    final deleted = await schoolTests.delete(request.params['id'] ?? '');
    if (!deleted) {
      return errorResponse(404, 'not_found', 'No finished run with that id.');
    }
    return jsonResponse(200, {'ok': true});
  }

  /// The Tests tab's school test card: model picker, results and prompts.
  String _adminSchoolTestsCard() {
    String esc(String s) => Api._htmlEscape(s).replaceAll('"', '&quot;');
    final configured = config.configuredAiUpstreams;
    final classroom = _aiClassroomRoute();
    final upstream = classroom?.upstream ??
        (configured.isEmpty ? AiUpstream.openrouter : configured.first);
    final upstreamOptions = AiUpstream.values.map((u) {
      final hasKey = configured.contains(u);
      return '<option value="${u.name}"${u == upstream ? ' selected' : ''}>'
          '${esc(u.label)}${hasKey ? '' : ' (no server key)'}</option>';
    }).join();
    final effortOptions = kAiReasoningEfforts.map((r) {
      final label = r.isEmpty ? 'Default' : r;
      return '<option value="$r"'
          '${(classroom?.reasoningEffort ?? '') == r ? ' selected' : ''}>'
          '$label</option>';
    }).join();
    return '<style>'
        '.st-form{display:grid;grid-template-columns:minmax(150px,1fr) '
        'minmax(220px,2fr) minmax(120px,.8fr) minmax(200px,1.6fr) auto;'
        'gap:10px;align-items:end}'
        '.st-form label{display:block;font-size:11px;letter-spacing:.05em;'
        'text-transform:uppercase;color:#8d86a8;margin-bottom:6px}'
        '.st-form select,.st-form input,.st-suite textarea{width:100%;'
        'background:#1a1530;color:#ece8f7;border:1px solid #2d2645;'
        'border-radius:9px;padding:8px 10px;font:13px inherit;outline:none;'
        'box-sizing:border-box}'
        '.st-form input{font-family:ui-monospace,Consolas,monospace;font-size:12.5px}'
        '.st-form select:focus,.st-form input:focus,.st-suite textarea:focus'
        '{border-color:#8a7ee0}'
        '.st-suite textarea{min-height:340px;resize:vertical;'
        'font:12px/1.5 ui-monospace,Consolas,monospace}'
        '.st-score{font:600 22px ui-monospace,Consolas,monospace}'
        '.st-score.good{color:#7ee08a}.st-score.mid{color:#e0c87e}'
        '.st-score.bad{color:#e07e7e}'
        '.st-kinds{font-size:12px;color:#c5bed9;white-space:nowrap}'
        '.st-detail td{background:#151122}'
        '.st-detail table td{font-size:12px;vertical-align:top;'
        'overflow-wrap:anywhere}'
        '.st-best{font-size:10.5px;margin-left:6px}'
        '@media (max-width:900px){.st-form{grid-template-columns:1fr}}'
        '</style>'
        '<div class="card">'
        '<h2>School test</h2>'
        '<div class="maint-desc">Runs your test prompts against one provider '
        'and model and scores how well it would do as the classroom tutor. '
        'Answers with a number or an option letter are checked by the '
        'server, not by the model; grading cases compare the model\'s '
        'verdict with yours (half a point when it is one step off), and '
        '"harsh" counts right answers it marked wrong. Grading and question '
        'cases use the classroom tutor\'s live instructions from the '
        'Assistant tab. Paste an API key to run a model on a key the server '
        'doesn\'t have, or on your own account; the key is used for that run '
        'only and is never saved.</div>'
        '<div class="st-form">'
        '<div><label for="stUpstream">Provider</label>'
        '<select id="stUpstream">$upstreamOptions</select></div>'
        '<div><label for="stModel">Model</label>'
        '<input id="stModel" type="text" list="ai-dl-${upstream.name}" '
        'value="${esc(classroom?.model ?? '')}" maxlength="200" '
        'spellcheck="false" autocomplete="off" placeholder="model id"></div>'
        '<div><label for="stEffort">Reasoning</label>'
        '<select id="stEffort">$effortOptions</select></div>'
        '<div><label for="stKey">API key (optional)</label>'
        '<input id="stKey" type="password" autocomplete="off" '
        'spellcheck="false" placeholder="Use the server\'s key"></div>'
        '<div style="display:flex;gap:6px">'
        '<button id="stRunBtn" type="button" class="btn btn-primary">Run test</button>'
        '<button id="stStopBtn" type="button" class="btn btn-ghost" hidden>Stop</button>'
        '</div>'
        '</div>'
        '<div id="stStatus" class="maint-status" style="margin-top:12px"></div>'
        '<div id="stProgress" class="bn-progress" hidden>'
        '<div class="bn-progress-head"><span id="stProgressLabel"></span></div>'
        '<div class="bn-bar" role="progressbar" aria-label="School test progress" '
        'aria-valuemin="0" aria-valuemax="100" aria-valuenow="0" id="stBar">'
        '<div id="stBarFill" class="bn-bar-fill"></div></div>'
        '</div>'
        '<div style="overflow-x:auto;margin-top:14px">'
        '<table><thead><tr><th>When</th><th>Model</th><th>Score</th>'
        '<th>By kind</th><th>Harsh</th><th>Errors</th><th>Tokens</th>'
        '<th>Avg time</th><th></th></tr></thead>'
        '<tbody id="stRuns"><tr><td colspan="9" class="muted">Loading…</td></tr>'
        '</tbody></table></div>'
        '</div>'
        '<div class="card st-suite">'
        '<h2>Test prompts</h2>'
        '<div class="maint-desc">The cases every run goes through, as JSON. '
        'Each case has an <code>id</code>, a <code>kind</code> and a '
        '<code>lesson</code> (country, school, year, level, subject, '
        'publisher, chapter, paragraph, topic). '
        '<code>answer</code> cases add a <code>question</code>, optional '
        '<code>choices</code> and an <code>expect</code> with one of '
        '<code>number</code> (plus optional <code>tolerance</code>), '
        '<code>choice</code> (the option letter) or <code>accept</code> '
        '(a list of accepted phrases). <code>grade</code> cases add a '
        '<code>question</code>, a <code>studentAnswer</code> and '
        '<code>expect.result</code>: correct, partly or wrong. '
        '<code>question</code> cases need only the lesson; the model writes '
        'a question and its format is checked. Up to $kSchoolTestMaxCases '
        'cases.</div>'
        '<textarea id="stSuite" spellcheck="false" aria-label="Test prompts JSON"></textarea>'
        '<div class="maint-actions" style="margin-top:10px">'
        '<button id="stSuiteSave" type="button" class="btn btn-primary">Save prompts</button>'
        '<button id="stSuiteReset" type="button" class="btn btn-ghost">Reset to starter set</button>'
        '<span id="stSuiteStatus" class="muted" style="font-size:12px"></span>'
        '</div>'
        '</div>';
  }

  String get _adminSchoolTestsScript => _schoolTestsScript;
}

/// The Tests tab's school test card: starts runs, polls while one runs,
/// renders the results table and edits the prompts.
const _schoolTestsScript = r'''
(function () {
  const runBtn = document.getElementById('stRunBtn');
  if (!runBtn) return;
  const stopBtn = document.getElementById('stStopBtn');
  const upstream = document.getElementById('stUpstream');
  const model = document.getElementById('stModel');
  const effort = document.getElementById('stEffort');
  const key = document.getElementById('stKey');
  const status = document.getElementById('stStatus');
  const rows = document.getElementById('stRuns');
  const progress = document.getElementById('stProgress');
  const progressLabel = document.getElementById('stProgressLabel');
  const bar = document.getElementById('stBar');
  const barFill = document.getElementById('stBarFill');
  const suite = document.getElementById('stSuite');
  const suiteStatus = document.getElementById('stSuiteStatus');
  const open = new Set();
  let timer = null;
  let suiteLoaded = false;

  function esc(v) {
    return String(v == null ? '' : v).replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    })[c]);
  }
  function scoreClass(s) { return s >= 80 ? 'good' : s >= 55 ? 'mid' : 'bad'; }
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

  upstream.addEventListener('change', () => {
    model.setAttribute('list', 'ai-dl-' + upstream.value);
  });

  const kindNames = { answer: 'Answers', grade: 'Grading', question: 'Questions' };
  function render(state) {
    const runs = state.runs || [];
    const finished = runs.filter((r) => r.status === 'done');
    const best = finished.reduce((b, r) => (!b || r.score > b.score ? r : b), null);
    if (!runs.length) {
      rows.innerHTML = '<tr><td colspan="9" class="muted">No runs yet. Pick a model and press Run test.</td></tr>';
    } else {
      rows.innerHTML = runs.map((r) => {
        const kinds = Object.entries(r.byKind || {}).map(([k, v]) =>
          esc(kindNames[k] || k) + ' ' + Math.round(v.score) + '% <span class="muted">(' + v.n + ')</span>').join('<br>');
        const state = r.status === 'running'
          ? '<span class="badge warn">running ' + r.done + '/' + r.total + '</span>'
          : r.status === 'done' ? ''
          : '<span class="badge err">' + esc(r.status) + ' at ' + r.done + '/' + r.total + '</span>';
        const main = '<tr data-run="' + esc(r.id) + '">'
          + '<td class="nowrap">' + esc(new Date(r.startedAtMs).toLocaleString()) + '</td>'
          + '<td><strong>' + esc(r.model) + '</strong>'
          + (best && best.id === r.id && finished.length > 1 ? '<span class="badge ok st-best">best</span>' : '')
          + '<div class="muted" style="font-size:11px">' + esc(r.upstreamLabel)
          + (r.reasoningEffort ? ' · ' + esc(r.reasoningEffort) : '')
          + (r.ownKey ? ' · own key' : '') + '</div>' + state + '</td>'
          + '<td><span class="st-score ' + scoreClass(r.score) + '">' + r.score.toFixed(1) + '%</span></td>'
          + '<td class="st-kinds">' + (kinds || '—') + '</td>'
          + '<td>' + (r.harsh ? '<span class="badge err">' + r.harsh + '</span>' : '0') + '</td>'
          + '<td>' + r.errors + '</td>'
          + '<td>' + r.tokens.toLocaleString() + '</td>'
          + '<td>' + (r.avgMs / 1000).toFixed(1) + ' s</td>'
          + '<td class="actions-cell nowrap">'
          + '<button type="button" class="btn btn-ghost btn-sm st-detail-btn">'
          + (open.has(r.id) ? 'Hide' : 'Details') + '</button> '
          + (r.status === 'running' ? '' : '<button type="button" class="btn btn-ghost btn-sm st-del-btn">Delete</button>')
          + '</td></tr>';
        return main + (open.has(r.id)
          ? '<tr class="st-detail" data-detail="' + esc(r.id) + '"><td colspan="9" class="muted">Loading…</td></tr>'
          : '');
      }).join('');
      open.forEach(loadDetail);
    }
    const running = runs.find((r) => r.status === 'running');
    runBtn.disabled = !!running;
    stopBtn.hidden = !running;
    progress.hidden = !running;
    if (running) {
      const pct = running.total ? Math.round(running.done / running.total * 100) : 0;
      progressLabel.textContent = running.model + ': ' + running.done + ' of ' + running.total + ' cases';
      bar.setAttribute('aria-valuenow', String(pct));
      barFill.style.width = pct + '%';
    }
    if (!suiteLoaded) {
      suite.value = state.suite || '';
      suiteLoaded = true;
    }
    suiteStatus.textContent = state.suiteError
      ? 'The saved prompts have a problem: ' + state.suiteError
      : state.cases + ' cases' + (state.customSuite ? '' : ' (starter set)');
    return !!running;
  }

  function loadDetail(id) {
    fetch('/admin/school-tests/runs/' + encodeURIComponent(id)).then(json).then((run) => {
      const cell = rows.querySelector('tr[data-detail="' + CSS.escape(id) + '"] td');
      if (!cell || !run.results) return;
      cell.classList.remove('muted');
      cell.innerHTML = '<table><thead><tr><th>Case</th><th>Kind</th><th>Expected</th>'
        + '<th>Model said</th><th>Score</th><th>Time</th></tr></thead><tbody>'
        + run.results.map((c) => '<tr><td class="nowrap">' + esc(c.id) + '</td>'
          + '<td>' + esc(kindNames[c.kind] || c.kind) + '</td>'
          + '<td>' + esc(c.expected) + '</td>'
          + '<td>' + esc(c.got) + (c.error ? '<div class="badge err">' + esc(c.error) + '</div>' : '')
          + (c.harsh ? ' <span class="badge err">harsh</span>' : '') + '</td>'
          + '<td><span class="st-score ' + scoreClass(c.score * 100) + '" style="font-size:13px">'
          + (c.score === 1 ? '✓' : c.score === 0 ? '✗' : '½') + '</span></td>'
          + '<td>' + (c.ms / 1000).toFixed(1) + ' s</td></tr>').join('')
        + '</tbody></table>';
    });
  }

  function load() {
    fetch('/admin/school-tests').then(json).then((state) => {
      if (!state.runs) { status.textContent = state.message || 'Could not load the tests.'; return; }
      const running = render(state);
      clearTimeout(timer);
      if (running) timer = setTimeout(load, 2500);
    }).catch(() => { status.textContent = 'Could not load the tests.'; });
  }

  rows.addEventListener('click', (event) => {
    const tr = event.target.closest('tr[data-run]');
    if (!tr) return;
    const id = tr.dataset.run;
    if (event.target.closest('.st-detail-btn')) {
      if (open.has(id)) open.delete(id); else open.add(id);
      load();
    } else if (event.target.closest('.st-del-btn')) {
      if (!confirm('Delete this run?')) return;
      open.delete(id);
      post('/admin/school-tests/runs/' + encodeURIComponent(id) + '/delete').then(load);
    }
  });

  runBtn.addEventListener('click', () => {
    if (!model.value.trim()) { status.textContent = 'Enter a model first.'; model.focus(); return; }
    runBtn.disabled = true;
    status.textContent = 'Starting…';
    post('/admin/school-tests/run', {
      upstream: upstream.value,
      model: model.value.trim(),
      reasoningEffort: effort.value,
      apiKey: key.value.trim(),
    }).then((j) => {
      if (!j.id) {
        status.textContent = j.message || 'Could not start the test.';
        runBtn.disabled = false;
        return;
      }
      key.value = '';
      status.textContent = 'Running ' + j.model + ' through ' + j.total + ' cases…';
      load();
    }).catch(() => { status.textContent = 'Could not start the test.'; runBtn.disabled = false; });
  });

  stopBtn.addEventListener('click', () => {
    stopBtn.disabled = true;
    post('/admin/school-tests/stop').then(() => {
      status.textContent = 'Stopping after the cases already in flight…';
      stopBtn.disabled = false;
      load();
    });
  });

  document.getElementById('stSuiteSave').addEventListener('click', () => {
    suiteStatus.textContent = 'Saving…';
    post('/admin/school-tests/suite', { suite: suite.value }).then((j) => {
      suiteStatus.textContent = j.ok ? 'Saved — ' + j.cases + ' cases.' : (j.message || 'Could not save.');
    });
  });
  document.getElementById('stSuiteReset').addEventListener('click', () => {
    if (!confirm('Replace your test prompts with the starter set?')) return;
    post('/admin/school-tests/suite', { reset: true }).then((j) => {
      if (j.ok) suite.value = j.suite;
      suiteStatus.textContent = j.ok ? 'Back to the starter set — ' + j.cases + ' cases.' : (j.message || 'Could not reset.');
    });
  });

  load();
})();
''';
