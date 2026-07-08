## Bugs + storage change

### Bug 1 — App always opens on Auto Clicker, not Home
**Root cause:** `lib/app/app_shell.dart:55` has `String? _selectedPluginId = 'auto-clicker'; // TEMP-QA`, plus a forced-activate block at lines 101–110 that injects a fake Auto Clicker record. This is leftover QA scaffolding.

**Fix:** Revert `_selectedPluginId` to `null` and delete the forced-activate `if (_selectedPluginId == 'auto-clicker')` block. App will then open on the configured start screen (Home by default).

### Bug 2 — "Sync & account" block defaults open
**Root cause:** `_CollapsibleSectionState._expanded = true` at `lib/account/account_page.dart:175`.

**Fix:** Change the default to `false`.

### Bug 3 + storage change — Changing plans does nothing; storage now 10/25/50 MB, only user data counts

These are one fix: make the selected **plan drive the storage limit**, which is the real, visible effect of switching plans.

**My interpretation of "plugins do not count, only the database generated":** count **all user-generated data** — every feature/plugin database and JSON store (finance, passwords, notes, calendar/agenda, mood journal, school, price tracker, QR codes, bulletin board, data management, auto-clicker settings, youtube history, sync/p2p state, pw key). **Exclude** the app's own binaries/tools (the `tools/` **and** `ffmpeg/` dirs — the ~120 MB converter binary currently counts, which is wrong) and log files (`*.log`). Rationale: you listed "agenda" (the Calendar plugin) as something that counts, so plugin *data* counts; only app binaries/tools/logs are excluded. *(If you actually meant only core features — finance/passwords/notes — should count and all plugin data excluded, tell me and I'll switch to an allowlist.)*

**Changes:**

1. **`lib/account/plan.dart`** — Add `final int storageMb;` to `Plan`. Values: core = 10, orbit = 25, nova = 50. Update the three plans' feature strings from "1 GB / Expanded / Largest local storage" to **"10 MB / 25 MB / 50 MB local storage"**. Rewrite the class doc comment (currently says "purely cosmetic … same cap regardless of plan" — no longer true).

2. **`lib/storage/storage_guard.dart`**:
   - Replace `static const int limitBytes` with an instance `int _limitBytes` + getter `int get limitBytes` + a `void setLimitBytes(int bytes)` setter. Keep `static late StorageGuardService instance`. Update `isOverLimit` / `ensureWithinLimit` to use the instance field (they already reference `limitBytes` — fine once it's an instance getter). `StorageLimitExceededException` already receives the value as a ctor arg, no change.
   - Expand exclusions so only user data counts: `_excludedDirNames = {'tools', 'ffmpeg'}`, and in `refresh()` skip any file whose path ends in `.log` (covers `update.log`, `luma_p2p_debug.log`).

3. **`lib/main.dart`** (`_LumaAppState`):
   - Import `account/plan.dart`.
   - In `initState`, after `StorageGuardService.instance = _storageGuard`, set the initial limit: `_storageGuard.setLimitBytes(planById(widget.settings.selectedPlanId).storageMb * 1024 * 1024)`.
   - Listen to plan changes: add `widget.settings.addListener(_onSettingsChanged)`, where `_onSettingsChanged` recomputes the bytes from the current plan and, if different, calls `_storageGuard.setLimitBytes(...)` then `_storageGuard.refresh()` (so a downgrade that puts the user over the new cap immediately reflects in the banner / write-blocking). Remove the listener in `dispose()`.

4. **`lib/account/account_page.dart`** (`_LocalStorageBar`):
   - Change `const limit = StorageGuardService.limitBytes;` → `final limit = guard.limitBytes;` so the bar reflects the active plan's cap.

5. **No change needed** to `plan_selection_page.dart` — `_selectPlan` already calls `setSelectedPlanId` + persists + pops. The new settings listener in `main.dart` makes that selection actually change the storage limit (the visible effect that was missing).

**Note on enforcement:** Hitting the limit will continue to block new writes (existing behavior). With a 10 MB Core cap a heavy user could hit it fast; if you'd rather it only warn instead of block, say so and I'll adjust. Downgrading below current usage will immediately trip the cap — expected.

### Verification
- `flutter analyze` (lint clean).
- Launch → lands on Home (bug 1).
- Account tab → "Sync & account" collapsed by default (bug 2).
- Account → Change plan → pick Orbit → return → Storage bar now shows "X of 25 MB used"; pick Core → shows "10 MB"; pick Nova → "50 MB" (bug 3 / storage change).
- Storage bar value no longer includes the converter's ffmpeg binary or logs.