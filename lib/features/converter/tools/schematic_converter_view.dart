import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../theme/luma_theme.dart';
import '../converter_widgets.dart';
import '../file_saver.dart';
import '../schematic/block_colors.dart';
import '../schematic/schematic_model.dart';
import '../schematic/schematic_service.dart';
import 'schematic_viewer.dart';

/// Converts between the Minecraft block formats — Sponge `.schem`, Litematica
/// `.litematic`, MCEdit `.schematic`, vanilla `.nbt` structures and Bedrock
/// `.mcstructure` — and previews the build in 3D while you do it.
class SchematicConverterView extends StatefulWidget {
  const SchematicConverterView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<SchematicConverterView> createState() => _SchematicConverterViewState();
}

class _SchematicConverterViewState extends State<SchematicConverterView> {
  String? _name;
  int _size = 0;
  Schematic? _schematic;

  SchematicFormat _target = SchematicFormat.litematic;
  bool _loading = false;
  bool _converting = false;
  String? _error;
  SaveResult? _result;
  List<String> _exportNotes = const <String>[];

  Future<void> _pickFile() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: SchematicFormat.allExtensions,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _error = 'Could not read the selected file.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _exportNotes = const <String>[];
      _schematic = null;
      _name = file.name;
      _size = file.size;
    });

    // Let the spinner paint before the parse takes over the frame; a large
    // build can take a moment to decompress and unpack.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    try {
      final schematic = SchematicService.load(bytes, file.name);
      setState(() {
        _loading = false;
        _schematic = schematic;
        // Default to something other than what was opened, since converting a
        // file to its own format is rarely what is wanted.
        _target = schematic.sourceFormat == SchematicFormat.litematic
            ? SchematicFormat.sponge
            : SchematicFormat.litematic;
      });
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Something went wrong while reading that file: $e';
      });
    }
  }

  Future<void> _convert() async {
    final schematic = _schematic;
    final name = _name;
    if (schematic == null || name == null) return;

    setState(() {
      _converting = true;
      _error = null;
      _result = null;
      _exportNotes = const <String>[];
    });

    try {
      final export = SchematicService.save(schematic, _target);
      final save = await saveConvertedFile(
        bytes: export.bytes,
        suggestedName: SchematicService.suggestFileName(name, _target),
        mimeType: 'application/octet-stream',
        extensions: [_target.extension],
      );
      if (!mounted) return;
      setState(() {
        _converting = false;
        _result = save;
        _exportNotes = export.notes;
      });
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _converting = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _converting = false;
        _error = 'Something went wrong while converting: $e';
      });
    }
  }

  void _reset() {
    setState(() {
      _name = null;
      _size = 0;
      _schematic = null;
      _result = null;
      _error = null;
      _exportNotes = const <String>[];
    });
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final schematic = _schematic;

    return ToolScaffold(
      icon: Icons.view_in_ar_outlined,
      title: 'Minecraft schematics',
      subtitle: 'Convert between schem, litematic, schematic, nbt and '
          'mcstructure',
      onBack: widget.onBack,
      children: [
        if (schematic == null && !_loading)
          ConverterDropZone(
            onTap: _pickFile,
            icon: Icons.view_in_ar_outlined,
            title: 'Click to choose a build',
            subtitle: 'SCHEM · LITEMATIC · SCHEMATIC · NBT · MCSTRUCTURE',
          )
        else
          ConverterFileCard(
            name: _name ?? '',
            icon: Icons.view_in_ar_outlined,
            meta: formatBytes(_size),
            badge: schematic?.sourceFormat == null
                ? null
                : FormatChip(label: schematic!.sourceFormat!.label),
            onChange: _pickFile,
          ),

        if (_loading) ...[
          const SizedBox(height: 16),
          ConverterCard(
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation(luma.accent),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'Reading the build…',
                  style: TextStyle(color: luma.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ],

        if (schematic != null) ...[
          const SizedBox(height: 16),
          _BuildSummary(schematic: schematic),
          const SizedBox(height: 16),
          ConverterCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FormatTransition(
                  source: schematic.sourceFormat?.label ?? 'BUILD',
                  target: _target.label,
                ),
                const SizedBox(height: 20),
                Text(
                  'Convert to',
                  style: TextStyle(
                    color: luma.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final format in SchematicFormat.values)
                      _FormatPill(
                        label: format.label,
                        selected: format == _target,
                        onTap: _converting
                            ? null
                            : () => setState(() => _target = format),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _target.description,
                  style: TextStyle(color: luma.textMuted, fontSize: 12.5),
                ),
                if (_target.isBedrock) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Bedrock uses different block ids and states from Java, so '
                    'this direction is a best-effort translation.',
                    style: TextStyle(color: luma.textMuted, fontSize: 12.5),
                  ),
                ],
                const SizedBox(height: 16),
                ConverterPrimaryButton(
                  label: kIsWeb ? 'Convert & download' : 'Convert & save',
                  icon: Icons.bolt_rounded,
                  loading: _converting,
                  onTap: _convert,
                ),
              ],
            ),
          ),
        ],

        if (_error != null) ...[
          const SizedBox(height: 16),
          ConverterBanner(
            icon: Icons.error_outline_rounded,
            color: luma.danger,
            message: _error!,
          ),
        ],

        if (_result != null && _result!.saved) ...[
          const SizedBox(height: 16),
          ConverterBanner(
            icon: Icons.check_circle_outline_rounded,
            color: luma.success,
            message: _result!.summary,
            trailing:
                ConverterTextButton(label: 'Convert another', onTap: _reset),
          ),
        ],

        if (schematic != null) ...[
          if (schematic.notes.isNotEmpty || _exportNotes.isNotEmpty) ...[
            const SizedBox(height: 16),
            _NotesCard(notes: [...schematic.notes, ..._exportNotes]),
          ],
          const SizedBox(height: 24),
          _SectionHeading(
            icon: Icons.threed_rotation_rounded,
            title: '3D preview',
            hint: 'Drag to orbit · scroll to zoom',
          ),
          const SizedBox(height: 12),
          SchematicViewer(
            // A new build needs a fresh camera and layer range, not the last
            // one's.
            key: ObjectKey(schematic),
            schematic: schematic,
          ),
          const SizedBox(height: 24),
          _SectionHeading(
            icon: Icons.grid_view_rounded,
            title: 'Materials',
            hint: '${schematic.blockCount} blocks',
          ),
          const SizedBox(height: 12),
          _MaterialList(schematic: schematic),
        ],
      ],
    );
  }
}

/// Dimensions, block count and palette size for the opened build.
class _BuildSummary extends StatelessWidget {
  const _BuildSummary({required this.schematic});
  final Schematic schematic;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return ConverterCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stats = <(String, String)>[
            (
              'Size',
              '${schematic.width} × ${schematic.height} × ${schematic.length}',
            ),
            ('Blocks', _thousands(schematic.blockCount)),
            ('Volume', _thousands(schematic.volume)),
            ('Block types', _thousands(schematic.palette.length - 1)),
          ];
          final columns = constraints.maxWidth >= 460 ? 4 : 2;
          return Wrap(
            spacing: 0,
            runSpacing: 16,
            children: [
              for (final (label, value) in stats)
                SizedBox(
                  width: constraints.maxWidth / columns,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label.toUpperCase(),
                        style: TextStyle(
                          color: luma.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Anything the conversion had to approximate, listed rather than hidden.
class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes});
  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: luma.accentSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: luma.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: luma.accent),
              const SizedBox(width: 10),
              Text(
                'Worth knowing',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final note in notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4, right: 10),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: luma.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      note,
                      style: TextStyle(
                        color: luma.textSecondary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The build's block tally, most-used first — the shopping list you would take
/// into the world to build it.
class _MaterialList extends StatefulWidget {
  const _MaterialList({required this.schematic});
  final Schematic schematic;

  @override
  State<_MaterialList> createState() => _MaterialListState();
}

class _MaterialListState extends State<_MaterialList> {
  static const int _collapsedCount = 8;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final materials = widget.schematic.materials();
    if (materials.isEmpty) {
      return ConverterCard(
        child: Text(
          'This build has no blocks in it.',
          style: TextStyle(color: luma.textSecondary, fontSize: 13),
        ),
      );
    }

    final shown =
        _expanded ? materials : materials.take(_collapsedCount).toList();

    return ConverterCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: BlockColors.of(shown[i].state),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: luma.border),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _prettyName(shown[i].state),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _thousands(shown[i].count),
                  style: TextStyle(
                    color: luma.textSecondary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
          if (materials.length > _collapsedCount) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: ConverterTextButton(
                label: _expanded
                    ? 'Show fewer'
                    : 'Show all ${materials.length} block types',
                onTap: () => setState(() => _expanded = !_expanded),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    required this.hint,
  });

  final IconData icon;
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        Icon(icon, size: 18, color: luma.textSecondary),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          hint,
          style: TextStyle(color: luma.textMuted, fontSize: 12.5),
        ),
      ],
    );
  }
}

class _FormatPill extends StatelessWidget {
  const _FormatPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor:
          onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? luma.accentSubtle : luma.surfaceHover,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? luma.accent : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? luma.accent : luma.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

/// `minecraft:oak_stairs[facing=north]` reads better as
/// `Oak stairs · facing north`.
String _prettyName(BlockState state) {
  final words = state.shortName.split('_').join(' ');
  final label = words.isEmpty
      ? state.name
      : '${words[0].toUpperCase()}${words.substring(1)}';
  if (state.properties.isEmpty) return label;
  final keys = state.properties.keys.toList()..sort();
  final detail =
      keys.map((k) => '${k.replaceAll('_', ' ')} ${state.properties[k]}')
          .join(', ');
  return '$label · $detail';
}

String _thousands(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
