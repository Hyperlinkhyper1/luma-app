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

  String _wikiView() => '''<div id="wikiView" hidden class="bg-body">
    <h3>Wiki search test</h3><p>Embeds 24 passages and 24 indirect queries. Score is mean reciprocal rank at 10; higher is better.</p>
    <label for="wikiModel">Embedding model</label><select id="wikiModel" class="bn-input"></select>
    <label for="wikiManual">Or enter a model ID</label><input id="wikiManual" class="bn-input" placeholder="vendor/model">
    <label for="wikiKey">OpenRouter key (optional; otherwise server key)</label><input id="wikiKey" class="bn-input" type="password" autocomplete="off">
    <button type="button" class="btn" id="wikiRun">Run benchmark</button>
    <p id="wikiStatus" role="status"></p><div id="wikiRuns"></div>
    </div>''';

  String get _wikiScript => r'''
(() => {
  const view = document.getElementById('wikiView'), model = document.getElementById('wikiModel');
  const status = document.getElementById('wikiStatus'), runs = document.getElementById('wikiRuns');
  let timer;
  async function load() {
    try {
      const state = await (await fetch('/admin/wiki-tests')).json();
      status.textContent = state.busy ? 'Running benchmark…' : (state.error || 'Ready.');
      runs.replaceChildren();
      (state.runs || []).forEach(r => { const p = document.createElement('p'); p.textContent = r.model + ': ' + Number(r.score).toFixed(1) + '%'; runs.appendChild(p); });
      clearTimeout(timer); if (state.busy) timer = setTimeout(load, 2000);
    } catch (_) { status.textContent = 'Could not load results.'; }
  }
  async function open() {
    load();
    if (model.options.length) return;
    try {
      const result = await (await fetch('/admin/wiki-tests/models')).json();
      (result.models || []).forEach(m => { const o = document.createElement('option'); o.value = m.id; o.textContent = m.name + ' (' + m.id + ')'; model.appendChild(o); });
      if (!model.options.length) status.textContent = 'Could not load embedding models.';
    } catch (_) { status.textContent = 'Could not load embedding models.'; }
  }
  document.addEventListener('luma-benchmark-mode', e => { if (e.detail === 'wiki') open(); });
  document.getElementById('wikiRun').addEventListener('click', async () => {
    try {
      const response = await fetch('/admin/wiki-tests/run', {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({model:document.getElementById('wikiManual').value.trim() || model.value, apiKey:document.getElementById('wikiKey').value})});
      const result = await response.json();
      if (!response.ok) { status.textContent = result.message || 'Could not start benchmark.'; return; }
      document.getElementById('wikiKey').value = ''; load();
    } catch (_) { status.textContent = 'Could not start benchmark.'; }
  });
  if (!view.hidden) open();
})();
''';
}
