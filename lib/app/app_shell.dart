import 'package:flutter/material.dart';

import '../features/converter/converter_page.dart';
import '../features/home/home_page.dart';
import '../features/passwords/passwords_page.dart';
import '../features/plugins/plugins_page.dart';
import '../finance/finance_page.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_page.dart';
import '../settings/settings_scope.dart';
import '../theme/luma_theme.dart';
import 'nav_rail.dart';
import 'top_bar.dart';

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

  static const _titles = [
    'Home',
    'File Converter',
    'Finance',
    'Password Manager',
    'Plugins',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final settings = SettingsScope.of(context);
    final index = _selectedIndex ?? _startIndex(settings.startScreen);

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NavRail(
            selectedIndex: index,
            onSelect: (i) => setState(() => _selectedIndex = i),
          ),
          Expanded(
            child: Container(
              color: luma.background,
              child: Column(
                children: [
                  TopBar(title: _titles[index]),
                  Expanded(
                    child: IndexedStack(
                      index: index,
                      children: [
                        HomePage(
                          onNavigate: (i) =>
                              setState(() => _selectedIndex = i),
                        ),
                        const ConverterPage(),
                        const FinancePage(),
                        const PasswordsPage(),
                        const PluginsPage(),
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
  }

  static int _startIndex(StartScreen screen) => switch (screen) {
        StartScreen.home => 0,
        StartScreen.converter => 1,
        StartScreen.finance => 2,
      };
}
