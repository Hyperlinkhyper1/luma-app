# luma plugins

This folder is the plugin catalog for the luma app. It is **not** part of the
compiled app — `lib/` never imports anything from here. Instead, the app's
Plugins marketplace fetches `registry.json` (and each plugin's `manifest.json`)
straight from this repo over HTTPS at runtime, so the catalog can grow without
shipping a new build.

## Layout

- `registry.json` — the list shown in the marketplace grid (id, name,
  description, icon, category, version).
- `<plugin-id>/manifest.json` — fetched when the user clicks Download, used to
  confirm the plugin and record its version locally.

## Adding a plugin

1. Add an entry to `registry.json`.
2. Add `<plugin-id>/manifest.json` with matching fields.
3. Implement the plugin's UI in `lib/features/plugins/installed/<plugin-id>/`
   and register its id in `AppShell._pluginPageFor` so it can be opened once
   installed.
