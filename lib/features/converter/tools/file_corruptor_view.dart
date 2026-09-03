import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../theme/luma_theme.dart';
import '../converter_widgets.dart';
import '../corruption/binary_utils.dart';
import '../corruption/file_corruptor.dart';
import '../file_saver.dart';

/// Deliberately damages a file, and — unless told otherwise — writes the
/// recipe that takes the damage back off again.
class FileCorruptorView extends StatefulWidget {
  const FileCorruptorView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<FileCorruptorView> createState() => _FileCorruptorViewState();
}

class _FileCorruptorViewState extends State<FileCorruptorView> {
  String? _name;
  Uint8List? _bytes;

  final Set<DamageStyle> _styles = {DamageStyle.bitRot, DamageStyle.scramble};
  DamagePreset _preset = DamagePreset.medium;
  bool _recoverable = true;
  int _seed = _freshSeed();

  bool _working = false;
  String? _error;
  CorruptionResult? _result;
  SaveResult? _fileSave;
  SaveResult? _recipeSave;

  static int _freshSeed() => math.Random().nextInt(0x7FFFFFFF) | 1;

  Future<void> _pickFile() async {
    final picked = await FilePicker.pickFiles(withData: true);
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _error = 'Could not read the selected file.');
      return;
    }
    setState(() {
      _name = file.name;
      _bytes = bytes;
      _error = null;
      _result = null;
      _fileSave = null;
      _recipeSave = null;
    });
  }

  Future<void> _corrupt() async {
    final bytes = _bytes;
    final name = _name;
    if (bytes == null || name == null) return;

    setState(() {
      _working = true;
      _error = null;
      _result = null;
      _fileSave = null;
      _recipeSave = null;
    });

    // Let the spinner paint before a large file takes over the frame.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    try {
      final result = FileCorruptor.corrupt(
        bytes,
        name,
        CorruptionSettings(
          styles: _styles,
          intensity: _preset.intensity,
          seed: _seed,
          recoverable: _recoverable,
        ),
      );
      if (!mounted) return;
      setState(() {
        _working = false;
        _result = result;
      });
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = 'Something went wrong while corrupting that file: $e';
      });
    }
  }

  Future<void> _saveCorrupted() async {
    final result = _result;
    final name = _name;
    if (result == null || name == null) return;
    final suggested = FileCorruptor.suggestCorruptName(name);
    final save = await saveConvertedFile(
      bytes: result.bytes,
      suggestedName: suggested,
      mimeType: 'application/octet-stream',
      extensions: [_extensionOf(suggested)],
    );
    if (!mounted) return;
    setState(() => _fileSave = save);
  }

  Future<void> _saveRecipe() async {
    final result = _result;
    final name = _name;
    final recipe = result?.recipe;
    if (recipe == null || name == null) return;
    final suggested = FileCorruptor.suggestRecipeName(
      FileCorruptor.suggestCorruptName(name),
    );
    final save = await saveConvertedFile(
      bytes: recipe.encode(),
      suggestedName: suggested,
      mimeType: 'application/json',
      extensions: const ['lumafix'],
    );
    if (!mounted) return;
    setState(() => _recipeSave = save);
  }

  void _reset() {
    setState(() {
      _name = null;
      _bytes = null;
      _result = null;
      _error = null;
      _fileSave = null;
      _recipeSave = null;
      _seed = _freshSeed();
    });
  }

  static String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    return dot < 0 || dot == name.length - 1 ? 'bin' : name.substring(dot + 1);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final bytes = _bytes;
    final result = _result;

    return ToolScaffold(
      icon: Icons.broken_image_outlined,
      title: 'File corruptor',
      subtitle: 'Break a file on purpose, and keep the key to unbreak it',
      onBack: widget.onBack,
      children: [
        if (bytes == null)
          ConverterDropZone(
            onTap: _pickFile,
            icon: Icons.bolt_rounded,
            title: 'Click to choose a file',
            subtitle: 'Any file at all — the original is never touched',
          )
        else
          ConverterFileCard(
            name: _name ?? '',
            icon: Icons.insert_drive_file_outlined,
            meta: formatBytes(bytes.length),
            onChange: _pickFile,
          ),

        if (bytes != null) ...[
          const SizedBox(height: 16),
          ConverterCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Heading(label: 'Damage', hint: 'Pick one or more'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final style in DamageStyle.values)
                      _SelectPill(
                        label: style.label,
                        selected: _styles.contains(style),
                        onTap: _working
                            ? null
                            : () => setState(() {
                                if (!_styles.remove(style)) {
                                  _styles.add(style);
                                }
                              }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final style in DamageStyle.values)
                  if (_styles.contains(style))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.circle, size: 6, color: luma.textMuted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              style.description,
                              style: TextStyle(
                                color: luma.textMuted,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                const SizedBox(height: 14),
                _Heading(label: 'How hard', hint: _preset.hint),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preset in DamagePreset.values)
                      _SelectPill(
                        label: preset.label,
                        selected: preset == _preset,
                        onTap: _working
                            ? null
                            : () => setState(() => _preset = preset),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _RecoverableSwitch(
                  value: _recoverable,
                  onChanged: _working
                      ? null
                      : (value) => setState(() => _recoverable = value),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.tag_rounded, size: 16, color: luma.textMuted),
                    const SizedBox(width: 8),
                    Text(
                      'Seed $_seed',
                      style: TextStyle(color: luma.textMuted, fontSize: 12.5),
                    ),
                    const Spacer(),
                    ConverterTextButton(
                      label: 'New seed',
                      onTap: () => setState(() => _seed = _freshSeed()),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ConverterPrimaryButton(
                  label: 'Corrupt file',
                  icon: Icons.bolt_rounded,
                  loading: _working,
                  onTap: _styles.isEmpty ? null : _corrupt,
                ),
              ],
            ),
          ),
        ],

        if (!_recoverable && bytes != null) ...[
          const SizedBox(height: 16),
          ConverterBanner(
            icon: Icons.warning_amber_rounded,
            color: luma.danger,
            message:
                'No recovery recipe will be written. Nothing — including '
                'luma — will be able to undo this.',
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

        if (result != null) ...[
          const SizedBox(height: 16),
          _DamageReport(result: result, originalSize: bytes?.length ?? 0),
          const SizedBox(height: 16),
          ConverterCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConverterPrimaryButton(
                  label: kIsWeb
                      ? 'Download corrupted file'
                      : 'Save corrupted file',
                  loading: false,
                  icon: Icons.download_rounded,
                  onTap: _saveCorrupted,
                ),
                if (result.recoverable) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Keep the recipe somewhere safe — it is the only thing that '
                    'can undo this.',
                    style: TextStyle(color: luma.textMuted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 10),
                  ConverterPrimaryButton(
                    label: kIsWeb
                        ? 'Download .lumafix recipe'
                        : 'Save .lumafix recipe',
                    loading: false,
                    icon: Icons.vpn_key_outlined,
                    onTap: _saveRecipe,
                  ),
                ],
              ],
            ),
          ),
        ],

        for (final save in [_fileSave, _recipeSave])
          if (save != null && save.saved) ...[
            const SizedBox(height: 12),
            ConverterBanner(
              icon: Icons.check_circle_outline_rounded,
              color: luma.success,
              message: save.summary,
            ),
          ],

        if (_fileSave != null && _fileSave!.saved) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ConverterTextButton(
              label: 'Corrupt another file',
              onTap: _reset,
            ),
          ),
        ],
      ],
    );
  }
}

/// The list of edits that were made, so nothing about the damage is hidden.
class _DamageReport extends StatelessWidget {
  const _DamageReport({required this.result, required this.originalSize});

  final CorruptionResult result;
  final int originalSize;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final delta = result.bytes.length - originalSize;
    return ConverterCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.recoverable
                    ? Icons.lock_open_rounded
                    : Icons.lock_rounded,
                size: 18,
                color: result.recoverable ? luma.success : luma.danger,
              ),
              const SizedBox(width: 10),
              Text(
                result.recoverable ? 'Recoverable' : 'Permanent',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${formatSize(result.bytes.length)}'
                '${delta == 0
                    ? ''
                    : delta > 0
                    ? ' (+${formatSize(delta)})'
                    : ' (−${formatSize(-delta)})'}',
                style: TextStyle(color: luma.textMuted, fontSize: 12.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final step in result.steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.arrow_right_rounded, size: 18, color: luma.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      step,
                      style: TextStyle(
                        color: luma.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          for (final note in result.notes) ...[
            const SizedBox(height: 8),
            Text(note, style: TextStyle(color: luma.textMuted, fontSize: 12.5)),
          ],
        ],
      ),
    );
  }
}

class _RecoverableSwitch extends StatelessWidget {
  const _RecoverableSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Write a recovery recipe',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value
                    ? 'A .lumafix file records every edit, so the fixer can '
                          'rebuild the original exactly.'
                    : 'Nothing is recorded. The damage is permanent.',
                style: TextStyle(color: luma.textMuted, fontSize: 12.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: luma.accent,
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.label, this.hint});

  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: luma.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (hint != null) ...[
          const Spacer(),
          Flexible(
            child: Text(
              hint!,
              textAlign: TextAlign.right,
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}

class _SelectPill extends StatelessWidget {
  const _SelectPill({
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
    return Material(
      color: selected ? luma.accentSubtle : luma.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? luma.accent : luma.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? luma.accent : luma.textSecondary,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
