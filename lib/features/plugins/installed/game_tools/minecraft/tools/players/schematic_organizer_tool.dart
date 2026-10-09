import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../../../../app/widgets.dart';
import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../../theme/luma_theme.dart';
import '../../../../../../converter/schematic/block_colors.dart';
import '../../../../../../converter/schematic/schematic_model.dart';
import '../../../../../../converter/schematic/schematic_service.dart';
import '../../../../../../converter/tools/schematic_viewer.dart';
import '../../mc_tool_host.dart';
import '../../ui/mc_schematic_panel.dart';
import '../../ui/mc_style.dart';
import 'build_planner_tool.dart';

/// What a background read of one schematic file reports back.
class _Summary {
  const _Summary({
    this.width = 0,
    this.height = 0,
    this.length = 0,
    this.blocks = 0,
    this.thumb,
    this.thumbSize = 0,
    this.error,
  });

  final int width;
  final int height;
  final int length;
  final int blocks;

  /// Top-down RGBA pixels, [thumbSize] square.
  final Uint8List? thumb;
  final int thumbSize;
  final String? error;
}

const _unreadable = '\u0000unreadable';
const _tooLarge = '\u0000tooLarge';

_Summary _summarize(Uint8List bytes, String name) {
  try {
    final s = SchematicService.load(bytes, name);
    const size = 48;
    final pixels = Uint8List(size * size * 4);
    final span = s.width > s.length ? s.width : s.length;
    final ox = (span - s.width) / 2, oz = (span - s.length) / 2;
    for (var py = 0; py < size; py++) {
      for (var px = 0; px < size; px++) {
        final x = (px * span / size - ox).floor();
        final z = (py * span / size - oz).floor();
        if (x < 0 || z < 0 || x >= s.width || z >= s.length) continue;
        for (var y = s.height - 1; y >= 0; y--) {
          final state = s.blockAt(x, y, z);
          if (state.isAir) continue;
          final c = BlockColors.of(state);
          final light = 0.65 + 0.35 * (y + 1) / s.height;
          final i = (py * size + px) * 4;
          pixels[i] = (c.r * 255 * light).round().clamp(0, 255);
          pixels[i + 1] = (c.g * 255 * light).round().clamp(0, 255);
          pixels[i + 2] = (c.b * 255 * light).round().clamp(0, 255);
          pixels[i + 3] = 255;
          break;
        }
      }
    }
    return _Summary(
      width: s.width,
      height: s.height,
      length: s.length,
      blocks: s.blockCount,
      thumb: pixels,
      thumbSize: size,
    );
  } on Object catch (e) {
    return _Summary(error: e is FormatException ? e.message : _unreadable);
  }
}

class _Entry {
  _Entry(this.file, this.stat);

  File file;
  final FileStat stat;
  _Summary? summary;
  ui.Image? thumb;

  String get name => file.uri.pathSegments.last;
  String get extension {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  String get stem {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? name : name.substring(0, dot);
  }
}

enum _Sort {
  name,
  modified,
  size,
  blocks;

  String label(L t) => switch (this) {
    name => t.mcOrgSortName,
    modified => t.mcOrgSortNewest,
    size => t.mcOrgSortLargest,
    blocks => t.mcOrgSortBlocks,
  };
}

/// Favourites, groups and the last folder, kept on this device.
class _Library {
  String? folder;
  final Set<String> favorites = {};
  final Map<String, String> groups = {};

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}minecraft_tools${Platform.pathSeparator}schematic_organizer.json');
  }

  static Future<_Library> load() async {
    final lib = _Library();
    try {
      final f = await _file();
      if (!await f.exists()) return lib;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      lib.folder = j['folder'] as String?;
      lib.favorites.addAll((j['favorites'] as List? ?? const []).cast<String>());
      lib.groups.addAll((j['groups'] as Map? ?? const {}).cast<String, String>());
    } on Object {
      // A damaged file just means starting fresh.
    }
    return lib;
  }

  Future<void> save() async {
    try {
      final f = await _file();
      await f.parent.create(recursive: true);
      await f.writeAsString(jsonEncode({
        'folder': folder,
        'favorites': favorites.toList(),
        'groups': groups,
      }));
    } on Object {
      // Not being able to remember a favourite is not worth an error.
    }
  }

  void moved(String from, String to) {
    if (favorites.remove(from)) favorites.add(to);
    final g = groups.remove(from);
    if (g != null) groups[to] = g;
  }
}

/// A folder of schematics, previewed: top-down thumbnails, sizes, favourites,
/// groups and renaming, without opening each file in the game.
class SchematicOrganizerTool extends StatefulWidget {
  const SchematicOrganizerTool({super.key, required this.host});

  final McToolHost host;

  @override
  State<SchematicOrganizerTool> createState() => _SchematicOrganizerToolState();
}

class _SchematicOrganizerToolState extends State<SchematicOrganizerTool> {
  _Library? _library;
  List<_Entry> _entries = [];
  bool _recursive = true;
  bool _scanning = false;
  String _query = '';
  _Sort _sort = _Sort.modified;
  String? _filter;
  int _generation = 0;

  static final _extensions = SchematicFormat.allExtensions.toSet();

  @override
  void initState() {
    super.initState();
    _Library.load().then((lib) {
      if (!mounted) return;
      setState(() => _library = lib);
      final folder = lib.folder;
      if (folder != null && Directory(folder).existsSync()) _scan(folder);
    });
  }

  Future<void> _pickFolder() async {
    final path = await FilePicker.getDirectoryPath(dialogTitle: L.of(context).mcOrgChooseFolderTitle);
    if (path == null) return;
    _library?.folder = path;
    await _library?.save();
    await _scan(path);
  }

  Future<void> _scan(String path) async {
    final generation = ++_generation;
    setState(() {
      _scanning = true;
      _entries = [];
    });
    final found = <_Entry>[];
    try {
      await for (final e in Directory(path).list(recursive: _recursive, followLinks: false)) {
        if (e is! File) continue;
        final name = e.uri.pathSegments.last;
        final dot = name.lastIndexOf('.');
        if (dot < 0 || !_extensions.contains(name.substring(dot + 1).toLowerCase())) continue;
        found.add(_Entry(e, await e.stat()));
        if (found.length >= 2000) break;
      }
    } on FileSystemException catch (e) {
      if (mounted) mcToast(context, L.of(context).mcOrgFolderError(e.message));
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _entries = found;
      _scanning = false;
    });
    for (final entry in List.of(found)) {
      if (!mounted || generation != _generation) return;
      await _summarizeEntry(entry);
    }
  }

  Future<void> _summarizeEntry(_Entry entry) async {
    if (entry.stat.size > 64 * 1024 * 1024) {
      entry.summary = const _Summary(error: _tooLarge);
      if (mounted) setState(() {});
      return;
    }
    final bytes = await entry.file.readAsBytes();
    final name = entry.name;
    final summary = await Isolate.run(() => _summarize(bytes, name));
    ui.Image? image;
    final thumb = summary.thumb;
    if (thumb != null) {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        thumb,
        summary.thumbSize,
        summary.thumbSize,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      image = await completer.future;
    }
    if (!mounted) return;
    setState(() {
      entry.summary = summary;
      entry.thumb = image;
    });
  }

  Future<void> _rename(_Entry entry) async {
    final t = L.of(context);
    final controller = TextEditingController(text: entry.stem);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.mcOrgRenameTitle),
        content: SizedBox(
          width: lumaDialogWidth(context, 360),
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(suffixText: '.${entry.extension}'),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t.mcCancel)),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(t.mcOrgRename)),
        ],
      ),
    );
    controller.dispose();
    final clean = name?.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
    if (clean == null || clean.isEmpty || clean == entry.stem) return;
    final target = File('${entry.file.parent.path}${Platform.pathSeparator}$clean.${entry.extension}');
    if (await target.exists()) {
      if (mounted) mcToast(context, t.mcOrgExists(target.uri.pathSegments.last));
      return;
    }
    try {
      final from = entry.file.path;
      entry.file = await entry.file.rename(target.path);
      _library?.moved(from, entry.file.path);
      await _library?.save();
      if (mounted) setState(() {});
    } on FileSystemException catch (e) {
      if (mounted) mcToast(context, t.mcOrgRenameError(e.message));
    }
  }

  Future<void> _group(_Entry entry) async {
    final t = L.of(context);
    final existing = _library!.groups.values.toSet().toList()..sort();
    final controller = TextEditingController(text: _library!.groups[entry.file.path] ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.mcOrgGroup),
        content: SizedBox(
          width: lumaDialogWidth(context, 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(hintText: t.mcOrgGroupHint),
                onSubmitted: (v) => Navigator.pop(context, v),
              ),
              if (existing.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final g in existing)
                      ActionChip(label: Text(g), onPressed: () => Navigator.pop(context, g)),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, ''), child: Text(t.mcOrgNoGroup)),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(t.mcSave)),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    setState(() {
      if (result.trim().isEmpty) {
        _library!.groups.remove(entry.file.path);
      } else {
        _library!.groups[entry.file.path] = result.trim();
      }
    });
    await _library!.save();
  }

  Future<void> _preview(_Entry entry) async {
    final bytes = await entry.file.readAsBytes();
    Schematic schematic;
    try {
      schematic = await mcLoadSchematic(bytes, entry.name);
    } on Object catch (e) {
      if (mounted) mcToast(context, L.of(context).mcOrgReadError(entry.name, '$e'));
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820, maxHeight: 760),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: McHeading(entry.stem, size: 20)),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    child: McFormColumn(
                      children: [
                        SchematicViewer(schematic: schematic),
                        for (final m in schematic.materials().take(30)) McMaterialRow(material: m),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final lib = _library;
    final groups = lib == null ? <String>[] : (lib.groups.values.toSet().toList()..sort());
    final q = _query.trim().toLowerCase();
    final visible = _entries.where((e) {
      if (q.isNotEmpty && !e.name.toLowerCase().contains(q)) return false;
      if (_filter == '★') return lib?.favorites.contains(e.file.path) ?? false;
      if (_filter != null) return lib?.groups[e.file.path] == _filter;
      return true;
    }).toList()
      ..sort((a, b) => switch (_sort) {
        _Sort.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        _Sort.modified => b.stat.modified.compareTo(a.stat.modified),
        _Sort.size => b.stat.size.compareTo(a.stat.size),
        _Sort.blocks => (b.summary?.blocks ?? -1).compareTo(a.summary?.blocks ?? -1),
      });
    // Favourites float to the top within the chosen order.
    visible.sort((a, b) {
      final fa = lib?.favorites.contains(a.file.path) ?? false;
      final fb = lib?.favorites.contains(b.file.path) ?? false;
      return fa == fb ? 0 : (fa ? -1 : 1);
    });

    return widget.host.frame(
      context,
      actions: [
        McButton(
          label: lib?.folder == null ? t.mcOrgChooseFolder : t.mcOrgChangeFolder,
          icon: Icons.folder_open_rounded,
          onTap: lib == null ? null : _pickFolder,
        ),
        if (lib?.folder != null)
          McButton(
            label: t.mcOrgRescan,
            icon: Icons.refresh_rounded,
            primary: false,
            busy: _scanning,
            onTap: () => _scan(lib!.folder!),
          ),
      ],
      child: lib?.folder == null
          ? McPanel(
              child: McHint(
                icon: Icons.folder_special_rounded,
                title: t.mcOrgPointTitle,
                body: t.mcOrgPointBody,
                action: McButton(
                  label: t.mcOrgChooseFolder,
                  icon: Icons.folder_open_rounded,
                  onTap: lib == null ? null : _pickFolder,
                ),
              ),
            )
          : McFormColumn(
              children: [
                Text(
                  lib!.folder!,
                  style: mcMono(context, size: 12, color: luma.textMuted),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 240,
                      child: McTextField(
                        hint: t.mcOrgSearch,
                        prefixIcon: Icons.search_rounded,
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                    SizedBox(
                      width: 170,
                      child: McDropdown<_Sort>(
                        values: _Sort.values,
                        value: _sort,
                        label: (s) => t.mcOrgSortBy(s.label(t)),
                        onChanged: (s) => setState(() => _sort = s),
                      ),
                    ),
                    FilterChip(
                      label: Text(t.mcOrgSubfolders),
                      selected: _recursive,
                      onSelected: (v) {
                        setState(() => _recursive = v);
                        _scan(lib.folder!);
                      },
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: Text(t.mcOrgAll(_entries.length)),
                      selected: _filter == null,
                      onSelected: (_) => setState(() => _filter = null),
                    ),
                    ChoiceChip(
                      label: Text(t.mcOrgFavourites),
                      selected: _filter == '★',
                      onSelected: (_) => setState(() => _filter = '★'),
                    ),
                    for (final g in groups)
                      ChoiceChip(
                        label: Text(g),
                        selected: _filter == g,
                        onSelected: (_) => setState(() => _filter = g),
                      ),
                  ],
                ),
                if (_scanning)
                  const LinearProgressIndicator(minHeight: 2)
                else if (visible.isEmpty)
                  McPanel(
                    child: McHint(
                      icon: Icons.search_off_rounded,
                      title: _entries.isEmpty ? t.mcOrgEmpty : t.mcOrgNothing,
                      body: t.mcOrgLookingFor('.${SchematicFormat.allExtensions.join(', .')}'),
                    ),
                  ),
                McGrid(
                  minTileWidth: 210,
                  spacing: 12,
                  children: [
                    for (final e in visible)
                      _EntryCard(
                        entry: e,
                        favorite: lib.favorites.contains(e.file.path),
                        group: lib.groups[e.file.path],
                        onFavorite: () {
                          setState(() {
                            if (!lib.favorites.remove(e.file.path)) lib.favorites.add(e.file.path);
                          });
                          lib.save();
                        },
                        onRename: () => _rename(e),
                        onGroup: () => _group(e),
                        onOpen: () => _preview(e),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.favorite,
    required this.group,
    required this.onFavorite,
    required this.onRename,
    required this.onGroup,
    required this.onOpen,
  });

  final _Entry entry;
  final bool favorite;
  final String? group;
  final VoidCallback onFavorite;
  final VoidCallback onRename;
  final VoidCallback onGroup;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final s = entry.summary;
    final kb = entry.stat.size / 1024;
    final size = kb > 1024 ? '${(kb / 1024).toStringAsFixed(1)} MB' : '${kb.toStringAsFixed(0)} KB';
    final date = entry.stat.modified;
    return Material(
      color: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: favorite ? McHue.amber.color : luma.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1.5,
              child: Container(
                color: luma.surfaceHover,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (entry.thumb != null)
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: RawImage(
                          image: entry.thumb,
                          filterQuality: FilterQuality.none,
                          fit: BoxFit.contain,
                        ),
                      )
                    else if (s?.error != null)
                      Center(
                        child: Text(
                          switch (s!.error!) {
                            _unreadable => t.mcOrgUnreadable,
                            _tooLarge => t.mcOrgTooLarge,
                            final other => other,
                          },
                          textAlign: TextAlign.center,
                          style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                        ),
                      )
                    else
                      const Center(
                        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    Positioned(left: 8, top: 8, child: McTag(entry.extension, hue: McHue.sky)),
                    Positioned(
                      right: 2,
                      top: 2,
                      child: IconButton(
                        tooltip: favorite ? t.mcOrgUnfavourite : t.mcOrgFavourite,
                        onPressed: onFavorite,
                        icon: Icon(
                          favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: favorite ? McHue.amber.color : luma.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.stem,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        Text(
                          [
                            if (s != null && s.error == null) '${s.width}×${s.height}×${s.length}',
                            if (s != null && s.error == null) t.mcOrgBlocks(s.blocks),
                            size,
                          ].join(' · '),
                          style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                        ),
                        Text(
                          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
                          '${group == null ? '' : ' · $group'}',
                          style: TextStyle(color: luma.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: t.mcOrgMore,
                    onSelected: (v) => switch (v) {
                      'rename' => onRename(),
                      'group' => onGroup(),
                      _ => onOpen(),
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'open', child: Text(t.mcOrgPreview)),
                      PopupMenuItem(value: 'rename', child: Text(t.mcOrgRenameMenu)),
                      PopupMenuItem(value: 'group', child: Text(t.mcOrgGroupMenu)),
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
}
