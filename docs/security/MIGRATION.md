# Deployment and recovery precautions

This change writes new vault (`pw3:`), AI (`ai2:`), and sync (`LA/01`) ciphertext formats. New code reads historical formats. Older app versions cannot read new ciphertext or OS-stored keys. **Upgrade all sync/P2P devices together; do not downgrade an upgraded data directory.** There is no format-negotiation mechanism for old peers.

1. Test on a disposable copy of representative data and a disposable OS account first. Keep original legacy keys and data together in access-controlled offline backup before rollout; the application does not create a portable encrypted backup for you.
2. Ensure OS secure storage works. Linux needs libsecret/Secret Service, an unlocked user keyring and packaged libjsoncpp runtime dependencies. Windows uses its user protection facilities. Validate Android keystore behavior, Apple Keychain entitlements/signing, and OS account restore separately.
3. First load validates and transfers existing key bytes unchanged, reads the protected value back, then deletes the legacy key file. A missing/conflicting/malformed key fails. Never “repair” that error by generating a new key or deleting ciphertext.
4. Vault record migration is transactional and repeatable. Private metadata is packed into an authenticated envelope in the existing info column; no table deletion/schema replacement occurs. A corrupt password, TOTP or metadata envelope keeps its original row and is reported as unreadable. Correct the original data/key using a verified backup; do not save an empty replacement.
5. Sync JSON credentials are moved into a protected account/origin-bound bundle. Preserve the OS user/keyring when moving machines. A bare copy of app-support files is insufficient after migration.
6. Account password rotation retains old encryption keys securely before changing server credentials. Failed remote re-encryption is surfaced; the originating device can still try retained keys. Keep that device until all remote objects and other devices have been verified. Retained keys deliberately remain after success because interrupted transfers, copies and old snapshots may still need them.

Android automatic backup is disabled to avoid restoring encrypted state without its keystore keys. Some device manufacturers' transfer behavior differs; validate actual devices. Historical backups/plaintext pages are not erased by this setting.

HTTPS is now required for server APIs in production builds, including self-hosted servers. Configure TLS before upgrading. Literal localhost HTTP remains available only in debug builds. Server redirects must be replaced with the final configured HTTPS base URL.

App PINs migrate from SHA-256 to Argon2id after successful verification; new PINs use Argon2id immediately. Each device keeps its own PIN setting; synced settings no longer set, replace or clear it. Clipboard secrets now expire after 30 seconds when still present.

Outstanding deployment validation: power interruption during each persistence operation; OS keyring locked/unavailable; Android OS backup/restore; Apple reinstall/keychain persistence; Windows profile migration; Linux headless sessions; mixed-version peers; partially completed password rotations; concurrent devices writing during rotation. Do not claim these tests passed merely because in-memory tests passed.
