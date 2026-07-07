import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../data/school_database.dart';
import '../school_repository.dart';
import '../school_scope.dart';

/// A list of mind maps, each opening into a freeform canvas of draggable,
/// connected nodes.
class MindmapTab extends StatefulWidget {
  const MindmapTab({super.key});

  @override
  State<MindmapTab> createState() => _MindmapTabState();
}

class _MindmapTabState extends State<MindmapTab> {
  int? _activeMapId;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _activeMapId == null
          ? _MapListView(key: const ValueKey('list'), onOpen: (id) => setState(() => _activeMapId = id))
          : _MindMapCanvas(
              key: ValueKey('map-$_activeMapId'),
              mapId: _activeMapId!,
              onClose: () => setState(() => _activeMapId = null),
            ),
    );
  }
}

class _MapListView extends StatefulWidget {
  const _MapListView({super.key, required this.onOpen});
  final ValueChanged<int> onOpen;

  @override
  State<_MapListView> createState() => _MapListViewState();
}

class _MapListViewState extends State<_MapListView> {
  final _titleController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _create(SchoolRepository repo) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final id = await repo.createMindMap(title);
    _titleController.clear();
    if (mounted) widget.onOpen(id);
  }

  @override
  Widget build(BuildContext context) {
    final repo = SchoolScope.of(context);
    final luma = context.luma;
    return StreamData<List<MindMap>>(
      stream: repo.watchMindMaps(),
      builder: (context, maps) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(hintText: 'New mind map title', isDense: true),
                      onSubmitted: (_) => _create(repo),
                    ),
                  ),
                  const SizedBox(width: 12),
                  LumaPrimaryButton(label: 'Create', icon: Icons.add_rounded, onTap: () => _create(repo)),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: maps.isEmpty
                    ? const LumaEmptyState(
                        icon: Icons.account_tree_rounded,
                        title: 'No mind maps yet',
                        subtitle: 'Create one to start organizing ideas visually.',
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 260,
                          mainAxisExtent: 90,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: maps.length,
                        itemBuilder: (context, i) {
                          final m = maps[i];
                          return LumaCard(
                            child: InkWell(
                              onTap: () => widget.onOpen(m.id),
                              borderRadius: BorderRadius.circular(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(m.title,
                                        style: TextStyle(
                                            color: luma.textPrimary, fontWeight: FontWeight.w700)),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded,
                                        color: luma.textMuted, size: 20),
                                    onPressed: () => repo.deleteMindMap(m.id),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MindMapCanvas extends StatelessWidget {
  const _MindMapCanvas({super.key, required this.mapId, required this.onClose});
  final int mapId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final repo = SchoolScope.of(context);
    final luma = context.luma;
    return StreamData<List<MindMapNode>>(
      stream: repo.watchNodes(mapId),
      builder: (context, nodes) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: onClose),
                  Expanded(
                    child: Text('${nodes.length} nodes', style: TextStyle(color: luma.textSecondary)),
                  ),
                  LumaPrimaryButton(
                    label: 'Add node',
                    icon: Icons.add_rounded,
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => _NodeDialog(repo: repo, mapId: mapId, nodes: nodes),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: luma.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: luma.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InteractiveViewer(
                    constrained: false,
                    boundaryMargin: const EdgeInsets.all(2000),
                    minScale: 0.3,
                    maxScale: 2.5,
                    child: SizedBox(
                      width: 3000,
                      height: 2000,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(painter: _ConnectorPainter(nodes, luma.border)),
                          ),
                          for (final n in nodes)
                            _NodeCard(
                              key: ValueKey(n.id),
                              node: n,
                              repo: repo,
                              onEdit: () => showDialog(
                                context: context,
                                builder: (_) => _NodeDialog(
                                    repo: repo, mapId: mapId, nodes: nodes, existing: n),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter(this.nodes, this.color);
  final List<MindMapNode> nodes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    final byId = {for (final n in nodes) n.id: n};
    for (final n in nodes) {
      final parent = n.parentId == null ? null : byId[n.parentId];
      if (parent == null) continue;
      canvas.drawLine(
        Offset(n.x + 70, n.y + 24),
        Offset(parent.x + 70, parent.y + 24),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter oldDelegate) =>
      oldDelegate.nodes != nodes || oldDelegate.color != color;
}

class _NodeCard extends StatefulWidget {
  const _NodeCard({super.key, required this.node, required this.repo, required this.onEdit});
  final MindMapNode node;
  final SchoolRepository repo;
  final VoidCallback onEdit;

  @override
  State<_NodeCard> createState() => _NodeCardState();
}

class _NodeCardState extends State<_NodeCard> {
  late MindMapNode _node = widget.node;
  Offset? _dragStartDelta;

  @override
  void didUpdateWidget(_NodeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node != widget.node) _node = widget.node;
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Positioned(
      left: _node.x,
      top: _node.y,
      child: GestureDetector(
        onPanStart: (details) {
          _dragStartDelta = details.globalPosition - Offset(_node.x, _node.y);
        },
        onPanUpdate: (details) {
          if (_dragStartDelta == null) return;
          setState(() {
            _node = _node.copyWith(
              x: details.globalPosition.dx - _dragStartDelta!.dx,
              y: details.globalPosition.dy - _dragStartDelta!.dy,
            );
          });
        },
        onPanEnd: (_) {
          _dragStartDelta = null;
          widget.repo.updateNodePosition(_node.id, _node.x, _node.y);
        },
        onDoubleTap: widget.onEdit,
        child: Container(
          constraints: const BoxConstraints(minWidth: 140, maxWidth: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Color(_node.color),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)],
          ),
          child: Text(
            _node.label,
            style: TextStyle(color: luma.onAccent, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ),
    );
  }
}

class _NodeDialog extends StatefulWidget {
  const _NodeDialog({
    required this.repo,
    required this.mapId,
    required this.nodes,
    this.existing,
  });
  final SchoolRepository repo;
  final int mapId;
  final List<MindMapNode> nodes;
  final MindMapNode? existing;

  @override
  State<_NodeDialog> createState() => _NodeDialogState();
}

class _NodeDialogState extends State<_NodeDialog> {
  late final _labelController = TextEditingController(text: widget.existing?.label ?? '');
  late int? _parentId = widget.existing?.parentId;

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final label = _labelController.text.trim();
    if (label.isEmpty) return;
    if (widget.existing == null) {
      await widget.repo.createNode(widget.mapId, label,
          x: 100 + widget.nodes.length * 30.0,
          y: 100 + widget.nodes.length * 20.0,
          parentId: _parentId);
    } else {
      await widget.repo.updateNodeLabel(widget.existing!.id, label);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final candidates = widget.nodes.where((n) => n.id != widget.existing?.id).toList();
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add node' : 'Edit node'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _labelController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Label'),
          ),
          if (widget.existing == null && candidates.isNotEmpty)
            DropdownButtonFormField<int?>(
              initialValue: _parentId,
              decoration: const InputDecoration(labelText: 'Connects to (optional)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                for (final n in candidates) DropdownMenuItem(value: n.id, child: Text(n.label)),
              ],
              onChanged: (v) => setState(() => _parentId = v),
            ),
        ],
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: () async {
              await widget.repo.deleteNode(widget.existing!.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: context.luma.danger)),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
