part of 'api.dart';

const _wikiVersion = 'wiki-search-v1';

class _WikiStore {
  _WikiStore(String dir) : file = File('$dir/wiki-search-results.json') {
    try {
      final data = jsonDecode(file.readAsStringSync());
      if (data is List)
        runs.addAll(
            data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
    } catch (_) {}
  }
  final File file;
  final List<Map<String, dynamic>> runs = [];
  bool busy = false;
  String? error;
  Future<void> save() async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(runs));
    await tmp.rename(file.path);
  }
}

extension WikiTestsApi on Api {
  Future<Response> _wikiState(Request request) async => jsonResponse(200, {
        'busy': wikiTests.busy,
        'error': wikiTests.error,
        'runs':
            wikiTests.runs.where((r) => r['suite'] == _wikiVersion).toList(),
        'serverKey': config.openRouterKeyConfigured,
      });

  Future<Response> _wikiResults(Request request, StoredUser user) async =>
      jsonResponse(200, {
        'cases': wikiQueries.length,
        'models':
            wikiTests.runs.where((r) => r['suite'] == _wikiVersion).toList(),
      });

  Future<Response> _wikiModels(Request request) async {
    final key = config.openRouterApiKey;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client
          .getUrl(Uri.parse('https://openrouter.ai/api/v1/embeddings/models'));
      if (key != null && key.isNotEmpty)
        req.headers.set('Authorization', 'Bearer $key');
      final res = await req.close().timeout(const Duration(seconds: 20));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200)
        throw HttpException('Model catalog returned ${res.statusCode}');
      final data = (jsonDecode(body) as Map)['data'];
      return jsonResponse(200, {
        'models': [
          if (data is List)
            for (final m in data)
              if (m is Map && m['id'] is String)
                {'id': m['id'], 'name': m['name'] ?? m['id']},
        ]
      });
    } catch (_) {
      return errorResponse(502, 'catalog_unavailable',
          'Could not load the embedding model catalog.');
    } finally {
      client.close(force: true);
    }
  }

  Future<Response> _wikiStart(Request request) async {
    Map<String, dynamic> body;
    try {
      body = await Api._readJson(request);
    } on FormatException {
      return errorResponse(400, 'bad_request', 'Malformed request.');
    }
    final model =
        body['model'] is String ? (body['model'] as String).trim() : '';
    if (!isValidAiModelId(model))
      return errorResponse(400, 'bad_request', 'Choose a valid model.');
    final pasted =
        body['apiKey'] is String ? (body['apiKey'] as String).trim() : '';
    if (pasted.isNotEmpty) {
      final problem = deciderKeyProblem(DeciderProvider.openrouter, pasted);
      if (problem != null) return errorResponse(400, 'bad_key', problem);
    }
    final key = pasted.isEmpty ? config.openRouterApiKey : pasted;
    if (key == null || key.isEmpty)
      return errorResponse(
          409, 'no_key', 'Configure or paste an OpenRouter key.');
    if (wikiTests.busy)
      return errorResponse(
          409, 'busy', 'A wiki search test is already running.');
    wikiTests.busy = true;
    wikiTests.error = null;
    unawaited(_wikiRun(model, key));
    return jsonResponse(200, {'ok': true});
  }

  Future<void> _wikiRun(String model, String key) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client
          .postUrl(Uri.parse('https://openrouter.ai/api/v1/embeddings'));
      req.headers.set('Authorization', 'Bearer $key');
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'model': model,
        'input': [...wikiPassages, ...wikiQueries]
      }));
      final res = await req.close().timeout(const Duration(seconds: 120));
      final body = await res
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200)
        throw HttpException('Embedding request failed (${res.statusCode})');
      final decoded = jsonDecode(body) as Map;
      final data = decoded['data'];
      if (data is! List ||
          data.length != wikiPassages.length + wikiQueries.length)
        throw const FormatException('Missing embeddings');
      final vectors = List<List<double>?>.filled(data.length, null);
      for (final item in data) {
        if (item is! Map || item['index'] is! int || item['embedding'] is! List)
          throw const FormatException('Invalid embedding');
        final index = item['index'] as int;
        if (index < 0 || index >= vectors.length || vectors[index] != null)
          throw const FormatException('Invalid embedding index');
        vectors[index] = (item['embedding'] as List)
            .map((v) => (v as num).toDouble())
            .toList();
      }
      final score = wikiScore(vectors.map((v) => v!).toList());
      wikiTests.runs.removeWhere(
          (r) => r['model'] == model && r['suite'] == _wikiVersion);
      wikiTests.runs.insert(0, {
        'model': model,
        'score': score,
        'suite': _wikiVersion,
        'finishedAtMs': DateTime.now().millisecondsSinceEpoch
      });
      await wikiTests.save();
    } catch (e) {
      wikiTests.error = 'Benchmark failed: $e';
    } finally {
      client.close(force: true);
      wikiTests.busy = false;
    }
  }

  String _wikiView() => '''<div id="wikiView" hidden class="dt-view">
    <section class="dt-sec">
    <div class="bg-step-head"><h3>Models</h3><span id="wikiCount" class="bg-step-hint">Loading models…</span></div>
    <div class="dt-desc">Embeds 24 passages and 24 indirect queries. Score is mean reciprocal rank at 10; higher is better. Select one model or enter a model ID. Runs use the server's OpenRouter key unless you paste one.</div>
    <div class="dt-form">
    <div><label for="wikiKey">OpenRouter API key (optional)</label><input id="wikiKey" type="password" autocomplete="new-password" placeholder="Use the server's key"></div>
    <div><label for="wikiManual">Other model ID</label><input id="wikiManual" type="text" autocomplete="off" spellcheck="false" placeholder="vendor/model"></div>
    <div><label for="wikiSearch">Search models</label><input id="wikiSearch" type="search" autocomplete="off" placeholder="Name or model ID"></div>
    </div>
    <div class="dt-pick-head"><span class="dt-desc">Choose one model</span></div>
    <div id="wikiModels" class="dt-models" role="radiogroup" aria-label="Embedding model"><div class="muted">Loading models…</div></div>
    </section>
    <section class="dt-sec"><div class="bg-step-head"><h3>Runs</h3></div><div id="wikiRuns" class="dt-desc">No finished runs yet.</div></section>
    <div><button type="button" class="btn btn-primary" id="wikiRun">Run selected</button> <span id="wikiStatus" class="muted" role="status"></span></div>
    </div>''';

  String get _wikiScript => r'''
(() => {
  const view = document.getElementById('wikiView'), modelsBox = document.getElementById('wikiModels');
  const status = document.getElementById('wikiStatus'), runs = document.getElementById('wikiRuns');
  const manual = document.getElementById('wikiManual'), search = document.getElementById('wikiSearch');
  const count = document.getElementById('wikiCount'), run = document.getElementById('wikiRun');
  let timer, models = [], latest = [], selected = '', busy = false, catalogLoaded = false;
  function render() {
    const query = search.value.trim().toLowerCase();
    const shown = models.filter(m => (m.name + ' ' + m.id).toLowerCase().includes(query));
    count.textContent = models.length + ' embedding models · ' + (selected || manual.value.trim() ? '1 selected' : '0 selected');
    modelsBox.replaceChildren();
    shown.forEach(m => {
      const label = document.createElement('label'); label.className = 'dt-model';
      const input = document.createElement('input'); input.type = 'radio'; input.name = 'wiki-model'; input.value = m.id; input.checked = selected === m.id;
      input.addEventListener('change', () => { selected = m.id; manual.value = ''; render(); });
      const content = document.createElement('span'), head = document.createElement('span'); head.className = 'dt-model-head';
      const name = document.createElement('span'); name.textContent = m.name; head.appendChild(name);
      const result = latest.find(r => r.model === m.id), tag = document.createElement('span'); tag.className = 'dt-tag' + (result ? ' done' : '');
      tag.textContent = result ? Number(result.score).toFixed(1) + '%' : 'Not run yet'; head.appendChild(tag);
      const id = document.createElement('code'); id.textContent = m.id;
      content.append(head, id); label.append(input, content); modelsBox.appendChild(label);
    });
    if (!shown.length) { const empty = document.createElement('div'); empty.className = 'muted'; empty.textContent = models.length ? 'No matching models.' : 'No models available. Enter a model ID above.'; modelsBox.appendChild(empty); }
    run.disabled = busy || !(manual.value.trim() || selected);
  }
  async function load() {
    try {
      const state = await (await fetch('/admin/wiki-tests')).json();
      busy = !!state.busy; latest = state.runs || []; status.textContent = busy ? 'Running benchmark…' : (state.error || 'Ready.');
      runs.replaceChildren();
      latest.forEach(r => { const p = document.createElement('p'); p.textContent = r.model + ': ' + Number(r.score).toFixed(1) + '%'; runs.appendChild(p); });
      if (!latest.length) runs.textContent = 'No finished runs yet.';
      render();
      clearTimeout(timer); if (state.busy) timer = setTimeout(load, 2000);
    } catch (_) { status.textContent = 'Could not load results.'; }
  }
  async function open() {
    load();
    if (catalogLoaded) return;
    try {
      const response = await fetch('/admin/wiki-tests/models');
      const result = await response.json();
      if (!response.ok) throw new Error('Catalog unavailable');
      models = (result.models || []).filter(m => typeof m.id === 'string').map(m => ({id: m.id, name: String(m.name || m.id)}));
      catalogLoaded = true; render();
      if (!models.length) status.textContent = 'Could not load embedding models.';
    } catch (_) { render(); status.textContent = 'Could not load embedding models. Enter a model ID above.'; }
  }
  document.addEventListener('luma-benchmark-mode', e => { if (e.detail === 'wiki') open(); });
  search.addEventListener('input', render);
  manual.addEventListener('input', () => { if (manual.value.trim()) selected = ''; render(); });
  document.getElementById('wikiRun').addEventListener('click', async () => {
    try {
      run.disabled = true;
      const response = await fetch('/admin/wiki-tests/run', {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({model:manual.value.trim() || selected, apiKey:document.getElementById('wikiKey').value})});
      const result = await response.json();
      if (!response.ok) { status.textContent = result.message || 'Could not start benchmark.'; render(); return; }
      document.getElementById('wikiKey').value = ''; load();
    } catch (_) { status.textContent = 'Could not start benchmark.'; render(); }
  });
  if (!view.hidden) open();
})();
''';
}
