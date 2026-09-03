import 'package:flutter/material.dart';

import '../../../theme/luma_theme.dart';
import '../converter_widgets.dart';
import 'file_corruptor_view.dart';
import 'file_fixer_view.dart';
import 'schematic_converter_view.dart';

/// The converter's "Other" category: the tools that are not audio, image or
/// video work. Each one opens its own screen, the same way the main hub works.
enum OtherTool { minecraftSchematic, fileCorruptor, fileFixer }

class OtherToolsView extends StatefulWidget {
  const OtherToolsView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<OtherToolsView> createState() => _OtherToolsViewState();
}

class _OtherToolsViewState extends State<OtherToolsView> {
  OtherTool? _active;

  @override
  Widget build(BuildContext context) {
    switch (_active) {
      case OtherTool.minecraftSchematic:
        return SchematicConverterView(
          onBack: () => setState(() => _active = null),
        );
      case OtherTool.fileCorruptor:
        return FileCorruptorView(onBack: () => setState(() => _active = null));
      case OtherTool.fileFixer:
        return FileFixerView(onBack: () => setState(() => _active = null));
      case null:
        return _OtherHub(
          onBack: widget.onBack,
          onOpen: (tool) => setState(() => _active = tool),
        );
    }
  }
}

class _OtherHub extends StatelessWidget {
  const _OtherHub({required this.onBack, required this.onOpen});

  final VoidCallback onBack;
  final ValueChanged<OtherTool> onOpen;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return ToolScaffold(
      icon: Icons.category_outlined,
      title: 'Other',
      subtitle: 'Format tools beyond audio, images and video',
      onBack: onBack,
      children: [
        ConverterToolGrid(
          tiles: [
            ConverterToolTile(
              icon: Icons.view_in_ar_outlined,
              title: 'Minecraft schematics',
              subtitle: 'SCHEM · LITEMATIC · SCHEMATIC · NBT · MCSTRUCTURE',
              badge: 'MINECRAFT',
              onTap: () => onOpen(OtherTool.minecraftSchematic),
            ),
            ConverterToolTile(
              icon: Icons.broken_image_outlined,
              title: 'File corruptor',
              subtitle: 'Break a file on purpose, recoverably or for good',
              badge: 'DAMAGE',
              onTap: () => onOpen(OtherTool.fileCorruptor),
            ),
            ConverterToolTile(
              icon: Icons.healing_outlined,
              title: 'File fixer',
              subtitle: 'Undo a corruption, or rebuild a broken file',
              badge: 'REPAIR',
              onTap: () => onOpen(OtherTool.fileFixer),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'The schematic tool converts any of the five block formats into any '
          'other and shows the build in 3D before you save it. The corruptor '
          'and fixer are a pair: corrupt with a recipe and the fixer rebuilds '
          'the original byte for byte, or point the fixer at any damaged file '
          'and it rebuilds what structure it can.',
          style: TextStyle(color: luma.textMuted, fontSize: 12.5),
        ),
      ],
    );
  }
}
