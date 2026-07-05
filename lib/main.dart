import 'package:flutter/material.dart';

import 'app/app_shell.dart';
import 'app/splash_screen.dart';
import 'app/update/update_gate.dart';
import 'app/window_controls.dart';
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
import 'features/plugins/plugin_catalog_service.dart';
import 'features/plugins/plugin_repository.dart';
import 'features/plugins/plugin_scope.dart';
import 'features/notes/notes_repository.dart';
import 'features/plugins/installed/cloud_files/cloud_files_controller.dart';
import 'features/plugins/installed/cloud_files/cloud_files_scope.dart';
import 'finance/data/database.dart';
import 'finance/finance_repository.dart';
import 'finance/finance_scope.dart';
import 'p2p/peer_sync_controller.dart';
import 'p2p/peer_sync_scope.dart';
import 'settings/settings_controller.dart';
import 'settings/settings_scope.dart';
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

  // Optional server sync: every feature registers an adapter; nothing is
  // uploaded unless the user signs in AND enables the feature in Settings.
  late final SyncService _sync = SyncService(collections: [
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
    JsonStoreSyncCollection(
      id: 'price_tracker',
      label: 'Price tracker',
      icon: Icons.trending_down_rounded,
      listenable: _priceTrackerRepository,
      exporter: () => _priceTrackerRepository.exportData(),
      importer: (data) => _priceTrackerRepository.importData(data),
    ),
  ]);

  // The Cloud Files plugin stores encrypted files on the same sync server.
  late final CloudFilesController _cloudFiles = CloudFilesController(_sync);

  // Optional peer-to-peer (Wi-Fi/LAN) sync between same-account devices.
  late final PeerSyncController _peerSync = PeerSyncController(sync: _sync);

  // The real startup work the splash covers: catch up any recurring entries /
  // allocations that came due while closed. Errors are swallowed so a storage
  // hiccup never blocks (or hangs) startup.
  late final Future<void> _bootstrap =
      _repository.applyDue(DateTime.now()).catchError((_) => 0).then((_) {});

  @override
  void initState() {
    super.initState();
    _sync.init();
    _peerSync.init();
  }

  @override
  void dispose() {
    _peerSync.dispose();
    _cloudFiles.dispose();
    _sync.dispose();
    _db.close();
    _passwordDb.close();
    _pluginDb.close();
    _qrCodeDb.close();
    _bulletinBoardDb.close();
    _calendarDb.close();
    _dataManagementDb.close();
    _moodJournalDb.close();
    _serverTycoonRepository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SyncScope(
      service: _sync,
      child: PeerSyncScope(
      controller: _peerSync,
      child: CloudFilesScope(
      controller: _cloudFiles,
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
            onDone: () {
              setState(() => _showSplash = false);
              // Check for updates once the app is visible; the prompt (if any)
              // then layers over the warm app.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) checkAndPromptForUpdate(context);
              });
            },
          ),
      ],
    );
  }
}
