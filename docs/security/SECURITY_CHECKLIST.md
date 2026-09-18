# Release security checklist

Checked items are narrow implemented controls, not a global security approval. Revalidate them for each release.

- [x] New password/TOTP ciphertext uses authenticated encryption and row/field binding.
- [x] New sync ciphertext uses a maintained AES-GCM implementation.
- [x] Password and TOTP use separate derived subkeys.
- [x] Targeted legacy ciphertext migration and corruption/rollback tests exist.
- [x] Vault and selected credential keys migrate into verified OS secure storage.
- [x] Sync tokens are protected together with their server/account binding.
- [x] App PIN verifier uses a versioned, salted Argon2id format.
- [x] Server client rejects production plaintext HTTP and automatic redirects.
- [x] Release jobs depend on the security regression workflow.
- [ ] Full master-password vault with repository-enforced lock and key lifecycle.
- [x] New and successfully migrated vault metadata/secure notes encrypted.
- [ ] Local finance/notes encrypted; unreadable legacy vault rows resolved.
- [ ] Remaining custom credential ciphers replaced and tested.
- [ ] All credential/refresh-token storage audited and migrated.
- [ ] Compiled plugins and executable workloads isolated from vault keys.
- [ ] Enforced capabilities and sensitive-data consent UI.
- [ ] AI privacy controls cover every provider/plugin entry point.
- [ ] Account KDF migrated to versioned Argon2id and wrapped random encryption keys.
- [ ] Password rotation is atomic/resumable across devices, with fault-injection tests.
- [ ] User-held recovery and portable encrypted backup restore tested.
- [ ] Raw sync object name/version binding and replay resistance reviewed.
- [ ] Windows/custom updater verifies independent signatures before execution.
- [ ] Release signing trust roots and rotation configured on all platforms.
- [ ] Logs/diagnostics demonstrably exclude all sensitive test fixtures.
- [ ] Archive/import/decompression size and path protections comprehensively tested.
- [ ] Repository history secret scan and lockfile vulnerability scan completed.
- [ ] All actions/tool downloads pinned to reviewed immutable versions.
- [ ] Full static analysis clean; complete tests and platform release builds pass.
- [ ] OS secure-storage failure, reinstall, backup and profile-migration tests pass.
- [ ] Security contact, disclosure process and retention policy configured.
- [ ] Independent audit completed before strong password/finance security marketing.
