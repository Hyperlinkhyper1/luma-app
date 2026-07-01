import 'package:flutter/material.dart';

import '../features/converter/converter_page.dart';
import '../features/home/home_page.dart';
import '../features/notes/notes_page.dart';
import '../features/passwords/passwords_page.dart';
import '../features/plugins/installed/file_tree/file_tree_page.dart';
import '../features/plugins/installed/bulletin_board/bulletin_board_page.dart';
import '../features/plugins/installed/price_tracker/price_tracker_page.dart';
import '../features/plugins/installed/qr_code_generator/qr_code_generator_page.dart';
import '../features/plugins/plugin_repository.dart';
import '../features/plugins/plugin_scope.dart';
import '../features/plugins/plugins_page.dart';
import '../finance/finance_page.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_page.dart';
import '../settings/settings_scope.dart';
import '../theme/luma_theme.dart';
import 'nav_rail.dart';
import 'top_bar.dart';
import 'widgets.dart';

/// The top-level layout: a fixed left icon rail (Modrinth-style) next to the
/// active content area, which has its own top bar.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Null until the user navigates: the active section then defaults to the
  // configured start screen.
  int? _selectedIndex;

  // Non-null while an installed plugin's page is being shown, taking
  // priority over [_selectedIndex].
  String? _selectedPluginId;

  static const _titles = [
    'Home',
    'File Converter',
    'Finance',
    'Password Manager',
    'Notes',
    'Plugins',
    'Settings',
  ];

  void _selectFixed(int i) => setState(() {
        _selectedIndex = i;
        _selectedPluginId = null;
      });

  void _selectPlugin(String id) => setState(() => _selectedPluginId = id);

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final settings = SettingsScope.of(context);
    final pluginRepo = PluginScope.of(context);
    final index = _selectedIndex ?? _startIndex(settings.startScreen);

    return StreamBuilder<List<InstalledPluginRecord>>(
      stream: pluginRepo.watchInstalled(),
      builder: (context, snapshot) {
        final installed = snapshot.data ?? const <InstalledPluginRecord>[];
        InstalledPluginRecord? activePlugin;
        if (_selectedPluginId != null) {
          for (final p in installed) {
            if (p.pluginId == _selectedPluginId) {
              activePlugin = p;
              break;
            }
          }
        }
        final showingPlugin = activePlugin != null;
        final title = showingPlugin ? activePlugin.name : _titles[index];

        return Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NavRail(
                selectedIndex: showingPlugin ? -1 : index,
                selectedPluginId: showingPlugin ? activePlugin.pluginId : null,
                installedPlugins: installed,
                onSelect: _selectFixed,
                onSelectPlugin: _selectPlugin,
              ),
              Expanded(
                child: Container(
                  color: luma.background,
                  child: Column(
                    children: [
                      TopBar(title: title),
                      Expanded(
                        child: showingPlugin
                            ? _pluginPageFor(activePlugin.pluginId)
                            : IndexedStack(
                                index: index,
                                children: [
                                  HomePage(onNavigate: _selectFixed),
                                  const ConverterPage(),
                                  const FinancePage(),
                                  const PasswordsPage(),
                                  const NotesPage(),
                                  PluginsPage(onOpenPlugin: _selectPlugin),
                                  const SettingsPage(),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static int _startIndex(StartScreen screen) => switch (screen) {
        StartScreen.home => 0,
        StartScreen.converter => 1,
        StartScreen.finance => 2,
      };

  static Widget _pluginPageFor(String pluginId) => switch (pluginId) {
        'qr-code-generator' => const QrCodeGeneratorPage(),
        'file-tree' => const FileTreePage(),
        'bulletin-board' => const BulletinBoardPage(),
        'price-tracker' => const PriceTrackerPage(),
        _ => const LumaEmptyState(
            icon: Icons.extension_off_rounded,
            title: 'Plugin unavailable',
          ),
      };
}
