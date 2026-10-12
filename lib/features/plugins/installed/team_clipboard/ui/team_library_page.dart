import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import '../team_clipboard_controller.dart';
import '../team_clipboard_models.dart';
import '../team_library_models.dart';
import '../team_model_mesh.dart';
import 'team_clipboard_style.dart';
import 'team_files.dart';
import 'team_model_view.dart';

/// The Team Clipboard's assets library: the Modrinth mods a lead picked,
/// unpacked on the luma server so the team can browse every texture, model,
/// blockstate, lang and data file without downloading the jar. The server
/// watches Modrinth and unpacks each new version as it drops; this tab polls
/// while it is open, so a reload shows up here by itself.
class TeamLibraryPage extends StatefulWidget {
  const TeamLibraryPage({
    super.key,
    required this.controller,
    this.pollInterval = const Duration(seconds: 6),
  });

  final TeamClipboardController controller;
  final Duration pollInterval;

  @override
  State<TeamLibraryPage> createState() => _TeamLibraryPageState();
}

class _TeamLibraryPageState extends State<TeamLibraryPage> {
  final _library = ValueNotifier<TeamLibraryState?>(null);
  String? _error;
  Timer? _poll;
  bool _polling = false;
  String? _selectedId;

  /// The version each mod was at when last seen, to tell a reload apart
  /// from the first load.
  final Map<String, String> _versions = {};

  TeamLibraryState? get _state => _library.value;

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_load);
    _poll = Timer.periodic(widget.pollInterval, (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _library.dispose();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (_polling) return;
    _polling = true;
    try {
      final since = quiet ? _state?.revision : null;
      final next = await widget.controller.library(
        (api) => api.library(since: since),
      );
      if (!mounted) return;
      _take(next);
      if (_error != null) setState(() => _error = null);
    } catch (e) {
      if (mounted && !quiet) setState(() => _error = '$e');
    } finally {
      _polling = false;
    }
  }

  /// Shows [next], and says so when a mod moved to a new version.
  void _take(TeamLibraryState next) {
    final mods = next.mods;
    if (mods == null) return;
    final reloaded = <TeamLibraryMod>[];
    for (final mod in mods) {
      final version = mod.version?.id;
      if (version == null) continue;
      final before = _versions[mod.id];
      if (before != null && before != version) reloaded.add(mod);
      _versions[mod.id] = version;
    }
    _library.value = next;
    setState(() {
      if (_selectedId != null && !mods.any((m) => m.id == _selectedId)) {
        _selectedId = null;
      }
    });
    if (reloaded.isNotEmpty) {
      final t = L.of(context);
      final messenger = ScaffoldMessenger.of(context);
      for (final mod in reloaded) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              t.teamLibraryReloaded(mod.title, mod.version!.number),
            ),
          ),
        );
      }
    }
  }

  /// Runs a change and shows the library it returns. Returns whether it
  /// went through; a refusal is shown in a snack bar.
  Future<bool> _apply(
    Future<TeamLibraryState> Function(TeamClipboardController c) call,
  ) async {
    try {
      final next = await call(widget.controller);
      if (mounted) _take(next);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
      return false;
    }
  }

  Future<void> _check([String? projectId]) async {
    final t = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _apply(
      (c) => c.library((api) => api.checkLibrary(projectId)),
    );
    if (ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(t.teamLibraryCheckStarted)),
      );
    }
  }

  Future<void> _add() async {
    final state = _state;
    if (state == null) return;
    final next = await showDialog<TeamLibraryState>(
      context: context,
      builder: (context) => _AddModDialog(
        controller: widget.controller,
        inLibrary: {for (final m in state.mods ?? const []) m.id},
      ),
    );
    if (next != null && mounted) {
      _take(next);
      final added = next.mods?.lastOrNull;
      if (added != null) setState(() => _selectedId = added.id);
    }
  }

  Future<void> _editVersions(TeamLibraryMod mod) async {
    final picked = await showDialog<({String? loader, String? gameVersion})>(
      context: context,
      builder: (context) => _VersionsDialog(mod: mod),
    );
    if (picked == null) return;
    await _apply(
      (c) => c.library(
        (api) => api.setLibraryFilters(
          mod.id,
          loader: picked.loader,
          gameVersion: picked.gameVersion,
        ),
      ),
    );
  }

  Future<bool> _remove(TeamLibraryMod mod) async {
    final t = L.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.teamLibraryRemove),
        content: Text(t.teamLibraryRemoveConfirm(mod.title)),
        actions: [
          LumaGhostButton(
            label: t.commonCancel,
            onTap: () => Navigator.of(context).pop(false),
          ),
          LumaPrimaryButton(
            label: t.commonRemove,
            icon: Icons.delete_outline_rounded,
            onTap: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (sure != true) return false;
    return _apply((c) => c.library((api) => api.removeLibraryMod(mod.id)));
  }

  _LibraryActions get _actions => _LibraryActions(
    check: _check,
    editVersions: _editVersions,
    remove: _remove,
  );

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final state = _state;
    if (state == null) {
      if (_error != null) {
        return LumaEmptyState(
          icon: Icons.cloud_off_rounded,
          title: t.teamClipboardErrorTitle,
          subtitle: _error,
          action: LumaPrimaryButton(
            label: t.commonRetry,
            icon: Icons.refresh_rounded,
            onTap: _load,
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    final mods = state.mods ?? const <TeamLibraryMod>[];
    if (mods.isEmpty) {
      return LumaEmptyState(
        icon: Icons.inventory_2_outlined,
        title: t.teamLibraryEmptyTitle,
        subtitle: state.canManage
            ? t.teamLibraryEmptyLead
            : t.teamLibraryEmptyMember,
        action: state.canManage
            ? LumaPrimaryButton(
                label: t.teamLibraryAddMod,
                icon: Icons.add_rounded,
                onTap: _add,
              )
            : null,
      );
    }
    final luma = context.luma;
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 820;
        final list = _ModList(
          mods: mods,
          canManage: state.canManage,
          busy: state.busy,
          selectedId: wide ? _selectedId : null,
          onAdd: _add,
          onCheckAll: () => _check(),
          onOpen: (mod) {
            if (wide) {
              setState(() => _selectedId = mod.id);
            } else {
              _openOnPhone(mod);
            }
          },
        );
        if (!wide) return list;
        final selected = _selectedId;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: box.maxWidth >= 1240 ? 340 : 300, child: list),
            VerticalDivider(width: 1, color: luma.border),
            Expanded(
              child: selected == null
                  ? LumaEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: t.teamClipboardLibrary,
                      subtitle: t.teamLibraryPickMod,
                    )
                  : _ModDetail(
                      key: ValueKey(selected),
                      controller: widget.controller,
                      projectId: selected,
                      library: _library,
                      actions: _actions,
                    ),
            ),
          ],
        );
      },
    );
  }

  void _openOnPhone(TeamLibraryMod mod) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          final luma = context.luma;
          return Scaffold(
            backgroundColor: luma.background,
            appBar: AppBar(
              backgroundColor: luma.background,
              surfaceTintColor: Colors.transparent,
              title: Text(mod.title),
            ),
            body: _ModDetail(
              controller: widget.controller,
              projectId: mod.id,
              library: _library,
              actions: _actions,
              onGone: () => Navigator.of(context).maybePop(),
            ),
          );
        },
      ),
    );
  }
}

/// What a mod's page can ask the library tab to do.
class _LibraryActions {
  const _LibraryActions({
    required this.check,
    required this.editVersions,
    required this.remove,
  });

  final Future<void> Function([String? projectId]) check;
  final Future<void> Function(TeamLibraryMod mod) editVersions;
  final Future<bool> Function(TeamLibraryMod mod) remove;
}

// ---- Mod list ---------------------------------------------------------------

class _ModList extends StatelessWidget {
  const _ModList({
    required this.mods,
    required this.canManage,
    required this.busy,
    required this.selectedId,
    required this.onAdd,
    required this.onCheckAll,
    required this.onOpen,
  });

  final List<TeamLibraryMod> mods;
  final bool canManage;
  final bool busy;
  final String? selectedId;
  final VoidCallback onAdd;
  final VoidCallback onCheckAll;
  final ValueChanged<TeamLibraryMod> onOpen;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              if (canManage)
                FilledButton.icon(
                  key: const ValueKey('team-library-add'),
                  onPressed: onAdd,
                  style: FilledButton.styleFrom(
                    backgroundColor: luma.accent,
                    foregroundColor: luma.onAccent,
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(t.teamLibraryAddMod),
                )
              else
                Text(
                  t.teamLibraryMods.toUpperCase(),
                  style: TextStyle(
                    color: luma.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              const Spacer(),
              IconButton(
                tooltip: t.teamLibraryCheckUpdates,
                onPressed: busy ? null : onCheckAll,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded, size: 20),
                color: luma.textSecondary,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            itemCount: mods.length,
            itemBuilder: (context, i) => _ModTile(
              mod: mods[i],
              selected: mods[i].id == selectedId,
              onTap: () => onOpen(mods[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModTile extends StatelessWidget {
  const _ModTile({
    required this.mod,
    required this.selected,
    required this.onTap,
  });

  final TeamLibraryMod mod;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final version = mod.version;
    final Widget status;
    if (mod.working) {
      status = _StatePill(mod: mod);
    } else if (version == null) {
      status = _StatePill(mod: mod);
    } else {
      status = Text(
        '${version.number} · ${t.teamLibraryFileCount(mod.fileCount)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: luma.textMuted, fontSize: 12),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? luma.accentSubtle : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                _ModIcon(mod: mod, size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mod.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Align(alignment: Alignment.centerLeft, child: status),
                    ],
                  ),
                ),
                if (mod.error != null && !mod.working) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: mod.error!,
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 17,
                      color: luma.warning,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.mod});

  final TeamLibraryMod mod;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    return switch (mod.state) {
      TeamLibraryModState.queued => TeamPill(
        label: t.teamLibraryQueued,
        color: luma.textSecondary,
        icon: Icons.schedule_rounded,
      ),
      TeamLibraryModState.loading => TeamPill(
        label: t.teamLibraryLoading,
        color: luma.accent,
        icon: Icons.downloading_rounded,
      ),
      TeamLibraryModState.failed => TeamPill(
        label: t.teamLibraryFailed,
        color: luma.danger,
        icon: Icons.error_outline_rounded,
      ),
      TeamLibraryModState.ready => TeamPill(
        label: mod.version?.number ?? '',
        color: luma.success,
      ),
    };
  }
}

class _ModIcon extends StatelessWidget {
  const _ModIcon({required this.mod, required this.size});

  final TeamLibraryMod mod;
  final double size;

  @override
  Widget build(BuildContext context) =>
      _ProjectIcon(url: mod.iconUrl, size: size);
}

class _ProjectIcon extends StatelessWidget {
  const _ProjectIcon({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final fallback = Icon(
      Icons.extension_rounded,
      size: size * 0.55,
      color: luma.accent,
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: luma.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? fallback
          : Image.network(
              url!,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

// ---- One mod ----------------------------------------------------------------

/// A mod's page: what version the library holds, and every file in it,
/// with the board's viewer on top for the one picked.
class _ModDetail extends StatefulWidget {
  const _ModDetail({
    super.key,
    required this.controller,
    required this.projectId,
    required this.library,
    required this.actions,
    this.onGone,
  });

  final TeamClipboardController controller;
  final String projectId;
  final ValueListenable<TeamLibraryState?> library;
  final _LibraryActions actions;

  /// Called when the mod leaves the library, so a phone page can close.
  final VoidCallback? onGone;

  @override
  State<_ModDetail> createState() => _ModDetailState();
}

class _ModDetailState extends State<_ModDetail> {
  TeamLibraryIndex? _index;
  String? _indexFor;
  Object? _indexError;
  bool _indexLoading = false;

  TeamAssetCategory? _category = TeamAssetCategory.textures;
  String _query = '';
  String? _namespace;

  /// The file picked in the list, and what the viewer shows for it.
  String? _pickedPath;
  TeamEntry? _view;
  String? _viewSubject;
  String? _resolving;

  List<TeamLibraryAsset>? _filtered;
  String? _filteredFor;

  @override
  void initState() {
    super.initState();
    widget.library.addListener(_onLibrary);
    _follow();
  }

  @override
  void dispose() {
    widget.library.removeListener(_onLibrary);
    super.dispose();
  }

  TeamLibraryMod? get _mod => widget.library.value?.mods
      ?.where((m) => m.id == widget.projectId)
      .firstOrNull;

  bool get _canManage => widget.library.value?.canManage ?? false;

  void _onLibrary() {
    if (_follow() && mounted) setState(() {});
  }

  /// Loads the file list again when the library moved the mod to a new
  /// version. Returns false once the mod has left the library.
  bool _follow() {
    final mod = _mod;
    if (mod == null) {
      if (widget.library.value?.mods != null) widget.onGone?.call();
      return false;
    }
    final version = mod.version?.id;
    if (mod.hasAssets && version != _indexFor && !_indexLoading) {
      unawaited(_loadIndex(mod));
    }
    return true;
  }

  Future<void> _loadIndex(TeamLibraryMod mod) async {
    _indexLoading = true;
    try {
      final index = await widget.controller.library(
        (api) => api.libraryFiles(mod.id, loadedAt: mod.loadedAt),
      );
      if (!mounted) return;
      final picked = _pickedPath;
      setState(() {
        _index = index;
        _indexFor = mod.version?.id;
        _indexError = null;
        _filtered = null;
        if (_namespace != null && !mod.namespaces.contains(_namespace)) {
          _namespace = null;
        }
        _view = null;
        _viewSubject = null;
        _pickedPath = null;
      });
      final again = picked == null ? null : index[picked];
      if (again != null) unawaited(_open(again));
    } catch (e) {
      if (mounted) setState(() => _indexError = e);
    } finally {
      _indexLoading = false;
    }
    final now = _mod;
    if (mounted && now != null && now.version?.id != _indexFor) {
      _onLibrary();
    }
  }

  List<TeamLibraryAsset> _visible(
    TeamLibraryIndex index,
    TeamAssetCategory? category,
  ) {
    final key =
        '${index.versionId}|${category?.name}|$_namespace|${_query.toLowerCase()}';
    if (_filteredFor == key && _filtered != null) return _filtered!;
    final q = _query.trim().toLowerCase();
    _filtered = [
      for (final a in index.assets)
        if ((category == null || a.category == category) &&
            (_namespace == null || a.namespace == _namespace) &&
            (q.isEmpty || a.path.toLowerCase().contains(q)))
          a,
    ];
    _filteredFor = key;
    return _filtered!;
  }

  Map<TeamAssetCategory, int> _counts(TeamLibraryIndex index) {
    final counts = <TeamAssetCategory, int>{};
    for (final a in index.assets) {
      if (_namespace != null && a.namespace != _namespace) continue;
      counts[a.category] = (counts[a.category] ?? 0) + 1;
    }
    return counts;
  }

  Future<Map<String, dynamic>?> _json(TeamLibraryAsset asset) async {
    final bytes = await widget.controller.file(asset.fileId);
    if (bytes == null) return null;
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  TeamEntry _entryOf(List<TeamLibraryAsset> assets) {
    final mod = _mod;
    final seen = <String>{};
    return TeamEntry(
      id: '$kTeamLibraryFilePrefix${widget.projectId}',
      kind: TeamEntryKind.model,
      title: mod?.title ?? '',
      brief: '',
      stage: TeamEntryStage.idea,
      closed: false,
      author: '',
      mine: false,
      claimedBy: null,
      claimedByMe: false,
      createdAt: mod?.loadedAt ?? DateTime.now(),
      updatedAtMs: 0,
      messageCount: 0,
      lastMessage: null,
      files: [
        for (final a in assets)
          if (seen.add(a.fileId)) a.toTeamFile(),
      ],
      canEdit: false,
      canClose: false,
      canDelete: false,
    );
  }

  /// Shows [asset]: a texture in the viewer with its animation, a model or
  /// blockstate in 3D with the textures and parents it uses from this mod,
  /// and anything else as text.
  Future<void> _open(TeamLibraryAsset asset) async {
    final index = _index;
    if (index == null) return;
    if (asset.isImage) {
      final meta = index['${asset.path}.mcmeta'];
      setState(() {
        _pickedPath = asset.path;
        _view = _entryOf([asset, ?meta]);
        _viewSubject = asset.fileId;
      });
      return;
    }
    final modelish =
        asset.isJson &&
        asset.category != TeamAssetCategory.lang &&
        asset.category != TeamAssetCategory.data;
    if (!modelish) return _preview(asset);

    setState(() => _resolving = asset.path);
    try {
      var subject = asset;
      var model = await _json(asset);
      if (model != null && !teamLooksLikeModel(model)) {
        final ref = teamFirstModelRef(model);
        final target = ref == null ? null : index.model(ref);
        if (target == null) return _preview(asset);
        subject = target;
        model = await _json(target);
      }
      if (model == null || !teamLooksLikeModel(model)) return _preview(asset);
      final files = <TeamLibraryAsset>[subject];
      Map<String, dynamic>? current = model;
      for (var depth = 0; current != null && depth < 16; depth++) {
        final textures = current['textures'];
        if (textures is Map) {
          for (final ref in textures.values) {
            if (ref is! String || ref.startsWith('#')) continue;
            final texture = index.texture(ref);
            if (texture != null && !files.contains(texture)) {
              files.add(texture);
            }
          }
        }
        final parentRef = current['parent'];
        final parent = parentRef is String ? index.model(parentRef) : null;
        if (parent == null || files.contains(parent)) break;
        files.add(parent);
        current = await _json(parent);
      }
      if (!mounted || _index != index) return;
      setState(() {
        _pickedPath = asset.path;
        _view = _entryOf(files);
        _viewSubject = subject.fileId;
      });
    } finally {
      if (mounted) setState(() => _resolving = null);
    }
  }

  void _preview(TeamLibraryAsset asset) {
    if (!mounted) return;
    showTeamFilePreview(context, _entryOf([asset]), asset.toTeamFile());
  }

  Future<void> _save(TeamLibraryAsset asset) async {
    final messenger = ScaffoldMessenger.of(context);
    final t = L.of(context);
    try {
      final path = await saveTeamFile(widget.controller, asset.toTeamFile());
      if (path != null) {
        messenger.showSnackBar(
          SnackBar(content: Text(t.teamClipboardSavedTo(path))),
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final mod = _mod;
    if (mod == null) return const SizedBox.shrink();
    final index = _index;
    final Widget body;
    if (!mod.hasAssets) {
      body = mod.working
          ? LumaEmptyState(
              icon: Icons.downloading_rounded,
              title: t.teamLibraryUnpackingTitle(mod.title),
              subtitle: t.teamLibraryUnpackingBody,
              action: const SizedBox(
                width: 160,
                child: LinearProgressIndicator(),
              ),
            )
          : LumaEmptyState(
              icon: Icons.error_outline_rounded,
              title: t.teamLibraryFailedTitle,
              subtitle: mod.error,
              action: LumaPrimaryButton(
                label: t.commonRetry,
                icon: Icons.refresh_rounded,
                onTap: () => widget.actions.check(mod.id),
              ),
            );
    } else if (index == null) {
      body = _indexError != null
          ? LumaEmptyState(
              icon: Icons.cloud_off_rounded,
              title: t.teamClipboardErrorTitle,
              subtitle: '$_indexError',
              action: LumaPrimaryButton(
                label: t.commonRetry,
                icon: Icons.refresh_rounded,
                onTap: () => _loadIndex(mod),
              ),
            )
          : const Center(child: CircularProgressIndicator());
    } else {
      body = _browser(context, mod, index);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ModHeader(mod: mod, canManage: _canManage, actions: widget.actions),
        Expanded(child: body),
      ],
    );
  }

  Widget _browser(
    BuildContext context,
    TeamLibraryMod mod,
    TeamLibraryIndex index,
  ) {
    final t = L.of(context);
    final luma = context.luma;
    final counts = _counts(index);
    // A mod without textures (or a namespace without the picked kind)
    // opens on everything rather than on an empty, hidden filter.
    final category = (counts[_category] ?? 0) > 0 ? _category : null;
    final shown = _visible(index, category);
    final view = _view;
    final picked = _pickedPath == null ? null : index[_pickedPath!];
    return LayoutBuilder(
      builder: (context, box) {
        final viewerHeight = (box.maxHeight * 0.42).clamp(220.0, 380.0);
        final showViewer = view != null && box.maxHeight >= 420;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showViewer)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SizedBox(
                  height: viewerHeight,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: TeamFileViewer(
                          key: ValueKey(view.files),
                          entry: view,
                          subjectId: _viewSubject,
                          onSubject: (id) => setState(() => _viewSubject = id),
                        ),
                      ),
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: Row(
                          children: [
                            if (picked != null)
                              _ViewerButton(
                                icon: Icons.download_rounded,
                                tooltip: t.commonDownload,
                                onTap: () => _save(picked),
                              ),
                            _ViewerButton(
                              icon: Icons.close_rounded,
                              tooltip: t.commonClose,
                              onTap: () => setState(() {
                                _view = null;
                                _pickedPath = null;
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _SearchBox(
                      hint: t.teamLibrarySearchFiles,
                      onChanged: (q) => setState(() => _query = q),
                    ),
                  ),
                  if (mod.namespaces.length > 1) ...[
                    const SizedBox(width: 10),
                    _NamespaceMenu(
                      namespaces: mod.namespaces,
                      value: _namespace,
                      onChanged: (ns) => setState(() => _namespace = ns),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                children: [
                  for (final chip in [null, ...TeamAssetCategory.values])
                    if (chip == null || (counts[chip] ?? 0) > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _CategoryChip(
                          label: _categoryLabel(t, chip),
                          icon: _categoryIcon(chip),
                          count: chip == null
                              ? counts.values.fold(0, (a, b) => a + b)
                              : counts[chip]!,
                          selected: category == chip,
                          onTap: () => setState(() => _category = chip),
                        ),
                      ),
                ],
              ),
            ),
            if (mod.skipped > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(
                  t.teamLibrarySkipped(mod.skipped),
                  style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                ),
              ),
            Expanded(
              child: shown.isEmpty
                  ? LumaEmptyState(
                      icon: Icons.search_off_rounded,
                      title: t.commonNoResults,
                    )
                  : category == TeamAssetCategory.textures
                  ? _textureGrid(shown)
                  : _fileList(shown),
            ),
          ],
        );
      },
    );
  }

  Widget _textureGrid(List<TeamLibraryAsset> shown) => GridView.builder(
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 104,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.82,
    ),
    itemCount: shown.length,
    itemBuilder: (context, i) {
      final asset = shown[i];
      return _TextureTile(
        key: ValueKey(asset.path),
        controller: widget.controller,
        asset: asset,
        selected: asset.path == _pickedPath,
        onTap: () => _open(asset),
      );
    },
  );

  Widget _fileList(List<TeamLibraryAsset> shown) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
    itemCount: shown.length,
    itemExtent: 52,
    itemBuilder: (context, i) {
      final asset = shown[i];
      return _FileRow(
        key: ValueKey(asset.path),
        controller: widget.controller,
        asset: asset,
        selected: asset.path == _pickedPath,
        resolving: asset.path == _resolving,
        onTap: () => _open(asset),
        onSave: () => _save(asset),
      );
    },
  );
}

String _categoryLabel(L t, TeamAssetCategory? category) => switch (category) {
  null => t.commonAll,
  TeamAssetCategory.textures => t.teamLibraryTextures,
  TeamAssetCategory.models => t.teamLibraryModels,
  TeamAssetCategory.blockstates => t.teamLibraryBlockstates,
  TeamAssetCategory.lang => t.teamLibraryLang,
  TeamAssetCategory.data => t.teamLibraryData,
  TeamAssetCategory.other => t.commonOther,
};

IconData? _categoryIcon(TeamAssetCategory? category) => switch (category) {
  null => null,
  TeamAssetCategory.textures => Icons.image_outlined,
  TeamAssetCategory.models => Icons.view_in_ar_rounded,
  TeamAssetCategory.blockstates => Icons.grid_view_rounded,
  TeamAssetCategory.lang => Icons.translate_rounded,
  TeamAssetCategory.data => Icons.dataset_outlined,
  TeamAssetCategory.other => Icons.description_outlined,
};

class _ModHeader extends StatelessWidget {
  const _ModHeader({
    required this.mod,
    required this.canManage,
    required this.actions,
  });

  final TeamLibraryMod mod;
  final bool canManage;
  final _LibraryActions actions;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final version = mod.version;
    final facts = [
      if (mod.loadedAt case final at?)
        t.teamLibraryUnpackedAgo(teamRelativeTime(context, at)),
      if (mod.checkedAt case final at?)
        t.teamLibraryCheckedAgo(teamRelativeTime(context, at)),
      if (mod.hasAssets) t.teamLibraryFileCount(mod.fileCount),
      if (mod.hasAssets) teamFileSize(mod.bytes),
      if (mod.addedBy.isNotEmpty) t.teamLibraryAddedBy(mod.addedBy),
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: luma.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ModIcon(mod: mod, size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mod.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (mod.working || version == null)
                          _StatePill(mod: mod)
                        else
                          TeamPill(
                            label: version.number,
                            color: luma.success,
                            icon: Icons.inventory_2_outlined,
                          ),
                        TeamPill(
                          label: mod.loader ?? t.teamLibraryAnyLoader,
                          color: luma.textSecondary,
                          icon: Icons.memory_rounded,
                        ),
                        TeamPill(
                          label: mod.gameVersion ?? t.teamLibraryAnyVersion,
                          color: luma.textSecondary,
                          icon: Icons.sports_esports_outlined,
                        ),
                        if (mod.projectType == 'resourcepack')
                          TeamPill(
                            label: t.teamLibraryResourcePack,
                            color: luma.accent,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: t.teamLibraryCheckUpdates,
                onPressed: mod.working ? null : () => actions.check(mod.id),
                icon: mod.working
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded, size: 20),
                color: luma.textSecondary,
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: luma.textSecondary),
                onSelected: (action) => switch (action) {
                  'modrinth' => launchUrl(
                    Uri.parse(mod.url),
                    mode: LaunchMode.externalApplication,
                  ),
                  'history' => showDialog<void>(
                    context: context,
                    builder: (context) => _HistoryDialog(mod: mod),
                  ),
                  'versions' => actions.editVersions(mod),
                  _ => actions.remove(mod),
                },
                itemBuilder: (context) => [
                  _menuItem(
                    'modrinth',
                    Icons.open_in_new_rounded,
                    t.teamLibraryOpenModrinth,
                  ),
                  if (mod.history.isNotEmpty)
                    _menuItem(
                      'history',
                      Icons.history_rounded,
                      t.teamLibraryEarlierVersions,
                    ),
                  if (canManage) ...[
                    _menuItem(
                      'versions',
                      Icons.tune_rounded,
                      t.teamLibraryChangeVersions,
                    ),
                    _menuItem(
                      'remove',
                      Icons.delete_outline_rounded,
                      t.teamLibraryRemove,
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (facts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              facts.join(' · '),
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            ),
          ],
          if (mod.error != null && mod.hasAssets) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: luma.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: luma.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: luma.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mod.error!,
                      style: TextStyle(color: luma.textPrimary, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) =>
      PopupMenuItem(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 10),
            Text(label),
          ],
        ),
      );
}

class _HistoryDialog extends StatelessWidget {
  const _HistoryDialog({required this.mod});

  final TeamLibraryMod mod;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    return AlertDialog(
      title: Text(t.teamLibraryEarlierVersions),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final h in mod.history)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.history_rounded, color: luma.textMuted),
                title: Text(h.number),
                subtitle: Text(
                  t.teamLibraryUnpackedAgo(
                    teamRelativeTime(context, h.loadedAt),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        LumaGhostButton(
          label: t.commonClose,
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _ViewerButton extends StatelessWidget {
  const _ViewerButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Material(
        color: luma.surface.withValues(alpha: 0.9),
        shape: CircleBorder(side: BorderSide(color: luma.border)),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, size: 17, color: luma.textSecondary),
        ),
      ),
    );
  }
}

class _TextureTile extends StatefulWidget {
  const _TextureTile({
    super.key,
    required this.controller,
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  final TeamClipboardController controller;
  final TeamLibraryAsset asset;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TextureTile> createState() => _TextureTileState();
}

class _TextureTileState extends State<_TextureTile> {
  late Future<Uint8List?> _bytes = widget.controller.file(widget.asset.fileId);

  @override
  void didUpdateWidget(_TextureTile old) {
    super.didUpdateWidget(old);
    if (old.asset.fileId != widget.asset.fileId) {
      _bytes = widget.controller.file(widget.asset.fileId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final asset = widget.asset;
    return Tooltip(
      message: asset.path,
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: widget.selected ? luma.accentSubtle : luma.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.selected ? luma.accent : luma.border,
              width: widget.selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: FutureBuilder<Uint8List?>(
                    future: _bytes,
                    builder: (context, snap) {
                      final bytes =
                          snap.data ??
                          widget.controller.cachedFile(asset.fileId);
                      if (bytes != null) {
                        return TeamTexture(bytes: bytes, cell: 4);
                      }
                      return Center(
                        child: snap.connectionState == ConnectionState.done
                            ? Icon(
                                Icons.broken_image_rounded,
                                color: luma.textMuted,
                              )
                            : const SizedBox.square(
                                dimension: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                asset.name.replaceFirst(RegExp(r'\.png$'), ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: luma.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    super.key,
    required this.controller,
    required this.asset,
    required this.selected,
    required this.resolving,
    required this.onTap,
    required this.onSave,
  });

  final TeamClipboardController controller;
  final TeamLibraryAsset asset;
  final bool selected;
  final bool resolving;
  final VoidCallback onTap;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    return Material(
      color: selected ? luma.accentSubtle : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 32,
                child: asset.isImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: _TextureTileThumb(
                          controller: controller,
                          asset: asset,
                        ),
                      )
                    : Icon(
                        _categoryIcon(asset.category) ??
                            Icons.description_outlined,
                        size: 20,
                        color: luma.textSecondary,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${asset.namespace}:${asset.folder}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              if (resolving)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              Text(
                teamFileSize(asset.size),
                style: TextStyle(color: luma.textMuted, fontSize: 11.5),
              ),
              IconButton(
                tooltip: t.commonDownload,
                onPressed: onSave,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.download_rounded,
                  size: 18,
                  color: luma.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextureTileThumb extends StatefulWidget {
  const _TextureTileThumb({required this.controller, required this.asset});

  final TeamClipboardController controller;
  final TeamLibraryAsset asset;

  @override
  State<_TextureTileThumb> createState() => _TextureTileThumbState();
}

class _TextureTileThumbState extends State<_TextureTileThumb> {
  late final Future<Uint8List?> _bytes = widget.controller.file(
    widget.asset.fileId,
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: _bytes,
    builder: (context, snap) {
      final bytes =
          snap.data ?? widget.controller.cachedFile(widget.asset.fileId);
      return bytes == null
          ? const SizedBox.shrink()
          : TeamTexture(bytes: bytes, cell: 3);
    },
  );
}

class _SearchBox extends StatefulWidget {
  const _SearchBox({required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    return TextField(
      controller: _text,
      onChanged: (q) {
        setState(() {});
        widget.onChanged(q);
      },
      decoration: InputDecoration(
        hintText: widget.hint,
        isDense: true,
        prefixIcon: Icon(Icons.search_rounded, color: luma.textMuted, size: 20),
        suffixIcon: _text.text.isEmpty
            ? null
            : IconButton(
                tooltip: t.commonClear,
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _text.clear();
                  setState(() {});
                  widget.onChanged('');
                },
              ),
      ),
    );
  }
}

class _NamespaceMenu extends StatelessWidget {
  const _NamespaceMenu({
    required this.namespaces,
    required this.value,
    required this.onChanged,
  });

  final List<String> namespaces;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    return PopupMenuButton<String>(
      tooltip: '',
      onSelected: (ns) => onChanged(ns.isEmpty ? null : ns),
      itemBuilder: (context) => [
        PopupMenuItem(value: '', child: Text(t.teamLibraryAllNamespaces)),
        for (final ns in namespaces) PopupMenuItem(value: ns, child: Text(ns)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: luma.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_outlined, size: 16, color: luma.textSecondary),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                value ?? t.teamLibraryAllNamespaces,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: luma.textPrimary, fontSize: 13),
              ),
            ),
            Icon(Icons.expand_more_rounded, size: 18, color: luma.textMuted),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? luma.accentSubtle : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? luma.accent : luma.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: selected ? luma.accent : luma.textSecondary,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? luma.textPrimary : luma.textSecondary,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$count',
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Lead dialogs -----------------------------------------------------------

/// Search Modrinth, pick a mod, say which loader and game version to follow.
/// Pops with the library the server answers once it is added.
class _AddModDialog extends StatefulWidget {
  const _AddModDialog({required this.controller, required this.inLibrary});

  final TeamClipboardController controller;
  final Set<String> inLibrary;

  @override
  State<_AddModDialog> createState() => _AddModDialogState();
}

class _AddModDialogState extends State<_AddModDialog> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<TeamLibraryHit>? _hits;
  String? _error;
  bool _searching = false;
  int _searchId = 0;

  TeamLibraryHit? _picked;
  String? _loader;
  String? _gameVersion;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_search);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final id = ++_searchId;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final hits = await widget.controller.library(
        (api) => api.searchLibrary(_query.text.trim()),
      );
      if (mounted && id == _searchId) setState(() => _hits = hits);
    } catch (e) {
      if (mounted && id == _searchId) setState(() => _error = '$e');
    } finally {
      if (mounted && id == _searchId) setState(() => _searching = false);
    }
  }

  Future<void> _add() async {
    final hit = _picked;
    if (hit == null) return;
    setState(() {
      _adding = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    try {
      final state = await widget.controller.library(
        (api) => api.addLibraryMod(
          hit.id,
          loader: _loader,
          gameVersion: _gameVersion,
        ),
      );
      navigator.pop(state);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final picked = _picked;
    return AlertDialog(
      title: Text(t.teamLibraryAddTitle),
      content: SizedBox(
        width: 520,
        height: 460,
        child: picked == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t.teamLibraryAddHint,
                    style: TextStyle(color: luma.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('team-library-search'),
                    controller: _query,
                    autofocus: true,
                    onChanged: (_) {
                      _debounce?.cancel();
                      _debounce = Timer(
                        const Duration(milliseconds: 350),
                        _search,
                      );
                    },
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: t.teamLibrarySearchModrinth,
                      isDense: true,
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: luma.textMuted,
                        size: 20,
                      ),
                      suffixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox.square(
                                dimension: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error!,
                        style: TextStyle(color: luma.danger, fontSize: 12.5),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _hits == null
                        ? const SizedBox.shrink()
                        : _hits!.isEmpty
                        ? Center(
                            child: Text(
                              t.commonNoResults,
                              style: TextStyle(color: luma.textMuted),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _hits!.length,
                            itemBuilder: (context, i) {
                              final hit = _hits![i];
                              final already = widget.inLibrary.contains(hit.id);
                              return _HitTile(
                                hit: hit,
                                already: already,
                                onTap: already
                                    ? null
                                    : () => setState(() {
                                        _picked = hit;
                                        _loader = null;
                                        _gameVersion = null;
                                        _error = null;
                                      }),
                              );
                            },
                          ),
                  ),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HitTile(hit: picked, already: false, onTap: null),
                    const SizedBox(height: 16),
                    Text(
                      t.teamLibraryChangeVersionsBody,
                      style: TextStyle(color: luma.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    _FilterDropdown(
                      label: t.teamLibraryLoader,
                      anyLabel: t.teamLibraryAnyLoader,
                      options: picked.loaders,
                      value: _loader,
                      onChanged: (v) => setState(() => _loader = v),
                    ),
                    const SizedBox(height: 12),
                    _FilterDropdown(
                      label: t.teamLibraryGameVersion,
                      anyLabel: t.teamLibraryAnyVersion,
                      options: picked.gameVersions,
                      value: _gameVersion,
                      onChanged: (v) => setState(() => _gameVersion = v),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _error!,
                          style: TextStyle(color: luma.danger, fontSize: 12.5),
                        ),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        if (picked != null)
          LumaGhostButton(
            label: t.commonBack,
            onTap: _adding ? null : () => setState(() => _picked = null),
          )
        else
          LumaGhostButton(
            label: t.commonCancel,
            onTap: () => Navigator.of(context).pop(),
          ),
        if (picked != null)
          LumaPrimaryButton(
            label: t.commonAdd,
            icon: Icons.add_rounded,
            loading: _adding,
            onTap: _adding ? null : _add,
          ),
      ],
    );
  }
}

class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit, required this.already, this.onTap});

  final TeamLibraryHit hit;
  final bool already;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final meta = [
      if (hit.author.isNotEmpty) hit.author,
      t.teamLibraryDownloads(_compact(hit.downloads)),
      if (hit.projectType == 'resourcepack') t.teamLibraryResourcePack,
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Opacity(
        opacity: already ? 0.55 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProjectIcon(url: hit.iconUrl, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hit.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hit.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: luma.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              if (already)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: luma.success,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _compact(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K';
  return '$n';
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.anyLabel,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String anyLabel;
  final List<String> options;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final all = [
      ...options,
      if (value != null && !options.contains(value)) value!,
    ];
    return DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: [
        DropdownMenuItem<String?>(value: null, child: Text(anyLabel)),
        for (final o in all)
          DropdownMenuItem<String?>(value: o, child: Text(o)),
      ],
      onChanged: onChanged,
    );
  }
}

class _VersionsDialog extends StatefulWidget {
  const _VersionsDialog({required this.mod});

  final TeamLibraryMod mod;

  @override
  State<_VersionsDialog> createState() => _VersionsDialogState();
}

class _VersionsDialogState extends State<_VersionsDialog> {
  late String? _loader = widget.mod.loader;
  late String? _gameVersion = widget.mod.gameVersion;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    return AlertDialog(
      title: Text(t.teamLibraryChangeVersions),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.teamLibraryChangeVersionsBody,
              style: TextStyle(color: luma.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            _FilterDropdown(
              label: t.teamLibraryLoader,
              anyLabel: t.teamLibraryAnyLoader,
              options: widget.mod.loaders,
              value: _loader,
              onChanged: (v) => setState(() => _loader = v),
            ),
            const SizedBox(height: 12),
            _FilterDropdown(
              label: t.teamLibraryGameVersion,
              anyLabel: t.teamLibraryAnyVersion,
              options: widget.mod.gameVersions,
              value: _gameVersion,
              onChanged: (v) => setState(() => _gameVersion = v),
            ),
          ],
        ),
      ),
      actions: [
        LumaGhostButton(
          label: t.commonCancel,
          onTap: () => Navigator.of(context).pop(),
        ),
        LumaPrimaryButton(
          label: t.commonSave,
          icon: Icons.check_rounded,
          onTap: () => Navigator.of(
            context,
          ).pop((loader: _loader, gameVersion: _gameVersion)),
        ),
      ],
    );
  }
}
