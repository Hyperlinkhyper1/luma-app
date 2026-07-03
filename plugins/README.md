# luma plugins

This folder is the plugin catalog for the luma app. It is **not** part of the
compiled app — `lib/` never imports anything from here. Instead, the app's
Plugins marketplace fetches `registry.json` (and each plugin's `manifest.json`)
straight from this repo over HTTPS at runtime, so the catalog can grow without
shipping a new build.

## Layout

- `registry.json` — the list shown in the marketplace (id, name, short
  description, icon, category, tags, free, version).
- `<plugin-id>/manifest.json` — fetched when the user clicks Download *or*
  opens the plugin's detail page (tap anywhere on its row except the button).
  Confirms the plugin is reachable, records its version locally, and supplies
  the detail page's long-form content:
  - `details` — the full write-up, shown under "About". Separate paragraphs
    with a blank line; each becomes its own paragraph in the app.
  - `screenshots` — a list of image filenames (e.g. `["overview.png",
    "chart.png"]`). Put the actual image files in
    `<plugin-id>/screenshots/`. The app resolves each one to
    `plugins/<plugin-id>/screenshots/<filename>` and shows them as a
    horizontal, tap-to-zoom gallery. Omit the field (or leave it empty) for no
    gallery.

If `details` is left out, the detail page falls back to the short
`description` from `registry.json`.

## Adding a plugin

1. Add an entry to `registry.json`.
2. Add `<plugin-id>/manifest.json` with matching fields, plus `details` and
   (optionally) `screenshots`.
3. If you listed screenshots, drop the image files in
   `<plugin-id>/screenshots/`.
4. Implement the plugin's UI in `lib/features/plugins/installed/<plugin-id>/`
   and register its id in `AppShell._pluginPageFor` so it can be opened once
   installed.

## Writing or updating a plugin's page later

You don't need to touch the app at all to change a plugin's detail page —
just edit `<plugin-id>/manifest.json` (`details` text, `screenshots` list) and
push. The marketplace fetches it fresh every time someone opens that plugin's
page.
