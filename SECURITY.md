# Security policy

Luma is undergoing security hardening. No version is represented as independently audited or certified. See [current limitations](docs/security/AUDIT_READINESS.md) before relying on it for sensitive credentials or financial information.

## Supported versions

Security fixes currently target the latest source/release. There is no maintained older-version support matrix or guaranteed response SLA. New encrypted formats may require coordinated device upgrades; consult [migration notes](docs/security/MIGRATION.md).

## Reporting vulnerabilities

Owner action required: enable and verify GitHub private vulnerability reporting for `Hyperlinkhyper1/luma-app`, or publish a verified private reporting contact. This work has not confirmed that private reporting is enabled and does not invent an email address. If the repository Security tab offers “Report a vulnerability,” use that private flow. Otherwise request a private reporting channel without posting exploit details or secrets in a public issue.

Include affected version/platform, prerequisites, reproducible steps using fake data, expected versus observed behavior, impact and a minimal proof of concept. Do not send real passwords, TOTP seeds, tokens, user databases, private keys or unrelated personal information.

Please coordinate disclosure and avoid publishing an unpatched exploit immediately. Intended maintainer process: acknowledge privately, reproduce/triage, agree remediation and disclosure timing, add regression tests, release a fix and advisory, and credit the reporter with permission. This process and contact configuration require owner adoption; no response-time guarantee is asserted.
