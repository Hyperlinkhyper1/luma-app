import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../theme/luma_theme.dart';
import '../converter_widgets.dart';
import '../world/world_conversion.dart';
import '../world/world_converter_service.dart';

class WorldConverterView extends StatefulWidget {
  const WorldConverterView({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  State<WorldConverterView> createState() => _WorldConverterViewState();
}

class _WorldConverterViewState extends State<WorldConverterView> {
  final _service = WorldConverterService();
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
    final name = source
        .replaceAll('\\', '/')
        .split('/')
        .where((s) => s.isNotEmpty)
        .last;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await _service.convert(
        source: source,
        destination:
            '$parent/${name}_${_target.edition.name}_${_target.version}',
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
                  'Close this world in Minecraft before converting. Select its folder containing level.dat. The original stays unchanged.',
                  style: TextStyle(color: luma.textSecondary),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickWorld,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Choose world folder'),
                ),
                if (_source != null)
                  Text(_source!, style: TextStyle(color: luma.textMuted)),
                if (census != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${census.edition.label} · ${census.entities.length} entities · ${census.localPlayer ? 1 : 0} local player · ${census.remotePlayers} additional players',
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
                          'Mobs, pets, villagers, vehicles and passengers. Every source entity must match a saved output record or conversion fails.',
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
                        subtitle: const Text(
                          'Single-player inventory, equipment and position. Additional players require account mappings and cause an error when selected.',
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
