import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'free_sketch_repository.dart';
import 'free_sketch_scope.dart';
import 'io/sketch_export.dart';
import 'model/sketch_limits.dart';
import 'model/sketch_meta.dart';
import 'ui/sketch_studio.dart';
import 'ui/studio_controller.dart';

/// Free Sketch: a gallery of artworks that opens into the painting studio.
class FreeSketchPage extends StatefulWidget {
  const FreeSketchPage({super.key});

  @override
  State<FreeSketchPage> createState() => _FreeSketchPageState();
}

class _FreeSketchPageState extends State<FreeSketchPage> {
  StudioController? _studio;
  String? _opening;
  Object? _openError;

  @override
  void dispose() {
    final studio = _studio;
    if (studio != null) {
      unawaited(studio.close().whenComplete(studio.dispose));
    }
    super.dispose();
  }

  Future<void> _open(String id) async {
    if (_opening != null) return;
    setState(() {
      _opening = id;
      _openError = null;
    });
    try {
      final controller = await StudioController.open(FreeSketchScope.of(context), id);
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _studio = controller);
    } on Object catch (error) {
      if (mounted) setState(() => _openError = error);
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  Future<void> _close() async {
    final studio = _studio;
    if (studio == null) return;
    await studio.close();
    if (!mounted) return;
    setState(() => _studio = null);
    studio.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studio = _studio;
    if (studio != null) {
      return SketchStudio(key: ObjectKey(studio), controller: studio, onClose: _close);
    }
    return _Gallery(
      opening: _opening,
      error: _openError,
      onOpen: _open,
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.opening, required this.error, required this.onOpen});

  final String? opening;
  final Object? error;
  final ValueChanged<String> onOpen;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  Future<List<SketchSummary>>? _list;
  FreeSketchRepository? _repository;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = FreeSketchScope.of(context);
    if (!identical(repository, _repository)) {
      _repository?.removeListener(_reload);
      _repository = repository..addListener(_reload);
      _list = repository.list();
    }
  }

  @override
  void dispose() {
    _repository?.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _list = _repository!.list();
    });
  }

  Future<void> _create() async {
    final spec = await showDialog<_NewCanvas>(context: context, builder: (_) => const _NewCanvasDialog());
    if (spec == null || !mounted) return;
    final meta = await FreeSketchScope.of(context).create(
      title: spec.title,
      width: spec.width,
      height: spec.height,
      background: spec.background,
      showBackground: spec.showBackground,
    );
    widget.onOpen(meta.id);
  }

  Future<void> _importAsNew() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif'],
      withData: true,
    );
    final file = result?.files.firstOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null || !mounted) return;
    final repository = FreeSketchScope.of(context);
    try {
      final natural = await StudioController.imageSize(bytes);
      final longest = natural.longestSide;
      final scale = longest > CanvasPreset.maxSide ? CanvasPreset.maxSide / longest : 1.0;
      final width = (natural.width * scale).round().clamp(CanvasPreset.minSide, CanvasPreset.maxSide);
      final height = (natural.height * scale).round().clamp(CanvasPreset.minSide, CanvasPreset.maxSide);
      final layer = await StudioController.decodeToCanvas(bytes, width, height);
      final png = await SketchExporter.pngOf(layer);
      layer.dispose();
      final name = file.name.contains('.') ? file.name.substring(0, file.name.lastIndexOf('.')) : file.name;
      final meta = await repository.create(
        title: name,
        width: width,
        height: height,
        firstLayerPng: png,
        firstLayerName: name,
      );
      widget.onOpen(meta.id);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('That image could not be opened: $error')));
    }
  }

  Future<void> _rename(SketchSummary summary) async {
    final text = TextEditingController(text: summary.meta.title);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename artwork'),
        content: TextField(
          controller: text,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, text.text), child: const Text('Rename')),
        ],
      ),
    ).whenComplete(text.dispose);
    final trimmed = title?.trim();
    if (trimmed == null || trimmed.isEmpty || !mounted) return;
    await FreeSketchScope.of(context).rename(summary.meta.id, trimmed);
  }

  Future<void> _delete(SketchSummary summary) async {
    final luma = context.luma;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${summary.meta.title}"?'),
        content: Text(
          'All ${summary.meta.layers.length} layer${summary.meta.layers.length == 1 ? '' : 's'} '
          'will be removed from this device for good. Export it first if you want to keep a copy.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: luma.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false) || !mounted) return;
    await FreeSketchScope.of(context).delete(summary.meta.id);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final narrow = MediaQuery.sizeOf(context).width < 760;
    return Padding(
      padding: EdgeInsets.fromLTRB(narrow ? 12 : 24, 12, narrow ? 12 : 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gallery',
                      style: TextStyle(color: luma.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Every artwork is saved on this device as you paint.',
                      style: TextStyle(color: luma.textMuted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              LumaGhostButton(label: narrow ? 'Import' : 'Import image', icon: Icons.image_outlined, onTap: _importAsNew),
              const SizedBox(width: 10),
              LumaPrimaryButton(label: narrow ? 'New' : 'New artwork', icon: Icons.add_rounded, onTap: _create),
            ],
          ),
          if (widget.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'That artwork could not be opened: ${widget.error}',
                style: TextStyle(color: luma.danger, fontSize: 12.5),
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<SketchSummary>>(
              future: _list,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return LumaEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'The gallery could not be read',
                    subtitle: '${snapshot.error}',
                  );
                }
                final items = snapshot.data;
                if (items == null) {
                  return const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)));
                }
                if (items.isEmpty) {
                  return LumaEmptyState(
                    icon: Icons.brush_rounded,
                    title: 'Your gallery is empty',
                    subtitle: 'Start a new artwork — pencils, inks, watercolours, markers, airbrushes and '
                        'blenders, with layers, blend modes, symmetry and pressure. '
                        'Export to PNG, JPEG, Photoshop or OpenRaster.',
                    action: LumaPrimaryButton(label: 'New artwork', icon: Icons.add_rounded, onTap: _create),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: narrow ? 220 : 260,
                    mainAxisExtent: narrow ? 210 : 236,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _ArtworkCard(
                      summary: item,
                      opening: widget.opening == item.meta.id,
                      onOpen: () => widget.onOpen(item.meta.id),
                      onRename: () => _rename(item),
                      onDuplicate: () => FreeSketchScope.of(context).duplicate(item.meta.id),
                      onDelete: () => _delete(item),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtworkCard extends StatelessWidget {
  const _ArtworkCard({
    required this.summary,
    required this.opening,
    required this.onOpen,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
  });

  final SketchSummary summary;
  final bool opening;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final meta = summary.meta;
    final thumb = summary.thumbnail;
    return Material(
      color: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: luma.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: opening ? null : onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: luma.background,
                padding: const EdgeInsets.all(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumb != null)
                      Image.file(
                        thumb,
                        key: ValueKey('${thumb.path}@${meta.updated.microsecondsSinceEpoch}'),
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) => Icon(Icons.brush_rounded, color: luma.textMuted),
                      )
                    else
                      Center(
                        child: AspectRatio(
                          aspectRatio: meta.width / meta.height,
                          child: Container(color: Color(meta.background)),
                        ),
                      ),
                    if (opening)
                      const Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.6))),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meta.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${meta.width}×${meta.height} · ${meta.layers.length} layer${meta.layers.length == 1 ? '' : 's'} · ${_relative(meta.updated)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Artwork actions',
                    icon: Icon(Icons.more_vert_rounded, size: 18, color: luma.textMuted),
                    onSelected: (value) {
                      switch (value) {
                        case 'rename':
                          onRename();
                        case 'duplicate':
                          onDuplicate();
                        case 'delete':
                          onDelete();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'rename', child: Text('Rename')),
                      PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
    return '${when.year}-${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')}';
  }
}

class _NewCanvas {
  const _NewCanvas(this.title, this.width, this.height, this.background, this.showBackground);

  final String title;
  final int width;
  final int height;
  final int background;
  final bool showBackground;
}

class _NewCanvasDialog extends StatefulWidget {
  const _NewCanvasDialog();

  @override
  State<_NewCanvasDialog> createState() => _NewCanvasDialogState();
}

class _NewCanvasDialogState extends State<_NewCanvasDialog> {
  final _title = TextEditingController(text: 'Untitled artwork');
  final _width = TextEditingController(text: '${CanvasPreset.all.first.width}');
  final _height = TextEditingController(text: '${CanvasPreset.all.first.height}');
  CanvasPreset? _preset = CanvasPreset.all.first;
  int _background = 0xFFFFFFFF;
  bool _transparent = false;

  static const _backgrounds = [0xFFFFFFFF, 0xFFF6F1E7, 0xFFE9E6DF, 0xFF1E1E24];

  @override
  void dispose() {
    _title.dispose();
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  int? _parse(TextEditingController c) {
    final v = int.tryParse(c.text.trim());
    if (v == null || v < CanvasPreset.minSide || v > CanvasPreset.maxSide) return null;
    return v;
  }

  void _pick(CanvasPreset preset) {
    setState(() {
      _preset = preset;
      _width.text = '${preset.width}';
      _height.text = '${preset.height}';
    });
  }

  void _swap() {
    final w = _width.text;
    setState(() {
      _width.text = _height.text;
      _height.text = w;
      _preset = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final w = _parse(_width);
    final h = _parse(_height);
    final valid = w != null && h != null && _title.text.trim().isNotEmpty;
    final megabytes = valid ? (w * h * 4 / (1024 * 1024)) : 0.0;
    return AlertDialog(
      title: const Text('New artwork'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Title'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Text('Canvas', style: TextStyle(color: luma.textSecondary, fontWeight: FontWeight.w600, fontSize: 12.5)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in CanvasPreset.all)
                    ChoiceChip(
                      selected: _preset == preset,
                      onSelected: (_) => _pick(preset),
                      label: Text(preset.note == null ? preset.name : '${preset.name} · ${preset.note}'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _width,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(labelText: 'Width (px)', errorText: w == null ? '64–4096' : null),
                      onChanged: (_) => setState(() => _preset = null),
                    ),
                  ),
                  IconButton(tooltip: 'Swap width and height', onPressed: _swap, icon: const Icon(Icons.swap_horiz_rounded)),
                  Expanded(
                    child: TextField(
                      controller: _height,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(labelText: 'Height (px)', errorText: h == null ? '64–4096' : null),
                      onChanged: (_) => setState(() => _preset = null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Background', style: TextStyle(color: luma.textSecondary, fontWeight: FontWeight.w600, fontSize: 12.5)),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final bg in _backgrounds)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _background = bg;
                          _transparent = false;
                        }),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Color(bg),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: !_transparent && _background == bg ? luma.accent : luma.border,
                              width: !_transparent && _background == bg ? 2.5 : 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ChoiceChip(
                    selected: _transparent,
                    onSelected: (v) => setState(() => _transparent = v),
                    avatar: const Icon(Icons.grid_on_rounded, size: 16),
                    label: const Text('Transparent'),
                  ),
                ],
              ),
              if (valid) ...[
                const SizedBox(height: 14),
                Text(
                  '${megabytes.toStringAsFixed(1)} MB per layer · up to '
                  '${SketchLimits.maxLayers(w, h)} layers',
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: valid
              ? () => Navigator.pop(context, _NewCanvas(_title.text.trim(), w, h, _background, !_transparent))
              : null,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
