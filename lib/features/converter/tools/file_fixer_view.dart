import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../theme/luma_theme.dart';
import '../converter_widgets.dart';
import '../corruption/corruption_recipe.dart';
import '../corruption/file_repair_service.dart';
import '../corruption/file_signatures.dart';
import '../corruption/repair_report.dart';
import '../file_saver.dart';

/// Puts damaged files back together — exactly, when a `.lumafix` recipe is
/// there to say how, and best-effort when there is not.
class FileFixerView extends StatefulWidget {
  const FileFixerView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<FileFixerView> createState() => _FileFixerViewState();
}

class _FileFixerViewState extends State<FileFixerView> {
  String? _name;
  Uint8List? _bytes;

  String? _recipeName;
  CorruptionRecipe? _recipe;

  bool _working = false;
  String? _error;
  RepairResult? _result;
  SaveResult? _save;

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
      _save = null;
    });
  }

  Future<void> _pickRecipe() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [kRecipeExtension],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _error = 'Could not read the recipe.');
      return;
    }
    try {
      final recipe = CorruptionRecipe.decode(bytes);
      setState(() {
        _recipe = recipe;
        _recipeName = file.name;
        _error = null;
        _result = null;
        _save = null;
      });
    } on FormatException catch (e) {
      setState(() {
        _recipe = null;
        _recipeName = null;
        _error = e.message;
      });
    }
  }

  void _clearRecipe() {
    setState(() {
      _recipe = null;
      _recipeName = null;
      _result = null;
      _save = null;
    });
  }

  Future<void> _fix() async {
    final bytes = _bytes;
    final name = _name;
    if (bytes == null || name == null) return;

    setState(() {
      _working = true;
      _error = null;
      _result = null;
      _save = null;
    });

    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    try {
      final recipe = _recipe;
      final result = recipe != null
          ? FileRepairService.restoreFromRecipe(
              corrupted: bytes,
              recipe: recipe,
              corruptedName: name,
            )
          : FileRepairService.repair(bytes, name);
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
        _error = 'Something went wrong while repairing that file: $e';
      });
    }
  }

  Future<void> _saveFixed() async {
    final result = _result;
    if (result == null) return;
    final save = await saveConvertedFile(
      bytes: result.bytes,
      suggestedName: result.suggestedName,
      mimeType: 'application/octet-stream',
      extensions: [
        FileSignatures.extensionOf(result.suggestedName).isEmpty
            ? 'bin'
            : FileSignatures.extensionOf(result.suggestedName),
      ],
    );
    if (!mounted) return;
    setState(() => _save = save);
  }

  void _reset() {
    setState(() {
      _name = null;
      _bytes = null;
      _recipe = null;
      _recipeName = null;
      _result = null;
      _error = null;
      _save = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final bytes = _bytes;
    final recipe = _recipe;
    final result = _result;

    return ToolScaffold(
      icon: Icons.healing_outlined,
      title: 'File fixer',
      subtitle: 'Undo a luma corruption exactly, or rebuild a broken file',
      onBack: widget.onBack,
      children: [
        if (bytes == null)
          ConverterDropZone(
            onTap: _pickFile,
            icon: Icons.healing_outlined,
            title: 'Click to choose the damaged file',
            subtitle: 'Images · archives · documents · audio · video',
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
                Row(
                  children: [
                    Icon(
                      recipe == null
                          ? Icons.auto_fix_high_outlined
                          : Icons.vpn_key_outlined,
                      size: 18,
                      color: recipe == null ? luma.textSecondary : luma.success,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        recipe == null
                            ? 'Best-effort repair'
                            : 'Exact restore from recipe',
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (recipe != null)
                      ConverterTextButton(label: 'Remove', onTap: _clearRecipe),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  recipe == null
                      ? 'No recipe loaded, so luma will work out what the file '
                            'is and rebuild whatever structure it can. Headers, '
                            'checksums and indexes can come back; bytes that were '
                            'overwritten cannot.'
                      : 'Recorded ${_recipeAge(recipe)} for '
                            '"${recipe.originalName}" in '
                            '${recipe.ops.length} step'
                            '${recipe.ops.length == 1 ? '' : 's'}. The original '
                            'comes back byte for byte.',
                  style: TextStyle(color: luma.textMuted, fontSize: 12.5),
                ),
                if (recipe == null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ConverterTextButton(
                      label: 'Load a .lumafix recipe',
                      onTap: _pickRecipe,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Text(
                    _recipeName ?? '',
                    style: TextStyle(color: luma.textMuted, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 16),
                ConverterPrimaryButton(
                  label: recipe == null
                      ? 'Analyse & repair'
                      : 'Restore original',
                  icon: Icons.build_rounded,
                  loading: _working,
                  onTap: _fix,
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

        if (result != null) ...[
          const SizedBox(height: 16),
          _RepairReportCard(result: result, originalSize: bytes?.length ?? 0),
          const SizedBox(height: 16),
          ConverterPrimaryButton(
            label: kIsWeb ? 'Download repaired file' : 'Save repaired file',
            loading: false,
            icon: Icons.download_rounded,
            onTap: _saveFixed,
          ),
        ],

        if (_save != null && _save!.saved) ...[
          const SizedBox(height: 16),
          ConverterBanner(
            icon: Icons.check_circle_outline_rounded,
            color: luma.success,
            message: _save!.summary,
            trailing: ConverterTextButton(label: 'Fix another', onTap: _reset),
          ),
        ],
      ],
    );
  }

  static String _recipeAge(CorruptionRecipe recipe) {
    final difference = DateTime.now().difference(recipe.createdAt);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes} min ago';
    if (difference.inDays < 1) return '${difference.inHours} h ago';
    return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
  }
}

/// Everything the repairer did and everything it could not do, in one list.
class _RepairReportCard extends StatelessWidget {
  const _RepairReportCard({required this.result, required this.originalSize});

  final RepairResult result;
  final int originalSize;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final headlineColor = result.restoredExactly
        ? luma.success
        : result.notes.any((n) => n.severity == RepairSeverity.failed)
        ? luma.warning
        : result.changed
        ? luma.success
        : luma.textSecondary;

    return ConverterCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.restoredExactly
                    ? Icons.verified_rounded
                    : Icons.build_circle_outlined,
                size: 18,
                color: headlineColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.restoredExactly
                      ? 'Restored exactly'
                      : result.changed
                      ? '${result.fixCount} repair'
                            '${result.fixCount == 1 ? '' : 's'} applied'
                      : 'Nothing to repair',
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FormatChip(label: result.formatLabel),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${formatBytes(originalSize)} in · '
            '${formatBytes(result.bytes.length)} out',
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          for (final note in result.notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _iconFor(note.severity),
                    size: 16,
                    color: _colorFor(note.severity, luma),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note.message,
                      style: TextStyle(
                        color: note.severity == RepairSeverity.info
                            ? luma.textMuted
                            : luma.textSecondary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (result.hasWarnings && !result.restoredExactly) ...[
            const SizedBox(height: 4),
            Text(
              'A structural repair puts the container back together. It cannot '
              'invent content that was overwritten — check the result before '
              'you rely on it.',
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  static IconData _iconFor(RepairSeverity severity) => switch (severity) {
    RepairSeverity.info => Icons.info_outline_rounded,
    RepairSeverity.fixed => Icons.check_circle_outline_rounded,
    RepairSeverity.warning => Icons.warning_amber_rounded,
    RepairSeverity.failed => Icons.cancel_outlined,
  };

  static Color _colorFor(RepairSeverity severity, LumaPalette luma) =>
      switch (severity) {
        RepairSeverity.info => luma.textMuted,
        RepairSeverity.fixed => luma.success,
        RepairSeverity.warning => luma.warning,
        RepairSeverity.failed => luma.danger,
      };
}
