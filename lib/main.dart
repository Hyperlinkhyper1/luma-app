import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'account/plan.dart';
import 'app/app_shell.dart';
import 'app/splash_screen.dart';
import 'app/update/app_version.dart';
import 'app/update/update_gate.dart';
import 'app/window_controls.dart';
import 'features/chat/data/chat_database.dart';
import 'features/chat/data/chat_repository.dart';
import 'features/chat/chat_scope.dart';
import 'features/plugins/installed/auto_clicker/auto_clicker_repository.dart';
import 'features/plugins/installed/auto_clicker/auto_clicker_scope.dart';
import 'features/plugins/installed/mood_journal/data/mood_journal_database.dart';
import 'features/plugins/installed/mood_journal/mood_journal_repository.dart';
import 'features/plugins/installed/mood_journal/mood_journal_scope.dart';
import 'features/plugins/installed/data_management/data/data_management_database.dart';
import 'features/plugins/installed/data_management/data_management_repository.dart';
import 'features/plugins/installed/server_tycoon/server_tycoon_repository.dart';
import 'features/plugins/installed/server_tycoon/server_tycoon_scope.dart';
import 'features/plugins/installed/data_management/data_management_scope.dart';
import 'features/passwords/data/password_database.dart';
import 'features/passwords/password_crypto.dart';
import 'features/passwords/password_repository.dart';
import 'features/passwords/password_scope.dart';
import 'features/plugins/data/plugin_database.dart';
import 'l10n/app_localizations.dart';
import 'features/plugins/installed/calendar/calendar_repository.dart';
import 'features/plugins/installed/calendar/calendar_scope.dart';
import 'features/plugins/installed/calendar/data/calendar_database.dart';
import 'features/plugins/installed/bulletin_board/bulletin_board_repository.dart';
import 'features/plugins/installed/bulletin_board/bulletin_board_scope.dart';
import 'features/plugins/installed/bulletin_board/data/bulletin_board_database.dart';
import 'features/plugins/installed/price_tracker/price_tracker_repository.dart';
import 'features/plugins/installed/price_tracker/price_tracker_scope.dart';
import 'features/plugins/installed/qr_code_generator/data/qr_code_database.dart';
import 'features/plugins/installed/qr_code_generator/qr_code_repository.dart';
import 'features/plugins/installed/qr_code_generator/qr_code_scope.dart';
import 'features/plugins/installed/card_wallet/data/card_wallet_database.dart';
import 'features/plugins/installed/card_wallet/card_wallet_repository.dart';
import 'features/plugins/installed/card_wallet/card_wallet_scope.dart';
import 'features/plugins/installed/errands/data/errands_database.dart';
import 'features/plugins/installed/errands/errands_repository.dart';
import 'features/plugins/installed/errands/errands_scope.dart';
import 'features/plugins/installed/school/data/school_database.dart';
import 'features/plugins/installed/school/school_repository.dart';
import 'features/plugins/installed/school/school_scope.dart';
import 'features/plugins/installed/usage/data/usage_database.dart';
import 'features/plugins/installed/usage/usage_repository.dart';
import 'features/plugins/installed/usage/usage_scope.dart';
import 'features/plugins/installed/wifi_speed_test/wifi_speed_test_repository.dart';
import 'features/plugins/installed/wifi_speed_test/wifi_speed_test_scope.dart';
import 'features/plugins/installed/groceries/data/groceries_database.dart';
import 'features/plugins/installed/groceries/groceries_api.dart';
import 'features/plugins/installed/groceries/groceries_repository.dart';
import 'features/plugins/installed/groceries/groceries_scope.dart';
import 'features/plugins/plugin_catalog_service.dart';
import 'features/plugins/plugin_repository.dart';
import 'features/plugins/plugin_scope.dart';
import 'features/notes/notes_repository.dart';
import 'features/plugins/installed/cloud_files/cloud_files_controller.dart';
import 'features/plugins/installed/cloud_files/cloud_files_scope.dart';
import 'features/plugins/installed/secure_chat/chat_repository.dart' as secure_chat;
import 'features/plugins/installed/secure_chat/secure_chat_scope.dart';
import 'family/family_repository.dart';
import 'family/family_scope.dart';
import 'finance/data/database.dart';
import 'finance/finance_repository.dart';
import 'finance/finance_scope.dart';
import 'p2p/peer_sync_controller.dart';
import 'p2p/peer_sync_scope.dart';
import 'settings/settings_controller.dart';
import 'settings/settings_scope.dart';
import 'settings/sync_section.dart';
import 'storage/storage_guard.dart';
import 'storage/storage_guard_scope.dart';
import 'sync/sync_collections.dart';
import 'sync/sync_scope.dart';
import 'sync/sync_service.dart';
import 'theme/luma_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initWindowChrome();
  final settings = await SettingsController.load();
  final passwordCrypto = await PasswordCrypto.load();
  runApp(LumaApp(settings: settings, passwordCrypto: passwordCrypto));
}

class LumaApp extends StatefulWidget {
  const LumaApp({
    super.key,
    required this.settings,
    required this.passwordCrypto,
  });

  final SettingsController settings;
  final PasswordCrypto passwordCrypto;

  @override
  State<LumaApp> createState() => _LumaAppState();
}

class _LumaAppState extends State<LumaApp> {
  late final AppDatabase _db = AppDatabase();
  late final FinanceRepository _repository = FinanceRepository(_db);
  late final PasswordDatabase _passwordDb = PasswordDatabase();
  late final PasswordRepository _passwordRepository =
      PasswordRepository(_passwordDb, widget.passwordCrypto);
  late final PluginDatabase _pluginDb = PluginDatabase();
  late final PluginRepository _pluginRepository =
      PluginRepository(_pluginDb, PluginCatalogService());
  late final QrCodeDatabase _qrCodeDb = QrCodeDatabase();
  late final QrCodeRepository _qrCodeRepository = QrCodeRepository(_qrCodeDb);
  late final CardWalletDatabase _cardWalletDb = CardWalletDatabase();
  late final CardWalletRepository _cardWalletRepository =
      CardWalletRepository(_cardWalletDb);
  late final ErrandsDatabase _errandsDb = ErrandsDatabase();
  late final ErrandsRepository _errandsRepository =
      ErrandsRepository(_errandsDb);
  late final ChatDatabase _chatDb = ChatDatabase();
  late final ChatRepository _chatRepository = ChatRepository(_chatDb);
  late final BulletinBoardDatabase _bulletinBoardDb = BulletinBoardDatabase();
  late final BulletinBoardRepository _bulletinBoardRepository = BulletinBoardRepository(_bulletinBoardDb);
  late final PriceTrackerRepository _priceTrackerRepository = PriceTrackerRepository();
  late final CalendarDatabase _calendarDb = CalendarDatabase();
  late final CalendarRepository _calendarRepository = CalendarRepository(_calendarDb);
  late final DataManagementDatabase _dataManagementDb = DataManagementDatabase();
  late final DataManagementRepository _dataManagementRepository = DataManagementRepository(_dataManagementDb);
  late final ServerTycoonRepository _serverTycoonRepository = ServerTycoonRepository();
  late final MoodJournalDatabase _moodJournalDb = MoodJournalDatabase();
  late final MoodJournalRepository _moodJournalRepository = MoodJournalRepository(_moodJournalDb);
  late final SchoolDatabase _schoolDb = SchoolDatabase();
  late final SchoolRepository _schoolRepository = SchoolRepository(_schoolDb);
  late final AutoClickerRepository _autoClickerRepository =
      AutoClickerRepository();
  late final UsageDatabase _usageDb = UsageDatabase();
  late final UsageRepository _usageRepository = UsageRepository(_usageDb);
  late final WifiSpeedTestRepository _wifiSpeedTestRepository =
      WifiSpeedTestRepository();
  late final GroceriesDatabase _groceriesDb = GroceriesDatabase();
  late final GroceriesRepository _groceriesRepository =
      GroceriesRepository(_groceriesDb);
  late final GroceriesApi _groceriesApi = GroceriesApi();

  // Global local-storage cap, enforced regardless of which plugins are
  // installed — see StorageGuardService.
  late final StorageGuardService _storageGuard = StorageGuardService();

  // Optional server sync: every feature registers an adapter; nothing is
  // uploaded unless the user signs in AND enables the feature in Settings.
  late final SyncService _sync = SyncService(
    syncCollectionLimit: () =>
        planById(widget.settings.selectedPlanId).maxSyncCollections,
    onServerPlan: (id) => widget.settings.setAdminPlan(id),
    collections: [
    // Always synced (see SyncStateStore.collection / SyncService — the
    // 'settings' id defaults to enabled and can't be toggled off), so a
    // paired device always picks up the same theme/preferences.
    JsonStoreSyncCollection(
      id: 'settings',
      label: 'Settings',
      icon: Icons.tune_rounded,
      listenable: widget.settings,
      exporter: () async => widget.settings.exportData(),
      importer: (data) => widget.settings.importData(data),
    ),
    JsonStoreSyncCollection(
      id: 'notes',
      label: 'Notes',
      icon: Icons.sticky_note_2_rounded,
      listenable: NotesRepository(),
      exporter: () => NotesRepository().exportData(),
      importer: (data) => NotesRepository().importData(data),
    ),
    DriftSyncCollection(
      id: 'finance',
      label: 'Finance',
      icon: Icons.account_balance_wallet_rounded,
      db: _db,
    ),
    PasswordVaultSyncCollection(
      db: _passwordDb,
      crypto: widget.passwordCrypto,
    ),
    DriftSyncCollection(
      id: 'calendar',
      label: 'Calendar',
      icon: Icons.calendar_month_rounded,
      db: _calendarDb,
    ),
    DriftSyncCollection(
      id: 'bulletin_board',
      label: 'Bulletin board',
      icon: Icons.push_pin_rounded,
      db: _bulletinBoardDb,
    ),
    DriftSyncCollection(
      id: 'qr_codes',
      label: 'QR codes',
      icon: Icons.qr_code_rounded,
      db: _qrCodeDb,
    ),
    DriftSyncCollection(
      id: 'card_wallet',
      label: 'Card wallet',
      icon: Icons.wallet_rounded,
      db: _cardWalletDb,
    ),
    DriftSyncCollection(
      id: 'errands',
      label: 'Errands',
      icon: Icons.checklist_rounded,
      db: _errandsDb,
    ),
    DriftSyncCollection(
      id: 'data_management',
      label: 'Data management',
      icon: Icons.table_chart_rounded,
      db: _dataManagementDb,
    ),
    DriftSyncCollection(
      id: 'mood_journal',
      label: 'Mood journal',
      icon: Icons.mood_rounded,
      db: _moodJournalDb,
    ),
    DriftSyncCollection(
      id: 'school',
      label: 'School',
      icon: Icons.school_rounded,
      db: _schoolDb,
    ),
    JsonStoreSyncCollection(
      id: 'price_tracker',
      label: 'Price tracker',
      icon: Icons.trending_down_rounded,
      listenable: _priceTrackerRepository,
      exporter: () => _priceTrackerRepository.exportData(),
      importer: (data) => _priceTrackerRepository.importData(data),
    ),
    JsonStoreSyncCollection(
      id: 'wifi_speed_test',
      label: 'Wi-Fi speed test',
      icon: Icons.speed_rounded,
      listenable: _wifiSpeedTestRepository,
      exporter: () => _wifiSpeedTestRepository.exportData(),
      importer: (data) => _wifiSpeedTestRepository.importData(data),
    ),
    DriftSyncCollection(
      id: 'groceries',
      label: 'Groceries',
      icon: Icons.local_grocery_store_rounded,
      db: _groceriesDb,
    ),
  ]);

  // The Cloud Files plugin stores encrypted files on the same sync server.
  late final CloudFilesController _cloudFiles = CloudFilesController(_sync);

  // Families: invites, roster, and shared calendar entries. Talks to its own
  // (deliberately non-encrypted) server endpoints rather than the zero-
  // knowledge sync collections above — see lib/family/family_repository.dart.
  late final FamilyRepository _familyRepository = FamilyRepository(_sync);

  // Chat: end-to-end encrypted person-to-person messaging. Its own X25519
  // identity is generated on-device and only the public key ever reaches
  // the server — see lib/features/plugins/installed/secure_chat/.
  late final secure_chat.ChatRepository _secureChatRepository =
      secure_chat.ChatRepository(_sync);

  // Optional peer-to-peer (Wi-Fi/LAN) sync between same-account devices.
  late final PeerSyncController _peerSync = PeerSyncController(sync: _sync);

  // The real startup work the splash covers: catch up any recurring entries /
  // allocations that came due while closed. Errors are swallowed so a storage
  // hiccup never blocks (or hangs) startup.
  late final Future<void> _bootstrap =
      _repository.applyDue(DateTime.now()).catchError((_) => 0).then((_) {});

  AppLifecycleListener? _lifecycleListener;

  @override
  void initState() {
    super.initState();
    StorageGuardService.instance = _storageGuard;
    _applyPlanLimit();
    widget.settings.addListener(_onSettingsChanged);
    _storageGuard.refresh();
    _sync.init();
    _peerSync.init();
    _familyRepository.init();
    _secureChatRepository.init();
    _autoClickerRepository.init();
    _usageRepository.init();
    _lifecycleListener = AppLifecycleListener(
      onDetach: _sync.saveState,
    );
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    widget.settings.removeListener(_onSettingsChanged);
    _peerSync.dispose();
    _cloudFiles.dispose();
    _familyRepository.dispose();
    _secureChatRepository.dispose();
    _sync.dispose();
    _db.close();
    _passwordDb.close();
    _pluginDb.close();
    _qrCodeDb.close();
    _cardWalletDb.close();
    _errandsDb.close();
    _chatDb.close();
    _bulletinBoardDb.close();
    _calendarDb.close();
    _dataManagementDb.close();
    _moodJournalDb.close();
    _schoolDb.close();
    _serverTycoonRepository.dispose();
    _autoClickerRepository.dispose();
    _usageRepository.dispose();
    _usageDb.close();
    _groceriesDb.close();
    _groceriesApi.dispose();
    super.dispose();
  }

  /// Applies the selected plan's storage cap to the guard. Cheap — no-ops when
  /// the limit is unchanged (so it's safe to call on every settings change).
  void _applyPlanLimit() {
    final plan = planById(widget.settings.selectedPlanId);
    _storageGuard.setLimitBytes(plan.storageMb * 1024 * 1024);
  }

  /// Reacts to settings changes — only the plan affects the guard, but this
  /// fires for any preference mutation; [setLimitBytes] bails out when the
  /// value is the same, so the cost is a single comparison otherwise.
  void _onSettingsChanged() {
    final before = _storageGuard.limitBytes;
    _applyPlanLimit();
    if (_storageGuard.limitBytes != before) {
      // A downgrade may have pushed existing usage over the new (smaller) cap;
      // re-scan so the banner / write-blocking reflects it right away.
      _storageGuard.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StorageGuardScope(
      service: _storageGuard,
      child: SyncScope(
      service: _sync,
      child: PeerSyncScope(
      controller: _peerSync,
      child: CloudFilesScope(
      controller: _cloudFiles,
      child: FamilyScope(
      repository: _familyRepository,
      child: SecureChatScope(
      repository: _secureChatRepository,
      child: SettingsScope(
      controller: widget.settings,
      child: FinanceScope(
        repository: _repository,
        child: PasswordScope(
          repository: _passwordRepository,
          child: PluginScope(
            repository: _pluginRepository,
            child: QrCodeScope(
              repository: _qrCodeRepository,
              child: CardWalletScope(
              repository: _cardWalletRepository,
              child: ErrandsScope(
              repository: _errandsRepository,
              child: ChatScope(
              repository: _chatRepository,
              child: BulletinBoardScope(
                repository: _bulletinBoardRepository,
                child: PriceTrackerScope(
                  repository: _priceTrackerRepository,
                  child: CalendarScope(
                  repository: _calendarRepository,
                  child: DataManagementScope(
                    repository: _dataManagementRepository,
                    child: ServerTycoonScope(
                      repository: _serverTycoonRepository,
                      child: MoodJournalScope(
                      repository: _moodJournalRepository,
                      child: SchoolScope(
                      repository: _schoolRepository,
                      child: AutoClickerScope(
                      repository: _autoClickerRepository,
                      child: UsageScope(
                      repository: _usageRepository,
                      child: WifiSpeedTestScope(
                      repository: _wifiSpeedTestRepository,
                      child: GroceriesScope(
                      repository: _groceriesRepository,
                      child: GroceriesApiScope(
                      api: _groceriesApi,
                      child: ListenableBuilder(
                      listenable: widget.settings,
                      builder: (context, _) {
                        final s = widget.settings;
                        return MaterialApp(
                          title: 'luma',
                          debugShowCheckedModeBanner: false,
                          theme: LumaTheme.from(Brightness.light, s.accentSeed),
                          darkTheme:
                              LumaTheme.from(Brightness.dark, s.accentSeed),
                          themeMode: s.themeMode,
                          locale: localeForLanguage(s.appLanguage),
                          supportedLocales: L.supportedLocales,
                          localizationsDelegates: [
                            L.delegate,
                            GlobalMaterialLocalizations.delegate,
                            GlobalWidgetsLocalizations.delegate,
                            GlobalCupertinoLocalizations.delegate,
                          ],
                          home: _BootGate(
                              bootstrap: _bootstrap, accentSeed: s.accentSeed),
                        );
                      },
                    ),
                    ),
                    ),
                    ),
                    ),
                    ),
                    ),
                    ),
                  ),
                  ),
                  ),
                ),
              ),
              ),
              ),
            ),
          ),
        ),
      ),
      ),
      ),
      ),
      ),
      ),
      ),
      ),
    );
  }
}

/// Holds the [SplashScreen] over the (already-building) [AppShell] until both
/// the splash animation and the startup [bootstrap] work have finished, then
/// crossfades the splash away to reveal the warm app.
class _BootGate extends StatefulWidget {
  const _BootGate({required this.bootstrap, this.accentSeed});

  final Future<void> bootstrap;
  final Color? accentSeed;

  @override
  State<_BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<_BootGate> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const AppShell(),
        if (_showSplash)
          SplashScreen(
            bootstrap: widget.bootstrap,
            accent: widget.accentSeed ?? const Color(0xFFB49DF5),
            version: AppVersion.isReleaseBuild
                ? 'v${AppVersion.current}'
                : 'Dev build',
            onDone: () {
              setState(() => _showSplash = false);
              // Check for updates once the app is visible; the prompt (if any)
              // then layers over the warm app.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) checkAndPromptForUpdate(context);
              });
              // New installs, and devices whose local-only identity was just
              // migrated away (see SyncService.init), have no account at
              // all — prompt them to create one.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                final sync = SyncScope.of(context);
                if (!sync.p2pReady) {
                  showAccountSetupDialog(context, sync, initialMode: 1);
                }
              });
            },
          ),
      ],
    );
  }
}
