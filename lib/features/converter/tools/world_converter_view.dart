import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../theme/luma_theme.dart';
import '../converter_widgets.dart';
import '../world/world_conversion.dart';
import '../world/world_converter_service.dart';

class WorldConverterView extends StatefulWidget {
  const WorldConverterView({super.key, required this.onBack, this.service});
  final VoidCallback onBack;
  final WorldConverterService? service;

  @override
  State<WorldConverterView> createState() => _WorldConverterViewState();
}

class _WorldConverterViewState extends State<WorldConverterView> {
  late final _service = widget.service ?? WorldConverterService();
  final _sourcePath = TextEditingController();
  String? _source;
  String? _outputParent;
  WorldCensus? _census;
  WorldTarget _target = WorldTarget.latest(WorldEdition.bedrock);
  bool _entities = true;
  bool _players = true;
  bool _statistics = true;
  bool _busy = false;
  String? _progress;
  String? _error;
  WorldConversionResult? _result;

  Future<void> _pickWorld() async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select the world folder containing level.dat',
    );
    if (path == null || !mounted) return;
    await _loadWorld(path);
  }

  Future<void> _pickArchive() async {
    final files = await FilePicker.pickFiles(
      dialogTitle: 'Select an exported Minecraft world',
      type: FileType.custom,
      allowedExtensions: ['mcworld', 'zip'],
    );
    final path = files?.files.single.path;
    if (path == null || !mounted) return;
    await _loadWorld(path);
  }

  @override
  void dispose() {
    _sourcePath.dispose();
    super.dispose();
  }

  Future<void> _loadWorld(String sourcePath) async {
    final path = normalizeWorldSourcePath(sourcePath);
    if (path.isEmpty) return;
    _sourcePath.text = path;
    setState(() {
      _source = path;
      _census = null;
      _error = null;
      _result = null;
      _busy = true;
      _progress = 'Reading the world…';
    });
    try {
      final census = await _service.inspect(path);
      if (!mounted) return;
      setState(() {
        _census = census;
        _target = WorldTarget.supported.firstWhere(
          (t) => t.edition != census.edition,
        );
      });
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _pickOutput() async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose where to save the converted world',
    );
    if (path != null && mounted) {
      setState(() {
        _outputParent = path;
        _result = null;
      });
    }
  }

  Future<void> _convert() async {
    final source = _source;
    final parent = _outputParent;
    if (source == null || parent == null) return;
    final name = _census?.levelName ?? worldSourceName(source);
    final edition = _target.edition == WorldEdition.java ? 'Java' : 'Bedrock';
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await _service.convert(
        source: source,
        destination: await _service.availableDestination(
          parent,
          '$name ($edition ${_target.displayVersion})',
        ),
        options: WorldConversionOptions(
          target: _target,
          entities: _entities,
          players: _players,
          statistics: _statistics,
        ),
        onProgress: (message) {
          if (mounted) setState(() => _progress = message);
        },
      );
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  String _message(Object e) => e is FormatException ? e.message : e.toString();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final census = _census;
    return ToolScaffold(
      icon: Icons.public_rounded,
      title: 'Minecraft world converter',
      subtitle: 'Java ↔ Bedrock · terrain, entities and player data',
      onBack: _busy ? () {} : widget.onBack,
      children: [
        if (!_service.supported)
          ConverterBanner(
            icon: Icons.info_outline,
            color: luma.accent,
            message: 'World conversion is available on Windows and Linux.',
          )
        else ...[
          ConverterCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Close this world in Minecraft before converting. Choose its folder or an exported .mcworld / .zip file, or paste its path below. The original stays unchanged.',
                  style: TextStyle(color: luma.textSecondary),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickWorld,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Choose world folder'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickArchive,
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('Choose .mcworld file'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _sourcePath,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'World folder or .mcworld / .zip path',
                    hintText: 'Paste a path here',
                  ),
                  onChanged: (_) => setState(() {
                    _census = null;
                    _source = null;
                    _result = null;
                    _error = null;
                  }),
                  onSubmitted: _busy ? null : _loadWorld,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _loadWorld(_sourcePath.text),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Load world'),
                ),
                if (census != null) ...[
                  const SizedBox(height: 12),
                  if (census.levelName case final levelName?)
                    Text(
                      levelName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  Text(
                    '${census.edition.label} · ${census.entities.length} entities · ${census.localPlayer ? 1 : 0} local player · ${census.remotePlayers} additional players',
                  ),
                  for (final warning in census.warnings)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        warning,
                        style: TextStyle(color: luma.textSecondary),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          ConverterCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<WorldEdition>(
                  key: ValueKey(_target.edition),
                  initialValue: _target.edition,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Convert to'),
                  items: WorldEdition.values
                      .map(
                        (e) => DropdownMenuItem(value: e, child: Text(e.label)),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (edition) {
                          if (edition != null) {
                            setState(() {
                              _target = WorldTarget.supported.firstWhere(
                                (t) => t.edition == edition,
                              );
                              _result = null;
                            });
                          }
                        },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<WorldTarget>(
                  key: ValueKey(_target),
                  initialValue: _target,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Target Minecraft version',
                  ),
                  items: WorldTarget.supported
                      .where((t) => t.edition == _target.edition)
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.displayVersion),
                        ),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (target) {
                          if (target != null) {
                            setState(() {
                              _target = target;
                              _result = null;
                            });
                          }
                        },
                ),
                const SizedBox(height: 8),
                Text(
                  'Java 1.8.8–26.3 and Bedrock 1.12–1.26.60 release formats. Targets before Java 1.13 or Bedrock 1.18.30 require excluding entities and players. Incompatible selected records cause an error. Custom dimensions are refused.',
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Material(
                  type: MaterialType.transparency,
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Convert entities'),
                        subtitle: const Text(
                          'Mobs, pets, villagers, vehicles and passengers. Every source entity must match a saved output record or conversion fails. Projectiles still in mid-air are listed, not carried over.',
                        ),
                        value: _entities,
                        onChanged: _busy
                            ? null
                            : (v) => setState(() {
                                _entities = v;
                                _result = null;
                              }),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Convert players'),
                        subtitle: Text(
                          census != null && census.remotePlayers > 0
                              ? 'This world has ${census.remotePlayers} additional player records. Turn off Convert players to convert terrain and entities. Moving these players requires account mappings.'
                              : 'Single-player inventory, equipment and position. Additional players require account mappings and cause an error when selected.',
                        ),
                        value: _players,
                        onChanged: _busy
                            ? null
                            : (v) => setState(() {
                                _players = v;
                                _result = null;
                              }),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Preserve statistics'),
                        subtitle: const Text(
                          'Java stats are archived for conversion back to Java. Bedrock has no compatible per-world stats format.',
                        ),
                        value: _statistics,
                        onChanged: _busy
                            ? null
                            : (v) => setState(() {
                                _statistics = v;
                                _result = null;
                              }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickOutput,
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: const Text('Choose output location'),
                ),
                if (_outputParent != null)
                  Text(_outputParent!, style: TextStyle(color: luma.textMuted)),
                if (census != null && census.edition == _target.edition) ...[
                  const SizedBox(height: 8),
                  Text(
                    'This world is already ${census.edition.label}. Choose the other edition to convert it.',
                    style: TextStyle(color: luma.textSecondary),
                  ),
                ],
                const SizedBox(height: 16),
                ConverterPrimaryButton(
                  label: 'Convert & verify world',
                  icon: Icons.swap_horiz_rounded,
                  loading: _busy,
                  onTap:
                      census == null ||
                          _outputParent == null ||
                          census.edition == _target.edition
                      ? null
                      : _convert,
                ),
              ],
            ),
          ),
        ],
        if (_progress != null) ...[
          const SizedBox(height: 16),
          Text(_progress!),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          ConverterBanner(
            icon: Icons.error_outline,
            color: luma.danger,
            message: _error!,
          ),
        ],
        if (_result case final result?) ...[
          const SizedBox(height: 16),
          ConverterBanner(
            icon: Icons.check_circle_outline,
            color: luma.success,
            message:
                'Saved to ${result.path}\n${_entities ? '${result.entityCount} entity records verified.' : 'Entities excluded.'}\n${result.notes.join('\n')}',
          ),
        ],
      ],
    );
  }
}
