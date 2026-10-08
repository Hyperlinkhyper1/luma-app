import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

import 'util.dart';

/// The admin dashboard's Start / Restart / Shut down buttons (top right).
///
/// Three things can be switched off:
///
/// * **luma** — the app-facing service: sync, accounts, the Assistant, every
///   route outside `/admin`. The dashboard is served by this same process, so
///   "luma off" can't mean stopping the container; it is a flag file on the
///   data volume ([lumaStopped]) that [Api]'s middleware turns into a 503 for
///   every non-admin request. It survives restarts until someone presses
///   Start (or Restart).
/// * **wiki** — the separate wiki checkout's containers/service on the host.
/// * **admin** — the whole stack: the wiki, then `docker compose stop` of
///   luma-sync, Caddy and SearXNG. Nothing can bring that back from a
///   browser, so the response carries the SSH commands that do.
///
/// Anything touching the host goes through deploy-watcher.sh the same way
/// the deploy and reboot buttons do: this container drops `power.request`
/// on the shared data volume and the watcher acts on it. The watcher also
/// keeps `wiki.state` and `wiki.start-cmd` current, so the dashboard can show
/// whether the wiki is up and how to start it by hand.
class PowerConsole {
  PowerConsole({
    required this.dataDir,
    required this.repoPath,
    required this.startedAt,
  }) {
    try {
      _lumaStopped = _lumaFlag.existsSync();
    } catch (_) {
      _lumaStopped = false;
    }
  }

  final String dataDir;

  /// LUMA_REPO_PATH: the checkout's path *on the host*, which is what the
  /// SSH commands need. Null when the watcher isn't set up at all.
  final String? repoPath;

  final DateTime startedAt;

  bool get _hostConfigured => repoPath != null && repoPath!.isNotEmpty;

  File get _lumaFlag => File('$dataDir/luma.stopped');
  File get _requestFile => File('$dataDir/power.request');
  File get _logFile => File('$dataDir/power.log');
  File get _wikiStateFile => File('$dataDir/wiki.state');
  File get _wikiStartCmdFile => File('$dataDir/wiki.start-cmd');
  File get _heartbeatFile => File('$dataDir/deploy.watcher');
  File get _deployLock => File('$dataDir/deploy.lock');
  File get _updateLock => File('$dataDir/update-check.lock');

  static const _freshFor = Duration(seconds: 60);

  late bool _lumaStopped;

  /// Read on every request by the middleware, so it is kept in memory and
  /// only the file is the durable copy.
  bool get lumaStopped => _lumaStopped;

  Future<bool> _isFresh(File file) async {
    try {
      if (!await file.exists()) return false;
      return DateTime.now().difference(await file.lastModified()) < _freshFor;
    } catch (_) {
      return false;
    }
  }

  Future<String> _readText(File file) async {
    try {
      if (!await file.exists()) return '';
      return await file.readAsString();
    } catch (_) {
      return '';
    }
  }

  Future<bool> get _watcherAlive => _isFresh(_heartbeatFile);

  Future<void> setLumaStopped(bool stopped) async {
    _lumaStopped = stopped;
    if (stopped) {
      await _lumaFlag.parent.create(recursive: true);
      await _lumaFlag.writeAsString(DateTime.now().toUtc().toIso8601String());
    } else if (await _lumaFlag.exists()) {
      await _lumaFlag.delete();
    }
  }

  /// `running`, `stopped`, `none` (no wiki found on the host) or `unknown`
  /// (no live watcher to ask).
  Future<String> _wikiState() async {
    if (!await _watcherAlive) return 'unknown';
    final state = (await _readText(_wikiStateFile)).trim();
    return const {'running', 'stopped', 'none'}.contains(state)
        ? state
        : 'unknown';
  }

  /// The commands that bring everything back after an admin shutdown.
  Future<List<String>> startCommands() async {
    final repo = repoPath ?? '~/luma-app';
    final wiki = (await _readText(_wikiStartCmdFile)).trim();
    return [
      'cd $repo/server && docker compose up -d',
      if (wiki.isNotEmpty) wiki,
    ];
  }

  Future<Map<String, dynamic>> _status() async => {
        'startedAt': startedAt.toUtc().toIso8601String(),
        'luma': _lumaStopped ? 'stopped' : 'running',
        'wiki': await _wikiState(),
        'watcherAlive': await _watcherAlive,
        'pending': await _requestFile.exists(),
        'log': await _readText(_logFile),
      };

  /// GET /admin/power/status
  Future<Response> status(Request request) async =>
      jsonResponse(200, await _status());

  /// Why a host request can't be filed right now, or null when it can.
  Future<Response?> _hostBlocked() async {
    if (!_hostConfigured) {
      return errorResponse(
          404,
          'not_configured',
          "LUMA_REPO_PATH is not set on this server, so the host watcher "
              "that would do this isn't running either.");
    }
    if (!await _watcherAlive) {
      return errorResponse(
          409,
          'watcher_down',
          'The deploy watcher is not running on the host, so nothing would '
              'act on this. Start it with: sudo systemctl start luma-deploy-watcher');
    }
    if (await _requestFile.exists()) {
      return errorResponse(409, 'power_pending',
          'Another start/stop request is still being handled.');
    }
    if (await _isFresh(_deployLock) || await _isFresh(_updateLock)) {
      return errorResponse(409, 'busy',
          'A server update is running. Try again once it has finished.');
    }
    return null;
  }

  Future<void> _fileRequest(String action, String target) async {
    try {
      if (await _logFile.exists()) await _logFile.delete();
    } catch (_) {}
    await _requestFile.parent.create(recursive: true);
    await _requestFile.writeAsString('$action $target\n');
  }

  static Map<String, dynamic> _body(String raw) {
    try {
      final body = jsonDecode(raw);
      return body is Map<String, dynamic> ? body : const {};
    } catch (_) {
      return const {};
    }
  }

  static Set<String> _targets(Map<String, dynamic> body) {
    try {
      final list = body['targets'];
      if (list is! List) return const {};
      return list
          .whereType<String>()
          .where(const {'luma', 'wiki', 'admin'}.contains)
          .toSet();
    } catch (_) {
      return const {};
    }
  }

  /// POST /admin/power/shutdown  {"targets": ["luma","wiki","admin"],
  /// "confirm": "admin"}. "admin" implies the other two and needs the
  /// confirm field, which the dialog only sends from its second step.
  Future<Response> shutdown(Request request) async {
    final body = _body(await request.readAsString());
    final targets = _targets(body);
    if (targets.isEmpty) {
      return errorResponse(400, 'no_targets', 'Pick something to shut down.');
    }

    if (targets.contains('admin')) {
      if (body['confirm'] != 'admin') {
        return errorResponse(400, 'confirm_required',
            'Shutting down the admin panel must be confirmed.');
      }
      final blocked = await _hostBlocked();
      if (blocked != null) return blocked;
      final commands = await startCommands();
      // Whoever runs the commands expects everything back, luma included.
      await setLumaStopped(false);
      await _fileRequest('shutdown', 'all');
      return jsonResponse(200, {'commands': commands});
    }

    if (targets.contains('wiki')) {
      final blocked = await _hostBlocked();
      if (blocked != null) return blocked;
    }
    if (targets.contains('luma')) await setLumaStopped(true);
    if (targets.contains('wiki')) await _fileRequest('stop', 'wiki');
    return jsonResponse(200, await _status());
  }

  /// POST /admin/power/start  {"targets": ["luma","wiki"]}
  Future<Response> start(Request request) async {
    final targets = _targets(_body(await request.readAsString()))
      ..remove('admin');
    if (targets.isEmpty) {
      return errorResponse(400, 'no_targets', 'Pick something to start.');
    }
    if (targets.contains('wiki')) {
      final blocked = await _hostBlocked();
      if (blocked != null) return blocked;
    }
    if (targets.contains('luma')) await setLumaStopped(false);
    if (targets.contains('wiki')) await _fileRequest('start', 'wiki');
    return jsonResponse(200, await _status());
  }

  /// POST /admin/power/restart — luma back on, then the host restarts the
  /// wiki and the whole server stack (this process included).
  Future<Response> restart(Request request) async {
    final blocked = await _hostBlocked();
    if (blocked != null) return blocked;
    await setLumaStopped(false);
    await _fileRequest('restart', 'all');
    return jsonResponse(200, await _status());
  }

  static const headerButtonsHtml =
      '<button id="pwStartBtn" type="button" class="btn btn-ghost btn-sm">'
      'Start<span id="pwStartCount" class="pw-count" hidden></span></button>'
      '<button id="pwRestartBtn" type="button" class="btn btn-ghost btn-sm">'
      'Restart</button>'
      '<button id="pwShutdownBtn" type="button" class="btn btn-danger btn-sm">'
      'Shut down</button>';

  static const dialogHtml = '''
<dialog id="pwDialog" class="bn-dialog pw-dialog" aria-labelledby="pwTitle">
  <div class="bn-dlg-head"><div><h2 id="pwTitle"></h2><div id="pwSub" class="bn-dlg-sub"></div></div><button type="button" id="pwClose" class="bn-icon-btn" aria-label="Close"><svg class="bn-ico" viewBox="0 0 24 24" aria-hidden="true"><path d="M6 6l12 12M18 6L6 18"/></svg></button></div>
  <div class="bn-dlg-body pw-body">
    <div id="pwPick" class="pw-pick">
      <label class="pw-opt" data-t="luma"><input type="checkbox" value="luma"><span><strong>luma</strong><span class="muted">Sync, accounts, the Assistant — everything the app talks to. The admin panel stays up.</span></span><span class="pw-state"></span></label>
      <label class="pw-opt" data-t="wiki"><input type="checkbox" value="wiki"><span><strong>Wiki</strong><span class="muted">The wiki website and its builder.</span></span><span class="pw-state"></span></label>
      <label class="pw-opt pw-opt-danger" data-t="admin"><input type="checkbox" value="admin"><span><strong>Admin panel</strong><span class="muted">Stops the whole server — luma, the wiki and this dashboard. It can only be started again over SSH.</span></span><span class="pw-state"></span></label>
    </div>
    <div id="pwConfirm" class="pw-confirm" hidden>
      <p><strong>Shut down the admin panel?</strong></p>
      <p class="muted">luma, the wiki and this dashboard all go offline. Nothing on this page can start them again — you will need SSH access to the server and the commands shown on the next screen.</p>
    </div>
    <div id="pwDone" hidden>
      <p>Everything is shutting down. To start it all again, SSH into the server and run:</p>
      <pre id="pwCmds" class="log pw-cmds"></pre>
      <div><button id="pwCopy" type="button" class="btn btn-ghost btn-sm">Copy commands</button></div>
    </div>
    <div id="pwNote" role="status" class="maint-status"></div>
    <pre id="pwLog" class="log maint-out" style="display:none"></pre>
  </div>
  <div class="bn-dlg-foot"><button id="pwBack" type="button" class="btn btn-ghost" hidden>Back</button><button id="pwGo" type="button" class="btn btn-primary"></button></div>
</dialog>
''';

  static const css = r'''
.pw-count{display:inline-block;min-width:16px;margin-left:6px;padding:0 5px;border-radius:8px;background:#e0c87e;color:#1a1408;font-size:10px;font-weight:700;line-height:16px;text-align:center}
.pw-count[hidden],.pw-dialog [hidden]{display:none!important}
.pw-dialog{width:min(560px,calc(100vw - 32px))}
.pw-body{display:flex;flex-direction:column;gap:12px}
.pw-pick{display:flex;flex-direction:column;gap:8px}
.pw-opt{display:flex;gap:12px;align-items:flex-start;padding:12px 14px;border:1px solid #2d2645;border-radius:10px;background:#1a1628;cursor:pointer}
.pw-opt>span:nth-child(2){display:flex;flex-direction:column;gap:2px;flex:1;min-width:0}
.pw-opt input{margin-top:3px}
.pw-opt.pw-off{opacity:.5;cursor:not-allowed}
.pw-opt-danger strong{color:#e07e7e}
.pw-state{font-size:11px;font-weight:600;letter-spacing:.04em;text-transform:uppercase;white-space:nowrap;color:#6f688a}
.pw-state.up{color:#7ee08a}.pw-state.down{color:#e07e7e}
.pw-confirm{border:1px solid #443030;border-radius:10px;padding:12px 14px;background:rgba(224,126,126,.06)}
.pw-confirm p{margin:0 0 6px}
.pw-cmds{white-space:pre-wrap;word-break:break-all;user-select:all}
''';

  static const script = r'''
(function () {
  var dlg = document.getElementById('pwDialog');
  var startBtn = document.getElementById('pwStartBtn');
  var restartBtn = document.getElementById('pwRestartBtn');
  var shutBtn = document.getElementById('pwShutdownBtn');
  if (!dlg || !startBtn || !restartBtn || !shutBtn) return;
  var $ = function (id) { return document.getElementById(id); };
  var title = $('pwTitle'), sub = $('pwSub'), pick = $('pwPick'),
      confirmBox = $('pwConfirm'), done = $('pwDone'), note = $('pwNote'),
      logEl = $('pwLog'), go = $('pwGo'), back = $('pwBack'), count = $('pwStartCount');
  var GREY = '#a49fb8', AMBER = '#e0c87e', GREEN = '#7ee08a', RED = '#e07e7e';
  var mode = null, status = null, busy = false;
  var LABEL = { running: 'Running', stopped: 'Stopped', none: 'Not found', unknown: 'Unknown' };

  function setNote(text, color) { note.textContent = text || ''; note.style.color = color || GREY; }
  function showLog(text) { logEl.style.display = text ? 'block' : 'none'; logEl.textContent = text || ''; }
  function opts() { return pick.querySelectorAll('.pw-opt'); }
  function opt(t) { return pick.querySelector('.pw-opt[data-t="' + t + '"]'); }
  function chosen() {
    var out = [];
    opts().forEach(function (o) {
      var i = o.querySelector('input');
      if (i.checked && !i.disabled) out.push(i.value);
    });
    if (opt('admin').querySelector('input').checked && mode === 'shutdown') out = ['admin'];
    return out;
  }

  function readJson(r) {
    if (r.redirected && r.url.indexOf('/admin/login') !== -1) {
      var e = new Error('admin session expired'); e.sessionExpired = true; throw e;
    }
    return r.json();
  }
  function post(path, body) {
    return fetch(path, { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body || {}) }).then(readJson);
  }
  function fetchStatus() {
    return fetch('/admin/power/status').then(readJson).then(function (s) {
      status = s; paintHeader(); if (dlg.open && mode !== 'done') paintOpts(); return s;
    });
  }

  function stoppedList() {
    if (!status) return [];
    var out = [];
    if (status.luma === 'stopped') out.push('luma');
    if (status.wiki === 'stopped') out.push('wiki');
    return out;
  }
  function paintHeader() {
    var n = stoppedList().length;
    count.hidden = n === 0;
    count.textContent = String(n);
    startBtn.title = n ? 'Stopped: ' + stoppedList().join(', ') : 'Everything is running';
  }

  function paintOpts() {
    var adminOn = opt('admin').querySelector('input').checked;
    opts().forEach(function (o) {
      var t = o.dataset.t, input = o.querySelector('input'), st = o.querySelector('.pw-state');
      var state = t === 'admin' ? 'running' : (status ? status[t] : 'unknown');
      st.textContent = LABEL[state] || state;
      st.className = 'pw-state' + (state === 'running' ? ' up' : state === 'stopped' ? ' down' : '');
      var usable;
      if (mode === 'start') {
        o.hidden = t === 'admin';
        usable = state === 'stopped';
      } else {
        o.hidden = false;
        usable = t === 'admin' || state === 'running';
        if (t !== 'admin' && adminOn) { usable = false; input.checked = true; }
      }
      input.disabled = !usable;
      if (!usable && !(mode !== 'start' && adminOn && t !== 'admin')) input.checked = false;
      o.classList.toggle('pw-off', !usable);
    });
    go.disabled = busy || chosen().length === 0;
  }

  function open(m) {
    mode = m; busy = false;
    pick.hidden = false; confirmBox.hidden = true; done.hidden = true; back.hidden = true;
    opts().forEach(function (o) { o.querySelector('input').checked = false; });
    setNote(''); showLog('');
    if (m === 'shutdown') {
      title.textContent = 'Shut down';
      sub.textContent = 'Pick what to switch off';
      go.textContent = 'Shut down'; go.className = 'btn btn-danger solid';
    } else {
      title.textContent = 'Start';
      sub.textContent = 'Start what is currently stopped';
      go.textContent = 'Start'; go.className = 'btn btn-primary';
    }
    paintOpts();
    if (!dlg.open) dlg.showModal();
    fetchStatus().then(function () {
      if (mode === 'start' && stoppedList().length === 0) setNote('Everything is already running.', GREEN);
    }).catch(function () { setNote('Could not read the current state.', RED); });
  }

  pick.addEventListener('change', function (e) {
    if (e.target.value === 'admin' && !e.target.checked) {
      opts().forEach(function (o) { o.querySelector('input').checked = false; });
    }
    paintOpts();
  });
  $('pwClose').addEventListener('click', function () { dlg.close(); });
  back.addEventListener('click', function () {
    mode = 'shutdown'; pick.hidden = false; confirmBox.hidden = true; back.hidden = true;
    go.textContent = 'Shut down'; setNote(''); paintOpts();
  });
  $('pwCopy').addEventListener('click', function () {
    var text = $('pwCmds').textContent;
    if (navigator.clipboard) navigator.clipboard.writeText(text).then(function () { setNote('Copied.', GREEN); });
  });

  function fail(err) {
    busy = false; go.disabled = false;
    if (err && err.sessionExpired) { setNote('Admin session expired — reload and sign in again.', RED); return; }
    setNote(err && err.message ? err.message : 'Request failed.', RED);
  }
  function answer(data) {
    if (data && data.error) { var e = new Error(data.message || data.error); throw e; }
    return data;
  }

  // Polls until the wiki reaches [want] (or the watcher reports a failure).
  function waitWiki(want, since) {
    fetchStatus().then(function (s) {
      if (s.wiki === want) { setNote('Wiki ' + (want === 'running' ? 'started' : 'stopped') + '.', GREEN); showLog(''); busy = false; paintOpts(); return; }
      if (!s.pending && s.log && /FAILED|Ignored/.test(s.log)) { busy = false; showLog(s.log); setNote('The wiki did not change — see below.', RED); paintOpts(); return; }
      if (Date.now() - since > 3 * 60 * 1000) { busy = false; showLog(s.log); setNote('Still waiting after 3 minutes — check the server.', RED); paintOpts(); return; }
      setTimeout(function () { waitWiki(want, since); }, 2000);
    }).catch(function () { setTimeout(function () { waitWiki(want, since); }, 2000); });
  }

  go.addEventListener('click', function () {
    var targets = chosen();
    if (!targets.length || busy) return;
    if (mode === 'shutdown' && targets.indexOf('admin') !== -1) {
      mode = 'confirm'; pick.hidden = true; confirmBox.hidden = false; back.hidden = false;
      go.textContent = 'Yes, shut everything down'; setNote(''); return;
    }
    busy = true; go.disabled = true; showLog('');
    if (mode === 'confirm') {
      setNote('Shutting everything down…', AMBER);
      post('/admin/power/shutdown', { targets: ['admin'], confirm: 'admin' }).then(answer).then(function (data) {
        mode = 'done'; confirmBox.hidden = true; back.hidden = true; done.hidden = false;
        $('pwCmds').textContent = data.commands.join('\n');
        title.textContent = 'Shut down'; sub.textContent = 'Keep these commands';
        go.hidden = true; setNote('The watcher on the host is stopping everything now.', AMBER);
      }).catch(fail);
      return;
    }
    var path = mode === 'start' ? '/admin/power/start' : '/admin/power/shutdown';
    setNote(mode === 'start' ? 'Starting…' : 'Shutting down…', AMBER);
    post(path, { targets: targets }).then(answer).then(function (s) {
      status = s; paintHeader();
      if (targets.indexOf('wiki') !== -1) {
        setNote(mode === 'start' ? 'Starting the wiki…' : 'Stopping the wiki…', AMBER);
        waitWiki(mode === 'start' ? 'running' : 'stopped', Date.now());
      } else {
        busy = false; setNote('luma ' + (mode === 'start' ? 'started' : 'shut down') + '.', GREEN); paintOpts();
      }
    }).catch(fail);
  });

  dlg.addEventListener('close', function () { go.hidden = false; });

  startBtn.addEventListener('click', function () { open('start'); });
  shutBtn.addEventListener('click', function () { open('shutdown'); });

  restartBtn.addEventListener('click', function () {
    if (!confirm('Restart luma and the wiki? luma is switched back on if it was '
        + 'shut down, and the server and this dashboard are briefly unreachable.')) return;
    restartBtn.disabled = true;
    var label = restartBtn.textContent;
    restartBtn.textContent = 'Restarting…';
    var oldStartedAt = status && status.startedAt, since = Date.now();
    function finish(text) {
      restartBtn.disabled = false; restartBtn.textContent = label;
      if (text) alert(text);
    }
    function poll() {
      fetchStatus().then(function (s) {
        if (s.startedAt !== oldStartedAt) { finish(); return; }
        if (!s.pending && s.log && /FAILED|Ignored/.test(s.log)) { finish('The restart failed:\n\n' + s.log); return; }
        again();
      }).catch(function (e) {
        if (e && e.sessionExpired) { finish('Admin session expired — reload and sign in again.'); return; }
        again();
      });
    }
    function again() {
      if (Date.now() - since > 5 * 60 * 1000) { finish('The server has not come back after 5 minutes. Check it over SSH.'); return; }
      setTimeout(poll, 2000);
    }
    post('/admin/power/restart').then(answer).then(function (s) {
      oldStartedAt = s.startedAt; status = s; paintHeader(); setTimeout(poll, 2000);
    }).catch(function (e) { finish(e && e.message ? e.message : 'Could not request the restart.'); });
  });

  fetchStatus().catch(function () {});
  setInterval(function () { if (!document.hidden) fetchStatus().catch(function () {}); }, 15000);
})();
''';
}
