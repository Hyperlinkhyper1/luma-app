# Repository Guidelines

## Project Structure & Module Organization

`luma` is a Flutter desktop/Android utility app. State is managed via the **Scope pattern**: each feature exposes an `InheritedWidget` (`*Scope`) that holds a repository, initialized in `main.dart` and nested at the widget tree root. Repositories own all business logic; widgets read from them via `context.dependOnInheritedWidgetOfExactType`.

```
lib/
  main.dart                  App entry: initialises all DBs, repos, SyncService, PeerSyncController, nests all Scopes
  theme/luma_theme.dart      LumaPalette design tokens + ThemeData factory
  app/
    app_shell.dart           Navigation shell (rail + IndexedStack); _pluginPageFor() maps plugin IDs → widgets
    update/                  Self-update via GitHub Releases (check → download → silent Inno installer on Windows)
    widgets.dart             Shared UI primitives (cards, pills, StreamData…)
  features/
    converter/               File converter; platform-split via _io.dart / _stub.dart / _web.dart suffix pattern
    home/                    Dashboard home page
    notes/                   Simple notes (JSON store, no drift)
    passwords/               AES-encrypted vault (drift DB + PasswordCrypto)
    plugins/
      installed/<id>/        One sub-directory per plugin with its own DB, repository, scope, and page widget
      plugin_catalog_service.dart   Fetches plugins/registry.json from GitHub
  finance/                   Personal finance (drift SQLite); amounts stored as integer cents
  p2p/                       Wi-Fi/LAN peer sync (nsd + WebSocket protocol)
  settings/                  SettingsController (shared_preferences-like, ChangeNotifier)
  sync/                      Server sync (SyncService coordinates multiple SyncCollection adapters)
server/                      Standalone Dart HTTP server; deploy via docker-compose
plugins/
  registry.json              Catalog of available plugins (fetched at runtime)
  <id>/manifest.json         Per-plugin metadata
```

**Platform-specific code** uses the suffix convention: `feature_io.dart` (Windows/Android/native), `feature_stub.dart` (unsupported platforms), `feature_web.dart` (web). The main `feature.dart` file exports the right one via conditional imports.

## Build, Test, and Development Commands

```powershell
flutter run -d windows                                         # run desktop app
flutter run -d android                                         # run on Android device/emulator
flutter test                                                   # all unit + widget tests
flutter test test/finance_logic_test.dart                      # single test file
flutter analyze                                                # lint (flutter_lints)
flutter build windows --release --no-tree-shake-icons          # Windows release (--no-tree-shake-icons is required)
flutter build apk --release --no-tree-shake-icons              # Android APK
dart run build_runner build                                    # regenerate drift .g.dart files after schema changes
```

`--no-tree-shake-icons` is **always required** for release builds because icon codepoints are constructed dynamically at runtime.

The version string is injected at build time: `--dart-define=APP_VERSION=<version>` (set by CI as `1.0.<run_number>`).

### Server (companion sync server)

```powershell
cd server
dart run bin/luma_server.dart      # run locally
.\run_local.ps1                    # PowerShell helper with env vars
docker-compose up                  # containerised deploy
```

## Coding Style & Naming Conventions

- Linter: `flutter_lints` (`flutter analyze`). No customisations beyond the defaults in `analysis_options.yaml`.
- Dart SDK constraint: `^3.12.2`.
- File names: `snake_case.dart`. Widget files named after the widget class they export.
- No trailing comments in production code.
- Repository classes are plain Dart objects (not `ChangeNotifier` unless they need to notify widgets directly).

## Testing Guidelines

- Framework: `flutter_test` (standard Flutter unit + widget tests).
- Test files live in `test/`.
- Run all tests: `flutter test`.
- Run a single file: `flutter test test/<file>_test.dart`.
- Integration/sync tests (`sync_integration_test.dart`, `p2p_test.dart`) require no external services — they spin up in-process fakes.

## Plugin Development

Adding a new plugin requires four steps (see `PLUGIN_GUIDE.md` for full detail):

1. Add entry to `plugins/registry.json` and create `plugins/<id>/manifest.json`.
2. Implement code under `lib/features/plugins/installed/<id>/` — follow the pattern of existing plugins (DB → repository → scope → page).
3. Register the scope in `main.dart` (initialise DB/repository, nest the scope).
4. Add the plugin ID → widget mapping in `app_shell.dart` → `_pluginPageFor()`.

## CI / Release

GitHub Actions (`.github/workflows/release.yml`) builds on every push to `master`:
- Windows: produces `dist/luma-setup.exe` (Inno Setup installer).
- Android: produces `luma-<version>.apk`.
- Both are attached to an automatically created GitHub Release tagged `v1.0.<run_number>`.

The in-app updater (`lib/app/update/`) polls GitHub Releases on startup and can apply the Windows installer silently (no admin rights needed; installs to `%LOCALAPPDATA%\Programs\luma`).

## Commit Conventions

Commits use short, lowercase, freeform messages (no conventional-commits prefix). There are no enforced branch or PR conventions observed in the history.
