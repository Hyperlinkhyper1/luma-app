# luma — brag plan

**What it is:** a local-first desktop + Android app that folds a budget tool, password vault, file converter, notes and an AI assistant into one window, plus 43 optional plugins.
**For:** people with a taskbar full of single-purpose apps.
**Sets it apart:** absurd breadth in one clean Modrinth-style shell, works fully offline with no account.
**Funniest true claim:** the password manager and the Minecraft launcher live in the same app.
**Visual hook:** a wall of single-purpose app tiles collapsing into one lavender window.
**Tone:** `default`, leaning deadpan on the punchline.
**Share caption:** "My password manager also launches Minecraft."

## Angle
"Stop opening 14 apps." Every scene is the real luma shell (icon rail, top bar, rounded cards) in the default dark gray lavender palette, with the rail selecting each destination like a real click. The last highlight walks the plugin marketplace and lands on Minecraft Launcher → Installed.

## Visual identity
LumaPalette.dark: rail #121019, bg #17141F, surface #1E1B28, border #2C2839, accent #B49DF5, text #ECEAF4 / #A9A3BD / #6F6981, success #57D9A3, danger #FF6B81, warning #FFC15E. Segoe UI (Flutter's Windows default), Material rounded icons, 72px rail with 44px buttons and a 3px accent bar.

Rebuilt by hand in HTML: the app is Flutter with drift/sqlite and native plugins, so it can't render in a browser. Layout, tokens, icons and copy are taken from `nav_rail.dart`, `luma_theme.dart`, `app_en.arb`, README and `plugins/registry.json`.

**Placeholder data:** every amount, pot, vault entry, email and chat message is fictional (example.com sites, round euro figures). Nothing from the user's own app data.

## Music
"Technology Synthpop No Copyright" by MiroMaxMusic (Pixabay Content License, no attribution required), 105 BPM (beat 0.571s). Excerpt 63.16s–102.02s: the quiet breakdown plays under the hook and the drop (66.59s) lands on the reveal. Every scene starts on a kick; soft UI ticks sit under the music on each click. Fades out over the last 2.5s.

## Storyboard (38.86s = 68 beats, 30fps, 1920×1080)

Second version: slower (6 beats ≈ 3.4s per feature, up from ~2.3s) and three more features, at the user's request. That puts it past the usual 15–25s window on purpose.

| # | Beats | Time | Scene | On screen |
|---|---|---|---|---|
| 1 | 0–6 | 0.0–3.4 | Hook | 14 app tiles pop in. **"Stop opening 14 apps."** |
| 2 | 6–12 | 3.4–6.9 | Reveal (drop) | Tiles collapse into the luma window. **luma** / "Everything you open daily. One window." |
| 3 | 12–18 | 6.9–10.3 | Finance | Net worth counts up, pots fill, weekly bars. "Budgets, pots & net worth." |
| 4 | 18–24 | 10.3–13.7 | Password Manager | Vault with live 2FA codes, offline breach flag. "An encrypted vault with built-in 2FA." |
| 5 | 24–30 | 13.7–17.1 | File Converter | holiday.mov → MP4, "Exported" toast. "Audio, video, images. Offline." |
| 6 | 30–36 | 17.1–20.6 | Assistant | Switch to Nebula, prompt, streamed reply. "AI chat in three modes." |
| 7 | 36–42 | 20.6–24.0 | Groceries List | Search "oat drink" across Jumbo, Albert Heijn, Hoogvliet and Lidl, add the cheapest to a list split by store, total ticks up (example prices). "Supermarket prices, side by side." Plan badge shows Orbit, which includes Groceries. |
| 8 | 42–48 | 24.0–27.4 | Recipe Book | Meal planner week (breakfast/lunch/dinner), shopping list. "Recipes and a weekly meal planner." |
| 9 | 48–54 | 27.4–30.9 | Sync & account | Toggle Finance/Passwords/Notes (3 of 3), desktop ↔ phone, "Synced just now". "Encrypted sync across your devices." |
| 10 | 54–62 | 30.9–35.4 | Plugins | Scroll the marketplace, install Minecraft Launcher. "43 more tools…" → "Also, a Minecraft launcher." |
| 11 | 62–68 | 35.4–38.9 | Outro | luma, "Free & local-first · Windows, Linux, Android", GitHub URL |
