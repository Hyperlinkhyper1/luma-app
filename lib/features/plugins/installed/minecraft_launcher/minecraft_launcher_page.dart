import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import 'ui/accounts_tab.dart';
import 'ui/global_search_page.dart';
import 'ui/library_tab.dart';
import 'ui/servers_tab.dart';
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

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    if (!Platform.isWindows) {
      return Center(
        child: LumaEmptyState(
          icon: Icons.videogame_asset_off_outlined,
          title: t.minecraftLauncherNotWindowsTitle,
          subtitle: t.minecraftLauncherNotWindowsSubtitle,
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
                  tabs: [
                    t.minecraftLauncherTabLibrary,
                    t.minecraftLauncherTabAccounts,
                    t.minecraftLauncherTabServers,
                    t.minecraftLauncherTabSettings,
                  ],
                  selectedIndex: _tab,
                  onSelect: (i) => setState(() => _tab = i),
                ),
              ),
              IconButton(
                tooltip: t.commonSearch,
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
              ServersTab(),
              SettingsTab(),
            ],
          ),
        ),
      ],
    );
  }
}
