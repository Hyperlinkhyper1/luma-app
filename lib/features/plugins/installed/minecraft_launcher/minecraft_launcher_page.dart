import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import 'ui/accounts_tab.dart';
import 'ui/global_search_page.dart';
import 'ui/library_tab.dart';
import 'ui/settings_tab.dart';

/// Root of the Minecraft Launcher plugin: a segmented sub-navigation over the
/// instance library, accounts, and launcher settings.
class MinecraftLauncherPage extends StatefulWidget {
  const MinecraftLauncherPage({super.key});

  @override
  State<MinecraftLauncherPage> createState() => _MinecraftLauncherPageState();
}

class _MinecraftLauncherPageState extends State<MinecraftLauncherPage> {
  int _tab = 0;

  static const _tabs = ['Library', 'Accounts', 'Settings'];

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return const Center(
        child: LumaEmptyState(
          icon: Icons.videogame_asset_off_outlined,
          title: 'Not available on this platform',
          subtitle: 'Minecraft Launcher currently only supports Windows.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            children: [
              Expanded(
                child: LumaSegmentedTabs(
                  tabs: _tabs,
                  selectedIndex: _tab,
                  onSelect: (i) => setState(() => _tab = i),
                ),
              ),
              IconButton(
                tooltip: 'Search',
                icon: const Icon(Icons.search_rounded),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GlobalSearchPage()),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: const [
              LibraryTab(),
              AccountsTab(),
              SettingsTab(),
            ],
          ),
        ),
      ],
    );
  }
}
