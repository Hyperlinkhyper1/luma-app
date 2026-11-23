import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/luma_theme.dart';
import 'model_preview.dart';
import 'model_preview_server.dart';
import 'model_thumbnail_batch.dart';
import 'model_viewer_repository.dart';
import 'model_viewer_scope.dart';
import 'model_viewer_sign_in.dart';

class ModelViewerPage extends StatefulWidget {
  const ModelViewerPage({super.key});

  @override
  State<ModelViewerPage> createState() => _ModelViewerPageState();
}

class _ModelViewerPageState extends State<ModelViewerPage>
    with WidgetsBindingObserver {
  static const _pageSize = 8;
  static const _thumbnailCacheSize = 64;

  final _repoInput = TextEditingController();
  final _refInput = TextEditingController();
  final _search = TextEditingController();
  final _thumbnails = <String, Uint8List?>{};
  ModelCatalogue? _catalogue;
  RepositoryModel? _selected;
  int _page = 0;
  bool _appVisible = true;
  bool _restored = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final visible =
        state != AppLifecycleState.hidden &&
        state != AppLifecycleState.paused &&
        state != AppLifecycleState.detached;
    if (visible != _appVisible) setState(() => _appVisible = visible);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restored) return;
    ModelViewerScope.of(context).restoreConnection().then((_) {
      if (mounted) setState(() => _restored = true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clearThumbnails();
    _repoInput.dispose();
    _refInput.dispose();
    _search.dispose();
    super.dispose();
  }

  void _evictThumbnail(Uint8List? bytes) {
    if (bytes != null) {
      PaintingBinding.instance.imageCache.evict(MemoryImage(bytes));
    }
  }

  void _clearThumbnails() {
    for (final bytes in _thumbnails.values) {
      _evictThumbnail(bytes);
    }
    _thumbnails.clear();
  }

  Future<void> _scan() async {
    if (_busy) return;
    final repository = ModelViewerScope.of(context);
    final t = L.of(context);
    setState(() {
      _busy = true;
      _error = null;
      _catalogue = null;
      _selected = null;
      _page = 0;
      _clearThumbnails();
      _search.clear();
    });
    try {
      final catalogue = await repository.scan(
        _repoInput.text,
        ref: _refInput.text,
      );
      if (mounted) setState(() => _catalogue = catalogue);
    } on ModelViewerException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = t.modelViewerScanFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() async {
    final repository = ModelViewerScope.of(context);
    final connected = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ModelViewerSignIn(repository: repository),
    );
    if (!mounted || connected != true) return;
    if (_repoInput.text.trim().isNotEmpty) {
      await _scan();
    } else {
      setState(() => _error = null);
    }
  }

  Future<void> _disconnect() async {
    final repository = ModelViewerScope.of(context);
    final t = L.of(context);
    setState(() {
      _busy = true;
      _catalogue = null;
      _clearThumbnails();
      _error = null;
    });
    try {
      await repository.disconnect();
    } catch (_) {
      if (mounted) setState(() => _error = t.modelViewerSignOutFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final repository = ModelViewerScope.of(context);
    final catalogue = _catalogue;
    final query = _search.text.trim().toLowerCase();
    final allModels = catalogue?.models ?? const <RepositoryModel>[];
    final models = query.isEmpty
        ? allModels
        : allModels
              .where((model) => model.path.toLowerCase().contains(query))
              .toList();
    final selected = _selected;
    if (catalogue != null && selected != null) {
      return _modelDetail(t, catalogue, selected, models);
    }
    return Scaffold(
      backgroundColor: context.luma.background,
      appBar: AppBar(
        title: Text(t.pluginNameModelViewer),
        actions: [
          if (repository.githubLogin case final login?)
            PopupMenuButton<String>(
              enabled: _restored && !_busy,
              tooltip: t.modelViewerConnectGithub,
              icon: const Icon(Icons.account_circle_outlined),
              onSelected: (choice) =>
                  choice == 'switch' ? _connect() : _disconnect(),
              itemBuilder: (_) => [
                PopupMenuItem(enabled: false, child: Text('@$login')),
                PopupMenuItem(
                  value: 'switch',
                  child: Text(t.modelViewerChangeGithub),
                ),
                PopupMenuItem(
                  value: 'disconnect',
                  child: Text(t.modelViewerSignOut),
                ),
              ],
            )
          else
            TextButton.icon(
              onPressed: _restored && !_busy ? _connect : null,
              icon: const Icon(Icons.account_circle_outlined, size: 18),
              label: Text(t.modelViewerConnectGithub),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: _repositoryForm(t),
          ),
          Expanded(
            child: _busy
                ? const Center(child: CircularProgressIndicator())
                : _catalogueBody(t, catalogue, models, query),
          ),
        ],
      ),
    );
  }

  Widget _repositoryForm(L t) {
    final url = TextField(
      controller: _repoInput,
      enabled: !_busy,
      onSubmitted: (_) => _scan(),
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.go,
      decoration: InputDecoration(
        labelText: t.modelViewerGithubRepository,
        hintText: 'https://github.com/owner/repository',
        prefixIcon: const Icon(Icons.link_rounded),
        border: const OutlineInputBorder(),
      ),
    );
    final ref = TextField(
      controller: _refInput,
      enabled: !_busy,
      onSubmitted: (_) => _scan(),
      textInputAction: TextInputAction.go,
      decoration: InputDecoration(
        labelText: t.modelViewerRef,
        hintText: t.modelViewerDefaultBranch,
        border: const OutlineInputBorder(),
      ),
    );
    final open = FilledButton(
      onPressed: _busy ? null : _scan,
      child: Text(t.modelViewerLoadRepository),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 620) {
          return Row(
            children: [
              Expanded(flex: 2, child: url),
              const SizedBox(width: 12),
              Expanded(child: ref),
              const SizedBox(width: 12),
              open,
            ],
          );
        }
        return Column(
          children: [
            url,
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: ref),
                const SizedBox(width: 8),
                open,
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _catalogueBody(
    L t,
    ModelCatalogue? catalogue,
    List<RepositoryModel> models,
    String query,
  ) {
    if (_error case final error?) {
      return LumaEmptyState(
        icon: Icons.error_outline_rounded,
        title: t.modelViewerScanFailed,
        subtitle: error == t.modelViewerScanFailed ? null : error,
        action: OutlinedButton(onPressed: _scan, child: Text(t.commonRetry)),
      );
    }
    if (catalogue == null) {
      return LumaEmptyState(
        icon: Icons.view_in_ar_rounded,
        title: t.modelViewerEmptyTitle,
        subtitle: t.modelViewerEmptyDescription,
      );
    }
    final start = _page * _pageSize;
    final pageModels = models.skip(start).take(_pageSize).toList();
    final end = start + pageModels.length;
    final thumbnailsVisible =
        ModelThumbnailBatch.supported &&
        _appVisible &&
        TickerMode.valuesOf(context).enabled;
    final pending = thumbnailsVisible
        ? pageModels.where((model) {
            return !_thumbnails.containsKey(model.path) &&
                catalogue.sizeOf(model.path)! <=
                    ModelPreviewServer.thumbnailFileBudget;
          }).toList()
        : const <RepositoryModel>[];
    return Column(
      children: [
        ListTile(
          dense: true,
          title: Text(
            catalogue.slug,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${catalogue.ref} · ${t.modelViewerModelCount(catalogue.models.length)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            tooltip: t.commonRefresh,
            onPressed: _scan,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
        if (catalogue.models.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() => _page = 0),
              decoration: InputDecoration(
                hintText: t.modelViewerSearch,
                prefixIcon: const Icon(Icons.search_rounded),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        Expanded(
          child: models.isEmpty
              ? LumaEmptyState(
                  icon: Icons.search_off_rounded,
                  title: catalogue.models.isEmpty
                      ? t.modelViewerNoModels
                      : t.modelViewerNoMatches,
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1380),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final columns = switch (width) {
                          >= 1100 => 4,
                          >= 760 => 3,
                          >= 330 => 2,
                          _ => 1,
                        };
                        return GridView.builder(
                          key: PageStorageKey((
                            catalogue.slug,
                            catalogue.ref,
                            query,
                            _page,
                          )),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisExtent:
                                    (columns <= 2 ? 156 : 188) +
                                    MediaQuery.textScalerOf(context).scale(30),
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                              ),
                          itemCount: pageModels.length,
                          itemBuilder: (context, index) =>
                              _modelCard(pageModels[index]),
                        );
                      },
                    ),
                  ),
                ),
        ),
        if (models.length > _pageSize)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: t.commonPrevious,
                onPressed: _page == 0 ? null : () => setState(() => _page--),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Flexible(
                child: Text(
                  MaterialLocalizations.of(
                    context,
                  ).pageRowsInfoTitle(start + 1, end, models.length, false),
                ),
              ),
              IconButton(
                tooltip: t.commonNext,
                onPressed: end == models.length
                    ? null
                    : () => setState(() => _page++),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        if (pending.isNotEmpty)
          ModelThumbnailBatch(
            key: ValueKey((catalogue, query, _page)),
            catalogue: catalogue,
            models: pending,
            onThumbnail: (model, image) {
              if (!mounted || _catalogue != catalogue) return;
              setState(() {
                _thumbnails[model.path] = image;
                if (_thumbnails.length > _thumbnailCacheSize) {
                  _evictThumbnail(_thumbnails.remove(_thumbnails.keys.first));
                }
              });
            },
          ),
      ],
    );
  }

  Widget _modelCard(RepositoryModel model) {
    final image = _thumbnails[model.path];
    final placeholder = Center(
      child: Icon(
        Icons.view_in_ar_outlined,
        color: context.luma.accent,
        size: 32,
      ),
    );
    final folderEnd = model.path.lastIndexOf('/');
    final subtitle = folderEnd == -1
        ? model.format.name.toUpperCase()
        : model.path.substring(0, folderEnd);
    return LumaCard(
      padding: const EdgeInsets.all(1),
      child: Material(
        type: MaterialType.transparency,
        shape: context.lumaDecor.cardShape(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _selected = model),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Ink(
                  color: Color.lerp(
                    context.luma.background,
                    context.luma.surface,
                    0.35,
                  ),
                  child: image == null
                      ? placeholder
                      : Image.memory(
                          image,
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                          errorBuilder: (_, _, _) => placeholder,
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Tooltip(
                  message: model.path,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modelDetail(
    L t,
    ModelCatalogue catalogue,
    RepositoryModel model,
    List<RepositoryModel> models,
  ) {
    final position = models.indexOf(model);
    return Scaffold(
      backgroundColor: context.luma.background,
      appBar: AppBar(
        leading: BackButton(onPressed: () => setState(() => _selected = null)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(model.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              model.path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: t.modelViewerPrevious,
            onPressed: position > 0
                ? () => setState(() => _selected = models[position - 1])
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            tooltip: t.modelViewerNext,
            onPressed: position + 1 < models.length
                ? () => setState(() => _selected = models[position + 1])
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ModelPreview(
        key: ValueKey(model.path),
        catalogue: catalogue,
        model: model,
      ),
    );
  }
}
