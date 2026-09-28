import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/luma_theme.dart';
import '../../l10n/app_localizations.dart';
import 'dashboard_tiles.dart';
import 'home_editor.dart';
import 'home_layout.dart';
import 'home_greeting.dart';
import 'home_scope.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.onNavigate,
    this.onPlugin,
    this.startEditing = false,
    this.onEditRequestConsumed,
  });

  final ValueChanged<int> onNavigate;
  final ValueChanged<String>? onPlugin;
  final bool startEditing;
  final VoidCallback? onEditRequestConsumed;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  HomeLayout? _draft;
  bool _initialized = false;
  bool _saving = false;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final repo = HomeScope.of(context);
      repo.ready.then((_) {
        if (!mounted) return;
        if (widget.startEditing) widget.onEditRequestConsumed?.call();
        setState(() {
          _ready = true;
          if (widget.startEditing) _draft = repo.layout;
        });
      });
    }
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    setState(() => _saving = true);
    try {
      await HomeScope.of(context).save(draft);
      if (mounted) setState(() => _draft = null);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).homeSaveFailed(error.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _add() async {
    final definition = await showModalBottomSheet<DashboardTileDefinition>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: math.min(MediaQuery.sizeOf(context).height * .75, 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Text(
                  L.of(context).homeAddSheetTitle,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.4,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final item in dashboardTileDefinitions)
                      ListTile(
                        leading: Icon(item.icon, color: context.luma.accent),
                        title: Text(item.localizedTitle(context)),
                        trailing: const Icon(Icons.add_rounded),
                        onTap: () => Navigator.pop(context, item),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (definition == null || !mounted || _draft == null) return;
    final layout = _draft!;
    final tile = HomeTile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      kind: definition.kind,
      x: 0,
      y: layout.tiles.fold<int>(
        0,
        (end, tile) => math.max(end, tile.y + tile.h),
      ),
      w: math.min(definition.defaultWidth, layout.columns),
      h: definition.defaultHeight,
      config: const {},
    );
    final configured = await configureDashboardTile(context, tile);
    if (configured != null && mounted && _draft != null) {
      setState(() => _draft = _draft!.place(configured));
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = HomeScope.of(context);
    if (!_ready) return const Center(child: CircularProgressIndicator());
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final editing = _draft != null;
        final layout = _draft ?? repo.layout;
        final palette = context.luma;
        return Column(
          children: [
            if (repo.loadError != null)
              MaterialBanner(
                content: Text(repo.loadError!),
                actions: [
                  TextButton(
                    onPressed: () => setState(() => _draft = repo.layout),
                    child: Text(L.of(context).homeEditLayout),
                  ),
                ],
              ),
            Expanded(
              child: HomeGrid(
                header: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HomeGreeting(
                      layout: layout,
                      onEdit: editing && !_saving
                          ? () async {
                              final updated = await editHomeSummary(
                                context,
                                _draft!,
                              );
                              if (updated != null &&
                                  mounted &&
                                  _draft != null) {
                                setState(() => _draft = updated);
                              }
                            }
                          : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 20, 0, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 24,
                            runSpacing: 12,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (editing)
                                    Container(
                                      width: 4,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: palette.accent,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  if (editing) const SizedBox(width: 12),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          editing
                                              ? L.of(context).homeEditingTitle
                                              : L.of(context).homeAtAGlance,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                fontSize: editing ? 24 : 16,
                                                letterSpacing: -.3,
                                              ),
                                        ),
                                        if (editing)
                                          Text(
                                            repo.family == 'phone'
                                                ? L.of(context).homePhoneLayout
                                                : L.of(context).homeDesktopLayout,
                                            style: TextStyle(
                                              color: palette.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: editing
                                    ? [
                                        TextButton(
                                          onPressed: _saving
                                              ? null
                                              : () => setState(
                                                  () => _draft =
                                                      HomeLayout.defaults(
                                                        repo.family,
                                                      ),
                                                ),
                                          child: Text(
                                            L.of(context).homeResetDashboard,
                                          ),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: _saving ? null : _add,
                                          icon: const Icon(Icons.add_rounded),
                                          label: Text(L.of(context).homeAddTile),
                                        ),
                                        TextButton(
                                          onPressed: _saving
                                              ? null
                                              : () => setState(
                                                  () => _draft = null,
                                                ),
                                          child: Text(L.of(context).commonCancel),
                                        ),
                                        FilledButton.icon(
                                          onPressed: _saving ? null : _save,
                                          icon: _saving
                                              ? const SizedBox.square(
                                                  dimension: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Icon(Icons.check_rounded),
                                          label: Text(L.of(context).homeSaveLayout),
                                        ),
                                      ]
                                    : [
                                        IconButton(
                                          onPressed: () => setState(
                                            () => _draft = repo.layout,
                                          ),
                                          tooltip: L.of(context).homeEdit,
                                          visualDensity: VisualDensity.compact,
                                          color: palette.textMuted,
                                          icon: const Icon(
                                            Icons.tune_rounded,
                                            size: 18,
                                          ),
                                        ),
                                      ],
                              ),
                            ],
                          ),
                          if (editing)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                L.of(context).homeDragHint,
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                layout: layout,
                editing: editing && !_saving,
                onChanged: (value) => setState(() => _draft = value),
                onAdd: _add,
                onNavigate: widget.onNavigate,
                onPlugin: widget.onPlugin ?? (_) {},
              ),
            ),
          ],
        );
      },
    );
  }
}
