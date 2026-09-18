# Threat model

Scope: source review and partial code hardening, 2026-09-10. No penetration test or certification occurred. Assumes the legitimate app and OS are running; breaking that assumption exposes significant residual risk.

| Asset / attacker | Capability | Implemented protection | Residual risk |
|---|---|---|---|
| Vault root, passwords, TOTP / stolen files | Copies app data | OS-protected key storage; authenticated password/TOTP and metadata fields | Row IDs/times visible; unreadable legacy rows and copied legacy keys/backups; OS account compromise |
| Vault / same-user malware or plugin | Runs native/Dart code as user | Domain keys and limited ordinary AI tool injection | Same process/user can access keys and plaintext; no sandbox or cryptographic vault lock |
| Finance, notes, personal databases / stolen device | Reads local files | Per-user app directories and OS/device protection | Application-level encryption missing |
| Sync contents / malicious server | Reads/replaces/replays blobs and KDF parameters | Client AES-GCM, separate auth/encryption keys, collection checks | Password guessing, replay, metadata disclosure, identity substitution, raw-object binding gaps |
| Tokens / malicious network | Intercepts traffic or supplies redirects | HTTPS required in server client; no automatic redirects | Other HTTP clients/LAN paths not comprehensively constrained; compromised trusted CA/endpoint |
| Tokens / local JSON writer | Replaces server origin | Token and origin stored together in OS secure storage | Same-user malware may call secure storage directly |
| Accounts / credential stuffing | Repeated login and reset requests | Existing server rate limits, random hashed sessions, expiry/revocation | Distributed abuse, account enumeration and operator reset flows need deeper audit |
| Chat / compromised server or rogue family member | Changes keys, queries other users' objects | Existing X25519/AES-GCM and server ownership checks | No fully verified device enrollment/key transparency; family features may be plaintext server-side |
| All secrets / updater-host attacker | Supplies executable updates | HTTPS, repository/filename/version/size checks; Android package signing | Windows/custom updater lacks independent signature verification |
| Files / malicious archive or bank import | Crafted paths, compression bombs, malformed files | Existing Minecraft safeJoin and SFTP jail in inspected paths | Symlinks/reparse points, platform path quirks, parser/decompression resource limits need exhaustive review |
| Credentials / AI provider | Retains submitted prompts/tool outputs | No vault/TOTP tool in current assistant registry | User-pasted secrets; other AI entry points; incomplete explicit consent controls |
| Recovery keys / device loss | Deletes OS keyring, interrupts rotation | Old sync keys retained securely before rotation; fail-closed migrations | No portable encrypted backup/recovery key UI; multi-device rotation not atomic |
| All assets / supply chain | Compromises dependency, build action or signing pipeline | Committed lockfile; release-dependent security tests | Actions not SHA-pinned throughout; no complete vulnerability/history scan or reproducible signing |

Security boundaries must ultimately isolate high-risk executable plugins from vault key access. Same-process capability checks alone cannot satisfy the malicious-plugin threat. Independent reviewers should test real Windows/Android/iOS/Linux devices, privileged and unprivileged attackers, offline extraction, compromised-server scenarios and cross-account authorization.
