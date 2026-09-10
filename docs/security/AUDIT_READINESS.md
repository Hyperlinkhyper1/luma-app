# Audit readiness — partial hardening

Date: 2026-09-10. The requested comprehensive security architecture is **not complete**. The changes below fix concrete issues, but several remaining items require repository engineering, not merely owner configuration. No independent audit occurred.

## Security controls implemented

- Maintained AES-256-GCM for new vault password/TOTP, AI key and sync writes; versioned envelopes and authenticated contexts.
- Authenticated vault metadata envelope protects service, email, username, phone, icon and secure notes, without a destructive schema change. IDs and timestamps remain visible.
- Separate password/TOTP HKDF subkeys; existing independent credential-domain root keys retained.
- OS-protected key migration with read-back verification and fail-closed missing/conflicting/malformed key handling.
- Protected sync credential/origin bundle; serialized saves; corrupt sync state no longer silently discarded.
- Transactional verified vault migration; unreadable TOTP preservation; sync import/export rejection of missing/unreadable secret fields.
- Argon2id app PIN verifier with successful-login legacy upgrade; PIN settings no longer imported from sync.
- Clipboard expiry for copied vault values.
- Old sync key retention before credential rotation; opaque byte re-encryption; authentication-checked recovery reads; visible partial failure.
- Server HTTPS policy, redirect refusal, updater source/path/version/size checks.
- Security regression CI required by all four release jobs; Linux secure-storage build dependencies and Android backup protection.

## Existing controls retained

Server approval gates, random hashed expiring sessions and device revocation, account ownership checks, request-size/rate limits, client-side encrypted snapshot flow and collection checks, chat AES-GCM/X25519/HKDF, SSH known-host handling, SFTP host encryption/jail, Minecraft safe path checks, Android signing verification, per-user storage, committed lockfile and icon-preserving release build flags.

## Vulnerabilities identified

1. Custom vault/sync encryption and adjacent unprotected key files exposed credentials to app-directory theft.
2. Vault metadata and secure notes are plaintext, and the repository has no cryptographic lock.
3. Corrupt TOTP migration/export could silently destroy a seed; missing password import could replace credentials with blanks.
4. SFTP malformed-key handling generated a replacement and destroyed decryptability.
5. Sync persisted bearer tokens and encryption keys in JSON; a mutable origin could redirect tokens.
6. Password rotation discarded the active old key before all remote content was re-encrypted and assumed binary chunks were JSON.
7. PINs used fast unsalted SHA-256 and synced settings could alter local PIN protection.
8. Clipboard secrets had no expiry.
9. Static compiled plugins share process and OS privileges; no actual permission enforcement/sandbox.
10. AI/user content, chat cache, finance/notes and other plugin persistence need comprehensive privacy controls.
11. Server transport did not centrally require TLS; custom updater lacked independent signatures and accepted remote filenames without local path validation.
12. Logging, import/archive limits, secrets/history/dependency scanning, recovery and platform backup policies were not comprehensively secured.

## Vulnerabilities fixed

Fixed new-write custom ciphers in vault/sync/AI, migrated the listed key stores, removed plaintext sync credentials from JSON, bound protected token/origin, preserved corrupt TOTP rows, rejected destructive malformed vault snapshots, stopped malformed SFTP key replacement, upgraded the app PIN, stopped remote PIN overwrite, added clipboard expiry and constrained gated transport/update paths. Key migration preserves the same key bytes rather than making existing ciphertext unreadable.

## Risks reduced

Offline file-copy exposure is reduced for migrated key domains. Snapshot tampering is checked by a standard AEAD. Rotation now preserves locally recoverable key material and binary object content. This does not solve cross-device atomicity, every custom credential cipher, root-process compromise or portable backup recovery.

## Remaining risks

- Master-password random-key wrapping, repository lock, auto-lock, lifecycle handling and minimized seed decryption remain unimplemented.
- Account/server KDF migration remains unimplemented; existing derivation/salt behavior remains for compatibility.
- No plugin sandbox/capability enforcement; no comprehensive AI consent/data-access broker.
- Finance, notes and other private local stores remain plaintext. Unreadable legacy vault rows are deliberately preserved, including any plaintext metadata they already contain.
- Remaining custom credential ciphers and other integrations' credential storage remain to migrate.
- Newer ciphertext cannot be read by older devices. Coordinated rollout is necessary.
- Rotation retains old keys indefinitely on the initiating device; other devices and concurrent writers can still encounter partially rotated data. No fully tested resume protocol exists.
- Secure-storage failures may block startup/affected features. Actual platform keyring/reinstall/profile recovery needs validation.
- Clipboard history/screenshots, raw error logs, archive bombs/path edge cases, bank import resource use and telemetry privacy remain risks.
- A compromised GitHub/update endpoint can still provide malicious executable updates. Current updater authenticity is insufficient.
- No general user recovery key or tested portable encrypted backup/restore workflow.
- Dart cannot guarantee secret memory erasure or same-process isolation. Deleted files/SQLite pages/backups may retain old data.

## Items requiring external infrastructure

Production TLS for self-hosted APIs; protected code-signing and release-signature key custody; signed Windows and Apple distribution; authenticated key rotation infrastructure; protected release environments; production rate-limit/abuse monitoring; backup retention and incident response systems.

## Items requiring project-owner decisions

Choose mandatory vault unlock UX and recovery policy; approve independent plugin process/OS sandbox architecture; define permission/data-consent policy; coordinate all-device format rollout; define old-key retention/pruning; configure disclosure contact and private reporting; set retention/deletion policy; decide which platforms and older releases are supported.

## Items requiring professional security audit

- Crypto envelope parsing, AEAD/AAD/domain separation, legacy readers, KDF/salt semantics, nonce limits and library/platform implementation.
- Offline extraction, keyring access control, lock lifecycle, process memory, clipboard, screenshots and backups on real devices.
- Power-loss/concurrency fault injection through migrations, save ordering, password rotation and recovery.
- Malicious plugin/game/dependency escape into vault files/key APIs, scoped IPC and capability bypass.
- Compromised-server blob substitution/replay, object/collection binding, key enrollment and family cross-account access.
- All authentication/OAuth/reset/session routes, account enumeration, distributed rate limits and revoked-device behavior.
- Every AI egress path, prompt/tool injection, consent revocation and provider/proxy logging.
- Update trust root, signed manifest/artifact verification, rollback/freeze protection, signing pipeline and credential custody.
- Archive/import fuzzing, symlink/reparse-point traversal, download limits and external process argument handling.
- Full git-history secret scan, dependency/advisory scan, SBOM and CI action provenance.

## Cryptographic architecture

See `SECURITY_ARCHITECTURE.md`: standard AES-GCM new writes; legacy readers; OS-held random device keys; HKDF domain separation; Argon2id **app PIN only**; unchanged account PBKDF2. No master-password-wrapped random vault key has been implemented.

## Plugin isolation status

PARTIAL only in the sense of existing module organization. Security isolation is NOT implemented. No permission test should pretend calculator code cannot access vault resources when same-process code can.

## AI isolation status

Main assistant has no injected vault/TOTP query capability. This is a useful existing boundary at the tool interface, not a process sandbox or comprehensive privacy guarantee. Explicit data consent and other plugin/provider entry-point auditing remain outstanding.

## Sync security status

Client-side authenticated encryption protects normal snapshot content; server metadata remains visible. Family/shared APIs and AI proxies are distinct flows. Account-derived keys and retained rotation history are documented above. Avoid blanket zero-knowledge marketing.

## Update signing status

BLOCKED for a production signature trust root: no private signing key or publisher identity was supplied. Independent signature verification is also **not implemented in code**, so owner key provisioning alone does not finish the work. Android signing checks remain; Windows/custom updater signing and Apple signing require further implementation/configuration.

## Validation

See `VALIDATION.md` for commands/results and limits. Final affected suite: 94 passed. Server tests: 95 passed. Windows release build passed. Final full Flutter suite: 1,269 passed, one skipped, one reproducible worth-counter widget failure outside the changed security paths. Targeted analysis is clean; full analysis reports 139 existing broad repository diagnostics and was not globally suppressed.

## Scorecard

| Area | Before | After | Status |
|---|---|---|---|
| App PIN KDF | Unsalted SHA-256 | Versioned Argon2id, salted, legacy upgrade | COMPLETE for verifier only |
| Account/vault KDF architecture | PBKDF2 account; no wrapped vault root | Account unchanged; device root OS-protected | PARTIAL |
| Vault encryption | Custom cipher and plaintext metadata | AES-GCM password/TOTP and metadata, legacy reads | PARTIAL: cryptographic lock remains |
| TOTP separation | Same key, corruption-loss paths | Separate subkey; preservation tests | PARTIAL: lifetime/isolation remain |
| Secure storage | Adjacent keys/plain sync state | Eight migrated domains including chat and sync | PARTIAL: other credentials/platform tests |
| Plugin permissions | Same-process modules | Unchanged | PARTIAL |
| AI isolation | Narrow main tools; shared process | Preserved, provider-bound new key ciphertext | PARTIAL |
| Sync E2EE | Custom authenticated cipher | AES-GCM; old-key retention; binary rotation | PARTIAL |
| Sessions | Hashed random expiring/revocable | Retained; protected client storage/transport | PARTIAL: full auth audit outstanding |
| Recovery/backups | No portable encrypted restore | Local secure old-key history | PARTIAL |
| Updater signing | No independent verification | Source/path/size/version checks only | BLOCKED / further implementation |
| Logging | Raw exception paths | Broad sanitizer not implemented | PARTIAL |
| CI security | Release builds | Required affected-security regression checks | PARTIAL: scans/provenance remain |

## Important changed files

`lib/security/*`; password crypto/repository/page; AI key store; GitHub/YouTube/AIS/SFTP key loaders; secure-chat identity store; settings PIN creation/verification/sync; sync crypto/state/collection/service/gate; updater; `test/security_hardening_test.dart`; pubspec/lockfile/native plugin registration; Android manifest; release/security workflows; this documentation and root `SECURITY.md`.
