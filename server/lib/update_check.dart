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
  /// be claimed (polls every 2s).
  checking,

  /// A request is on disk but no watcher is alive to pick it up.
  stalled,

  /// The last check finished; [UpdateCheckStatus.log] holds its output.
  done;

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

  /// `apt`/`ubuntu-drivers` output from the last finished check. Empty while
  /// [phase] is [UpdateCheckPhase.checking] — the previous check's log is
  /// still on disk until the watcher claims the new request and truncates it.
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

/// The admin dashboard's "Check for updates" button. Reports available `apt`
/// package upgrades and graphics-driver updates for the host running the
/// server (Ubuntu Desktop) — a read-only check, so unlike [DeployConsole] it
/// never restarts anything. It still can't run inside this container though:
/// the container's own filesystem has nothing to do with the host's package
/// state, so this reuses the same deploy-watcher.sh request/log handoff on
/// the shared `/data` volume, just with its own file names.
class UpdateCheckConsole {
  UpdateCheckConsole({required this.dataDir, required this.repoPathConfigured});

  final String dataDir;
  final bool repoPathConfigured;

  File get _lockFile => File('$dataDir/update-check.lock');
  File get _requestFile => File('$dataDir/update-check.request');
  File get _logFile => File('$dataDir/update-check.log');
  File get _checkedAtFile => File('$dataDir/update-check.done');
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

  Future<String> _readLog() async {
    try {
      if (!await _logFile.exists()) return '';
      return await _logFile.readAsString();
    } catch (_) {
      return '';
    }
  }

  Future<DateTime?> _readCheckedAt() async {
    try {
      if (!await _checkedAtFile.exists()) return null;
      return DateTime.tryParse((await _checkedAtFile.readAsString()).trim());
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

    final checkedAt = await _readCheckedAt();
    return UpdateCheckStatus(
      phase: checkedAt == null ? UpdateCheckPhase.idle : UpdateCheckPhase.done,
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
          'An update check is already in progress. Wait for it to finish.');
    }

    await _requestFile.parent.create(recursive: true);
    await _requestFile.writeAsString(DateTime.now().toIso8601String());

    final watcherAlive = await isWatcherAlive;
    return jsonResponse(200, {
      'phase': (watcherAlive
              ? UpdateCheckPhase.checking
              : UpdateCheckPhase.stalled)
          .wireName,
      'watcherAlive': watcherAlive,
    });
  }

  /// GET /admin/system/check-updates/status — polled by [updateCheckScript].
  Future<Response> checkStatus(Request request) async =>
      jsonResponse(200, (await status()).toJson());

  /// Maintenance tab: the "Check for updates" button POSTs the request, then
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
        + 'run this check. Start it with: sudo systemctl start '
        + 'luma-deploy-watcher';
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
      text: 'Checking for package and driver updates…'
    },
    stalled: { busy: false, color: RED, poll: 0, text: watcherHint },
    done: {
      busy: false, color: GREEN, poll: 0,
      text: function (data) {
        return data.checkedAt
            ? 'Last checked ' + new Date(data.checkedAt).toLocaleString()
            : 'Check complete.';
      }
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
      .then(function (r) { return r.json(); })
      .then(render)
      .catch(function () {
        setStatus('Could not reach the server.', RED);
      });
  }

  btn.addEventListener('click', function () {
    if (timer) { clearTimeout(timer); timer = null; }
    log.style.display = 'none';
    log.textContent = '';
    setStatus('Starting check…', AMBER);
    setBusy(true);
    fetch('/admin/system/check-updates', { method: 'POST' })
      .then(function (r) { return r.json(); })
      .then(function (data) {
        if (data.error) {
          setBusy(false);
          setStatus(data.message || data.error, RED);
          return;
        }
        render({ phase: data.phase, log: '', checkedAt: null,
                 watcherAlive: data.watcherAlive });
      })
      .catch(function () {
        setBusy(false);
        setStatus('Could not start the check.', RED);
      });
  });

  poll();
})();
''';
}
