# Validation record

Environment: Windows, Flutter 3.44.4, Dart 3.12.2; 2026-09-10. Tests use fake credentials. The real user's vault and keyring were not migrated or opened to validate this work.

| Check | Result |
|---|---|
| Affected security/feature suite | 94 passed across security hardening, sync, server access, local account, P2P, SFTP, YouTube credential, settings widget and update-asset tests |
| Dedicated security file | 9 tests, included above; assertions include every-byte envelope mutation and 1,000 generated nonces |
| Companion server `dart test` | 95 passed |
| Final targeted `dart analyze` | No issues in `lib/security`, vault metadata/repository, updater and security tests |
| Full `flutter analyze --no-pub` | 139 diagnostics: 9 warnings and 130 informational diagnostics; no errors. Existing broad repository diagnostics remain. This run preceded the final metadata addition; that addition was separately analyzed. |
| Windows release | Passed with `flutter build windows --release --no-tree-shake-icons`, including native secure-storage registration; repeated after metadata/updater changes |
| First full Flutter suite | 1,268 passed, one skipped integration test, one worth-counter widget failure |
| Final full Flutter suite | 1,269 passed, one skipped integration test, the same one worth-counter widget failure |
| Worth-counter isolation run | Same failure reproduces: `test/worth_counter_widget_test.dart:88` expects `€9.00` but finds no matching text. Test/implementation are outside the changed security paths. |
| Git whitespace check | No whitespace errors; CRLF conversion notices only |

Logs are local under `tmp/security-*.log` and are not evidence of platform certification.

## Added security assertions

- AES-GCM round trip, wrong key, wrong context and mutation of every envelope byte, including version, nonce, ciphertext and tag.
- Fresh nonce sample uniqueness and rejection of unsupported versions.
- Vault password/TOTP domain and row binding; legacy v2 decryption.
- Verified repeatable migration and byte-for-byte preservation of a row with corrupt TOTP.
- Corrupt-secret export rejection and rollback when importing a missing password.
- Metadata encryption, authenticated metadata presence, two-device sync under different local keys, and fake-secret absence from raw SQLite bytes and rows.
- OS-store key migration, read-back use, malformed/missing key rejection, and preservation of malformed legacy key bytes.
- Sync JSON removal of fake token/key; protected origin overriding a tampered JSON URL; logout persistence.
- Argon2id verifier round trips, random salts, wrong input, unknown version rejection and legacy SHA-256 compatibility.
- Production HTTPS requirements, URL-credential rejection, debug loopback handling and lookalike-host rejection.

## Explicit gaps

No valid/invalid update-signature tests exist because signature verification is not implemented. No malicious-plugin denial test is claimed because no sandbox exists. No locked-vault test is claimed because no repository-enforced lock exists. No portable encrypted-backup restore test is claimed because that workflow is absent.

Keyring tests use the plugin's fake backend. Real OS credential access, disk corruption/power interruption, mobile reinstall/restore, Linux keyring availability, cross-device rotation interruption/concurrency, updater redirects against live GitHub, archive fuzzing and live malicious-server scenarios still require testing. iOS/Android/Linux release builds were not run on this Windows host. Server tests exercise existing controls; no professional penetration test occurred.
