import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../l10n/current_l.dart';
import '../../../../sync/sync_service.dart';
import 'data/team_clipboard_api.dart';
import 'team_clipboard_models.dart';
import 'team_file_check.dart';

/// A file picked to attach, before it is uploaded.
class TeamPickedFile {
  const TeamPickedFile(this.name, this.bytes);

  final String name;
  final Uint8List bytes;
}

/// Runs the Team Clipboard page: whether this account is on the team, the
/// board, the open entry with its thread, and a cache of file contents for
/// texture previews.
///
/// The board is shared and changes under you, so while a page is showing
/// ([attach]/[detach]) it polls. A poll sends the last revision it saw and
/// the server answers "unchanged" until something moves, so an idle board
/// costs one tiny request every [pollInterval].
class TeamClipboardController extends ChangeNotifier {
  TeamClipboardController(
    this._sync, {
    Future<File?> Function()? stateFile,
    this.pollInterval = const Duration(seconds: 8),
    TeamClipboardApi Function(String serverUrl, String? token)? apiFactory,
  }) : _stateFile = stateFile ?? _defaultStateFile,
       _apiFactory =
           apiFactory ?? ((url, token) => TeamClipboardApi(url, token: token));

  final SyncService _sync;

  /// Where the read-state is kept; a null file keeps it in memory only.
  final Future<File?> Function() _stateFile;
  final TeamClipboardApi Function(String, String?) _apiFactory;
  final Duration pollInterval;

  static Future<File?> _defaultStateFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/luma_team_clipboard.json');
  }

  TeamClipboardApi? _api;
  String? _apiUrl;
  String? _apiToken;

  TeamAccess _access = TeamAccess.unknown;
  String? _outsideEmail;
  String? _me;
  int? _revision;
  List<TeamEntry> _entries = const [];
  bool _loading = false;
  String? _error;

  String? _selectedId;
  TeamEntry? _selected;
  bool _loadingSelected = false;

  /// When each entry was last looked at, by its `updatedAtMs`, so the
  /// board can mark threads with news. Kept on this device only.
  final Map<String, int> _seen = {};
  bool _seenLoaded = false;
  bool _seenFresh = false;

  final Map<String, Uint8List> _fileCache = {};
  final Map<String, Future<Uint8List?>> _fileLoads = {};

  Timer? _poll;
  int _watchers = 0;
  bool _polling = false;

  bool get serverReady => _sync.serverReady;
  TeamAccess get access => _access;
  bool get isLead => _access == TeamAccess.lead;
  bool get onTeam => _access == TeamAccess.member || _access == TeamAccess.lead;

  /// The signed-in email, for the "ask the admin" screen.
  String? get outsideEmail => _outsideEmail ?? _sync.email;
  String? get me => _me;
  bool get loading => _loading;
  String? get error => _error;
  List<TeamEntry> get entries => _entries;

  String? get selectedId => _selectedId;
  bool get loadingSelected => _loadingSelected;

  /// The open entry, with its thread once it has loaded. Until then the
  /// board's copy stands in so the header shows straight away.
  TeamEntry? get selected {
    final id = _selectedId;
    if (id == null) return null;
    if (_selected?.id == id) return _selected;
    for (final e in _entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  TeamEntry? entryById(String? id) =>
      id == null ? null : _entries.where((e) => e.id == id).firstOrNull;

  /// The entries filed under main thread [id], in board order.
  List<TeamEntry> childrenOf(String id) =>
      _entries.where((e) => e.parentId == id).toList();

  /// Whether [e] can be a main thread: it isn't filed under one itself.
  bool canHoldChildren(TeamEntry e) => e.parentId == null;

  bool hasNews(TeamEntry e) =>
      _seenLoaded && e.updatedAtMs > (_seen[e.id] ?? 0) && e.id != _selectedId;

  int get newsCount => _entries.where(hasNews).length;

  // ---- Lifecycle ----------------------------------------------------------

  void init() {
    _sync.addListener(_onSyncChanged);
    _onSyncChanged();
  }

  @override
  void dispose() {
    _sync.removeListener(_onSyncChanged);
    _poll?.cancel();
    _api?.close();
    super.dispose();
  }

  /// A page showing the board calls this in initState, and [detach] in
  /// dispose; the board is only polled while one is attached.
  void attach() {
    _watchers++;
    if (_watchers == 1) {
      // Pages attach while they build; refreshing notifies listeners, so it
      // waits until the build is over.
      scheduleMicrotask(() => unawaited(refresh()));
      _poll ??= Timer.periodic(pollInterval, (_) => unawaited(_tick()));
    }
  }

  void detach() {
    _watchers = (_watchers - 1).clamp(0, 1 << 30);
    if (_watchers == 0) {
      _poll?.cancel();
      _poll = null;
    }
  }

  void _onSyncChanged() {
    if (!_sync.serverReady) {
      _api?.close();
      _api = null;
      _apiUrl = null;
      _apiToken = null;
      _reset();
      notifyListeners();
      return;
    }
    if (_api != null &&
        _apiUrl == _sync.serverUrl &&
        _apiToken == _sync.authToken) {
      return;
    }
    _api?.close();
    _apiUrl = _sync.serverUrl;
    _apiToken = _sync.authToken;
    _api = _apiFactory(_sync.serverUrl!, _sync.authToken);
    _reset();
    if (_watchers > 0) unawaited(refresh());
  }

  void _reset() {
    _access = TeamAccess.unknown;
    _outsideEmail = null;
    _me = null;
    _revision = null;
    _entries = const [];
    _error = null;
    _selectedId = null;
    _selected = null;
    _fileCache.clear();
    _fileLoads.clear();
  }

  // ---- Board ----------------------------------------------------------------

  Future<void> refresh() => _load(force: true);

  Future<void> _tick() async {
    if (_polling || _access == TeamAccess.unknown) return;
    _polling = true;
    try {
      await _load(force: false);
    } finally {
      _polling = false;
    }
  }

  Future<void> _load({required bool force}) async {
    final api = _api;
    if (api == null) return;
    if (force) {
      _loading = true;
      notifyListeners();
    }
    try {
      await _loadSeen();
      final snapshot = await api.board(since: force ? null : _revision);
      if (!identical(api, _api)) return;
      _error = null;
      _access = snapshot.access;
      if (snapshot.access == TeamAccess.outside) {
        _outsideEmail = snapshot.email;
        _entries = const [];
        _selectedId = null;
        _selected = null;
      } else {
        _me = snapshot.me;
        _revision = snapshot.revision;
        if (snapshot.entries case final entries?) {
          _applyBoard(entries);
        }
      }
    } on TeamClipboardApiException catch (e) {
      if (!force) return;
      _error = e.message;
    } catch (e) {
      if (!force) return;
      _error = '$e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _applyBoard(List<TeamEntry> entries) {
    _entries = entries;
    if (_seenFresh) {
      for (final e in entries) {
        _seen[e.id] = e.updatedAtMs;
      }
      _seenFresh = false;
      unawaited(_saveSeen());
    }
    final id = _selectedId;
    if (id == null) return;
    final summary = entries.where((e) => e.id == id).firstOrNull;
    if (summary == null) {
      _selectedId = null;
      _selected = null;
    } else if (_selected == null ||
        summary.updatedAtMs != _selected!.updatedAtMs) {
      unawaited(_loadSelected(id));
    }
  }

  // ---- Open entry -----------------------------------------------------------

  void select(String? id) {
    if (id == _selectedId) return;
    _selectedId = id;
    _selected = null;
    notifyListeners();
    if (id != null) unawaited(_loadSelected(id));
  }

  Future<void> _loadSelected(String id) async {
    final api = _api;
    if (api == null) return;
    _loadingSelected = true;
    notifyListeners();
    try {
      final entry = await api.entry(id);
      if (_selectedId == id) _store(entry);
    } on TeamClipboardApiException catch (e) {
      if (e.accessRemoved) {
        unawaited(refresh());
      } else if (e.status == 404 && _selectedId == id) {
        _selectedId = null;
        _entries = _entries.where((x) => x.id != id).toList();
      }
    } catch (_) {
    } finally {
      _loadingSelected = false;
      notifyListeners();
    }
  }

  /// Takes a fresh copy of [entry] from the server into the board and, if
  /// it's the open one, as the open entry, and counts it as seen.
  void _store(TeamEntry entry) {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    final next = List<TeamEntry>.of(_entries);
    if (index < 0) {
      next.insert(0, entry);
    } else {
      next[index] = entry;
    }
    _entries = next;
    if (_selectedId == entry.id) _selected = entry;
    _markSeen(entry);
    notifyListeners();
  }

  void _markSeen(TeamEntry entry) {
    if ((_seen[entry.id] ?? 0) >= entry.updatedAtMs) return;
    _seen[entry.id] = entry.updatedAtMs;
    unawaited(_saveSeen());
  }

  // ---- Changes --------------------------------------------------------------

  /// Runs [call] against the server, takes the entry it returns and asks the
  /// board for whatever else moved. Errors are rethrown for the page to
  /// show; losing access flips the page back to the gate.
  Future<TeamEntry> _change(
    Future<TeamEntry> Function(TeamClipboardApi api) call,
  ) async {
    final api = _api;
    if (api == null) throw StateError('Not signed in.');
    try {
      final entry = await call(api);
      _store(entry);
      unawaited(_tick());
      return entry;
    } on TeamClipboardApiException catch (e) {
      if (e.accessRemoved) unawaited(refresh());
      rethrow;
    }
  }

  /// Puts a new entry on the board and attaches [files] to it. Returns the
  /// entry and the names of any files the server refused.
  Future<(TeamEntry, List<String>)> create({
    required TeamEntryKind kind,
    required String title,
    required String brief,
    String? parentId,
    List<TeamPickedFile> files = const [],
  }) async {
    var entry = await _change(
      (api) => api.create(
        kind: kind,
        title: title,
        brief: brief,
        parentId: parentId,
      ),
    );
    final failed = <String>[];
    for (final file in files) {
      try {
        entry = await _change(
          (api) async => api.upload(entry.id, file.name, await _checked(file)),
        );
      } on TeamClipboardApiException {
        failed.add(file.name);
      }
    }
    select(entry.id);
    return (entry, failed);
  }

  Future<TeamEntry> edit(
    String id, {
    required TeamEntryKind kind,
    required String title,
    required String brief,
    required String? parentId,
  }) => _change(
    (api) => api.update(
      id,
      kind: kind,
      title: title,
      brief: brief,
      parentId: parentId,
    ),
  );

  /// Changes the name this account goes by on the board, then reloads the
  /// board so every entry and message shows it.
  Future<void> rename(String name) async {
    final api = _api;
    if (api == null) throw StateError('Not signed in.');
    try {
      _me = await api.rename(name);
      notifyListeners();
      unawaited(refresh());
      if (_selectedId case final id?) unawaited(_loadSelected(id));
    } on TeamClipboardApiException catch (e) {
      if (e.accessRemoved) unawaited(refresh());
      rethrow;
    }
  }

  Future<TeamEntry> setStage(String id, TeamEntryStage stage) =>
      _change((api) => api.setStage(id, stage));

  Future<TeamEntry> setClosed(String id, bool closed) =>
      _change((api) => api.setClosed(id, closed));

  Future<TeamEntry> post(String id, String text) =>
      _change((api) => api.post(id, text));

  Future<TeamEntry> upload(String id, TeamPickedFile file) =>
      _change((api) async => api.upload(id, file.name, await _checked(file)));

  /// The file's bytes once they pass [checkTeamFile]. Every upload goes
  /// through here, so nothing the server would refuse ever leaves the
  /// device, whichever screen picked it.
  Future<Uint8List> _checked(TeamPickedFile file) async {
    final problem = await checkTeamFile(file.name, file.bytes);
    if (problem == null) return file.bytes;
    throw TeamClipboardApiException(
      0,
      'rejected_locally',
      problem.describe(currentL, file.name),
    );
  }

  Future<TeamEntry> removeFile(String id, String fileId) async {
    final entry = await _change((api) => api.removeFile(id, fileId));
    _fileCache.remove(fileId);
    _fileLoads.remove(fileId);
    return entry;
  }

  Future<void> delete(String id) async {
    final api = _api;
    if (api == null) return;
    await api.delete(id);
    _entries = _entries.where((e) => e.id != id).toList();
    if (_selectedId == id) {
      _selectedId = null;
      _selected = null;
    }
    _seen.remove(id);
    unawaited(_saveSeen());
    notifyListeners();
    unawaited(_tick());
  }

  // ---- Files ----------------------------------------------------------------

  Uint8List? cachedFile(String fileId) => _fileCache[fileId];

  /// The contents of [fileId], from the cache or the server. Null when it
  /// can't be fetched.
  Future<Uint8List?> file(String fileId) {
    final cached = _fileCache[fileId];
    if (cached != null) return Future.value(cached);
    return _fileLoads[fileId] ??= () async {
      try {
        final bytes = await _api?.download(fileId);
        if (bytes != null) _fileCache[fileId] = bytes;
        return bytes;
      } catch (_) {
        return null;
      } finally {
        _fileLoads.remove(fileId);
      }
    }();
  }

  // ---- Seen state -----------------------------------------------------------

  Future<void> _loadSeen() async {
    if (_seenLoaded) return;
    try {
      final file = await _stateFile();
      if (file != null && await file.exists()) {
        final raw = jsonDecode(await file.readAsString());
        if (raw is Map && raw['seen'] is Map) {
          (raw['seen'] as Map).forEach((id, at) {
            if (id is String && at is int) _seen[id] = at;
          });
        }
      } else {
        _seenFresh = true;
      }
    } catch (_) {}
    _seenLoaded = true;
  }

  Future<void> _saveSeen() async {
    try {
      final live = {for (final e in _entries) e.id};
      _seen.removeWhere((id, _) => !live.contains(id));
      final file = await _stateFile();
      await file?.writeAsString(jsonEncode({'seen': _seen}), flush: true);
    } catch (_) {}
  }
}
