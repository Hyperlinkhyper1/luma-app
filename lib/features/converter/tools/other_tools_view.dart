import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/luma_theme.dart';
import '../converter_widgets.dart';
import 'file_corruptor_view.dart';
import 'file_fixer_view.dart';
import 'schematic_converter_view.dart';
import 'world_converter_view.dart';

/// The converter's "Other" category: the tools that are not audio, image or
/// video work. Each one opens its own screen, the same way the main hub works.
enum OtherTool { minecraftSchematic, minecraftWorld, fileCorruptor, fileFixer }

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
      case OtherTool.minecraftWorld:
        return WorldConverterView(onBack: () => setState(() => _active = null));
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
    final t = L.of(context);
    return ToolScaffold(
      icon: Icons.category_outlined,
      title: t.commonOther,
      subtitle: t.convOtherSubtitle,
      onBack: onBack,
      children: [
        ConverterToolGrid(
          tiles: [
            ConverterToolTile(
              icon: Icons.public_rounded,
              title: t.convOtherMinecraftWorld,
              subtitle: t.convOtherMinecraftWorldSub,
              badge: 'MINECRAFT',
              onTap: () => onOpen(OtherTool.minecraftWorld),
            ),
            ConverterToolTile(
              icon: Icons.view_in_ar_outlined,
              title: t.convOtherMinecraftSchematics,
              subtitle: 'SCHEM · LITEMATIC · SCHEMATIC · NBT · MCSTRUCTURE',
              badge: 'MINECRAFT',
              onTap: () => onOpen(OtherTool.minecraftSchematic),
            ),
            ConverterToolTile(
              icon: Icons.broken_image_outlined,
              title: t.convOtherCorruptor,
              subtitle: t.convOtherCorruptorSub,
              badge: t.convOtherBadgeDamage,
              onTap: () => onOpen(OtherTool.fileCorruptor),
            ),
            ConverterToolTile(
              icon: Icons.healing_outlined,
              title: t.convOtherFixer,
              subtitle: t.convOtherFixerSub,
              badge: t.convOtherBadgeRepair,
              onTap: () => onOpen(OtherTool.fileFixer),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          t.convOtherFooter,
          style: TextStyle(color: luma.textMuted, fontSize: 12.5),
        ),
      ],
    );
  }
}
