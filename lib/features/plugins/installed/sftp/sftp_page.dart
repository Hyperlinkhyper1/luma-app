import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';

import '../../../../account/plan.dart';
import '../../../../account/plan_selection_page.dart';
import '../../../../app/widgets.dart';
import '../../../../p2p/peer_sync_scope.dart';
import '../../../../settings/settings_scope.dart';
import '../../../../theme/luma_theme.dart';
import 'host/host_panel.dart';
import 'host/host_server.dart';
import 'host/this_device_page.dart';
import 'share/device_share_scope.dart';
import 'share/device_share_view.dart';
import 'sftp_dialogs.dart';
import 'sftp_file_pane.dart';
import 'sftp_local_fs.dart';
import 'sftp_paths.dart';
import 'sftp_queue_panel.dart';
import 'sftp_session.dart';
import 'sftp_site.dart';
import 'sftp_site_manager.dart';
import 'sftp_site_store.dart';
import 'sftp_transfer_queue.dart';

/// The SFTP plugin: a two-pane file transfer client for your own servers.
///
/// Nova-exclusive, like the other paid plugins, and entirely peer-to-server —
/// the SSH connection is opened by this device straight to the host the user
/// typed. No luma server is involved at any point, so nothing here goes
/// through `SyncService` or `GatedServerClient`.
class SftpPage extends StatefulWidget {
  const SftpPage({super.key});

  @override
  State<SftpPage> createState() => _SftpPageState();
}

class _SftpPageState extends State<SftpPage> {
  final _store = SftpSiteStore.instance;
  final _queue = SftpTransferQueue();

  SftpSession? _session;
  String? _connectingSiteId;
  String? _connectionError;
  StreamSubscription<void>? _sessionWatch;

  String _localPath = '';
  List<PaneEntry> _localEntries = const [];
  final Set<String> _localSelection = {};
  bool _localLoading = false;
  String? _localError;

  String _remotePath = RemotePath.separator;
  List<PaneEntry> _remoteEntries = const [];
  final Set<String> _remoteSelection = {};
  bool _remoteLoading = false;
  String? _remoteError;

  bool _queueExpanded = false;
  int _phoneTab = 0;
  Timer? _refreshDebounce;

  /// Owned here rather than by the Host tab's widget so that switching tabs
  /// never tears a listener down mid-transfer. It is stopped in [dispose], so
  /// leaving the plugin stops hosting.
  final _host = SftpHostServer();

  /// 0 = Servers (SFTP), 1 = My devices (the shared folder), 2 = Host.
  int _mode = 0;
  final Set<String> _shareSelection = {};
  int _phoneShareTab = 0;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    // The connection bar shows a dot while hosting, so it has to rebuild when
    // the listener starts or stops.
    _host.addListener(_onStoreChanged);
    _queue.onItemComplete = _onTransferComplete;
    _bootstrapLocalPane();
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    _sessionWatch?.cancel();
    _store.removeListener(_onStoreChanged);
    _host.removeListener(_onStoreChanged);
    _queue.dispose();
    _session?.close();
    _host.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrapLocalPane() async {
    String path;
    try {
      path = await LocalBrowser.defaultDirectory();
    } catch (e) {
      if (!mounted) return;
      setState(() => _localError = 'Could not find a folder to start in. '
          '${_describe(e)}');
      return;
    }
    if (!mounted) return;
    setState(() => _localPath = path);
    await _loadLocal();
  }

  // ---------------------------------------------------------------- panes

  Future<void> _loadLocal() async {
    if (_localPath.isEmpty) return;
    setState(() {
      _localLoading = true;
      _localError = null;
    });
    try {
      final entries = await LocalBrowser.list(_localPath);
      if (!mounted) return;
      setState(() {
        _localEntries = [
          for (final entry in entries)
            PaneEntry(
              name: entry.name,
              path: entry.path,
              isDirectory: entry.isDirectory,
              size: entry.size,
              modified: entry.modified,
            ),
        ];
        _localSelection.removeWhere(
          (path) => !_localEntries.any((e) => e.path == path),
        );
        _localLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _localLoading = false;
        _localError = 'Could not open this folder. ${_describe(e)}';
      });
    }
  }

  Future<void> _loadRemote() async {
    final session = _session;
    if (session == null) return;
    setState(() {
      _remoteLoading = true;
      _remoteError = null;
    });
    try {
      final entries = await session.list(_remotePath);
      if (!mounted) return;
      setState(() {
        _remoteEntries = [
          for (final entry in entries)
            PaneEntry(
              name: entry.name,
              path: entry.path,
              isDirectory: entry.isDirectory,
              isLink: entry.isLink,
              size: entry.size,
              modified: entry.modified,
              permissions: entry.mode == null ? null : entry.permissionsLabel,
            ),
        ];
        _remoteSelection.removeWhere(
          (path) => !_remoteEntries.any((e) => e.path == path),
        );
        _remoteLoading = false;
      });
      unawaited(_store.rememberDirectories(session.site.id, remote: _remotePath));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _remoteLoading = false;
        _remoteError = 'Could not list this folder. ${_describe(e)}';
      });
    }
  }

  void _navigateLocal(String path) {
    setState(() {
      _localPath = path;
      _localSelection.clear();
    });
    _loadLocal();
    final session = _session;
    if (session != null) {
      unawaited(_store.rememberDirectories(session.site.id, local: path));
    }
  }

  void _navigateRemote(String path) {
    setState(() {
      _remotePath = RemotePath.normalize(path);
      _remoteSelection.clear();
    });
    _loadRemote();
  }

  // ----------------------------------------------------------- connecting

  Future<void> _connect(SftpSite site) async {
    if (_connectingSiteId != null) return;
    setState(() {
      _connectingSiteId = site.id;
      _connectionError = null;
    });

    var secret = await _store.secretFor(site);
    var promptedSave = site.saveSecret;

    // Password sites always need something; key sites only when the key file
    // turns out to be passphrase-protected, which connect() reports back.
    if (secret == null && site.authMode == SftpAuthMode.password) {
      if (!mounted) return;
      final answer = await promptSecret(
        context,
        title: site.isLumaHost
            ? 'Pairing password for ${site.displayName}'
            : 'Password for ${site.displayName}',
        message: site.isLumaHost
            ? 'Type the password shown on that device\'s Host tab.'
            : 'Signing in as ${site.username} on ${site.host}.',
        offerSave: true,
        initialSave: site.saveSecret,
      );
      if (answer == null) {
        setState(() => _connectingSiteId = null);
        return;
      }
      secret = answer.secret;
      promptedSave = answer.save;
    }

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final session = await SftpSession.connect(
          site: site,
          secret: secret,
          onHostKey: (prompt) async {
            if (!mounted) return false;
            return showHostKeyDialog(context, prompt);
          },
        );
        await _onConnected(session, site, secret, promptedSave);
        return;
      } on SftpConnectionException catch (e) {
        if (!mounted) return;
        if (!e.isAuthFailure || attempt > 0) {
          setState(() {
            _connectingSiteId = null;
            _connectionError = e.message;
          });
          return;
        }
        final answer = await promptSecret(
          context,
          title: site.isLumaHost
              ? 'Pairing password for ${site.displayName}'
              : site.authMode == SftpAuthMode.key
                  ? 'Passphrase for ${site.displayName}'
                  : 'Password for ${site.displayName}',
          message: e.message,
          offerSave: true,
          initialSave: promptedSave,
        );
        if (answer == null) {
          if (!mounted) return;
          setState(() => _connectingSiteId = null);
          return;
        }
        secret = answer.secret;
        promptedSave = answer.save;
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _connectingSiteId = null;
          _connectionError = _describe(e);
        });
        return;
      }
    }
  }

  Future<void> _onConnected(
    SftpSession session,
    SftpSite site,
    String? secret,
    bool save,
  ) async {
    // Only touch the stored secret when the user actually typed one; a site
    // connected from its remembered password must not have it overwritten.
    await _store.upsert(
      site.copyWith(saveSecret: save, lastUsed: DateTime.now()),
      secret: save ? secret : null,
    );

    final remote = site.remoteDirectory.trim().isEmpty
        ? session.homeDirectory
        : site.remoteDirectory.trim();
    final local = site.localDirectory.trim().isEmpty
        ? _localPath
        : site.localDirectory.trim();

    _sessionWatch?.cancel();
    _sessionWatch = session.done.asStream().listen((_) => _onDropped());

    if (!mounted) {
      session.close();
      return;
    }
    setState(() {
      _session = session;
      _connectingSiteId = null;
      _connectionError = null;
      _remotePath = RemotePath.normalize(remote);
      _remoteSelection.clear();
      if (local != _localPath && Directory(local).existsSync()) {
        _localPath = local;
        _localSelection.clear();
      }
      _phoneTab = 1;
    });
    _queue.bind(session);
    await Future.wait([_loadRemote(), _loadLocal()]);
  }

  void _onDropped() {
    if (!mounted || _session == null) return;
    _queue.bind(null);
    setState(() {
      _session = null;
      _remoteEntries = const [];
      _remoteSelection.clear();
      _connectionError = 'The connection to the server closed.';
      _phoneTab = 0;
    });
  }

  void _disconnect() {
    _sessionWatch?.cancel();
    _sessionWatch = null;
    _queue.bind(null);
    _session?.close();
    setState(() {
      _session = null;
      _remoteEntries = const [];
      _remoteSelection.clear();
      _connectionError = null;
      _phoneTab = 0;
    });
  }

  // ------------------------------------------------------------ transfers

  void _onTransferComplete(TransferItem item) {
    if (!mounted) return;
    // Bursts of small files would otherwise re-list the directory once per
    // file; one refresh shortly after the last one is enough.
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (item.direction == TransferDirection.upload) {
        if (RemotePath.parent(item.remotePath) == _remotePath) _loadRemote();
      } else {
        if (File(item.localPath).parent.path == _localPath) _loadLocal();
      }
    });
  }

  Future<void> _uploadEntries(
    List<PaneEntry> entries,
    String remoteDirectory,
  ) async {
    if (_session == null || entries.isEmpty) return;
    var queued = 0;
    for (final entry in entries) {
      if (entry.isDirectory) {
        final files = await LocalBrowser.walk(entry.path);
        for (final file in files) {
          _queue.enqueueUpload(
            file.file,
            RemotePath.join(
              remoteDirectory,
              '${entry.name}/${file.relativePath}',
            ),
          );
          queued++;
        }
      } else {
        _queue.enqueueUpload(
          File(entry.path),
          RemotePath.join(remoteDirectory, entry.name),
          size: entry.size,
        );
        queued++;
      }
    }
    if (!mounted) return;
    setState(() {
      _localSelection.clear();
      if (queued > 0) _queueExpanded = true;
    });
    _announce(queued == 0 ? 'Nothing to upload.' : 'Queued $queued for upload.');
  }

  Future<void> _downloadEntries(
    List<PaneEntry> entries,
    String localDirectory,
  ) async {
    final session = _session;
    if (session == null || entries.isEmpty) return;
    var queued = 0;
    for (final entry in entries) {
      if (entry.isDirectory) {
        final files = await session.walk(entry.path);
        for (final file in files) {
          final relative =
              file.relativePath.replaceAll('/', LocalBrowser.separator);
          _queue.enqueueDownload(
            file.entry.path,
            File(
              LocalBrowser.join(
                localDirectory,
                '${entry.name}${LocalBrowser.separator}$relative',
              ),
            ),
            size: file.entry.size,
          );
          queued++;
        }
      } else {
        _queue.enqueueDownload(
          entry.path,
          File(LocalBrowser.join(localDirectory, entry.name)),
          size: entry.size,
        );
        queued++;
      }
    }
    if (!mounted) return;
    setState(() {
      _remoteSelection.clear();
      if (queued > 0) _queueExpanded = true;
    });
    _announce(
      queued == 0 ? 'Nothing to download.' : 'Queued $queued for download.',
    );
  }

  void _onDrop(PaneDragPayload payload, String targetDirectory) {
    if (payload.side == PaneSide.local) {
      unawaited(_uploadEntries(payload.entries, targetDirectory));
    } else {
      unawaited(_downloadEntries(payload.entries, targetDirectory));
    }
  }

  List<PaneEntry> _selected(PaneSide side) {
    final selection = side == PaneSide.local ? _localSelection : _remoteSelection;
    final entries = side == PaneSide.local ? _localEntries : _remoteEntries;
    return entries.where((e) => selection.contains(e.path)).toList();
  }

  // -------------------------------------------------------- file actions

  Future<void> _openLocal(PaneEntry entry) async {
    if (entry.isDirectory) {
      _navigateLocal(entry.path);
      return;
    }
    final result = await OpenFile.open(entry.path);
    if (result.type != ResultType.done && mounted) {
      _announce('Could not open ${entry.name}. ${result.message}');
    }
  }

  Future<void> _openRemote(PaneEntry entry) async {
    final session = _session;
    if (session == null) return;
    if (entry.isDirectory) {
      _navigateRemote(entry.path);
      return;
    }
    if (entry.isLink) {
      // A link's own attributes say "link", not what it points at — ask the
      // server before deciding whether this opens or selects.
      try {
        final resolved = await session.statEntry(entry.path);
        if (resolved.isDirectory) {
          _navigateRemote(entry.path);
          return;
        }
      } catch (_) {
        // Falls through to selection.
      }
    }
    setState(() {
      if (!_remoteSelection.remove(entry.path)) {
        _remoteSelection.add(entry.path);
      }
    });
  }

  Future<void> _newFolder(PaneSide side) async {
    final name = await promptText(
      context,
      title: 'New folder',
      label: 'Folder name',
      icon: Icons.create_new_folder_rounded,
      confirmLabel: 'Create',
    );
    if (name == null || !mounted) return;
    try {
      if (side == PaneSide.local) {
        await Directory(LocalBrowser.join(_localPath, name)).create();
        await _loadLocal();
      } else {
        await _session?.makeDirectory(RemotePath.join(_remotePath, name));
        await _loadRemote();
      }
    } catch (e) {
      _announce('Could not create the folder. ${_describe(e)}');
    }
  }

  Future<void> _rename(PaneSide side, PaneEntry entry) async {
    final name = await promptText(
      context,
      title: 'Rename',
      label: 'New name',
      icon: Icons.drive_file_rename_outline_rounded,
      initial: entry.name,
    );
    if (name == null || name == entry.name || !mounted) return;
    try {
      if (side == PaneSide.local) {
        final target = LocalBrowser.join(_localPath, name);
        if (entry.isDirectory) {
          await Directory(entry.path).rename(target);
        } else {
          await File(entry.path).rename(target);
        }
        await _loadLocal();
      } else {
        await _session?.rename(entry.path, RemotePath.join(_remotePath, name));
        await _loadRemote();
      }
    } catch (e) {
      _announce('Could not rename ${entry.name}. ${_describe(e)}');
    }
  }

  Future<void> _delete(PaneSide side, List<PaneEntry> entries) async {
    if (entries.isEmpty) return;
    final confirmed = await confirmDelete(
      context,
      names: entries.map((e) => e.name).toList(),
      remote: side == PaneSide.remote,
    );
    if (!confirmed || !mounted) return;
    try {
      for (final entry in entries) {
        if (side == PaneSide.local) {
          if (entry.isDirectory) {
            await Directory(entry.path).delete(recursive: true);
          } else {
            await File(entry.path).delete();
          }
        } else {
          final session = _session;
          if (session == null) return;
          if (entry.isDirectory && !entry.isLink) {
            await session.removeDirectory(entry.path);
          } else {
            await session.removeFile(entry.path);
          }
        }
      }
    } catch (e) {
      _announce('Could not delete everything. ${_describe(e)}');
    }
    if (side == PaneSide.local) {
      setState(_localSelection.clear);
      await _loadLocal();
    } else {
      setState(_remoteSelection.clear);
      await _loadRemote();
    }
  }

  Future<void> _changePermissions(PaneEntry entry) async {
    final session = _session;
    if (session == null) return;
    final current = parsePermissions(entry.permissions ?? '');
    final mode = await promptPermissions(
      context,
      name: entry.name,
      current: current,
    );
    if (mode == null || !mounted) return;
    try {
      await session.chmod(entry.path, mode);
      await _loadRemote();
    } catch (e) {
      _announce('Could not change permissions. ${_describe(e)}');
    }
  }

  Future<void> _showContextMenu(
    PaneSide side,
    PaneEntry entry,
    Offset position,
  ) async {
    final luma = context.luma;
    final selection = _selected(side);
    final targets = selection.any((e) => e.path == entry.path)
        ? selection
        : <PaneEntry>[entry];
    final local = side == PaneSide.local;

    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    TextStyle style([Color? color]) =>
        TextStyle(color: color ?? luma.textPrimary, fontSize: 13);

    final action = await showMenu<String>(
      context: context,
      color: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: luma.border),
      ),
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: 'transfer',
          child: Row(
            children: [
              Icon(
                local ? Icons.north_rounded : Icons.south_rounded,
                size: 16,
                color: luma.accent,
              ),
              const SizedBox(width: 10),
              Text(
                local
                    ? 'Upload ${_countLabel(targets)}'
                    : 'Download ${_countLabel(targets)}',
                style: style(),
              ),
            ],
          ),
        ),
        if (local && targets.length == 1 && !entry.isDirectory)
          PopupMenuItem(
            value: 'open',
            child: Row(
              children: [
                Icon(Icons.open_in_new_rounded,
                    size: 16, color: luma.textSecondary),
                const SizedBox(width: 10),
                Text('Open', style: style()),
              ],
            ),
          ),
        if (targets.length == 1)
          PopupMenuItem(
            value: 'rename',
            child: Row(
              children: [
                Icon(Icons.drive_file_rename_outline_rounded,
                    size: 16, color: luma.textSecondary),
                const SizedBox(width: 10),
                Text('Rename', style: style()),
              ],
            ),
          ),
        if (!local && targets.length == 1)
          PopupMenuItem(
            value: 'permissions',
            child: Row(
              children: [
                Icon(Icons.lock_outline_rounded,
                    size: 16, color: luma.textSecondary),
                const SizedBox(width: 10),
                Text('Permissions', style: style()),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: 16, color: luma.danger),
              const SizedBox(width: 10),
              Text('Delete ${_countLabel(targets)}', style: style(luma.danger)),
            ],
          ),
        ),
      ],
    );

    if (action == null || !mounted) return;
    switch (action) {
      case 'transfer':
        if (local) {
          await _uploadEntries(targets, _remotePath);
        } else {
          await _downloadEntries(targets, _localPath);
        }
      case 'open':
        await _openLocal(entry);
      case 'rename':
        await _rename(side, entry);
      case 'permissions':
        await _changePermissions(entry);
      case 'delete':
        await _delete(side, targets);
    }
  }

  Future<void> _showPlaces() async {
    final roots = await LocalBrowser.roots();
    if (!mounted || roots.isEmpty) return;
    final luma = context.luma;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: luma.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.folder_special_rounded,
                      size: 18, color: luma.accent),
                  const SizedBox(width: 10),
                  Text(
                    'Places',
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            for (final root in roots)
              ListTile(
                leading: Icon(Icons.folder_rounded, color: luma.accent, size: 20),
                title: Text(
                  root.name,
                  style: TextStyle(color: luma.textPrimary, fontSize: 13.5),
                ),
                subtitle: Text(
                  root.path,
                  style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                ),
                onTap: () => Navigator.of(context).pop(root.path),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice != null) _navigateLocal(choice);
  }

  // --------------------------------------------------------- shared folder

  Future<void> _addToShare() async {
    final repository = DeviceShareScope.of(context);
    if (repository == null) return;
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      dialogTitle: 'Add to the shared folder',
    );
    final paths = result?.files
        .map((f) => f.path)
        .whereType<String>()
        .map(File.new)
        .toList();
    if (paths == null || paths.isEmpty) return;
    await repository.addFiles(paths);
  }

  /// Copies whatever was dragged over from the local pane into the shared
  /// folder — which is all "sending to another device" is: the mirror does
  /// the rest on its own.
  Future<void> _shareEntries(List<PaneEntry> entries) async {
    final repository = DeviceShareScope.of(context);
    if (repository == null || entries.isEmpty) return;
    for (final entry in entries) {
      if (entry.isDirectory) {
        await repository.addDirectory(Directory(entry.path));
      } else {
        await repository.addFiles([File(entry.path)]);
      }
    }
    if (!mounted) return;
    setState(_localSelection.clear);
    _announce(
      entries.length == 1
          ? '${entries.first.name} is in the shared folder.'
          : '${entries.length} items are in the shared folder.',
    );
  }

  Future<void> _openShareFolder() async {
    final repository = DeviceShareScope.of(context);
    if (repository == null) return;
    final result = await OpenFile.open(repository.folder.root.path);
    if (result.type != ResultType.done && mounted) {
      _announce('The folder is at ${repository.folder.root.path}');
    }
  }

  Future<void> _openSharedFile(String path) async {
    final repository = DeviceShareScope.of(context);
    if (repository == null) return;
    final result = await OpenFile.open(repository.folder.fileFor(path).path);
    if (result.type != ResultType.done && mounted) {
      _announce('Could not open $path. ${result.message}');
    }
  }

  Future<void> _deleteFromShare() async {
    final repository = DeviceShareScope.of(context);
    if (repository == null || _shareSelection.isEmpty) return;
    final paths = _shareSelection.toList();
    final confirmed = await confirmDelete(
      context,
      names: paths,
      remote: false,
      extraWarning:
          'They will also disappear from the shared folder on your other '
          'devices the next time they connect.',
    );
    if (!confirmed || !mounted) return;
    await repository.deleteFiles(paths);
    if (!mounted) return;
    setState(_shareSelection.clear);
  }

  // ---------------------------------------------------------- site manager

  Future<void> _newSite() async {
    final draft = await showSftpSiteEditor(context);
    if (draft == null) return;
    await _store.upsert(draft.site, secret: draft.secret);
  }

  /// Opens the screen that makes this device reachable. Its listener lives
  /// and dies with the route — see [SftpThisDevicePage] — which is why it is
  /// pushed rather than shown as another tab in the page's `IndexedStack`.
  Future<void> _openThisDevice() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SftpThisDevicePage()),
    );
  }

  Future<void> _editSite(SftpSite site) async {
    final existing = await _store.secretFor(site);
    if (!mounted) return;
    final draft = await showSftpSiteEditor(
      context,
      site: site,
      existingSecret: existing,
    );
    if (draft == null) return;
    await _store.upsert(draft.site, secret: draft.secret);
  }

  Future<void> _deleteSite(SftpSite site) async {
    final confirmed = await confirmDelete(
      context,
      names: [site.displayName],
      remote: false,
    );
    if (!confirmed) return;
    await _store.delete(site.id);
  }

  // ------------------------------------------------------------------- ui

  void _announce(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  static String _countLabel(List<PaneEntry> entries) =>
      entries.length == 1 ? entries.first.name : '${entries.length} items';

  static String _describe(Object error) {
    if (error is FileSystemException) {
      return error.osError?.message ?? error.message;
    }
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    if (settings.selectedPlanId != 'nova') return const _NovaUpsell();

    final session = _session;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return Column(
          children: [
            _ConnectionBar(
              session: session,
              connecting: _connectingSiteId != null,
              mode: _mode,
              hosting: _host.isRunning,
              onModeChanged: (mode) => setState(() => _mode = mode),
              onDisconnect: _disconnect,
              onManageSites: _disconnect,
            ),
            Expanded(
              child: _mode == 2
                  ? SftpHostPanel(
                      server: _host,
                      compact: !wide,
                      onAnnounce: _announce,
                    )
                  : _mode == 1
                  ? _buildDevices(wide)
                  : (session == null
                      ? SftpSiteManagerView(
                          sites: _store.sites,
                          loading: !_store.loaded,
                          connectingSiteId: _connectingSiteId,
                          error: _connectionError,
                          onConnect: _connect,
                          onEdit: _editSite,
                          onDelete: _deleteSite,
                          onNew: _newSite,
                          onThisDevice: () => unawaited(_openThisDevice()),
                        )
                      : (wide ? _buildWide(session) : _buildNarrow(session))),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDevices(bool wide) {
    final repository = DeviceShareScope.of(context);
    if (repository == null) {
      return DeviceShareUnavailable(
        onOpenSettings: () => _announce(
          'Open Settings → Sync & account to set this device up.',
        ),
      );
    }
    final peerSync = PeerSyncScope.of(context);

    final panel = DeviceSharePanel(
      repository: repository,
      peerSync: peerSync,
      selection: _shareSelection,
      compact: !wide,
      onToggleSelect: (path) => setState(() {
        if (!_shareSelection.remove(path)) _shareSelection.add(path);
      }),
      onAddFiles: _addToShare,
      onOpenFolder: _openShareFolder,
      onDeleteSelected: _deleteFromShare,
      onOpenFile: _openSharedFile,
      onDropped: (payload) => unawaited(_shareEntries(payload.entries)),
    );

    if (wide) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _localPane(compact: false)),
            _ShareArrow(
              enabled: _localSelection.isNotEmpty,
              onTap: () => _shareEntries(_selected(PaneSide.local)),
            ),
            Expanded(child: panel),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        children: [
          LumaSegmentedTabs(
            tabs: const ['This device', 'Shared folder'],
            selectedIndex: _phoneShareTab,
            onSelect: (index) => setState(() => _phoneShareTab = index),
          ),
          const SizedBox(height: 10),
          if (_phoneShareTab == 0 && _localSelection.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: LumaPrimaryButton(
                label: 'Share ${_localSelection.length} '
                    '${_localSelection.length == 1 ? 'item' : 'items'}',
                icon: Icons.folder_shared_rounded,
                expand: true,
                onTap: () => _shareEntries(_selected(PaneSide.local)),
              ),
            ),
          Expanded(
            child: _phoneShareTab == 0 ? _localPane(compact: true) : panel,
          ),
        ],
      ),
    );
  }

  Widget _buildWide(SftpSession session) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _localPane(compact: false)),
                _TransferArrows(
                  canUpload: _localSelection.isNotEmpty,
                  canDownload: _remoteSelection.isNotEmpty,
                  onUpload: () =>
                      _uploadEntries(_selected(PaneSide.local), _remotePath),
                  onDownload: () =>
                      _downloadEntries(_selected(PaneSide.remote), _localPath),
                ),
                Expanded(child: _remotePane(session, compact: false)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: SftpQueuePanel(
              queue: _queue,
              expanded: _queueExpanded,
              onToggleExpanded: () =>
                  setState(() => _queueExpanded = !_queueExpanded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrow(SftpSession session) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _queue,
            builder: (context, _) {
              final pending = _queue.pendingCount;
              return LumaSegmentedTabs(
                tabs: [
                  'This device',
                  'Server',
                  pending > 0 ? 'Queue ($pending)' : 'Queue',
                ],
                selectedIndex: _phoneTab,
                onSelect: (index) => setState(() => _phoneTab = index),
              );
            },
          ),
          const SizedBox(height: 10),
          if (_phoneTab != 2)
            _MobileTransferBar(
              uploading: _phoneTab == 0,
              count: _phoneTab == 0
                  ? _localSelection.length
                  : _remoteSelection.length,
              onTransfer: _phoneTab == 0
                  ? () => _uploadEntries(_selected(PaneSide.local), _remotePath)
                  : () =>
                      _downloadEntries(_selected(PaneSide.remote), _localPath),
            ),
          Expanded(
            child: switch (_phoneTab) {
              0 => _localPane(compact: true),
              1 => _remotePane(session, compact: true),
              _ => SftpQueuePanel(
                  queue: _queue,
                  expanded: true,
                  showHeader: false,
                  onToggleExpanded: () {},
                ),
            },
          ),
        ],
      ),
    );
  }

  Widget _localPane({required bool compact}) => SftpFilePane(
        side: PaneSide.local,
        title: 'This device',
        subtitle: _localPath,
        path: _localPath,
        crumbs: _localPath.isEmpty ? const [] : LocalBrowser.crumbs(_localPath),
        entries: _localEntries,
        selection: _localSelection,
        loading: _localLoading,
        error: _localError,
        canGoUp: _localPath.isNotEmpty && LocalBrowser.parent(_localPath) != null,
        compact: compact,
        onUp: () {
          final parent = LocalBrowser.parent(_localPath);
          if (parent != null) _navigateLocal(parent);
        },
        onRefresh: _loadLocal,
        onHome: _showPlaces,
        onNewFolder: () => _newFolder(PaneSide.local),
        onNavigate: _navigateLocal,
        onOpen: _openLocal,
        onToggleSelect: (entry) => setState(() {
          if (!_localSelection.remove(entry.path)) {
            _localSelection.add(entry.path);
          }
        }),
        onContextMenu: (entry, position) =>
            _showContextMenu(PaneSide.local, entry, position),
        onDropped: _onDrop,
      );

  Widget _remotePane(SftpSession session, {required bool compact}) =>
      SftpFilePane(
        side: PaneSide.remote,
        title: session.site.displayName,
        subtitle: _remotePath,
        path: _remotePath,
        crumbs: RemotePath.crumbs(_remotePath),
        entries: _remoteEntries,
        selection: _remoteSelection,
        loading: _remoteLoading,
        error: _remoteError,
        canGoUp: _remotePath != RemotePath.separator,
        compact: compact,
        onUp: () => _navigateRemote(RemotePath.parent(_remotePath)),
        onRefresh: _loadRemote,
        onHome: () => _navigateRemote(session.homeDirectory),
        onNewFolder: () => _newFolder(PaneSide.remote),
        onNavigate: _navigateRemote,
        onOpen: _openRemote,
        onToggleSelect: (entry) => setState(() {
          if (!_remoteSelection.remove(entry.path)) {
            _remoteSelection.add(entry.path);
          }
        }),
        onContextMenu: (entry, position) =>
            _showContextMenu(PaneSide.remote, entry, position),
        onDropped: _onDrop,
      );
}

/// The bar above both panes: who we are connected to, and the way out.
class _ConnectionBar extends StatelessWidget {
  const _ConnectionBar({
    required this.session,
    required this.connecting,
    required this.mode,
    required this.hosting,
    required this.onModeChanged,
    required this.onDisconnect,
    required this.onManageSites,
  });

  final SftpSession? session;
  final bool connecting;
  final int mode;

  /// Whether this device is currently serving its own folder, so the Host tab
  /// reads as live from the other tabs too.
  final bool hosting;

  final ValueChanged<int> onModeChanged;
  final VoidCallback onDisconnect;
  final VoidCallback onManageSites;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final site = session?.site;
    final devices = mode == 1;
    final host = mode == 2;
    final live = host ? hosting : (devices || session != null);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: live
                  ? luma.success
                  : (connecting ? luma.accent : luma.textMuted),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  host
                      ? 'Host this device'
                      : devices
                          ? 'My devices'
                          : (site == null ? 'SFTP' : site.displayName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  host
                      ? (hosting
                          ? 'Sharing a folder — any device with the pairing '
                              'password can connect.'
                          : 'Let another device connect to this one over your '
                              'network.')
                      : devices
                          ? 'One folder, mirrored across your own devices over '
                              'your network.'
                          : (site == null
                              ? 'Connect to your own server — nothing routes '
                                  'through luma.'
                              : 'Connected to ${site.endpointLabel}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: luma.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          LumaSegmentedTabs(
            tabs: const ['Servers', 'My devices', 'Host'],
            selectedIndex: mode,
            onSelect: onModeChanged,
          ),
          const SizedBox(width: 8),
          if (!devices && !host && session != null) ...[
            LumaGhostButton(
              label: 'Site Manager',
              icon: Icons.storage_rounded,
              onTap: onManageSites,
            ),
            const SizedBox(width: 8),
            LumaGhostButton(
              label: 'Disconnect',
              icon: Icons.link_off_rounded,
              onTap: onDisconnect,
            ),
          ],
        ],
      ),
    );
  }
}

/// The Devices view's equivalent of the transfer arrows: one button that
/// copies the local selection into the shared folder.
class _ShareArrow extends StatelessWidget {
  const _ShareArrow({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ArrowButton(
            icon: Icons.arrow_forward_rounded,
            tooltip: 'Put the selected files in the shared folder',
            enabled: enabled,
            onTap: onTap,
            luma: luma,
          ),
        ],
      ),
    );
  }
}

/// The column between the panes on desktop: the non-drag way to transfer,
/// and the thing that makes the direction obvious at a glance.
class _TransferArrows extends StatelessWidget {
  const _TransferArrows({
    required this.canUpload,
    required this.canDownload,
    required this.onUpload,
    required this.onDownload,
  });

  final bool canUpload;
  final bool canDownload;
  final VoidCallback onUpload;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ArrowButton(
            icon: Icons.arrow_forward_rounded,
            tooltip: 'Upload the selected files',
            enabled: canUpload,
            onTap: onUpload,
            luma: luma,
          ),
          const SizedBox(height: 10),
          _ArrowButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Download the selected files',
            enabled: canDownload,
            onTap: onDownload,
            luma: luma,
          ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
    required this.luma,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: enabled ? luma.accent : luma.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: enabled ? luma.accent : luma.border),
            ),
            child: Icon(
              icon,
              size: 20,
              color: enabled ? luma.onAccent : luma.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// The phone's stand-in for the arrows: one button that moves whatever is
/// selected in the tab you are looking at.
class _MobileTransferBar extends StatelessWidget {
  const _MobileTransferBar({
    required this.uploading,
    required this.count,
    required this.onTransfer,
  });

  final bool uploading;
  final int count;
  final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LumaPrimaryButton(
        label: uploading
            ? 'Upload $count ${count == 1 ? 'item' : 'items'}'
            : 'Download $count ${count == 1 ? 'item' : 'items'}',
        icon: uploading ? Icons.north_rounded : Icons.south_rounded,
        expand: true,
        onTap: onTransfer,
      ),
    );
  }
}

/// What Core and Orbit see instead of the browser.
class _NovaUpsell extends StatelessWidget {
  const _NovaUpsell();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: LumaEmptyState(
        icon: Icons.auto_awesome_rounded,
        title: 'SFTP is a Nova exclusive',
        subtitle:
            'Connect to your own servers with a host, username, password and '
            'port, browse both sides at once, and drag files across. The '
            'connection goes straight from this device to your server — '
            'nothing passes through a luma server.',
        action: LumaPrimaryButton(
          label: 'Upgrade to ${planById('nova').name}',
          icon: Icons.auto_awesome_rounded,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PlanSelectionPage()),
          ),
        ),
      ),
    );
  }
}
