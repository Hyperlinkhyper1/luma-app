# Initial source inventory

Recorded from code inspection before implementation, 2026-09-10. This inventories discovered surfaces, not a line-by-line audit of every plugin. The working tree also contained unrelated AI catalog, school, asset and supermarket edits; those were preserved.

| Subsystem / source | Initial classification and flow |
|---|---|
| `features/passwords/password_crypto.dart`, repository, database, page | Insecure architecture: custom HMAC stream cipher, adjacent plaintext random key, plaintext metadata, action-only optional PIN, decrypted collection held in widgets. Existing row/field MAC binding useful and retained. |
| Password legacy migration / sync adapter | Insecure failure handling: unreadable TOTP could become null; missing imported password became empty. Drift import transaction useful. |
| `sync/sync_crypto.dart` | Partial: PBKDF2 200k, HKDF auth/encryption separation and authenticated custom LS1 cipher. Not a standard AEAD implementation. |
| `sync/sync_state.dart` | Insecure: token and encryption key persisted as readable JSON; load/save errors swallowed. |
| `sync/sync_service.dart` password rotation | Insecure: changes server credentials first, replaces local key, treats every blob as gzip JSON and swallows re-encryption failures. Cloud-file chunks do not satisfy that assumption. |
| `sync/server_access.dart` | Useful approval gate, but no central TLS requirement or redirect policy. |
| `p2p/peer_protocol.dart`, controller/link/listener | Partial: account-secret-based peer trust and encrypted snapshots; not independent cryptographic device enrollment. |
| `server/lib/api.dart`, store, rate_limit | Useful random hashed expiring sessions, ownership checks, session listing/revocation, salted auth-key hashing, rate limits and body caps. Full route/abuse audit still needed. |
| `settings/settings_controller.dart`, settings page | Weak SHA-256 PIN verifier; PIN state included in synced settings. Not a cryptographic vault lock. |
| `features/chat/ai_key_store.dart`, controller, tools, providers | Custom credential cipher/key beside data. Main tool registry only injects plugin-install and QR capabilities; no vault query tool. User text/history goes to provider/proxy. |
| `features/plugins/plugin_repository.dart`, catalog, `main.dart`, `app_shell.dart` | Metadata enables compiled modules sharing root scopes/process. No sandbox or enforced permission boundary. |
| `installed/secure_chat/data` | AES-GCM/X25519/HKDF retained. Private identity JSON and message cache require at-rest protection; malicious-server identity trust remains unresolved. |
| `installed/sftp` | Custom saved-secret cipher; corrupt key could be overwritten. Existing SSH host-key checks and host jail/AES-GCM protocol retained. |
| `installed/account_overview`, transport AIS | Independent adjacent key files for GitHub/YouTube/AIS credential stores. Other integrations remain to audit. |
| `installed/minecraft_launcher` | OAuth/session data, downloaded code and processes are high risk. Existing `safe_path.dart` checks some archive paths. Symlink/reparse-point and executable containment not established. |
| `app/update/update_service.dart`, release workflow | HTTPS, newer-version comparison, Android signing checks. Untrusted asset name used in local path; no independent signature verification; Windows unsigned, iOS unsigned. |
| Finance/notes, cloud files, backups/imports | Finance SQLite and notes JSON plaintext locally. Cloud-file bytes sealed before upload. Bank imports buffer arbitrary files; limits and archive inflation need work. Portable encrypted backup/recovery not established. |
| Logging/telemetry | Raw exception logging is widespread; plugin download reporting and AI usage accounting exist. No comprehensive central sanitizer or consent audit established. |
| Dependencies/config | Lockfiles present, existing cryptography library available. Release actions use mutable major tags. Pattern scan of selected source/config directories found no obvious tested key patterns, but is not a full history/entropy scan. |

## Discovered Drift table classification

- **Critical credentials:** `PasswordEntries`; `McAccounts` needs column-by-column OAuth/session review.
- **Private financial:** `Categories`, `Merchants`, `Pots`, `FinanceTransactions`, `RecurringRules`, `AllocationRules`, `Holdings`, `MetaItems`, `BalanceSnapshots`, `OverviewGraphs`.
- **Private personal content/activity:** `ChatConversations`, `ChatMessages`, `ErrandCategories`, `Errands`, `GroceryLists`, `GroceryListItems`, `WalletCards`, `BoardItems`, `UsageSessions`, `CalendarEvents`, `DinnerPlans`, all school tables (`SchoolSubjects`, `Assignments`, `TimetableEntries`, `FlashcardDecks`, `Flashcards`, `Formulas`, `GradeComponents`, `GpaRecords`, `Citations`, `MindMaps`, `MindMapNodes`, `StudySessions`), standalone mind-map tables including `MindMapMeta`, `AiUsageTurns`, `AiUsageScanFiles`, `DataDatasets`, `DataRows`, `Recipes`, `QrCodeEntries`, `MoodEntries`.
- **Lower-sensitivity metadata, potentially personal in context:** `InstalledPlugins`, `SteamGames`, `SteamPricePoints`, `Cs2MarketItems`, `Cs2MarketPricePoints`, `Cs2PinnedSkins`, `McInstances`, `McLaunchHistory`, `McInstalledMods`.

These classifications do not mean all fields have been encrypted. JSON stores, attachments, native plugin state, temporary files and server storage also require assessment beyond Drift tables.
