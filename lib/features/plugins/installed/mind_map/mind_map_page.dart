import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/luma_theme.dart';
import 'data/mind_map_database.dart';
import 'mind_map_scope.dart';
import 'ui/mind_map_canvas.dart';

/// The plugin's entry point: a library of maps that opens into the canvas.
class MindMapPage extends StatefulWidget {
  const MindMapPage({super.key});

  @override
  State<MindMapPage> createState() => _MindMapPageState();
}

class _MindMapPageState extends State<MindMapPage> {
  int? _openMapId;

  @override
  Widget build(BuildContext context) {
    final repository = MindMapScope.of(context);
    if (_openMapId == null) {
      return _MapLibrary(onOpen: (id) => setState(() => _openMapId = id));
    }
    return StreamData<MindMap?>(
      stream: repository.watchMap(_openMapId!),
      builder: (context, map) {
        if (map == null) {
          // The map was deleted from another device mid-edit.
          return _MapLibrary(onOpen: (id) => setState(() => _openMapId = id));
        }
        return MindMapCanvas(
          key: ValueKey(map.id),
          map: map,
          repository: repository,
          onClose: () => setState(() => _openMapId = null),
        );
      },
    );
  }
}

class _MapLibrary extends StatefulWidget {
  const _MapLibrary({required this.onOpen});

  final ValueChanged<int> onOpen;

  @override
  State<_MapLibrary> createState() => _MapLibraryState();
}

class _MapLibraryState extends State<_MapLibrary> {
  final _title = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final title = _title.text.trim();
    if (title.isEmpty || _creating) return;
    setState(() => _creating = true);
    try {
      final repository = MindMapScope.of(context);
      final id = await repository.createMap(title);
      _title.clear();
      if (mounted) widget.onOpen(id);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _confirmDelete(MindMap map, int nodeCount) async {
    final t = L.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.mindMapDeleteMapTitle(map.title)),
        content: Text(
          nodeCount <= 1
              ? t.mindMapDeleteMapEmpty
              : t.mindMapDeleteMapNodes(nodeCount),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.luma.danger,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      if (!mounted) return;
      await MindMapScope.of(context).deleteMap(map.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final repository = MindMapScope.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 760;

    return StreamData<List<MindMap>>(
      stream: repository.watchMaps(),
      builder: (context, maps) {
        return StreamData<Map<int, int>>(
          stream: repository.watchNodeCounts(),
          builder: (context, counts) {
            return Padding(
              padding: EdgeInsets.fromLTRB(narrow ? 12 : 24, 8, narrow ? 12 : 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _title,
                          decoration: InputDecoration(
                            hintText: t.mindMapNewMapHint,
                            isDense: true,
                            prefixIcon: const Icon(Icons.hub_rounded, size: 18),
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _create(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      LumaPrimaryButton(
                        label: t.commonCreate,
                        icon: Icons.add_rounded,
                        loading: _creating,
                        onTap: _create,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: maps.isEmpty
                        ? LumaEmptyState(
                            icon: Icons.hub_rounded,
                            title: t.mindMapLibraryEmptyTitle,
                            subtitle: t.mindMapLibraryEmptySubtitle,
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.only(bottom: 24),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 300,
                              mainAxisExtent: 108,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: maps.length,
                            itemBuilder: (context, index) {
                              final map = maps[index];
                              return _MapCard(
                                map: map,
                                nodeCount: counts[map.id] ?? 0,
                                onOpen: () => widget.onOpen(map.id),
                                onDelete: () =>
                                    _confirmDelete(map, counts[map.id] ?? 0),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({
    required this.map,
    required this.nodeCount,
    required this.onOpen,
    required this.onDelete,
  });

  final MindMap map;
  final int nodeCount;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    return LumaCard(
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      map.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: t.mindMapDeleteMapTooltip,
                    iconSize: 18,
                    icon: Icon(Icons.delete_outline_rounded, color: luma.textMuted),
                    onPressed: onDelete,
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.hub_rounded, size: 13, color: luma.textMuted),
                  const SizedBox(width: 5),
                  Text(
                    t.mindMapNodeCount(nodeCount),
                    style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                  ),
                  const Spacer(),
                  Text(
                    _relative(t, map.updatedAt),
                    style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _relative(L t, DateTime when) {
    final difference = DateTime.now().difference(when);
    if (difference.inMinutes < 1) return t.commonJustNow;
    if (difference.inHours < 1) return t.commonMinutesAgo(difference.inMinutes);
    if (difference.inDays < 1) return t.commonHoursAgo(difference.inHours);
    if (difference.inDays < 30) return t.commonDaysAgo(difference.inDays);
    return '${when.year}-${when.month.toString().padLeft(2, '0')}-'
        '${when.day.toString().padLeft(2, '0')}';
  }
}
