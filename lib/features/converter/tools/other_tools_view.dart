import 'package:flutter/material.dart';

import '../../../theme/luma_theme.dart';
import '../converter_widgets.dart';
import 'schematic_converter_view.dart';

/// The converter's "Other" category: the tools that are not audio, image or
/// video work. Each one opens its own screen, the same way the main hub works.
enum OtherTool { minecraftSchematic }

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
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Converts any of the five block formats into any other, and shows '
          'the build in 3D before you save it.',
          style: TextStyle(color: luma.textMuted, fontSize: 12.5),
        ),
      ],
    );
  }
}
