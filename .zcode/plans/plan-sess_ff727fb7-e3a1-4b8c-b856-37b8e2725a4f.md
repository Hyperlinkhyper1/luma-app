# Make the cloud server optional for account creation (local-first)

## Problem
The user goes to **Settings → Sync & account → "Sign in or create account"** and is forced to enter a server URL (`_AccountDialog._submit()` at `sync_section.dart:431-438` bails with *"Add a cloud server first."*). But the backend to create a serverless local account (`SyncService.setLocalAccount`) **already exists and works** — P2P sync gates on `p2pReady`, not `signedIn`. The only gap is that the most discoverable dialog never offers the local path.

## The key insight
~95% of this feature is already built:
- `SyncService.setLocalAccount(email, password)` — derives an encryption key from email+password alone (deterministic salt from email). Same credentials on another device → same key → they recognize each other. No server.
- `isLocalOnly`, `p2pReady`, `localVerifier` (mistyped-password guard on the *same* device), `clearLocalAccount()` — all present.
- P2P controller, link, discovery all gate on `p2pReady`/`encryptionKey`, never on `signedIn`. A local account already pairs fine.
- Cloud-only features (Cloud Files, change password, delete account, storage bar, `syncNow`, periodic timer) correctly stay gated on `signedIn` (which still requires `token + encryptionKey + serverUrl`), so they remain inert for local accounts — **no weakening of that gate**.
- The Devices section already has a working `_LocalAccountDialog` reachable via its setup switch.

So this is a **focused UX change to one dialog**, not new infrastructure.

## Decision (user-chosen): Local-first, cloud optional
The "Sign in or create account" entry point defaults to the **no-server (local)** path. Cloud is the opt-in "advanced" path behind a button. This matches the app's "local utility" identity and removes the obstacle the user hit.

## Changes (all in `lib/settings/sync_section.dart`)

### 1. Rewrite `_AccountDialog` into a local-first flow
- **Rename** the entry button from "Sign in or create account" → "Set up account" (or keep "Create account") in `_SignedOutBody`. The dialog title becomes "Set up account".
- **Default mode = Local** (no server field shown). Fields: Email, Password, Confirm password. Calls `sync.setLocalAccount(email, password)`.
- **Cloud is opt-in**: a `LumaGhostButton("Use a cloud server instead")` reveals the server field AND switches to the cloud flow (the existing `signIn`/`register` path with segmented "Sign in / Create account" tabs). `_showServerField` becomes the mode switch (false = local, true = cloud).
- **`_submit()` rewritten** to branch cleanly:
  - `_showServerField == false` → validate email + password(≥10 chars) + confirm-match → `setLocalAccount`. This replaces the current "Add a cloud server first." bail-out.
  - `_showServerField == true` → existing cloud validation (`validateServerUrl`) → `signIn`/`register` as today.
- Pre-fill email from `sync.email` in both modes (already done). When editing an existing cloud account, `_showServerField` starts true (already the case via `_server.text.isNotEmpty`).
- Keep the existing mistyped-password warning behavior: `setLocalAccount` throws `StateError` if a local identity already exists on this device and the password doesn't match — surface that error in the dialog.

### 2. Adjust copy in `_SignedOutBody`
The current copy already mentions the Devices-section local path (lines 53-55). Tighten it so the primary CTA clearly leads to the (now local-first) account dialog, and the Devices section is mentioned as "or pair devices directly below." Avoid duplicating the setup entry point.

### 3. Keep `_SignedInBody` local/cloud branch as-is
It already handles both states correctly: `cloud ? serverUrl : 'Local only — syncs directly between your devices, no server'`, and the local branch shows "Back up to a server…" (opens the same dialog in cloud mode). No change needed — this is already the model the rewrite follows.

## What stays unchanged (and why)
- **`SyncStateStore.signedIn`** keeps its three-way definition. Local accounts have `encryptionKey` but no `token`/`serverUrl`, so `signedIn == false` and every `_api!` site stays protected. **Critical safety invariant preserved.**
- **`devices_section.dart` `_LocalAccountDialog`** — leave as-is. It's a secondary, equally-valid entry point from the Devices section. Both dialogs call the same `setLocalAccount`. (Could dedupe later, but two small dialogs are clearer than one overloaded one, and the user already has this path working.)
- **All P2P code** — already gates on `p2pReady`. No change.
- **Cloud Files** — stays gated on `signedIn`. No change.
- **`main.dart` wiring** — already unconditional. No change.

## Verification
- `flutter analyze` — expect 0 new errors/warnings.
- Manual: open Settings → Sync & account → "Set up account" → with NO server field visible, enter email+password → account created, `isLocalOnly == true`, Devices section activates.
- Manual: same dialog → click "Use a cloud server instead" → server field appears, cloud sign-in/register works as before.
- Manual: local account → "Back up to a server…" → cloud dialog pre-fills email, account upgrades to cloud (`register` reuses the local salt per `sync_service.dart:204-206`, so the encryption key and existing P2P peers are preserved).

## Files touched
- `lib/settings/sync_section.dart` — rewrite `_AccountDialog` + `_SignedOutBody` copy. **Only file changed.**

## Out of scope
Deduping the two local-account dialogs, changing `signedIn`'s definition, Bluetooth/BLE, cross-account sharing.