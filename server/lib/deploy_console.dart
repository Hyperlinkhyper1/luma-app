import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

import 'util.dart';

/// Where a deploy is in its lifecycle, as computed by [DeployConsole.phase].
///
/// This is the whole contract with the dashboard. The browser used to be
/// handed six loose booleans and integers (`running`, `ok`, `exitCode`,
/// `pending`, `watcherAlive`, `repoPathConfigured`) and had to reconstruct
/// the state machine itself, with its own timers and flags; now it switches
/// on one value that is decided — and tested — here.
enum DeployPhase {
  /// LUMA_REPO_PATH is unset, so the button can't do anything at all.
  notConfigured,

  /// Nothing in flight. A previous run's outcome may still be on disk, but
  /// it is old news rather than the result of anything the operator is
  /// currently watching.
  idle,

  /// The request file is on disk and deploy-watcher.sh is alive, so it is
  /// about to be claimed (the watcher polls every 2s).
  queued,

  /// deploy-watcher.sh is running the deploy right now.
  running,

  /// The last finished run exited 0.
  succeeded,

  /// The last finished run exited non-zero; see [DeployStatus.exitCode].
  failed,

  /// A request is on disk but no watcher is alive to pick it up. Without
  /// this the button would sit at "queued" forever with no explanation.
  stalled;

  String get wireName => name;
}

/// Everything the dashboard needs to render the deploy panel.
class DeployStatus {
  const DeployStatus({
    required this.phase,
    required this.log,
    required this.exitCode,
    required this.watcherAlive,
  });

  final DeployPhase phase;

  /// Output of the run in progress, or of the last finished one. Empty while
  /// [phase] is [DeployPhase.queued] — the previous run's log is still on
  /// disk at that point (the watcher truncates it when it claims the
  /// request), and showing it would read as output from the new run.
  final String log;

  /// Exit code of the last finished run; null unless [phase] is
  /// [DeployPhase.succeeded] or [DeployPhase.failed].
  final int? exitCode;

  /// Whether deploy-watcher.sh is alive, independent of [phase] — an idle
  /// dashboard still wants to warn that the button is currently unbacked.
  final bool watcherAlive;

  Map<String, dynamic> toJson() => {
        'phase': phase.wireName,
        'log': log,
        'exitCode': exitCode,
        'watcherAlive': watcherAlive,
      };
}

/// The admin dashboard's "Update & restart server" button.
///
/// A deploy can't be driven from inside the luma-sync container (even over
/// the host Docker socket): `docker compose up -d --build` recreating *this
/// very container* is a multi-step swap (stop old -> rename -> create new ->
/// start new -> remove old), and stopping the old container kills every
/// process inside it — including the `docker compose` CLI orchestrating the
/// rest of the swap — before it ever starts the new one. The container gets
/// stuck at "Created" and the deploy goes nowhere.
///
/// So this only drops a request file on the `/data` volume.
/// `deploy-watcher.sh`, running as a systemd service directly on the host
/// (outside any container, see luma-deploy-watcher.service), polls for that
/// file and does the actual git pull + rebuild — unaffected by the luma-sync
/// container being torn down and recreated out from under it.
///
/// **The watcher owns every artifact of a run.** It truncates the log and
/// clears the status when it claims a request, and refreshes the lock and
/// heartbeat while the run is in flight. This class only ever writes
/// `deploy.request`. Both sides used to clear the log and status, which left
/// a window where the request was on disk and every other file had been
/// wiped — a state that looked identical to "finished instantly" and which
/// the browser papered over with a 30-tick timeout.
class DeployConsole {
  DeployConsole({required this.dataDir, required this.repoPathConfigured});

  final String dataDir;
  final bool repoPathConfigured;

  /// Present only while a deploy is running. deploy-watcher.sh refreshes it
  /// every few seconds for the whole run, so staleness genuinely means the
  /// run died rather than that it is taking a while — a plain
  /// written-once-at-start file made any deploy longer than [_lockMaxAge]
  /// report itself as finished.
  ///
  /// Named `.lock` rather than `.pid` because nothing reads its contents: a
  /// host PID is meaningless to `kill -0` from inside this container's PID
  /// namespace, so presence and freshness are the entire signal.
  File get _lockFile => File('$dataDir/deploy.lock');
  File get _requestFile => File('$dataDir/deploy.request');
  File get _logFile => File('$dataDir/deploy.log');
  File get _statusFile => File('$dataDir/deploy.status');
  File get _heartbeatFile => File('$dataDir/deploy.watcher');

  /// Generous next to the ~5s refresh interval, so a momentarily busy host
  /// never reads as a dead deploy.
  static const _lockMaxAge = Duration(seconds: 60);

  /// deploy-watcher.sh rewrites its heartbeat every ~10s, including from a
  /// background refresher that keeps beating for the duration of a deploy.
  static const _heartbeatMaxAge = Duration(seconds: 60);

  Future<bool> _isFresh(File file, Duration maxAge) async {
    try {
      if (!await file.exists()) return false;
      return DateTime.now().difference(await file.lastModified()) < maxAge;
    } catch (_) {
      return false;
    }
  }

  Future<bool> get isRunning => _isFresh(_lockFile, _lockMaxAge);

  Future<bool> get isWatcherAlive => _isFresh(_heartbeatFile, _heartbeatMaxAge);

  Future<String> _readLog() async {
    try {
      if (!await _logFile.exists()) return '';
      return await _logFile.readAsString();
    } catch (_) {
      return '';
    }
  }

  /// Exit code of the last finished run, or null if none has finished since
  /// the last request was claimed.
  Future<int?> _readExitCode() async {
    try {
      if (!await _statusFile.exists()) return null;
      return int.tryParse((await _statusFile.readAsString()).trim());
    } catch (_) {
      return null;
    }
  }

  /// Collapses the files on the shared volume into a single [DeployPhase].
  Future<DeployStatus> status() async {
    final watcherAlive = await isWatcherAlive;

    if (!repoPathConfigured) {
      return DeployStatus(
        phase: DeployPhase.notConfigured,
        log: '',
        exitCode: null,
        watcherAlive: watcherAlive,
      );
    }

    if (await isRunning) {
      return DeployStatus(
        phase: DeployPhase.running,
        log: await _readLog(),
        exitCode: null,
        watcherAlive: watcherAlive,
      );
    }

    // A request still on disk has not been claimed yet. Whether that is
    // normal (the watcher polls every 2s) or terminal depends entirely on
    // whether anything is alive to claim it.
    if (await _requestFile.exists()) {
      return DeployStatus(
        phase: watcherAlive ? DeployPhase.queued : DeployPhase.stalled,
        log: '',
        exitCode: null,
        watcherAlive: watcherAlive,
      );
    }

    final exitCode = await _readExitCode();
    if (exitCode == null) {
      return DeployStatus(
        phase: DeployPhase.idle,
        log: await _readLog(),
        exitCode: null,
        watcherAlive: watcherAlive,
      );
    }

    return DeployStatus(
      // Whether the run worked is the exit code the watcher recorded, never
      // something inferred by grepping the log for hopeful-looking words —
      // that reported a `git pull` aborting on local changes as a bland
      // "deploy finished".
      phase: exitCode == 0 ? DeployPhase.succeeded : DeployPhase.failed,
      log: await _readLog(),
      exitCode: exitCode,
      watcherAlive: watcherAlive,
    );
  }

  /// POST /admin/deploy — drops the request file and reports the phase the
  /// dashboard should start polling from.
  Future<Response> requestDeploy(Request request) async {
    if (!repoPathConfigured) {
      return errorResponse(404, 'not_configured',
          "LUMA_REPO_PATH is not set on this server. Set it in .env to this "
          "repo's absolute path on the host, then restart.");
    }

    if (await isRunning) {
      return errorResponse(409, 'deploy_running',
          'A deploy is already in progress. Wait for it to finish.');
    }

    await _requestFile.parent.create(recursive: true);
    await _requestFile.writeAsString(DateTime.now().toIso8601String());

    final watcherAlive = await isWatcherAlive;
    return jsonResponse(200, {
      'phase': (watcherAlive ? DeployPhase.queued : DeployPhase.stalled)
          .wireName,
      'watcherAlive': watcherAlive,
    });
  }

  /// GET /admin/deploy/status — polled by [deployScript].
  Future<Response> deployStatus(Request request) async =>
      jsonResponse(200, (await status()).toJson());

  /// Control panel tab: the "Update & restart server" button POSTs to
  /// /admin/deploy, then polls /admin/deploy/status to stream the log into
  /// the <pre> below the button. The poll keeps going even after the server
  /// restarts (the fetch fails mid-restart and resumes once the new
  /// container is up), so the operator sees the outcome without refreshing.
  ///
  /// Every decision about what the deploy is doing is made server-side and
  /// arrives as [DeployStatus.phase]; this is a switch over that value and
  /// holds no state of its own beyond the poll timer.
  static const deployScript = r'''
(function () {
  const btn = document.getElementById('deployBtn');
  const status = document.getElementById('deployStatus');
  const log = document.getElementById('deployLog');
  if (!btn || !status || !log) return;

  var GREY = '#a49fb8', AMBER = '#e0c87e', GREEN = '#7ee08a', RED = '#e07e7e';

  var timer = null;

  function setStatus(text, color) {
    status.textContent = text;
    status.style.color = color || GREY;
  }

  function setBusy(busy) {
    btn.disabled = busy;
    btn.style.opacity = busy ? '0.5' : '';
    btn.style.cursor = busy ? 'not-allowed' : '';
  }

  function showLog(text) {
    if (!text) return;
    log.style.display = 'block';
    log.textContent = text;
    log.scrollTop = log.scrollHeight;
  }

  function watcherHint() {
    return 'The deploy watcher is not running on the host, so nothing will '
        + 'pick up the request. Start it with: sudo systemctl start '
        + 'luma-deploy-watcher';
  }

  // An admin session that has run out redirects to the login form, so the
  // response is HTML and .json() blows up. Say that plainly instead of
  // reporting it as a deploy that would not start.
  function readJson(r) {
    if (r.redirected && r.url.indexOf('/admin/login') !== -1) {
      var err = new Error('admin session expired');
      err.sessionExpired = true;
      throw err;
    }
    return r.json();
  }

  function sessionExpired(err) {
    if (!err || !err.sessionExpired) return false;
    setBusy(false);
    setStatus('Admin session expired — reload this page and sign in again.',
        RED);
    return true;
  }

  // One entry per DeployPhase (see deploy_console.dart). `poll` says whether
  // this phase is transient and should be polled again, and after how long.
  var PHASES = {
    notConfigured: {
      busy: true, color: GREY, poll: 0,
      text: 'Not configured: set LUMA_REPO_PATH in this server\'s .env '
          + '(see .env.example), then restart.'
    },
    idle: { busy: false, color: GREY, poll: 0, text: '' },
    queued: {
      busy: true, color: AMBER, poll: 1000,
      text: 'Queued — waiting for the deploy watcher to pick this up.'
    },
    running: {
      busy: true, color: AMBER, poll: 2000,
      text: 'Deploying… (the server will restart briefly)'
    },
    succeeded: {
      busy: false, color: GREEN, poll: 0,
      text: 'Deploy complete — server rebuilt and restarted.'
    },
    failed: {
      busy: false, color: RED, poll: 0,
      text: function (data) {
        return 'Deploy failed (exit ' + data.exitCode + ') — see the log '
            + 'below for the step that stopped it.';
      }
    },
    stalled: { busy: false, color: RED, poll: 0, text: watcherHint }
  };

  function render(data) {
    var phase = PHASES[data.phase] || PHASES.idle;
    showLog(data.log);
    setBusy(phase.busy);

    var text = typeof phase.text === 'function' ? phase.text(data) : phase.text;
    // An idle panel with a dead watcher still needs to say so — the button
    // works, but nothing on the host would act on it.
    if (!text && data.watcherAlive === false) {
      setStatus(watcherHint(), AMBER);
    } else {
      setStatus(text, phase.color);
    }

    if (phase.poll) timer = setTimeout(poll, phase.poll);
  }

  function poll() {
    fetch('/admin/deploy/status')
      .then(readJson)
      .then(render)
      .catch(function (err) {
        if (sessionExpired(err)) return;
        // Expected while the container is being recreated out from under us:
        // keep polling until it answers again.
        setStatus('Server restarting… waiting for it to come back.', AMBER);
        timer = setTimeout(poll, 2000);
      });
  }

  btn.addEventListener('click', function () {
    if (!confirm('This will git pull, rebuild the image, and recreate the '
        + 'luma-sync container. The server will be briefly unavailable. '
        + 'Continue?')) return;
    if (timer) { clearTimeout(timer); timer = null; }
    // The previous run's log belongs to the previous run; the watcher
    // truncates the file when it claims this request.
    log.style.display = 'none';
    log.textContent = '';
    setStatus('Starting deploy…', AMBER);
    setBusy(true);
    fetch('/admin/deploy', { method: 'POST' })
      .then(readJson)
      .then(function (data) {
        if (data.error) {
          setBusy(false);
          setStatus(data.message || data.error, RED);
          return;
        }
        render({ phase: data.phase, log: '', exitCode: null,
                 watcherAlive: data.watcherAlive });
      })
      .catch(function (err) {
        if (sessionExpired(err)) return;
        setBusy(false);
        setStatus('Could not start the deploy.', RED);
      });
  });

  poll();
})();
''';
}

/// Restores the dashboard's own login sessions across a restart — most often
/// the restart the deploy button just triggered.
///
/// Only SHA-256 hashes of the cookie tokens are stored, so the file can't be
/// replayed into a session. These used to be in-memory only, on the
/// reasoning that an operator can just log in again after a restart — but
/// that quietly broke the one page whose whole job is to restart the server:
/// the deploy button killed the session of the very operator driving it.
class AdminSessionStore {
  AdminSessionStore(this.dataDir);

  final String dataDir;

  File get _file => File('$dataDir/admin_sessions.json');

  /// Expired entries are dropped on the way in; anything malformed is
  /// ignored, which only costs a re-login.
  Map<String, int> load() {
    final out = <String, int>{};
    try {
      if (!_file.existsSync()) return out;
      final decoded = jsonDecode(_file.readAsStringSync());
      if (decoded is! Map) return out;
      final now = DateTime.now().millisecondsSinceEpoch;
      decoded.forEach((hash, expiry) {
        if (hash is String && expiry is int && expiry > now) {
          out[hash] = expiry;
        }
      });
    } catch (e) {
      stderr.writeln('[luma] could not read ${_file.path}: $e');
    }
    return out;
  }

  /// Called on login and logout only — a handful of writes a day, not a
  /// per-request cost.
  ///
  /// A failure here is worth a log line: it silently returns the dashboard
  /// to losing its session on every deploy, which is exactly the bug this
  /// file exists to fix, and nobody is watching the screen when it happens.
  void save(Map<String, int> sessions) {
    try {
      _file.writeAsStringSync(jsonEncode(sessions));
    } catch (e) {
      stderr.writeln('[luma] could not persist admin sessions to '
          '${_file.path}: $e — dashboard logins will not survive a restart.');
    }
  }
}
