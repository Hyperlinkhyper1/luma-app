import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../account/account_page.dart';
import '../family/inbox_button.dart';
import '../features/chat/chat_page.dart';
import '../l10n/app_localizations.dart';
import '../features/converter/converter_page.dart';
import '../features/home/home_page.dart';
import '../features/notes/notes_page.dart';
import '../features/passwords/passwords_page.dart';
import '../features/plugins/installed/data_management/data_management_page.dart';
import '../features/plugins/installed/auto_clicker/auto_clicker_page.dart';
import '../features/plugins/installed/calculator/calculator_page.dart';
import '../features/plugins/installed/calendar/calendar_page.dart';
import '../features/plugins/installed/cloud_files/cloud_files_page.dart';
import '../features/plugins/installed/card_wallet/card_wallet_page.dart';
import '../features/plugins/installed/errands/errands_page.dart';
import '../features/plugins/installed/city_planner/city_planner_page.dart';
import '../features/plugins/installed/file_tree/file_tree_page.dart';
import '../features/plugins/installed/gallery/gallery_page.dart';
import '../features/plugins/installed/device_health/device_health_page.dart';
import '../features/plugins/installed/account_overview/account_overview_shell.dart';
import '../features/plugins/installed/file_viewer/file_viewer_page.dart';
import '../features/plugins/installed/groceries/groceries_page.dart';
import '../features/plugins/installed/minecraft_launcher/minecraft_launcher_page.dart';
import '../features/plugins/installed/mood_journal/mood_journal_page.dart';
import '../features/plugins/installed/ai_usage/ai_usage_shell.dart';
import '../features/plugins/installed/steam_tools/steam_tools_shell.dart';
import '../features/plugins/installed/ai_detector/ai_detector_page.dart';
import '../features/plugins/installed/nfc_tag_editor/nfc_tag_editor_page.dart';
import '../features/plugins/installed/bulletin_board/bulletin_board_page.dart';
import '../features/plugins/installed/price_tracker/price_tracker_page.dart';
import '../features/plugins/installed/qr_code_generator/qr_code_generator_page.dart';
import '../features/plugins/installed/machine_learning/machine_learning_page.dart';
import '../features/plugins/installed/mind_map/mind_map_page.dart';
import '../features/plugins/installed/whiteboard/whiteboard_page.dart';
import '../features/plugins/installed/school/school_page.dart';
import '../features/plugins/installed/secure_chat/secure_chat_page.dart';
import '../features/plugins/installed/sftp/sftp_page.dart';
import '../features/plugins/installed/airline_tycoon/airline_tycoon_page.dart';
import '../features/plugins/installed/server_tycoon/server_tycoon_page.dart';
import '../features/plugins/installed/space_colony/space_colony_page.dart';
import '../features/plugins/installed/subway_builder/subway_builder_page.dart';
import '../features/plugins/installed/transport_tracker/transport_tracker_page.dart';
import '../features/plugins/installed/usage/usage_page.dart';
import '../features/plugins/installed/wifi_speed_test/wifi_speed_test_page.dart';
import '../features/plugins/installed/worth_counter/worth_counter_page.dart';
import '../features/plugins/installed/media_downloader/media_downloader_page.dart';
import '../features/plugins/installed/recipe_book/recipe_book_page.dart';
import '../features/plugins/installed/roblox_tools/roblox_tools_page.dart';
import '../features/plugins/plugin_icons.dart';
import '../features/plugins/plugin_repository.dart';
import '../features/plugins/plugin_scope.dart';
import '../features/plugins/plugins_page.dart';
import '../finance/finance_page.dart';
import '../pet/luma_pet_panel.dart';
import '../pet/pet_scope.dart';
import '../pet/pet_search.dart';
import '../pet/pet_summon_button.dart';
import 'server_account_gate.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_page.dart';
import '../settings/settings_scope.dart';
import '../theme/coffee_ornaments.dart';
import '../theme/luma_theme.dart';
import 'bottom_nav.dart';
import 'nav_rail.dart';
import 'widgets.dart';
import 'window_title_bar.dart';

/// Below this width the vertical icon rail is replaced with a bottom nav bar,
/// since a fixed 72px-wide rail leaves too little room for phone content.
/// The number itself lives in `widgets.dart` as [kPhoneBreakpoint], so pages
/// can ask the same question the shell does.
const _phoneBreakpoint = kPhoneBreakpoint;

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
  int _homeEditRevision = 0;
  bool _homeEditRequested = false;

  void _editHome() {
    setState(() {
      _pushHistory();
      _selectedIndex = 0;
      _selectedPluginId = null;
      _homeEditRevision++;
      _homeEditRequested = true;
    });
  }

  // Non-null while an installed plugin's page is being shown, taking
  // priority over [_selectedIndex].
  String? _selectedPluginId;

  // The window size the shell was last laid out against. Held so the pet can
  // shrink the desktop window without the shell reflowing into the phone
  // layout behind it — see [build].
  Size? _shellSize;

  // Where the system/hardware Back button walks to. Every navigation records
  // the screen it left, so Back retraces those steps in-app instead of
  // popping the root route (which, on Android, quits the whole app the moment
  // you're anywhere but the start screen — and then a fresh launch has to
  // crawl through the boot/loading screen again).
  final List<_NavEntry> _history = [];

  static List<String> _titles(L t) => [
        t.navHome,
        t.navFileConverter,
        t.navFinance,
        t.navPasswordManager,
        t.navNotes,
        t.navAssistant,
        t.navPlugins,
        t.navSettings,
        t.navAccount,
      ];

  _NavEntry get _currentEntry => _NavEntry(_selectedIndex, _selectedPluginId);

  // Record the screen we're leaving so Back can return to it. Consecutive
  // duplicates are collapsed so tapping the same tab twice doesn't stack.
  void _pushHistory() {
    final cur = _currentEntry;
    if (_history.isEmpty || _history.last != cur) _history.add(cur);
  }

  void _selectFixed(int i) {
    if (_selectedIndex == i && _selectedPluginId == null) return;
    setState(() {
      _pushHistory();
      _selectedIndex = i;
      _selectedPluginId = null;
    });
  }

  void _selectPlugin(String id) {
    if (_selectedPluginId == id) return;
    setState(() {
      _pushHistory();
      _selectedPluginId = id;
    });
  }

  // Returns true if it consumed the Back gesture by moving within the app.
  bool _goBack() {
    if (_history.isEmpty) return false;
    final prev = _history.removeLast();
    setState(() {
      _selectedIndex = prev.index;
      _selectedPluginId = prev.pluginId;
    });
    return true;
  }

  void _closePlugin() {
    if (_goBack()) return;
    setState(() => _selectedPluginId = null);
  }

  // Plugins whose own content is the whole point of the screen (full-map or
  // full-canvas games): on phone, the top title bar and bottom nav just eat
  // space the game desperately needs, so they're hidden and replaced with a
  // single floating back button instead.
  static const _phoneImmersivePlugins = {
    'subway-builder',
    'server-tycoon',
    'transport-tracker',
    'airline-tycoon',
  };

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final settings = SettingsScope.of(context);
    final pluginRepo = PluginScope.of(context);
    final pet = PetScope.of(context);
    final index = _selectedIndex ?? _startIndex(settings.startScreen);
    final titles = _titles(t);

    // While the pet has the desktop window shrunk to panel size, the shell is
    // measured against the window it will be restored to, not the panel. It
    // is offstage anyway, and reflowing it into the phone layout at 480px
    // would rebuild every page from scratch — losing whatever the user had
    // open — only to undo it a second later.
    final mq = MediaQuery.of(context);
    final petWindow = pet.visible && pet.windowMode;
    if (!petWindow) _shellSize = mq.size;
    final shellSize = petWindow ? (_shellSize ?? mq.size) : mq.size;
    final shellMedia = mq.copyWith(size: shellSize);

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
        final title = showingPlugin ? activePlugin.name : titles[index];
        final isPhone = shellSize.width < _phoneBreakpoint;
        // A phone-sized device in *either* orientation. Landscape widens the
        // window past the width breakpoint, so immersive plugins use the
        // shortest side to stay full-screen when the phone is turned sideways.
        final isPhoneForm = shellSize.shortestSide < _phoneBreakpoint;
        final immersive = showingPlugin &&
            isPhoneForm &&
            _phoneImmersivePlugins.contains(activePlugin.pluginId);

        final content = Container(
          color: luma.background,
          child: StyleBackdrop(
            child: showingPlugin
                ? _pluginPageFor(activePlugin.pluginId, t)
                : IndexedStack(
                    index: index,
                    children: [
                      HomePage(
                        key: ValueKey(_homeEditRevision),
                        onNavigate: _selectFixed,
                        onPlugin: _selectPlugin,
                        startEditing: _homeEditRequested,
                        onEditRequestConsumed: () => _homeEditRequested = false,
                      ),
                      const ConverterPage(),
                      const FinancePage(),
                      const PasswordsPage(),
                      const NotesPage(),
                      ChatPage(
                        onOpenSettings: () =>
                            _selectFixed(NavRail.settingsIndex),
                        onOpenPlugin: _selectPlugin,
                      ),
                      PluginsPage(onOpenPlugin: _selectPlugin),
                      SettingsPage(onEditHome: _editHome),
                      const AccountPage(),
                    ],
                  ),
          ),
        );

        final scaffold = Scaffold(
          body: Column(
            children: [
              if (!immersive)
                WindowTitleBar(
                  title: title,
                  trailing: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [PetSummonButton(), InboxButton()],
                  ),
                ),
              Expanded(
                child: immersive
                    // No title bar here, so inset the plugin ourselves: the
                    // OS status bar (and any display cutout) would otherwise
                    // sit on top of the game's own HUD. A background layer
                    // fills the inset strip so it matches the app.
                    ? Stack(
                        children: [
                          Positioned.fill(
                            child: ColoredBox(color: luma.background),
                          ),
                          Positioned.fill(
                            child: SafeArea(child: content),
                          ),
                          _PhoneBackButton(onTap: _closePlugin),
                        ],
                      )
                    : (isPhone
                        ? content
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              NavRail(
                                selectedIndex: showingPlugin ? -1 : index,
                                selectedPluginId: showingPlugin
                                    ? activePlugin.pluginId
                                    : null,
                                installedPlugins: installed,
                                onSelect: _selectFixed,
                                onSelectPlugin: _selectPlugin,
                              ),
                              Expanded(child: content),
                            ],
                          )),
              ),
            ],
          ),
          bottomNavigationBar: (isPhone && !immersive)
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

        // Only the very first screen (nothing recorded to go back to, no
        // plugin open) lets the pop through to the OS, which then exits the
        // app. Everywhere else, Back retraces our own navigation history.
        final canExit = _history.isEmpty && _selectedPluginId == null;
        final shell = PopScope(
          canPop: canExit,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (_selectedPluginId != null) {
              _closePlugin();
              return;
            }
            _goBack();
          },
          child: MediaQuery(data: shellMedia, child: scaffold),
        );

        return CallbackShortcuts(
          // The same chord as the global hotkey, handled in-app as well: it
          // keeps working when the OS-level registration was refused (another
          // app holds Alt+Space) and on platforms that have no global
          // hotkeys at all.
          bindings: {
            const SingleActivator(LogicalKeyboardKey.space, alt: true):
                pet.toggle,
          },
          child: Focus(
            // Something inside this subtree has to hold focus for the binding
            // above to be reached; this claims it only when no page has, and
            // stays out of the tab order.
            autofocus: true,
            skipTraversal: true,
            child: Stack(
              children: [
                // Offstage rather than removed: the shell keeps its state, so
                // dismissing the pet returns to exactly the page and scroll
                // position it was summoned from.
                Offstage(offstage: petWindow, child: shell),
                if (pet.visible)
                  Positioned.fill(
                    child: LumaPetPanel(
                      fullBleed: pet.windowMode,
                      targets: _petTargets(t, installed),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Icons for the fixed sections, in the same order as [_titles] and the
  /// rail's own destinations.
  static const _sectionIcons = [
    Icons.dashboard_rounded,
    Icons.swap_horiz_rounded,
    Icons.account_balance_wallet_rounded,
    Icons.lock_rounded,
    Icons.sticky_note_2_rounded,
    Icons.smart_toy_rounded,
    Icons.extension_rounded,
    Icons.settings_rounded,
    Icons.badge_rounded,
  ];

  /// Hidden aliases, so "money" finds Finance and "todo" finds the errand
  /// plugin even though neither word is in the label. Deliberately English
  /// only: they are extras layered on top of the localized labels, which are
  /// what the list actually matches on first.
  static const _sectionKeywords = <List<String>>[
    ['dashboard', 'start'],
    ['convert', 'file', 'image', 'video', 'audio'],
    ['money', 'budget', 'bank', 'spending'],
    ['vault', 'login', 'credentials'],
    ['note', 'scratch'],
    ['ai', 'chat', 'ask'],
    ['marketplace', 'install', 'extensions'],
    ['preferences', 'theme', 'language'],
    ['plan', 'profile', 'sync'],
  ];

  /// Everything the pet can take the user to: the fixed sections plus every
  /// installed plugin. Built here because the shell is the only place that
  /// knows how to open both.
  List<PetTarget> _petTargets(L t, List<InstalledPluginRecord> installed) {
    final titles = _titles(t);
    return [
      for (var i = 0; i < titles.length; i++)
        PetTarget(
          id: 'section:$i',
          label: titles[i],
          icon: _sectionIcons[i],
          kind: PetTargetKind.section,
          keywords: _sectionKeywords[i],
          open: () => _selectFixed(i),
        ),
      for (final plugin in installed)
        PetTarget(
          id: 'plugin:${plugin.pluginId}',
          label: plugin.name,
          icon: pluginIconFor(plugin.icon),
          kind: PetTargetKind.plugin,
          keywords: [plugin.pluginId.replaceAll('-', ' ')],
          open: () => _selectPlugin(plugin.pluginId),
        ),
    ];
  }

  static int _startIndex(StartScreen screen) => switch (screen) {
        StartScreen.home => 0,
        StartScreen.converter => 1,
        StartScreen.finance => 2,
      };

  /// Plugins that do nothing at all without the server, mapped to the copy
  /// shown in their place until this device has an approved account. Kept
  /// compiled in rather than read from the fetched registry — the registry's
  /// own `requiresAccount` flag only drives the marketplace badge, and a
  /// gate must not depend on a file downloaded at runtime.
  static const serverOnlyPlugins =
      <String, ({String title, String description, IconData icon})>{
    'cloud-files': (
      title: 'Cloud Files needs an approved account',
      description: 'Cloud Files keeps your files on the luma server, '
          'locked on this device first.',
      icon: Icons.cloud_off_rounded,
    ),
    'secure-chat': (
      title: 'Chat needs an approved account',
      description: 'Chat passes locked messages between '
          'accounts through the luma server.',
      icon: Icons.lock_outline_rounded,
    ),
  };

  /// Resolves a plugin id to its page, wrapping the server-only ones in a
  /// [ServerAccountGate] so they stay inert until an account is approved.
  static Widget _pluginPageFor(String pluginId, L t) {
    final page = _pluginBodyFor(pluginId, t);
    final gate = serverOnlyPlugins[pluginId];
    if (gate == null) return page;
    return ServerAccountGate(
      title: gate.title,
      description: gate.description,
      icon: gate.icon,
      child: page,
    );
  }

  static Widget _pluginBodyFor(String pluginId, L t) => switch (pluginId) {
        'qr-code-generator' => const QrCodeGeneratorPage(),
        'card-wallet' => const CardWalletPage(),
        'errand-manager' => const ErrandsPage(),
        'file-tree' => const FileTreePage(),
        'file-viewer' => const FileViewerPage(),
        'bulletin-board' => const BulletinBoardPage(),
        'price-tracker' => const PriceTrackerPage(),
        'calculator' => const CalculatorPage(),
        'calendar' => const CalendarPage(),
        'cloud-files' => const CloudFilesPage(),
        'data-management' => const DataManagementPage(),
        'server-tycoon' => const ServerTycoonPage(),
        'airline-tycoon' => const AirlineTycoonPage(),
        'space-colony' => const SpaceColonyPage(),
        'subway-builder' => const SubwayBuilderPage(),
        'transport-tracker' => const TransportTrackerPage(),
        'city-planner' => const CityPlannerPage(),
        'mood-journal' => const MoodJournalPage(),
        'ai-usage' => const AiUsagePage(),
        'steam-tools' => const SteamToolsPage(),
        'ai-detector' => const AiDetectorPage(),
        'youtube-downloader' => const MediaDownloaderPage(),
        'school' => const SchoolPage(),
        'mind-map' => const MindMapPage(),
        'whiteboard' => const WhiteboardPage(),
        'machine-learning' => const MachineLearningPage(),
        'auto-clicker' => const AutoClickerPage(),
        'usage' => const UsagePage(),
        'wifi-speed-test' => const WifiSpeedTestPage(),
        'groceries-list' => const GroceriesPage(),
        'minecraft-launcher' => const MinecraftLauncherPage(),
        'secure-chat' => const SecureChatPage(),
        'sftp' => const SftpPage(),
        'recipe-book' => const RecipeBookPage(),
        'worth-counter' => const WorthCounterPage(),
        'gallery' => const GalleryPage(),
        'nfc-tag-editor' => const NfcTagEditorPage(),
        'roblox-tools' => const RobloxToolsPage(),
        'device-health' => const DeviceHealthPage(),
        'account-overview' => const AccountOverviewPage(),
        _ => LumaEmptyState(
            icon: Icons.extension_off_rounded,
            title: t.shellPluginUnavailable,
          ),
      };
}

/// A single step in [_AppShellState._history]: the fixed-section index (null
/// means the configured start screen) and any plugin that was open.
class _NavEntry {
  const _NavEntry(this.index, this.pluginId);
  final int? index;
  final String? pluginId;

  @override
  bool operator ==(Object other) =>
      other is _NavEntry && other.index == index && other.pluginId == pluginId;

  @override
  int get hashCode => Object.hash(index, pluginId);
}

/// Floating exit affordance for immersive phone plugins (see
/// [_AppShellState._phoneImmersivePlugins]) that otherwise have no chrome to
/// navigate away with once the title bar and bottom nav are hidden.
class _PhoneBackButton extends StatelessWidget {
  const _PhoneBackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final topInset = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: topInset + 8,
      left: 8,
      child: Material(
        color: luma.surface.withValues(alpha: 0.85),
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(Icons.arrow_back_rounded,
                color: luma.textPrimary, size: 22),
          ),
        ),
      ),
    );
  }
}
