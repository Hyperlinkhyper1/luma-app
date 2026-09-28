import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import 'minecraft/minecraft_library_view.dart';
import 'text_library_prefs.dart';
import 'ui/classic_library_view.dart';

/// Subjects full of texts, shown either as a plain two-pane library or as a
/// Minecraft hall of bookcases.
class TextLibraryPage extends StatefulWidget {
  const TextLibraryPage({super.key});

  @override
  State<TextLibraryPage> createState() => _TextLibraryPageState();
}

class _TextLibraryPageState extends State<TextLibraryPage> {
  LibraryViewMode? _mode;

  @override
  void initState() {
    super.initState();
    loadViewMode().then((mode) {
      if (mounted) setState(() => _mode = mode);
    });
  }

  void _setMode(LibraryViewMode mode) {
    if (mode == _mode) return;
    setState(() => _mode = mode);
    saveViewMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    final mode = _mode;
    if (mode == null) return const SizedBox.shrink();
    final t = L.of(context);
    final narrow = context.isPhoneWidth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (minecraftViewSupported)
          Padding(
            padding: EdgeInsets.fromLTRB(
              narrow ? 12 : 24,
              10,
              narrow ? 12 : 24,
              8,
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: LumaSegmentedTabs(
                tabs: [t.textLibraryModeClassic, t.textLibraryModeMinecraft],
                selectedIndex: mode.index,
                onSelect: (i) => _setMode(LibraryViewMode.values[i]),
              ),
            ),
          ),
        Expanded(
          child: switch (mode) {
            LibraryViewMode.classic => const ClassicLibraryView(),
            LibraryViewMode.minecraft => const MinecraftLibraryView(),
          },
        ),
      ],
    );
  }
}
