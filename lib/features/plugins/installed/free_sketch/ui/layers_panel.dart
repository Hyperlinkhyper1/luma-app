import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import '../engine/sketch_document.dart';
import '../model/sketch_blend.dart';
import 'studio_controller.dart';
import 'studio_widgets.dart';

/// The layer stack, top layer first. Collapsed it is a strip of thumbnails
/// down the side of the canvas; expanded it is the full panel with blend
/// modes, opacity, locks and clipping masks.
class LayersPanel extends StatelessWidget {
  const LayersPanel({
    super.key,
    required this.controller,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final StudioController controller;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller.document,
      builder: (context, _) => expanded
          ? _ExpandedLayers(controller: controller, onCollapse: onToggleExpanded)
          : _LayerStrip(controller: controller, onExpand: onToggleExpanded),
    );
  }
}

class _LayerStrip extends StatelessWidget {
  const _LayerStrip({required this.controller, required this.onExpand});

  final StudioController controller;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final state = controller.state;
    final layers = state.layers.reversed.toList();
    return Container(
      width: 68,
      decoration: BoxDecoration(
        color: luma.surface,
        border: Border(left: BorderSide(color: luma.border)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 6),
          StudioIconButton(icon: Icons.layers_rounded, tooltip: 'Show layer panel', onTap: onExpand),
          StudioIconButton(icon: Icons.add_rounded, tooltip: 'New layer', onTap: () => controller.addLayer()),
          Divider(color: luma.border, height: 10, indent: 10, endIndent: 10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: layers.length,
              itemBuilder: (context, index) {
                final layer = layers[index];
                final active = layer.id == state.activeLayerId;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  child: Tooltip(
                    message: layer.name,
                    waitDuration: const Duration(milliseconds: 500),
                    child: GestureDetector(
                      onTap: () => controller.selectLayer(layer.id),
                      onLongPress: onExpand,
                      child: Opacity(
                        opacity: layer.visible ? 1 : 0.4,
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: active ? luma.accent : luma.border,
                              width: active ? 2 : 1,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: LayerThumbnail(layer: layer, controller: controller),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandedLayers extends StatefulWidget {
  const _ExpandedLayers({required this.controller, required this.onCollapse});

  final StudioController controller;
  final VoidCallback onCollapse;

  @override
  State<_ExpandedLayers> createState() => _ExpandedLayersState();
}

class _ExpandedLayersState extends State<_ExpandedLayers> {
  StudioController get c => widget.controller;

  Future<void> _rename(SketchLayer layer) async {
    final text = TextEditingController(text: layer.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename layer'),
        content: TextField(
          controller: text,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, text.text), child: const Text('Rename')),
        ],
      ),
    ).whenComplete(text.dispose);
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    c.updateLayer(layer.id, (l) => l.copyWith(name: trimmed), 'Rename layer');
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final state = c.state;
    final layers = state.layers.reversed.toList();
    final active = state.active;
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: luma.surface,
        border: Border(left: BorderSide(color: luma.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 4),
            child: Row(
              children: [
                Text('Layers', style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(width: 6),
                Text(
                  '${state.layers.length}/${c.maxLayers}',
                  style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                ),
                const Spacer(),
                StudioIconButton(icon: Icons.add_rounded, tooltip: 'New layer (Ctrl+Shift+N)', size: 32, onTap: () => c.addLayer()),
                _LayerMenu(controller: c, onRename: () => _rename(active)),
                StudioIconButton(icon: Icons.chevron_right_rounded, tooltip: 'Collapse', size: 32, onTap: widget.onCollapse),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: layers.length,
              onReorderItem: (oldIndex, newIndex) {
                final n = layers.length;
                c.moveLayer(n - 1 - oldIndex, n - 1 - newIndex);
              },
              itemBuilder: (context, index) {
                final layer = layers[index];
                return _LayerRow(
                  key: ValueKey(layer.id),
                  index: index,
                  layer: layer,
                  active: layer.id == state.activeLayerId,
                  controller: c,
                  onRename: () => _rename(layer),
                );
              },
            ),
          ),
          _BackgroundRow(controller: c),
          Divider(color: luma.border, height: 1),
          _LayerProperties(controller: c, layer: active),
        ],
      ),
    );
  }
}

class _LayerRow extends StatelessWidget {
  const _LayerRow({
    super.key,
    required this.index,
    required this.layer,
    required this.active,
    required this.controller,
    required this.onRename,
  });

  final int index;
  final SketchLayer layer;
  final bool active;
  final StudioController controller;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final subtitle = [
      if (layer.blend != SketchBlend.normal) layer.blend.label,
      if (layer.opacity < 1) '${(layer.opacity * 100).round()}%',
      if (layer.alphaLocked) 'α lock',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: active ? luma.accentSubtle : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => controller.selectLayer(layer.id),
          onLongPress: onRename,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 0, 4),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(Icons.drag_indicator_rounded, size: 16, color: luma.textMuted),
                  ),
                ),
                if (layer.clipped)
                  Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Icon(Icons.subdirectory_arrow_right_rounded, size: 16, color: luma.accent),
                  ),
                Opacity(
                  opacity: layer.visible ? 1 : 0.45,
                  child: Container(
                    width: 52,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: active ? luma.accent : luma.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: LayerThumbnail(layer: layer, controller: controller),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        layer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active ? luma.accent : luma.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(subtitle, maxLines: 1, style: TextStyle(color: luma.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                if (layer.locked) Icon(Icons.lock_rounded, size: 14, color: luma.textMuted),
                StudioIconButton(
                  icon: layer.visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  tooltip: layer.visible ? 'Hide layer' : 'Show layer',
                  size: 32,
                  onTap: () => controller.updateLayer(
                    layer.id,
                    (l) => l.copyWith(visible: !l.visible),
                    layer.visible ? 'Hide layer' : 'Show layer',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackgroundRow extends StatelessWidget {
  const _BackgroundRow({required this.controller});

  final StudioController controller;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final state = controller.state;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 8, 6),
      child: Row(
        children: [
          PopupMenuButton<String>(
            tooltip: 'Background colour',
            onSelected: (value) {
              switch (value) {
                case 'current':
                  controller.setBackground(controller.color);
                case 'white':
                  controller.setBackground(const Color(0xFFFFFFFF));
                case 'paper':
                  controller.setBackground(const Color(0xFFF6F1E7));
                case 'dark':
                  controller.setBackground(const Color(0xFF1E1E24));
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'current', child: Text('Use current colour')),
              PopupMenuItem(value: 'white', child: Text('White')),
              PopupMenuItem(value: 'paper', child: Text('Warm paper')),
              PopupMenuItem(value: 'dark', child: Text('Charcoal')),
            ],
            child: Container(
              width: 52,
              height: 30,
              decoration: BoxDecoration(
                color: state.showBackground ? state.background : null,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: luma.border),
              ),
              child: state.showBackground
                  ? null
                  : Icon(Icons.grid_on_rounded, size: 16, color: luma.textMuted),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              state.showBackground ? 'Background' : 'Background (transparent)',
              style: TextStyle(color: luma.textSecondary, fontSize: 12.5),
            ),
          ),
          StudioIconButton(
            icon: state.showBackground ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            tooltip: state.showBackground ? 'Transparent background' : 'Show background',
            size: 32,
            onTap: controller.toggleBackground,
          ),
        ],
      ),
    );
  }
}

class _LayerProperties extends StatelessWidget {
  const _LayerProperties({required this.controller, required this.layer});

  final StudioController controller;
  final SketchLayer layer;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    Widget toggle(IconData icon, String label, bool on, VoidCallback onTap) => Expanded(
          child: Tooltip(
            message: label,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: on ? luma.accentSubtle : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(icon, size: 17, color: on ? luma.accent : luma.textSecondary),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(fontSize: 10, color: on ? luma.accent : luma.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Blend', style: TextStyle(color: luma.textSecondary, fontSize: 12)),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButton<SketchBlend>(
                  value: layer.blend,
                  isExpanded: true,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  style: TextStyle(color: luma.textPrimary, fontSize: 12.5),
                  items: [
                    for (final group in SketchBlend.groups)
                      for (final blend in group)
                        DropdownMenuItem(value: blend, child: Text(blend.label)),
                  ],
                  onChanged: (blend) {
                    if (blend == null) return;
                    controller.updateLayer(layer.id, (l) => l.copyWith(blend: blend), 'Blend mode');
                  },
                ),
              ),
            ],
          ),
          LabeledSlider(
            label: 'Opacity',
            value: layer.opacity,
            min: 0,
            max: 1,
            display: '${(layer.opacity * 100).round()}%',
            onChanged: (v) => controller.previewOpacity(layer.id, v),
            onChangeEnd: (_) => controller.commitOpacity(),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              toggle(Icons.lock_outline_rounded, 'Lock', layer.locked,
                  () => controller.updateLayer(layer.id, (l) => l.copyWith(locked: !l.locked), 'Lock layer')),
              toggle(Icons.opacity_rounded, 'Alpha lock', layer.alphaLocked,
                  () => controller.updateLayer(layer.id, (l) => l.copyWith(alphaLocked: !l.alphaLocked), 'Alpha lock')),
              toggle(Icons.subdirectory_arrow_right_rounded, 'Clip', layer.clipped,
                  () => controller.updateLayer(layer.id, (l) => l.copyWith(clipped: !l.clipped), 'Clipping mask')),
            ],
          ),
        ],
      ),
    );
  }
}

class _LayerMenu extends StatelessWidget {
  const _LayerMenu({required this.controller, required this.onRename});

  final StudioController controller;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return PopupMenuButton<String>(
      tooltip: 'Layer actions',
      icon: const Icon(Icons.more_horiz_rounded, size: 20),
      onSelected: (value) {
        switch (value) {
          case 'rename':
            onRename();
          case 'duplicate':
            c.duplicateLayer();
          case 'merge':
            c.mergeDown();
          case 'flatten':
            c.flatten();
          case 'clear':
            c.clearLayer();
          case 'fill':
            c.fillLayer();
          case 'copy':
            c.copy();
          case 'paste':
            c.paste();
          case 'delete':
            c.deleteLayer();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'rename', child: Text('Rename…')),
        const PopupMenuItem(value: 'duplicate', child: Text('Duplicate (Ctrl+J)')),
        PopupMenuItem(value: 'merge', enabled: c.canMergeDown(), child: const Text('Merge down (Ctrl+E)')),
        PopupMenuItem(value: 'flatten', enabled: c.state.layers.length > 1, child: const Text('Flatten all')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'copy', child: Text('Copy (Ctrl+C)')),
        PopupMenuItem(value: 'paste', enabled: c.hasClipboard, child: const Text('Paste as new layer (Ctrl+V)')),
        const PopupMenuItem(value: 'fill', child: Text('Fill with colour')),
        const PopupMenuItem(value: 'clear', child: Text('Clear (Delete)')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'delete', child: Text('Delete layer')),
      ],
    );
  }
}

/// A layer's pixels over a transparency checkerboard, scaled to fit.
class LayerThumbnail extends StatelessWidget {
  const LayerThumbnail({super.key, required this.layer, required this.controller});

  final SketchLayer layer;
  final StudioController controller;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ThumbPainter(layer, controller.width, controller.height),
      child: const SizedBox.expand(),
    );
  }
}

class _ThumbPainter extends CustomPainter {
  _ThumbPainter(this.layer, this.width, this.height);

  final SketchLayer layer;
  final int width;
  final int height;

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 5.0;
    final light = Paint()..color = const Color(0xFFFFFFFF);
    final dark = Paint()..color = const Color(0xFFDCDCE2);
    canvas.drawRect(Offset.zero & size, light);
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = ((y / cell).floor().isOdd ? cell : 0.0); x < size.width; x += cell * 2) {
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), dark);
      }
    }
    final image = layer.image;
    if (image == null) return;
    final scale = math.min(size.width / width, size.height / height);
    final w = width * scale;
    final h = height * scale;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_ThumbPainter old) => old.layer.image != layer.image;
}
