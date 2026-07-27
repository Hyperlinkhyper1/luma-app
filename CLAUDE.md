# CLAUDE.md

Guidance for Claude Code working in this repository.

The project's conventions live in one place, [`AGENTS.md`](AGENTS.md) —
structure, build/test commands, coding style, plugin steps, CI. Read it
first; this file only adds what is specific to working here as an agent.

@AGENTS.md

## Orientation

`luma` is a Flutter app for Windows, Linux and Android with a companion Dart
sync server in `server/`. State flows through the **Scope pattern**: a
repository per feature, exposed by an `InheritedWidget` created in
`main.dart`. When you add a feature, follow that shape rather than
introducing a new state-management approach.

## Things that will bite you

- **Never let anything reach a luma server without checking the gate.** Call
  sites check `SyncService.serverReady` (not `signedIn`), and HTTP goes
  through `GatedServerClient` in `lib/sync/server_access.dart`. The only
  exception is the account handshake in
  `ServerAccessGate.accountSetupPaths`. `test/server_access_test.dart`
  guards this.
- **`--no-tree-shake-icons` is required on every release build.** Icon
  codepoints are built at runtime, so tree-shaking silently blanks them.
- **Drift schema changes need `dart run build_runner build`.** Commit the
  regenerated `.g.dart` alongside the schema change; don't hand-edit it.
- **Amounts in finance are integer cents.** Never store money as a double.
- **Adding a plugin touches four places** — the registry entry plus
  manifest, the code under `lib/features/plugins/installed/<id>/`, the scope
  in `main.dart`, and the id → widget line in `AppShell._pluginBodyFor`.
  Miss the last one and the plugin installs but opens an empty state. See
  [`PLUGIN_GUIDE.md`](PLUGIN_GUIDE.md).
- **`plugins/` is data, not code.** `lib/` never imports from it; the app
  fetches `registry.json` over HTTPS at runtime. Editing a manifest changes
  the live marketplace without a rebuild.
- **User-visible strings are localized.** Add them to `lib/l10n/app_en.arb`
  and the other ARB files, then `flutter gen-l10n` — don't hardcode English
  in a widget.

## Verifying a change

`flutter analyze` and `flutter test` both run offline and are the bar for
any change. The sync and p2p tests spin up in-process fakes, so a green
suite means nothing external was needed. There is no Flutter toolchain in
every environment — if the commands aren't available, say so plainly in the
summary rather than implying the change was verified.

## Committing

- Short, lowercase, freeform subject lines (`stocks: keep the portfolio
  total on today's prices`). No conventional-commits prefixes.
- `.claude/settings.json` sets `includeCoAuthoredBy: false` — commits carry
  no `Co-Authored-By` trailer. Leave that setting alone.
- Don't commit the large screenshots at the repo root, build output, or
  generated localization files unless the change actually regenerates them.

## Skills

`.claude/skills/` carries design skills (`design`, `design-system`,
`ui-styling`, `ui-ux-pro-max`, `banner-design`, `brand`, `slides`). Reach
for them for visual and UI work; the app's own design tokens are in
`lib/theme/luma_theme.dart` (`LumaPalette`) and should win over any generic
palette a skill suggests.
