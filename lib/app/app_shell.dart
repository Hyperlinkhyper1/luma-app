import 'package:flutter/material.dart';

import '../account/account_page.dart';
import '../features/converter/converter_page.dart';
import '../features/home/home_page.dart';
import '../features/notes/notes_page.dart';
import '../features/passwords/passwords_page.dart';
import '../features/plugins/installed/data_management/data_management_page.dart';
import '../features/plugins/installed/auto_clicker/auto_clicker_page.dart';
import '../features/plugins/installed/calendar/calendar_page.dart';
import '../features/plugins/installed/cloud_files/cloud_files_page.dart';
import '../features/plugins/installed/file_tree/file_tree_page.dart';
import '../features/plugins/installed/mood_journal/mood_journal_page.dart';
import '../features/plugins/installed/bulletin_board/bulletin_board_page.dart';
import '../features/plugins/installed/price_tracker/price_tracker_page.dart';
import '../features/plugins/installed/qr_code_generator/qr_code_generator_page.dart';
import '../features/plugins/installed/school/school_page.dart';
import '../features/plugins/installed/server_tycoon/server_tycoon_page.dart';
import '../features/plugins/installed/space_colony/space_colony_page.dart';
import '../features/plugins/installed/youtube_downloader/youtube_downloader_page.dart';
import '../features/plugins/plugin_repository.dart';
import '../features/plugins/plugin_scope.dart';
import '../features/plugins/plugins_page.dart';
import '../finance/finance_page.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_page.dart';
import '../settings/settings_scope.dart';
import '../storage/storage_guard_scope.dart';
import '../theme/luma_theme.dart';
import 'bottom_nav.dart';
import 'nav_rail.dart';
import 'widgets.dart';
import 'window_title_bar.dart';

/// Below this width the vertical icon rail is replaced with a bottom nav bar,
/// since a fixed 72px-wide rail leaves too little room for phone content.
const _phoneBreakpoint = 700.0;

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
  String? _selectedPluginId = 'auto-clicker'; // TEMP-QA

  static const _titles = [
    'Home',
    'File Converter',
    'Finance',
    'Password Manager',
    'Notes',
    'Plugins',
    'Settings',
    'Account',
  ];

  // Dismissible per-session; only re-shown if the app is restarted while
  // still over the limit — the Account tab's Storage section always shows
  // the live truth regardless of this dismissal.
  bool _storageBannerDismissed = false;

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
    final storageGuard = StorageGuardScope.of(context);
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
        // TEMP-QA: force-open Auto Clicker regardless of install state.
        if (_selectedPluginId == 'auto-clicker') {
          activePlugin = InstalledPluginRecord(
            pluginId: 'auto-clicker',
            name: 'Auto Clicker',
            icon: 'ads_click',
            version: '1.0.0',
            installedAt: DateTime.now(),
          );
        }
        final showingPlugin = activePlugin != null;
        final title = showingPlugin ? activePlugin.name : _titles[index];
        final isPhone = MediaQuery.sizeOf(context).width < _phoneBreakpoint;

        final content = Container(
          color: luma.background,
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
                    const AccountPage(),
                  ],
                ),
        );

        return Scaffold(
          body: Column(
            children: [
              WindowTitleBar(title: title),
              ListenableBuilder(
                listenable: storageGuard,
                builder: (context, _) {
                  if (!storageGuard.isOverLimit || _storageBannerDismissed) {
                    return const SizedBox.shrink();
                  }
                  return _StorageLimitBanner(
                    onManage: () => _selectFixed(NavRail.accountIndex),
                    onDismiss: () =>
                        setState(() => _storageBannerDismissed = true),
                  );
                },
              ),
              Expanded(
                child: isPhone
                    ? content
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          NavRail(
                            selectedIndex: showingPlugin ? -1 : index,
                            selectedPluginId:
                                showingPlugin ? activePlugin.pluginId : null,
                            installedPlugins: installed,
                            onSelect: _selectFixed,
                            onSelectPlugin: _selectPlugin,
                          ),
                          Expanded(child: content),
                        ],
                      ),
              ),
            ],
          ),
          bottomNavigationBar: isPhone
              ? BottomNav(
                  selectedIndex: showingPlugin ? -1 : index,
                  selectedPluginId:
                      showingPlugin ? activePlugin.pluginId : null,
                  installedPlugins: installed,
                  onSelect: _selectFixed,
                  onSelectPlugin: _selectPlugin,
                )
              : null,
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
        'calendar' => const CalendarPage(),
        'cloud-files' => const CloudFilesPage(),
        'data-management' => const DataManagementPage(),
        'server-tycoon' => const ServerTycoonPage(),
        'space-colony' => const SpaceColonyPage(),
        'mood-journal' => const MoodJournalPage(),
        'youtube-downloader' => const YoutubeDownloaderPage(),
        'school' => const SchoolPage(),
        'auto-clicker' => const AutoClickerPage(),
        _ => const LumaEmptyState(
            icon: Icons.extension_off_rounded,
            title: 'Plugin unavailable',
          ),
      };
}

/// App-wide warning shown the moment the local storage cap is hit — covers
/// every page (and every plugin) with a single reactive banner rather than a
/// bespoke check on each one. See `StorageGuardService`.
class _StorageLimitBanner extends StatelessWidget {
  const _StorageLimitBanner({required this.onManage, required this.onDismiss});
  final VoidCallback onManage;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.red.shade400.withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: Colors.red.shade400),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "You've reached your storage limit. New data won't be saved "
              'or synced until you free up space.',
              style: TextStyle(color: luma.textPrimary, fontSize: 12.5),
            ),
          ),
          TextButton(
            onPressed: onManage,
            child: Text('Manage',
                style: TextStyle(color: luma.accent, fontWeight: FontWeight.w700)),
          ),
          IconButton(
            tooltip: 'Dismiss',
            icon: Icon(Icons.close_rounded, size: 18, color: luma.textSecondary),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
