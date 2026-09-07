import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "${map.title}"?'),
        content: Text(
          nodeCount <= 1
              ? 'This map is empty. It will be removed for good.'
              : 'All $nodeCount nodes on this map will be removed for good.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.luma.danger,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
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
                          decoration: const InputDecoration(
                            hintText: 'Name a new mind map',
                            isDense: true,
                            prefixIcon: Icon(Icons.hub_rounded, size: 18),
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _create(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      LumaPrimaryButton(
                        label: 'Create',
                        icon: Icons.add_rounded,
                        loading: _creating,
                        onTap: _create,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: maps.isEmpty
                        ? const LumaEmptyState(
                            icon: Icons.hub_rounded,
                            title: 'No mind maps yet',
                            subtitle:
                                'Name one above. You start on the centre idea and press '
                                'Tab to branch out — no dragging required.',
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
                    tooltip: 'Delete map',
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
                    '$nodeCount ${nodeCount == 1 ? 'node' : 'nodes'}',
                    style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                  ),
                  const Spacer(),
                  Text(
                    _relative(map.updatedAt),
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

  static String _relative(DateTime when) {
    final difference = DateTime.now().difference(when);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 30) return '${difference.inDays}d ago';
    return '${when.year}-${when.month.toString().padLeft(2, '0')}-'
        '${when.day.toString().padLeft(2, '0')}';
  }
}
