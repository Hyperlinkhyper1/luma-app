import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
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
import '../features/plugins/installed/audio_tools/audio_tools_page.dart';
import '../features/plugins/installed/auto_clicker/auto_clicker_page.dart';
import '../features/plugins/installed/auto_clicker/auto_clicker_repository.dart';
import '../features/plugins/installed/auto_clicker/auto_clicker_scope.dart';
import '../features/plugins/installed/auto_clicker/clicker_engine.dart';
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
import '../features/plugins/installed/text_library/text_library_page.dart';
import '../features/plugins/installed/ai_usage/ai_usage_shell.dart';
import '../features/plugins/installed/game_tools/game_tools_page.dart';
import '../features/plugins/installed/ai_detector/ai_detector_page.dart';
import '../features/plugins/installed/nfc_tag_editor/nfc_tag_editor_page.dart';
import '../features/plugins/installed/bulletin_board/bulletin_board_page.dart';
import '../features/plugins/installed/price_tracker/price_tracker_page.dart';
import '../features/plugins/installed/qr_code_generator/qr_code_generator_page.dart';
import '../features/plugins/installed/machine_learning/machine_learning_page.dart';
import '../features/plugins/installed/mind_map/mind_map_page.dart';
import '../features/plugins/installed/whiteboard/whiteboard_page.dart';
import '../features/plugins/installed/free_sketch/free_sketch_page.dart';
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
import '../features/plugins/installed/smart_home/smart_home_page.dart';
import '../features/plugins/installed/small_games/small_games_page.dart';
import '../features/plugins/installed/worth_counter/worth_counter_page.dart';
import '../features/plugins/installed/media_downloader/media_downloader_page.dart';
import '../features/plugins/installed/recipe_book/recipe_book_page.dart';
import '../features/plugins/installed/team_clipboard/team_clipboard_page.dart';
import '../features/plugins/plugin_icons.dart';
import '../features/plugins/plugin_l10n.dart';
import '../features/plugins/plugin_repository.dart';
import '../features/plugins/plugin_scope.dart';
import '../features/plugins/plugins_page.dart';
import '../finance/finance_page.dart';
import '../pet/luma_pet_panel.dart';
import '../pet/pet_repository.dart';
import '../pet/pet_scope.dart';
import '../pet/pet_search.dart';
import '../pet/pet_summon_button.dart';
import '../pet/pet_window_lifecycle.dart';
import '../pet/pet_window_protocol.dart';
import 'server_account_gate.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_page.dart';
import '../settings/settings_scope.dart';
import '../theme/coffee_ornaments.dart';
import '../theme/luma_theme.dart';
import 'bottom_nav.dart';
import 'home_widgets.dart';
import 'lazy_indexed_stack.dart';
import 'nav_rail.dart';
import 'plugin_tab_bar.dart';
import 'shell_tabs.dart';
import 'widgets.dart';
import 'window_title_bar.dart';
import 'window_controls.dart';

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
  final _tabs = ShellTabs();
  int? get _selectedIndex => _tabs.active.index;
  set _selectedIndex(int? value) => _tabs.active.index = value;
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
  String? get _selectedPluginId => _tabs.active.pluginId;
  set _selectedPluginId(String? value) => _tabs.active.pluginId = value;

  PetRepository? _petRepository;
  AutoClickerRepository? _autoClickerRepository;
  WindowController? _petWindow;
  String? _lastPetLocaleName;
  bool _petWindowVisible = false;
  List<PetTarget> _latestPetTargets = const [];
  bool _openingPetWindow = false;
  bool _petWindowFailed = false;
  bool _channelRegistered = false;
  StreamSubscription<String>? _widgetLaunches;

  @override
  void initState() {
    super.initState();
    if (PluginHomeWidgets.supported) {
      final widgets = PluginHomeWidgets.instance;
      _widgetLaunches = widgets.launches.listen(_openFromHomeWidget);
      unawaited(
        widgets.takeLaunchPlugin().then((id) {
          if (id != null) _openFromHomeWidget(id);
        }),
      );
    }
  }

  void _openFromHomeWidget(String pluginId) {
    if (mounted) _selectPlugin(pluginId);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pet = PetScope.of(context);
    final autoClicker = AutoClickerScope.of(context);
    if (!identical(_petRepository, pet)) {
      _petRepository?.removeListener(_onPetChanged);
      _petRepository = pet..addListener(_onPetChanged);
    }
    _autoClickerRepository = autoClicker;
    if (!_channelRegistered && hasCustomTitleBar) {
      _channelRegistered = true;
      unawaited(petMainChannel.setMethodCallHandler(_handlePetWindowCall));
    }
    final t = L.of(context);
    unawaited(setTrayLabels(open: t.trayOpen, quit: t.trayQuit));
  }

  @override
  void dispose() {
    unawaited(_widgetLaunches?.cancel());
    _petRepository?.removeListener(_onPetChanged);
    if (_channelRegistered) {
      unawaited(petMainChannel.setMethodCallHandler(null));
    }
    final window = _petWindow;
    if (window != null) {
      unawaited(_closePetWindowController(window));
    }
    super.dispose();
  }

  void _onPetChanged() {
    final pet = _petRepository;
    if (pet == null || !hasCustomTitleBar) return;
    if (pet.visible) {
      unawaited(_openPetWindow());
    } else {
      unawaited(_closePetWindow());
    }
  }

  Future<void> _openPetWindow() async {
    final pet = _petRepository;
    if (pet == null ||
        !pet.visible ||
        _petWindowVisible ||
        _openingPetWindow ||
        _latestPetTargets.isEmpty) {
      return;
    }
    _openingPetWindow = true;
    try {
      final snapshot = _petWindowSnapshot(pet);
      final existing = _petWindow;
      if (existing != null) {
        await existing.invokeMethod<void>(petWindowMethodShow, snapshot);
        if (!mounted || !pet.visible) {
          await _closePetWindowController(existing);
          return;
        }
        _petWindowVisible = true;
        if (_petWindowFailed) setState(() => _petWindowFailed = false);
        return;
      }
      final controller = await WindowController.create(
        WindowConfiguration(
          hiddenAtLaunch: true,
          arguments: jsonEncode({'kind': petWindowKind, ...snapshot}),
        ),
      );
      _petWindow = controller;
      if (!mounted || !pet.visible) {
        await _closePetWindowController(controller);
        return;
      }
      _petWindowVisible = true;
      if (_petWindowFailed && mounted) setState(() => _petWindowFailed = false);
    } catch (_) {
      _petWindow = null;
      _petWindowVisible = false;
      if (mounted) setState(() => _petWindowFailed = true);
    } finally {
      _openingPetWindow = false;
    }
  }

  Map<String, dynamic> _petWindowSnapshot(PetRepository pet) {
    final settings = SettingsScope.of(context);
    final locale = Localizations.localeOf(context);
    final brightness = Theme.of(context).brightness;
    return {
      'name': pet.name,
      'pats': pet.pats,
      'recentIds': pet.recentIds,
      'locale': locale.languageCode,
      'brightness': brightness.name,
      'accent': settings.accentSeed?.toARGB32(),
      'targets': [for (final target in _latestPetTargets) _targetJson(target)],
      'autoClicker': _autoClickerSnapshot(),
    };
  }

  Future<void> _closePetWindow() async {
    if (!_petWindowVisible) return;
    _petWindowVisible = false;
    final window = _petWindow;
    if (window == null) return;
    await _closePetWindowController(window);
  }

  Future<void> _closePetWindowController(WindowController window) async {
    try {
      await window.hide();
    } catch (_) {
      if (identical(_petWindow, window)) _petWindow = null;
    }
  }

  Map<String, dynamic> _targetJson(PetTarget target) => {
    'id': target.id,
    'label': target.label,
    'iconName': target.iconName,
    'kind': target.kind.name,
    'keywords': target.keywords,
  };

  Future<dynamic> _handlePetWindowCall(MethodCall call) async {
    final pet = _petRepository!;
    switch (call.method) {
      case petMethodPat:
        pet.pat();
      case petMethodRecordOpen:
        await pet.recordOpen(call.arguments as String);
      case petMethodOpenTarget:
        final id = call.arguments as String;
        if (id.startsWith('section:')) {
          final index = int.tryParse(id.substring('section:'.length));
          if (index != null) _selectFixed(index);
        } else if (id.startsWith('plugin:')) {
          _selectPlugin(id.substring('plugin:'.length));
        }
        await windowShow();
      case petMethodDismiss:
        final window = _petWindow;
        await dismissPetWindowFromChild(
          markHidden: () => _petWindowVisible = false,
          dismissPet: () async {
            if (call.arguments == true) await windowShow();
            await pet.close(navigating: call.arguments == true);
          },
          hideWindow: () async {
            if (window != null) await _closePetWindowController(window);
          },
        );
      case petMethodAutoClicker:
        return _handleAutoClickerCommand(
          Map<String, dynamic>.from(call.arguments as Map? ?? const {}),
        );
      default:
        throw MissingPluginException('Unknown pet method ${call.method}');
    }
    return null;
  }

  Map<String, dynamic> _handleAutoClickerCommand(Map<String, dynamic> command) {
    final repo = _autoClickerRepository!;
    switch (command['action']) {
      case 'toggle':
        repo.toggle();
      case 'setInterval':
        repo.setIntervalMs((command['value'] as num?)?.toInt() ?? 1);
      case 'setButton':
        final value = command['value'] as String?;
        repo.setButton(
          ClickButton.values.firstWhere(
            (button) => button.name == value,
            orElse: () => ClickButton.left,
          ),
        );
      case 'setDoubleClick':
        repo.setDoubleClick(command['value'] == true);
      case 'setClickAtCursor':
        repo.setClickAtCursor(command['value'] == true);
      case 'captureCursor':
        final point = ClickerEngine.cursorPosition;
        if (point != null) repo.setFixedPoint(point);
      case 'setRepeatMode':
        repo.setRepeatMode(
          command['value'] == 'count'
              ? ClickRepeatMode.count
              : ClickRepeatMode.untilStopped,
        );
      case 'setRepeatCount':
        repo.setRepeatCount((command['value'] as num?)?.toInt() ?? 1);
    }
    return _autoClickerSnapshot();
  }

  Map<String, dynamic> _autoClickerSnapshot() {
    final repo = _autoClickerRepository!;
    final fixed = repo.fixedPoint;
    return {
      'supported': repo.supported,
      'loaded': repo.loaded,
      'intervalMs': repo.intervalMs,
      'randomOffsetMs': repo.randomOffsetMs,
      'button': repo.button.name,
      'doubleClick': repo.doubleClick,
      'clickAtCursor': repo.clickAtCursor,
      if (fixed != null) 'fixedX': fixed.x,
      if (fixed != null) 'fixedY': fixed.y,
      'repeatMode': repo.repeatMode.name,
      'repeatCount': repo.repeatCount,
      'isRunning': repo.isRunning,
      'clicksDone': repo.clicksDone,
      'hotKey': repo.hotKey.debugName,
      'hotKeyError': repo.hotKeyError,
    };
  }

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

  ShellTabItem _tabItem(
    L t,
    ShellTab tab,
    List<InstalledPluginRecord> installed,
    List<String> titles,
    int startIndex,
  ) {
    final plugin = installed
        .where((plugin) => plugin.pluginId == tab.pluginId)
        .firstOrNull;
    final index = tab.index ?? startIndex;
    const icons = [
      Icons.dashboard_rounded,
      Icons.transform_rounded,
      Icons.account_balance_wallet_rounded,
      Icons.lock_rounded,
      Icons.note_rounded,
      Icons.chat_rounded,
      Icons.extension_rounded,
      Icons.settings_rounded,
      Icons.person_rounded,
    ];
    return ShellTabItem(
      id: tab.id,
      title: plugin == null
          ? titles[index]
          : pluginDisplayName(t, plugin.pluginId, plugin.name),
      icon: plugin == null ? icons[index] : pluginIconFor(plugin.icon),
    );
  }

  _NavEntry get _currentEntry =>
      _NavEntry(_selectedIndex, _selectedPluginId, _tabs.active.id);

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
      _tabs.openPlugin(id);
    });
  }

  void _addTab() {
    setState(() {
      _pushHistory();
      _tabs.add();
    });
  }

  void _selectTab(String id) {
    if (_tabs.active.id == id) return;
    setState(() {
      _pushHistory();
      _tabs.select(id);
    });
  }

  void _closeTab(String id) {
    setState(() {
      _tabs.close(id);
      _history.removeWhere((entry) => entry.tabId == id);
    });
  }

  // Returns true if it consumed the Back gesture by moving within the app.
  bool _goBack() {
    if (_history.isEmpty) return false;
    final prev = _history.removeLast();
    setState(() {
      _tabs.select(prev.tabId);
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

    final mq = MediaQuery.of(context);
    final shellSize = mq.size;
    final shellMedia = mq.copyWith(size: shellSize);

    return StreamBuilder<List<InstalledPluginRecord>>(
      stream: pluginRepo.watchInstalled(),
      builder: (context, snapshot) {
        final installed = snapshot.data ?? const <InstalledPluginRecord>[];
        _latestPetTargets = _petTargets(t, installed);
        final petLocaleName = Localizations.localeOf(context).languageCode;
        final localeChanged =
            _lastPetLocaleName != null && _lastPetLocaleName != petLocaleName;
        _lastPetLocaleName = petLocaleName;
        final petWindow = _petWindow;
        if (localeChanged && _petWindowVisible && petWindow != null) {
          unawaited(
            petWindow.invokeMethod<void>(
              petWindowMethodRefresh,
              _petWindowSnapshot(pet),
            ),
          );
        }
        if (PluginHomeWidgets.supported && snapshot.hasData) {
          unawaited(
            PluginHomeWidgets.instance.sync(
              installed,
              background: luma.accent,
              foreground: luma.onAccent,
            ),
          );
        }
        if (pet.visible &&
            hasCustomTitleBar &&
            !_petWindowVisible &&
            !_openingPetWindow) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(_openPetWindow());
          });
        }
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
        final tabs = _tabs.tabs;
        final activeTab = showingPlugin
            ? tabs.indexWhere((tab) => tab.id == _tabs.active.id)
            : -1;
        final title = showingPlugin
            ? pluginDisplayName(t, activePlugin.pluginId, activePlugin.name)
            : titles[index];
        final isPhone = shellSize.width < _phoneBreakpoint;
        // A phone-sized device in *either* orientation. Landscape widens the
        // window past the width breakpoint, so immersive plugins use the
        // shortest side to stay full-screen when the phone is turned sideways.
        final isPhoneForm = shellSize.shortestSide < _phoneBreakpoint;
        final immersive =
            showingPlugin &&
            isPhoneForm &&
            _phoneImmersivePlugins.contains(activePlugin.pluginId);

        final content = Container(
          color: luma.background,
          child: StyleBackdrop(
            child: IndexedStack(
              index: activeTab + 1,
              children: [
                TickerMode(
                  enabled: activeTab < 0,
                  child: LazyIndexedStack(
                    index: activeTab < 0 ? index : null,
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
                        onNavigate: (destination) {
                          switch (destination.toLowerCase()) {
                            case 'home':
                              _selectFixed(0);
                            case 'converter':
                              _selectFixed(1);
                            case 'finance':
                              _selectFixed(2);
                            case 'passwords':
                              _selectFixed(3);
                            case 'notes':
                              _selectFixed(4);
                            case 'assistant':
                              _selectFixed(5);
                            case 'plugins':
                              _selectFixed(6);
                            case 'settings':
                              _selectFixed(NavRail.settingsIndex);
                            case 'account':
                              _selectFixed(NavRail.accountIndex);
                            default:
                              _selectPlugin(destination);
                          }
                        },
                      ),
                      PluginsPage(onOpenPlugin: _selectPlugin),
                      SettingsPage(onEditHome: _editHome),
                      const AccountPage(),
                    ],
                  ),
                ),
                for (var i = 0; i < tabs.length; i++)
                  TickerMode(
                    key: ValueKey(
                      'tab:${tabs[i].id}:${tabs[i].mountedPluginId}',
                    ),
                    enabled: i == activeTab,
                    child:
                        !installed.any(
                          (plugin) =>
                              plugin.pluginId == tabs[i].mountedPluginId,
                        )
                        ? const SizedBox.shrink()
                        : _pluginPageFor(tabs[i].mountedPluginId!, t),
                  ),
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
                  tabs: PluginTabBar(
                    tabs: [
                      for (final tab in tabs)
                        _tabItem(
                          t,
                          tab,
                          installed,
                          titles,
                          _startIndex(settings.startScreen),
                        ),
                    ],
                    activeTabId: _tabs.active.id,
                    onSelect: _selectTab,
                    onClose: _closeTab,
                    onAdd: _addTab,
                  ),
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
                          Positioned.fill(child: SafeArea(child: content)),
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
                  selectedPluginId: showingPlugin
                      ? activePlugin.pluginId
                      : null,
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

        // No shortcut binding here on purpose: the in-app half of the summon
        // chord is registered by PetRepository through hotkey_manager, which
        // listens to the keyboard directly rather than through the focus
        // tree — so it answers wherever the user is, and it follows the chord
        // when they rebind it, which a hardcoded binding could not.
        return Stack(
          // Expand, not the default loose. An offstage child reports the
          // smallest size it is allowed, and the boot gate's own stack hands
          // this one loose constraints — so with a loose fit, the moment the
          // shell goes offstage for the pet this stack sizes itself to 0x0,
          // the panel is laid out into nothing, and the window paints black.
          fit: StackFit.expand,
          children: [
            shell,
            if (pet.visible && (!hasCustomTitleBar || _petWindowFailed))
              Positioned.fill(
                child: LumaPetPanel(
                  fullBleed: false,
                  targets: _latestPetTargets,
                ),
              ),
          ],
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
          iconName: 'section:$i',
          kind: PetTargetKind.section,
          keywords: _sectionKeywords[i],
          open: () => _selectFixed(i),
        ),
      for (final plugin in installed)
        PetTarget(
          id: 'plugin:${plugin.pluginId}',
          label: pluginDisplayName(t, plugin.pluginId, plugin.name),
          icon: pluginIconFor(plugin.icon),
          iconName: plugin.icon,
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

  /// Plugins that do nothing at all without the server; each shows
  /// [_serverGate]'s copy in its place until this device has an approved
  /// account. Kept compiled in rather than read from the fetched registry —
  /// the registry's own `requiresAccount` flag only drives the marketplace
  /// badge, and a gate must not depend on a file downloaded at runtime.
  static const serverOnlyPlugins = {
    'cloud-files',
    'secure-chat',
    'team-clipboard',
  };

  /// The localised copy for a [serverOnlyPlugins] entry, or null for plugins
  /// that work without the server.
  static ({String title, String description, IconData icon})? _serverGate(
    String pluginId,
    L t,
  ) => switch (pluginId) {
    'cloud-files' => (
      title: t.serverGateCloudFilesTitle,
      description: t.serverGateCloudFilesDescription,
      icon: Icons.cloud_off_rounded,
    ),
    'secure-chat' => (
      title: t.serverGateChatTitle,
      description: t.serverGateChatDescription,
      icon: Icons.lock_outline_rounded,
    ),
    'team-clipboard' => (
      title: t.serverGateTeamClipboardTitle,
      description: t.serverGateTeamClipboardDescription,
      icon: Icons.content_paste_off_rounded,
    ),
    _ => null,
  };

  /// Resolves a plugin id to its page, wrapping the server-only ones in a
  /// [ServerAccountGate] so they stay inert until an account is approved.
  static Widget _pluginPageFor(String pluginId, L t) {
    final page = _pluginBodyFor(pluginId, t);
    final gate = serverOnlyPlugins.contains(pluginId)
        ? _serverGate(pluginId, t)
        : null;
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
    'text-library' => const TextLibraryPage(),
    'ai-usage' => const AiUsagePage(),
    'game-tools' => const GameToolsPage(),
    'ai-detector' => const AiDetectorPage(),
    'youtube-downloader' => const MediaDownloaderPage(),
    'school' => const SchoolPage(),
    'mind-map' => const MindMapPage(),
    'whiteboard' => const WhiteboardPage(),
    'free-sketch' => const FreeSketchPage(),
    'machine-learning' => const MachineLearningPage(),
    'auto-clicker' => const AutoClickerPage(),
    'audio-tools' => const AudioToolsPage(),
    'usage' => const UsagePage(),
    'wifi-speed-test' => const WifiSpeedTestPage(),
    'smart-home' => const SmartHomePage(),
    'small-games' => const SmallGamesPage(),
    'groceries-list' => const GroceriesPage(),
    'minecraft-launcher' => const MinecraftLauncherPage(),
    'secure-chat' => const SecureChatPage(),
    'sftp' => const SftpPage(),
    'recipe-book' => const RecipeBookPage(),
    'team-clipboard' => const TeamClipboardPage(),
    'worth-counter' => const WorthCounterPage(),
    'gallery' => const GalleryPage(),
    'nfc-tag-editor' => const NfcTagEditorPage(),
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
  const _NavEntry(this.index, this.pluginId, this.tabId);
  final String tabId;
  final int? index;
  final String? pluginId;

  @override
  bool operator ==(Object other) =>
      other is _NavEntry &&
      other.index == index &&
      other.pluginId == pluginId &&
      other.tabId == tabId;

  @override
  int get hashCode => Object.hash(index, pluginId, tabId);
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
            child: Icon(
              Icons.arrow_back_rounded,
              color: luma.textPrimary,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
