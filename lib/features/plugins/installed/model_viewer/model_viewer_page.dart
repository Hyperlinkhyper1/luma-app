import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/luma_theme.dart';
import 'model_preview.dart';
import 'model_viewer_repository.dart';
import 'model_viewer_scope.dart';
import 'model_viewer_sign_in.dart';

class ModelViewerPage extends StatefulWidget {
  const ModelViewerPage({super.key});

  @override
  State<ModelViewerPage> createState() => _ModelViewerPageState();
}

class _ModelViewerPageState extends State<ModelViewerPage> {
  final _repoInput = TextEditingController();
  final _refInput = TextEditingController();
  final _search = TextEditingController();
  ModelCatalogue? _catalogue;
  RepositoryModel? _selected;
  bool _restored = false;
  bool _busy = false;
  String? _error;

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
    _repoInput.dispose();
    _refInput.dispose();
    _search.dispose();
    super.dispose();
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
    final models =
        catalogue?.models
            .where(
              (model) => model.path.toLowerCase().contains(
                _search.text.trim().toLowerCase(),
              ),
            )
            .toList() ??
        const <RepositoryModel>[];
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
                : _catalogueBody(t, catalogue, models),
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
              onChanged: (_) => setState(() {}),
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
              : GridView.builder(
                  key: PageStorageKey('${catalogue.slug}@${catalogue.ref}'),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 355,
                    mainAxisExtent: 92,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: models.length,
                  itemBuilder: (context, index) => _modelCard(models[index]),
                ),
        ),
      ],
    );
  }

  Widget _modelCard(RepositoryModel model) {
    return LumaCard(
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: context.lumaDecor.cardBorderRadius,
          ),
          leading: Icon(Icons.view_in_ar_outlined, color: context.luma.accent),
          trailing: const Icon(Icons.chevron_right_rounded, size: 18),
          onTap: () => setState(() => _selected = model),
          title: Text(model.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            model.path.contains('/')
                ? model.path
                : model.format.name.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
