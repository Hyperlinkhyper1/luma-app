import 'dart:io';

import 'package:shelf/shelf.dart';

import 'util.dart';

/// Where a system-update check is in its lifecycle, as computed by
/// [UpdateCheckConsole.status]. Mirrors [DeployPhase] in deploy_console.dart
/// — same file-drop handoff to the host, same reason for needing it: this
/// container doesn't run Ubuntu Desktop, the host does, so `apt`/
/// `ubuntu-drivers` output has to come from outside the container.
enum UpdateCheckPhase {
  /// LUMA_REPO_PATH is unset, so deploy-watcher.sh isn't running at all and
  /// nothing would ever claim a request.
  notConfigured,

  /// Nothing in flight; a previous result may still be on disk.
  idle,

  /// The request file is on disk and the watcher is alive, so it's about to
  /// be claimed (polls every 2s) or the update is currently installing and
  /// restarting the server and wiki.
  checking,

  /// A request is on disk but no watcher is alive to pick it up.
  stalled,

  /// The last update finished; [UpdateCheckStatus.log] holds its output and
  /// the server and wiki have been restarted.
  done,

  /// The last update finished, but this server process is older than the
  /// request — whatever ran on the host never restarted it.
  notRestarted;

  String get wireName => name;
}

class UpdateCheckStatus {
  const UpdateCheckStatus({
    required this.phase,
    required this.log,
    required this.checkedAt,
    required this.watcherAlive,
  });

  final UpdateCheckPhase phase;

  /// `apt`/`ubuntu-drivers` output plus server/wiki restart log from the last
  /// finished update. Empty while [phase] is [UpdateCheckPhase.checking] — the
  /// previous run's log is still on disk until the watcher claims the new
  /// request and truncates it.
  final String log;

  /// When the last check finished, or null if none has finished yet.
  final DateTime? checkedAt;

  final bool watcherAlive;

  Map<String, dynamic> toJson() => {
        'phase': phase.wireName,
        'log': log,
        'checkedAt': checkedAt?.toIso8601String(),
        'watcherAlive': watcherAlive,
      };
}

/// The admin dashboard's "System updates" button. Installs available `apt`
/// package upgrades and graphics-driver updates for the host running the
/// server (Ubuntu Desktop), then immediately restarts the server and wiki.
/// It still can't run inside this container though: the container's own
/// filesystem has nothing to do with the host's package state, so this
/// reuses the same deploy-watcher.sh request/log handoff on the shared
/// `/data` volume, just with its own file names.
class UpdateCheckConsole {
  UpdateCheckConsole({
    required this.dataDir,
    required this.repoPathConfigured,
    required this.startedAt,
  });

  final String dataDir;
  final bool repoPathConfigured;

  /// When this server process started. A finished update requested after
  /// this moment means the restart it promised never happened.
  final DateTime startedAt;

  File get _lockFile => File('$dataDir/update-check.lock');
  File get _requestFile => File('$dataDir/update-check.request');
  File get _logFile => File('$dataDir/update-check.log');
  File get _checkedAtFile => File('$dataDir/update-check.done');

  /// Written by this container, never by the watcher (which deletes the
  /// request file when it claims it), so it outlives the claim.
  File get _requestedAtFile => File('$dataDir/update-check.requested');
  File get _heartbeatFile => File('$dataDir/deploy.watcher');

  static const _lockMaxAge = Duration(seconds: 60);
  static const _heartbeatMaxAge = Duration(seconds: 60);

  Future<bool> _isFresh(File file, Duration maxAge) async {
    try {
      if (!await file.exists()) return false;
      return DateTime.now().difference(await file.lastModified()) < maxAge;
    } catch (_) {
      return false;
    }
  }

  Future<bool> get isChecking => _isFresh(_lockFile, _lockMaxAge);

  Future<bool> get isWatcherAlive => _isFresh(_heartbeatFile, _heartbeatMaxAge);

  File get _rebootRequestFile => File('$dataDir/reboot.request');
  File get _rebootLogFile => File('$dataDir/reboot.log');
  File get _rebootRequiredFile => File('$dataDir/reboot-required');

  Future<String> _readText(File file) async {
    try {
      if (!await file.exists()) return '';
      return await file.readAsString();
    } catch (_) {
      return '';
    }
  }

  Future<String> _readLog() => _readText(_logFile);

  Future<DateTime?> _readTimestamp(File file) async {
    try {
      if (!await file.exists()) return null;
      return DateTime.tryParse((await file.readAsString()).trim());
    } catch (_) {
      return null;
    }
  }

  Future<UpdateCheckStatus> status() async {
    final watcherAlive = await isWatcherAlive;

    if (!repoPathConfigured) {
      return UpdateCheckStatus(
        phase: UpdateCheckPhase.notConfigured,
        log: '',
        checkedAt: null,
        watcherAlive: watcherAlive,
      );
    }

    if (await isChecking) {
      return UpdateCheckStatus(
        phase: UpdateCheckPhase.checking,
        log: await _readLog(),
        checkedAt: null,
        watcherAlive: watcherAlive,
      );
    }

    if (await _requestFile.exists()) {
      return UpdateCheckStatus(
        phase: watcherAlive
            ? UpdateCheckPhase.checking
            : UpdateCheckPhase.stalled,
        log: '',
        checkedAt: null,
        watcherAlive: watcherAlive,
      );
    }

    final checkedAt = await _readTimestamp(_checkedAtFile);
    final requestedAt = await _readTimestamp(_requestedAtFile);
    final UpdateCheckPhase phase;
    if (checkedAt == null) {
      phase = UpdateCheckPhase.idle;
    } else if (requestedAt != null && startedAt.isBefore(requestedAt)) {
      phase = UpdateCheckPhase.notRestarted;
    } else {
      phase = UpdateCheckPhase.done;
    }
    return UpdateCheckStatus(
      phase: phase,
      log: await _readLog(),
      checkedAt: checkedAt,
      watcherAlive: watcherAlive,
    );
  }

  /// POST /admin/system/check-updates — drops the request file.
  Future<Response> requestCheck(Request request) async {
    if (!repoPathConfigured) {
      return errorResponse(404, 'not_configured',
          "LUMA_REPO_PATH is not set on this server, so the host watcher "
          "that runs this check isn't running either.");
    }

    if (await isChecking) {
      return errorResponse(409, 'check_running',
          'A system update is already in progress. Wait for it to finish.');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    await _requestFile.parent.create(recursive: true);
    await _requestedAtFile.writeAsString(now);
    await _requestFile.writeAsString(now);

    final watcherAlive = await isWatcherAlive;
    return jsonResponse(200, {
      'phase': (watcherAlive
              ? UpdateCheckPhase.checking
              : UpdateCheckPhase.stalled)
          .wireName,
      'watcherAlive': watcherAlive,
    });
  }

  /// POST /admin/system/reboot — asks the host watcher to reboot the machine.
  /// Refused while nothing could act on it (no watcher) or while an update
  /// is installing: rebooting mid-dpkg can leave the host unbootable.
  Future<Response> requestReboot(Request request) async {
    if (!repoPathConfigured) {
      return errorResponse(404, 'not_configured',
          "LUMA_REPO_PATH is not set on this server, so the host watcher "
          "that would reboot it isn't running either.");
    }
    if (!await isWatcherAlive) {
      return errorResponse(409, 'watcher_down',
          'The deploy watcher is not running on the host, so nothing would '
          'reboot it. Start it with: sudo systemctl start luma-deploy-watcher');
    }
    if (await isChecking || await _requestFile.exists()) {
      return errorResponse(409, 'check_running',
          'A system update is in progress. Reboot once it has finished.');
    }

    // The previous run's log goes first, so the page never mistakes an old
    // "FAILED" for this request's answer in the instant after the claim.
    try {
      if (await _rebootLogFile.exists()) await _rebootLogFile.delete();
    } catch (_) {}
    await _rebootRequestFile.parent.create(recursive: true);
    await _rebootRequestFile
        .writeAsString(DateTime.now().toUtc().toIso8601String());
    return jsonResponse(200, {'startedAt': startedAt.toUtc().toIso8601String()});
  }

  /// GET /admin/system/reboot/status — polled by [rebootScript]. The page
  /// knows the host came back when `startedAt` changes: this process is new.
  Future<Response> rebootStatus(Request request) async {
    final required = await _rebootRequiredFile.exists();
    return jsonResponse(200, {
      'startedAt': startedAt.toUtc().toIso8601String(),
      'rebootRequired': required,
      'rebootPackages':
          required ? (await _readText(_rebootRequiredFile)).trim() : '',
      'pending': await _rebootRequestFile.exists(),
      'log': await _readText(_rebootLogFile),
      'watcherAlive': await isWatcherAlive,
    });
  }

  /// GET /admin/system/check-updates/status — polled by [updateCheckScript].
  Future<Response> checkStatus(Request request) async =>
      jsonResponse(200, (await status()).toJson());

  /// Maintenance tab: the "System updates" button POSTs the request, then
  /// polls the status endpoint to stream the result into the <pre> below it.
  static const updateCheckScript = r'''
(function () {
  const btn = document.getElementById('updateCheckBtn');
  const status = document.getElementById('updateCheckStatus');
  const log = document.getElementById('updateCheckLog');
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
        + 'run this update. Start it with: sudo systemctl start '
        + 'luma-deploy-watcher';
  }

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
    setStatus('Admin session expired — reload this page and sign in again.', RED);
    return true;
  }

  var PHASES = {
    notConfigured: {
      busy: true, color: GREY, poll: 0,
      text: 'Not configured: set LUMA_REPO_PATH in this server\'s .env '
          + '(see .env.example), then restart.'
    },
    idle: { busy: false, color: GREY, poll: 0, text: '' },
    checking: {
      busy: true, color: AMBER, poll: 1500,
      text: 'Installing updates and restarting server and wiki… (the server will be briefly unavailable)'
    },
    stalled: { busy: false, color: RED, poll: 0, text: watcherHint },
    done: {
      busy: false, color: GREEN, poll: 0,
      text: function (data) {
        return data.checkedAt
            ? 'Last updated ' + new Date(data.checkedAt).toLocaleString() + ' — server and wiki restarted.'
            : 'Update complete — server and wiki restarted.';
      }
    },
    notRestarted: {
      busy: false, color: RED, poll: 0,
      text: 'Updates ran, but the server did not restart — see the log below. '
          + 'If the log has no "Restarting server and wiki" step, the host '
          + 'watcher is an old copy: sudo systemctl restart luma-deploy-watcher'
    }
  };

  function render(data) {
    var phase = PHASES[data.phase] || PHASES.idle;
    showLog(data.log);
    setBusy(phase.busy);

    var text = typeof phase.text === 'function' ? phase.text(data) : phase.text;
    if (!text && data.watcherAlive === false) {
      setStatus(watcherHint(), AMBER);
    } else {
      setStatus(text, phase.color);
    }

    if (phase.poll) timer = setTimeout(poll, phase.poll);
  }

  function poll() {
    fetch('/admin/system/check-updates/status')
      .then(readJson)
      .then(render)
      .catch(function (err) {
        if (sessionExpired(err)) return;
        setStatus('Server restarting… waiting for it to come back.', AMBER);
        timer = setTimeout(poll, 2000);
      });
  }

  btn.addEventListener('click', function () {
    if (!confirm('This will install all available apt and driver updates, then immediately restart the server and wiki. The server will be briefly unavailable. Continue?')) return;
    if (timer) { clearTimeout(timer); timer = null; }
    log.style.display = 'none';
    log.textContent = '';
    setStatus('Starting system update…', AMBER);
    setBusy(true);
    fetch('/admin/system/check-updates', { method: 'POST' })
      .then(readJson)
      .then(function (data) {
        if (data.error) {
          setBusy(false);
          setStatus(data.message || data.error, RED);
          return;
        }
        render({ phase: data.phase, log: '', checkedAt: null,
                 watcherAlive: data.watcherAlive });
      })
      .catch(function (err) {
        if (sessionExpired(err)) return;
        setBusy(false);
        setStatus('Could not start the update.', RED);
      });
  });

  poll();
})();
''';

  /// Maintenance tab: the "Reboot server" button. The dashboard goes down
  /// with the host, so the page polls through the outage and calls the
  /// reboot done only once a *new* server process answers.
  static const rebootScript = r'''
(function () {
  const btn = document.getElementById('rebootBtn');
  const status = document.getElementById('rebootStatus');
  const log = document.getElementById('rebootLog');
  if (!btn || !status || !log) return;

  var GREY = '#a49fb8', AMBER = '#e0c87e', GREEN = '#7ee08a', RED = '#e07e7e';
  var GIVE_UP_MS = 10 * 60 * 1000;

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
    log.style.display = text ? 'block' : 'none';
    log.textContent = text || '';
  }

  function readJson(r) {
    if (r.redirected && r.url.indexOf('/admin/login') !== -1) {
      var err = new Error('admin session expired');
      err.sessionExpired = true;
      throw err;
    }
    return r.json();
  }

  function showRequired(data) {
    if (!data.rebootRequired) return;
    setStatus('The host needs a reboot for installed updates to take effect'
        + (data.rebootPackages ? ' (' + data.rebootPackages.split('\n').join(', ') + ').' : '.'),
        AMBER);
  }

  function waitForReturn(oldStartedAt, since) {
    fetch('/admin/system/reboot/status')
      .then(readJson)
      .then(function (data) {
        if (data.startedAt !== oldStartedAt) {
          setBusy(false);
          showLog('');
          setStatus('Server rebooted and back up ('
              + new Date().toLocaleTimeString() + ').', GREEN);
          return;
        }
        if (!data.pending && data.log.indexOf('FAILED') !== -1) {
          setBusy(false);
          showLog(data.log);
          setStatus('The reboot did not happen — see below.', RED);
          return;
        }
        if (!data.pending && data.log.indexOf('Ignored') !== -1) {
          setBusy(false);
          showLog(data.log);
          setStatus('The watcher dropped the request as stale. Try again.', RED);
          return;
        }
        setStatus('Asking the host to reboot…', AMBER);
        retry(oldStartedAt, since);
      })
      .catch(function (err) {
        if (err && err.sessionExpired) {
          setBusy(false);
          setStatus('Admin session expired — reload this page and sign in again.', RED);
          return;
        }
        setStatus('Rebooting… waiting for the server to come back.', AMBER);
        retry(oldStartedAt, since);
      });
  }

  function retry(oldStartedAt, since) {
    if (Date.now() - since > GIVE_UP_MS) {
      setBusy(false);
      setStatus('The server has not come back after 10 minutes. Check the '
          + 'machine itself — it may be waiting at a disk-unlock or BIOS prompt.', RED);
      return;
    }
    setTimeout(function () { waitForReturn(oldStartedAt, since); }, 2000);
  }

  btn.addEventListener('click', function () {
    if (!confirm('Reboot the whole server machine? Everything on it — sync, '
        + 'the wiki, this dashboard — is offline until it boots back up, '
        + 'usually a minute or two.')) return;
    setBusy(true);
    showLog('');
    setStatus('Requesting reboot…', AMBER);
    fetch('/admin/system/reboot', { method: 'POST' })
      .then(readJson)
      .then(function (data) {
        if (data.error) {
          setBusy(false);
          setStatus(data.message || data.error, RED);
          return;
        }
        waitForReturn(data.startedAt, Date.now());
      })
      .catch(function () {
        setBusy(false);
        setStatus('Could not request the reboot.', RED);
      });
  });

  fetch('/admin/system/reboot/status')
    .then(readJson)
    .then(showRequired)
    .catch(function () {});
})();
''';
}
