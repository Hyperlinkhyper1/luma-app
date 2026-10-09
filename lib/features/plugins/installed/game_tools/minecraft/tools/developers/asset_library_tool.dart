import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../../theme/luma_theme.dart';
import '../../../../../../converter/schematic/textures/texture_downloader.dart';
import '../../../../../../converter/schematic/textures/texture_pack_source.dart';
import '../../mc_tool_host.dart';
import '../../ui/mc_files.dart';
import '../../ui/mc_style.dart';

/// One texture inside the jar.
class _Texture {
  _Texture(this.path, this.file);

  /// `block/oak_planks.png`, relative to `textures/`.
  final String path;
  final ArchiveFile file;

  String get category => path.split('/').first;
  String get name => path.split('/').last.replaceAll('.png', '');
  Uint8List? _bytes;
  Uint8List get bytes => _bytes ??= Uint8List.fromList(file.content);
}

/// One sound from the game's asset index.
class _Sound {
  const _Sound(this.key, this.file);

  /// `entity/creeper/primed.ogg`, relative to `minecraft/sounds/`.
  final String key;
  final File file;

  String get category => key.split('/').first;
}

/// Every block, item and mob texture, and every sound, read from the copy of
/// Minecraft on this machine. luma ships none of them: they are listed from
/// the user's own client jar and asset index, or from a jar fetched from
/// Mojang when the user asks for one.
class AssetLibraryTool extends StatefulWidget {
  const AssetLibraryTool({super.key, required this.host});

  final McToolHost host;

  @override
  State<AssetLibraryTool> createState() => _AssetLibraryToolState();
}

class _AssetLibraryToolState extends State<AssetLibraryTool> {
  List<TexturePackSource>? _sources;
  TexturePackSource? _source;
  InputFileStream? _stream;
  List<_Texture> _textures = [];
  List<_Sound> _sounds = [];
  bool _loading = false;
  String? _status;
  String _category = 'block';
  String _query = '';
  bool _soundsTab = false;
  _Texture? _selected;
  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    findTextureSources().then((found) {
      if (!mounted) return;
      setState(() => _sources = found);
      if (found.isNotEmpty) _open(found.first);
    });
  }

  @override
  void dispose() {
    _stream?.closeSync();
    _player.dispose();
    super.dispose();
  }

  Future<void> _open(TexturePackSource source) async {
    setState(() {
      _loading = true;
      _status = null;
      _source = source;
      _selected = null;
    });
    try {
      _stream?.closeSync();
      final stream = InputFileStream(source.path);
      final archive = ZipDecoder().decodeStream(stream);
      final textures = <_Texture>[];
      for (final f in archive.files) {
        const prefix = 'assets/minecraft/textures/';
        if (!f.isFile || !f.name.startsWith(prefix) || !f.name.endsWith('.png')) continue;
        textures.add(_Texture(f.name.substring(prefix.length), f));
      }
      textures.sort((a, b) => a.path.compareTo(b.path));
      final sounds = await _findSounds(source);
      if (!mounted) return;
      setState(() {
        _stream = stream;
        _textures = textures;
        _sounds = sounds;
        _loading = false;
        if (!_categories.contains(_category) && _categories.isNotEmpty) {
          _category = _categories.first;
        }
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = L.of(context).mcAssetReadError(source.label, '$e');
      });
    }
  }

  /// Sounds are not in the jar: they live in the launcher's shared asset
  /// store, listed by the version's asset index.
  Future<List<_Sound>> _findSounds(TexturePackSource source) async {
    try {
      final jar = File(source.path);
      final versionDir = jar.parent;
      final gameDir = versionDir.parent.parent;
      final sep = Platform.pathSeparator;
      final versionJson = File('${versionDir.path}$sep${versionDir.uri.pathSegments.where((s) => s.isNotEmpty).last}.json');
      if (!await versionJson.exists()) return const [];
      final meta = jsonDecode(await versionJson.readAsString()) as Map<String, dynamic>;
      final indexId = (meta['assetIndex'] as Map?)?['id'] as String? ?? meta['assets'] as String?;
      if (indexId == null) return const [];
      final index = File('${gameDir.path}${sep}assets${sep}indexes$sep$indexId.json');
      if (!await index.exists()) return const [];
      final objects = (jsonDecode(await index.readAsString()) as Map<String, dynamic>)['objects'] as Map<String, dynamic>;
      final out = <_Sound>[];
      const prefix = 'minecraft/sounds/';
      for (final e in objects.entries) {
        if (!e.key.startsWith(prefix) || !e.key.endsWith('.ogg')) continue;
        final hash = (e.value as Map)['hash'] as String;
        final file = File('${gameDir.path}${sep}assets${sep}objects$sep${hash.substring(0, 2)}$sep$hash');
        out.add(_Sound(e.key.substring(prefix.length), file));
      }
      out.sort((a, b) => a.key.compareTo(b.key));
      return out;
    } on Object {
      return const [];
    }
  }

  Future<void> _pickJar() async {
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['jar', 'zip']);
    final path = picked?.files.firstOrNull?.path;
    if (path == null) return;
    final name = path.split(RegExp(r'[\\/]')).last;
    await _open(TexturePackSource(path: path, label: name, version: '', isResourcePack: name.endsWith('.zip')));
  }

  Future<void> _download() async {
    setState(() {
      _loading = true;
      _status = L.of(context).mcAssetAsking;
    });
    try {
      final path = await downloadVanillaTextures(
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _status = p.total > 0
              ? '${p.stage} ${(p.received / 1048576).toStringAsFixed(1)} / ${(p.total / 1048576).toStringAsFixed(1)} MB'
              : p.stage);
        },
      );
      final found = await findTextureSources();
      if (!mounted) return;
      setState(() => _sources = found);
      final source = found.firstWhere((s) => s.path == path, orElse: () => TexturePackSource(path: path, label: 'Minecraft', version: ''));
      await _open(source);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = L.of(context).mcAssetDownloadFailed('$e');
      });
    }
  }

  List<String> get _categories {
    final counts = <String, int>{};
    for (final t in _textures) {
      counts[t.category] = (counts[t.category] ?? 0) + 1;
    }
    const preferred = ['block', 'item', 'entity', 'mob_effect', 'painting', 'particle', 'environment', 'gui', 'trims', 'map', 'misc'];
    return [
      ...preferred.where(counts.containsKey),
      ...(counts.keys.where((k) => !preferred.contains(k)).toList()..sort()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final sources = _sources;
    final source = _source;
    if (sources == null) {
      return widget.host.frame(context, child: const Center(child: CircularProgressIndicator()));
    }
    if (source == null) {
      return widget.host.frame(
        context,
        child: McPanel(
          child: McHint(
            icon: Icons.photo_library_rounded,
            title: _status ?? t.mcAssetNoCopy,
            body: t.mcAssetNoCopyBody((kApproximateClientJarBytes / 1048576).round()),
            action: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                McButton(label: t.mcAssetChooseJar, icon: Icons.folder_open_rounded, onTap: _pickJar),
                McButton(label: t.mcAssetDownload, icon: Icons.cloud_download_rounded, primary: false, busy: _loading, onTap: _download),
              ],
            ),
          ),
        ),
      );
    }

    final q = _query.trim().toLowerCase().replaceAll(' ', '_');
    final textures = _textures
        .where((t) => q.isNotEmpty ? t.path.contains(q) : t.category == _category)
        .take(600)
        .toList();
    final sounds = _sounds.where((s) => q.isEmpty || s.key.contains(q)).take(400).toList();

    return widget.host.frame(
      context,
      actions: [
        SizedBox(
          width: 220,
          child: McDropdown<TexturePackSource>(
            values: [...sources, if (!sources.contains(source)) source],
            value: source,
            label: (s) => s.label,
            onChanged: _open,
          ),
        ),
        McButton(label: t.mcAssetOtherFile, icon: Icons.folder_open_rounded, primary: false, onTap: _pickJar),
      ],
      child: McFormColumn(
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_status != null) Text(_status!, style: TextStyle(color: luma.warning, fontSize: 12.5)),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              McChoice<bool>(
                values: const [false, true],
                selected: _soundsTab,
                label: (v) => v ? t.mcAssetSounds(_sounds.length) : t.mcAssetImages(_textures.length),
                icon: (v) => v ? Icons.volume_up_rounded : Icons.image_rounded,
                onSelect: (v) => setState(() => _soundsTab = v),
              ),
              SizedBox(
                width: 260,
                child: McTextField(
                  hint: t.mcAssetSearch,
                  prefixIcon: Icons.search_rounded,
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            ],
          ),
          if (!_soundsTab) ...[
            if (q.isEmpty)
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (final c in _categories)
                    ChoiceChip(
                      label: Text(mcPretty(c)),
                      selected: c == _category,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                ],
              ),
            if (_selected != null) _TextureDetail(texture: _selected!, onClose: () => setState(() => _selected = null)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in textures)
                  Tooltip(
                    message: t.path,
                    waitDuration: const Duration(milliseconds: 400),
                    child: InkWell(
                      onTap: () => setState(() => _selected = t),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 64,
                        height: 64,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: luma.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: t == _selected ? luma.accent : luma.border),
                        ),
                        child: _FirstFrame(bytes: t.bytes),
                      ),
                    ),
                  ),
              ],
            ),
            if (textures.length >= 600)
              Text(t.mcAssetFirst600, style: TextStyle(color: luma.textMuted, fontSize: 12)),
          ] else if (_sounds.isEmpty)
            McPanel(
              child: McHint(
                icon: Icons.volume_off_rounded,
                title: t.mcAssetNoSounds,
                body: t.mcAssetNoSoundsBody,
              ),
            )
          else
            McPanel(
              padding: const EdgeInsets.all(6),
              child: Column(
                children: [
                  for (final s in sounds)
                    ListTile(
                      dense: true,
                      leading: IconButton(
                        tooltip: t.mcAssetPlay,
                        icon: Icon(Icons.play_circle_rounded, color: luma.accent),
                        onPressed: () async {
                          try {
                            await _player.stop();
                            await _player.play(DeviceFileSource(s.file.path, mimeType: 'audio/ogg'));
                          } on Object {
                            if (context.mounted) {
                              mcToast(context, t.mcAssetCannotPlay);
                            }
                          }
                        },
                      ),
                      title: Text(s.key.replaceAll('.ogg', ''), style: mcMono(context, size: 12.5)),
                      subtitle: Text(mcPretty(s.category), style: TextStyle(color: luma.textMuted, fontSize: 11)),
                      trailing: McIconButton(
                        icon: Icons.download_rounded,
                        tooltip: t.mcAssetSaveOgg,
                        onTap: () async {
                          final bytes = await s.file.readAsBytes();
                          if (!context.mounted) return;
                          await mcSaveBytes(context, bytes, fileName: s.key.split('/').last, mimeType: 'audio/ogg');
                        },
                      ),
                    ),
                ],
              ),
            ),
          Text(
            t.mcAssetNotice,
            style: TextStyle(color: luma.textMuted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

/// Shows a texture's first frame: animated textures are vertical strips.
class _FirstFrame extends StatelessWidget {
  const _FirstFrame({required this.bytes, this.size});

  final Uint8List bytes;
  final double? size;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Image.memory(
        bytes,
        filterQuality: FilterQuality.none,
        fit: BoxFit.fitWidth,
        alignment: Alignment.topCenter,
        width: size,
        height: size,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, size: 18),
      ),
    );
  }
}

class _TextureDetail extends StatelessWidget {
  const _TextureDetail({required this.texture, required this.onClose});

  final _Texture texture;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final id = texture.path.replaceAll('.png', '');
    return McPanel(
      title: mcPretty(texture.name),
      icon: Icons.image_rounded,
      trailing: McIconButton(icon: Icons.close_rounded, tooltip: t.mcAssetClose, onTap: onClose),
      child: Wrap(
        spacing: 20,
        runSpacing: 14,
        children: [
          Container(
            width: 192,
            height: 192,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: luma.surfaceHover, borderRadius: BorderRadius.circular(10)),
            child: _FirstFrame(bytes: texture.bytes, size: 168),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: McFormColumn(
              gap: 8,
              children: [
                Text('minecraft:$id', style: mcMono(context, size: 13)),
                Text('assets/minecraft/textures/${texture.path}', style: TextStyle(color: luma.textMuted, fontSize: 12)),
                Text('${(texture.bytes.length / 1024).toStringAsFixed(1)} KB', style: TextStyle(color: luma.textMuted, fontSize: 12)),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    McButton(
                      label: t.mcMapSavePng,
                      icon: Icons.download_rounded,
                      onTap: () => mcSaveBytes(context, texture.bytes, fileName: '${texture.name}.png', mimeType: 'image/png'),
                    ),
                    McButton(
                      label: t.mcAssetCopyId,
                      icon: Icons.copy_rounded,
                      primary: false,
                      onTap: () => mcCopy(context, 'minecraft:$id'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
