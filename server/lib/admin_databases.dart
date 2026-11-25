class AdminDatabases {
  static const html = '''
<section class="tab-panel" id="panel-databases" aria-labelledby="cs2-db-title">
  <div class="panel-head cs2-db-head">
    <div>
      <h2 class="panel-title" id="cs2-db-title">CS2 database</h2>
      <p class="muted" id="cs2-db-release" role="status">Loading database status…</p>
    </div>
    <button class="btn btn-ghost btn-sm" type="button" id="cs2-db-refresh">Refresh</button>
  </div>
  <div class="cs2-db-layout">
    <section class="card cs2-db-card" aria-labelledby="cs2-db-stage-title">
      <h3 id="cs2-db-stage-title">Stage rounds</h3>
      <form class="cs2-db-form" id="cs2-db-replay">
        <label for="cs2-db-file">Replay file</label>
        <p class="muted" id="cs2-db-file-help">Choose a CS2 .dem or .dem.bz2 file up to 95 MiB.</p>
        <input id="cs2-db-file" type="file" accept=".dem,.bz2"
               aria-describedby="cs2-db-file-help" required>
        <button class="btn btn-ghost" type="submit">Import replay</button>
        <p class="cs2-db-status" role="status"></p>
      </form>
      <form class="cs2-db-form" id="cs2-db-manual">
        <label for="cs2-db-map">Map ID</label>
        <input id="cs2-db-map" type="text" placeholder="de_mirage" maxlength="128"
               list="cs2-db-maps" spellcheck="false" autocapitalize="off" required>
        <datalist id="cs2-db-maps"></datalist>
        <label for="cs2-db-rounds">Round outcomes in order</label>
        <p class="muted" id="cs2-db-rounds-help">Enter A, B or Other for each round, separated by commas or spaces. Keep each T-side stint in a separate entry.</p>
        <textarea id="cs2-db-rounds" rows="3" placeholder="A, B, Other, A" maxlength="4000"
                  aria-describedby="cs2-db-rounds-help" required></textarea>
        <button class="btn btn-ghost" type="submit">Add rounds</button>
        <p class="cs2-db-status" role="status"></p>
      </form>
    </section>
    <div class="cs2-db-public">
      <section class="card cs2-db-card" aria-labelledby="cs2-db-publish-title">
        <h3 id="cs2-db-publish-title">Publish database</h3>
        <dl class="cs2-db-counts">
          <div><dt>Staged rounds</dt><dd id="cs2-db-staged">–</dd></div>
          <div><dt>Published rounds</dt><dd id="cs2-db-published">–</dd></div>
        </dl>
        <form class="cs2-db-form" id="cs2-db-publish">
          <label for="cs2-db-allocation">Rounds to publish</label>
          <p class="muted" id="cs2-db-allocation-help">Compile this many of the latest staged rounds. Users on any paid plan can download the result.</p>
          <input id="cs2-db-allocation" type="number" min="1" step="1"
                 aria-describedby="cs2-db-allocation-help" required disabled>
          <button class="btn btn-primary" type="submit" disabled>Publish</button>
          <p class="cs2-db-status" role="status"></p>
        </form>
      </section>
      <section class="card cs2-db-card" aria-labelledby="cs2-db-maps-title">
        <h3 id="cs2-db-maps-title">Map coverage</h3>
        <p id="cs2-db-empty" class="muted">Loading map coverage…</p>
        <table class="cs2-db-map-table" hidden>
          <thead><tr><th scope="col">Map</th><th scope="col">Staged</th><th scope="col">Published</th></tr></thead>
          <tbody id="cs2-db-map-rows"></tbody>
        </table>
      </section>
    </div>
  </div>
</section>
''';

  static const css = r'''
.cs2-db-head{display:flex;align-items:flex-start;justify-content:space-between;gap:12px;flex-wrap:wrap}
.cs2-db-head p{margin:4px 0 0}
.cs2-db-layout{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px;align-items:start}
.cs2-db-card h3{margin:0 0 16px;font-size:16px;color:#ece8f7}
.cs2-db-form{display:grid;gap:8px;justify-items:start}
.cs2-db-form + .cs2-db-form{margin-top:20px;padding-top:20px;border-top:1px solid #2d2645}
.cs2-db-form label{font-weight:600}
.cs2-db-form p{margin:0}
.cs2-db-form input,.cs2-db-form textarea{
  min-width:0;max-width:100%;padding:8px 11px;background:#1a1530;color:#ece8f7;
  border:1px solid #2d2645;border-radius:9px;font:inherit;color-scheme:dark;
}
.cs2-db-form input:focus-visible,.cs2-db-form textarea:focus-visible{outline:2px solid #8a7ee0;outline-offset:2px}
.cs2-db-form input[type=file],.cs2-db-form textarea{width:100%}
.cs2-db-form textarea{resize:vertical}
.cs2-db-form input[type=number]{width:135px}
.cs2-db-form .btn:disabled,.cs2-db-head .btn:disabled{opacity:.55;cursor:default}
.cs2-db-status:empty{display:none}
.cs2-db-status[data-kind=error],.cs2-db-head [data-kind=error]{color:#f2a3a3}
.cs2-db-status[data-kind=success]{color:#8fe0aa}
.cs2-db-counts{display:flex;flex-wrap:wrap;gap:12px 32px;margin:0 0 18px;font-variant-numeric:tabular-nums}
.cs2-db-counts dt{color:#a7a0bc;font-size:12px}
.cs2-db-counts dd{margin:0;font-size:21px;font-weight:650}
.cs2-db-map-table{table-layout:fixed;width:100%;font-variant-numeric:tabular-nums}
.cs2-db-map-table td,.cs2-db-map-table th{overflow-wrap:anywhere;white-space:normal}
.cs2-db-map-table th:not(:first-child),.cs2-db-map-table td:not(:first-child){text-align:right;width:29%;padding-inline:8px}
.cs2-db-map-table th:not(:first-child){white-space:nowrap}
@media(max-width:740px){.cs2-db-layout{grid-template-columns:minmax(0,1fr);gap:0}}
''';

  static const script = r'''
(function () {
  const endpoint = '/admin/databases/cs2';
  const byId = (name) => document.getElementById('cs2-db-' + name);
  const panel = document.getElementById('panel-databases');
  const release = byId('release');
  const refresh = byId('refresh');
  const manual = byId('manual');
  const replay = byId('replay');
  const publish = byId('publish');
  const allocation = byId('allocation');
  const mapRows = byId('map-rows');
  const empty = byId('empty');
  const maps = byId('maps');
  const forms = [manual, replay, publish];
  const number = new Intl.NumberFormat();
  const maxReplaySize = 95 * 1024 * 1024;
  let busy = false;
  let state;

  function show(element, message, kind = '') {
    element.textContent = message;
    element.dataset.kind = kind;
  }

  function syncControls() {
    const staged = state?.staged ?? 0;
    const count = allocation.valueAsNumber;
    refresh.disabled = busy;
    allocation.disabled = busy || staged === 0;
    for (const form of forms) {
      form.querySelector('button').disabled = busy ||
        (form === publish && (!Number.isInteger(count) || count < 1 || count > staged));
    }
  }

  function render(next) {
    const previousDefault = state?.published || state?.staged;
    const chosen = allocation.valueAsNumber;
    state = next;
    byId('staged').textContent = number.format(next.staged);
    byId('published').textContent = number.format(next.published);
    const timestamp = next.publishedAt ? new Date(next.publishedAt) : null;
    show(release, timestamp && Number.isFinite(timestamp.getTime())
      ? 'Last published ' + timestamp.toLocaleString()
      : 'No database published yet.');
    allocation.max = next.staged;
    if (!Number.isFinite(chosen) || chosen === previousDefault ||
        chosen > next.staged) {
      allocation.value = next.published || next.staged || '';
    }
    const rows = [];
    const options = [];
    for (const map of next.maps) {
      const option = document.createElement('option');
      option.value = map.id;
      option.label = map.name;
      options.push(option);
      if (!map.staged && !map.published) continue;
      const row = document.createElement('tr');
      for (const value of [
        map.name, number.format(map.staged), number.format(map.published),
      ]) {
        row.insertCell().textContent = value;
      }
      rows.push(row);
    }
    maps.replaceChildren(...options);
    mapRows.replaceChildren(...rows);
    mapRows.closest('table').hidden = rows.length === 0;
    empty.hidden = rows.length > 0;
    show(empty, 'Import a replay or add rounds to see coverage by map.');
    syncControls();
  }

  async function request(path, init) {
    const response = await fetch(endpoint + path, init);
    if (response.redirected && new URL(response.url).pathname === '/admin/login') {
      location.href = '/admin/login';
      throw new Error('Your admin session ended.');
    }
    const result = await response.json().catch(() => null);
    if (!response.ok || !result) {
      throw new Error(result?.message || 'Database request failed (' + response.status + ').');
    }
    return result;
  }

  function json(body) {
    return {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify(body),
    };
  }

  async function run(status, pending, action, success) {
    if (busy) return;
    busy = true;
    syncControls();
    show(status, pending);
    try {
      render(await action());
      if (success) show(status, success, 'success');
    } catch (error) {
      show(status, error.message || 'Database request failed.', 'error');
    } finally {
      busy = false;
      syncControls();
    }
  }

  function load() {
    run(release, 'Loading database status…', () => request(''));
  }

  refresh.addEventListener('click', load);
  allocation.addEventListener('input', syncControls);
  manual.addEventListener('submit', (event) => {
    event.preventDefault();
    const status = manual.querySelector('[role=status]');
    const map = byId('map').value.trim();
    const input = byId('rounds');
    const outcomes = input.value.toLowerCase().split(/[\s,]+/).filter(Boolean);
    if (!map || !outcomes.length || outcomes.length > 500 ||
        outcomes.some((value) => !['a', 'b', 'other'].includes(value))) {
      show(status, 'Choose a map ID and enter 1 to 500 outcomes using A, B or Other.', 'error');
      return;
    }
    run(status, 'Adding rounds…', async () => {
      const next = await request('/cases', json({map, outcomes}));
      input.value = '';
      return next;
    }, 'Rounds added to the staging pool.');
  });
  replay.addEventListener('submit', (event) => {
    event.preventDefault();
    const status = replay.querySelector('[role=status]');
    const input = byId('file');
    const file = input.files[0];
    if (!file || !/\.dem(?:\.bz2)?$/i.test(file.name) || !file.size ||
        file.size > maxReplaySize) {
      show(status, 'Choose a .dem or .dem.bz2 file up to 95 MiB.', 'error');
      return;
    }
    run(status, 'Uploading and reading replay…', async () => {
      const query = new URLSearchParams({name: file.name});
      const next = await request('/replay?' + query, {
        method: 'POST',
        headers: {'Content-Type': 'application/octet-stream'},
        body: file,
      });
      input.value = '';
      return next;
    }, 'Replay rounds added to the staging pool.');
  });
  publish.addEventListener('submit', (event) => {
    event.preventDefault();
    const status = publish.querySelector('[role=status]');
    const caseCount = allocation.valueAsNumber;
    run(status, 'Compiling database…', () => request('/publish', json({caseCount})),
      'Database published.');
  });
  document.querySelector('#project-luma [data-tab="databases"]')
    .addEventListener('click', () => { if (!state) load(); });
  if (panel.classList.contains('active')) load();
})();
''';
}
