import 'package:flutter/material.dart';

import 'app/app_shell.dart';
import 'app/splash_screen.dart';
import 'features/passwords/data/password_database.dart';
import 'features/passwords/password_crypto.dart';
import 'features/passwords/password_repository.dart';
import 'features/passwords/password_scope.dart';
import 'features/plugins/data/plugin_database.dart';
import 'features/plugins/installed/bulletin_board/bulletin_board_repository.dart';
import 'features/plugins/installed/bulletin_board/bulletin_board_scope.dart';
import 'features/plugins/installed/bulletin_board/data/bulletin_board_database.dart';
import 'features/plugins/installed/qr_code_generator/data/qr_code_database.dart';
import 'features/plugins/installed/qr_code_generator/qr_code_repository.dart';
import 'features/plugins/installed/qr_code_generator/qr_code_scope.dart';
import 'features/plugins/plugin_catalog_service.dart';
import 'features/plugins/plugin_repository.dart';
import 'features/plugins/plugin_scope.dart';
import 'finance/data/database.dart';
import 'finance/finance_repository.dart';
import 'finance/finance_scope.dart';
import 'settings/settings_controller.dart';
import 'settings/settings_scope.dart';
import 'theme/luma_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  // The real startup work the splash covers: catch up any recurring entries /
  // allocations that came due while closed. Errors are swallowed so a storage
  // hiccup never blocks (or hangs) startup.
  late final Future<void> _bootstrap =
      _repository.applyDue(DateTime.now()).catchError((_) => 0).then((_) {});

  @override
  void dispose() {
    _db.close();
    _passwordDb.close();
    _pluginDb.close();
    _qrCodeDb.close();
    _bulletinBoardDb.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
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
                child: ListenableBuilder(
                  listenable: widget.settings,
                  builder: (context, _) {
                    final s = widget.settings;
                    return MaterialApp(
                      title: 'luma',
                      debugShowCheckedModeBanner: false,
                      theme: LumaTheme.from(Brightness.light, s.accentSeed),
                      darkTheme: LumaTheme.from(Brightness.dark, s.accentSeed),
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
            onDone: () => setState(() => _showSplash = false),
          ),
      ],
    );
  }
}
