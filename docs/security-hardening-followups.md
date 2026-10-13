# Security hardening follow-ups

Checked on 2026-10-14. OSV-Scanner 2.7.0 scanned the eight tracked dependency manifests after the renderer's Puppeteer upgrade. It reports six affected package instances and nine vulnerability groups: one critical, one high, five medium, and two low. The renderer's dependency lockfile has no remaining reported vulnerability.

| Package reported | Source | Version reported | Remediation |
| --- | --- | --- | --- |
| Pygments | `.claude/skills/ui-styling/scripts/requirements.txt` | 2.9.0 | Resolve and pin the test dependency set with Pygments 2.20.0 or later. |
| Pygments | `.claude/skills/ui-styling/scripts/tests/requirements.txt` | 2.9.0 | Resolve and pin the test dependency set with Pygments 2.20.0 or later. |
| mysql2 | `supermarket-db/package-lock.json` | 3.22.6 | Update to 3.23.1 or later. |
| proxy-addr | `supermarket-db/package-lock.json` | 2.0.7 | Update to 2.0.8 or later. |
| qs | `supermarket-db/package-lock.json` | 6.15.3 | Update to 6.16.0 or later. |
| braces, development dependency | `tool/cruise_ship/package-lock.json` | 3.0.3 | OSV reports no fixed release; review the advisory and replace or remove the affected dependency path. |

The Python findings come from OSV's resolution of unpinned requirements; they do not establish which versions are installed in a particular Python environment. Local ignored worktrees were excluded from this snapshot.

`security.yml` now runs the complete server suite with isolated temporary storage, client secret/cache regressions, renderer Node regressions, full-history Gitleaks, OSV, and a Linux renderer container smoke test. The OSV job currently fails on the findings above and therefore blocks releases through the reusable security workflow. No vulnerability exclusions were added.

Local verification passes: all 515 server tests, all 146 tests in the client security CI set (including the 12 encrypted-cache cases), all 15 renderer Node tests, the Windows account-directory reopen/permission regression, targeted cache/renderer analysis, and workflow validation with actionlint 1.7.12. The configured security analysis step exits successfully with one pre-existing `prefer_initializing_formals` informational diagnostic. The Docker smoke job still needs its first real Linux runner execution; this workstation has no Docker runtime, and deployment has not been verified.

Gitleaks exceptions retain the default rules and cover only verified public constants, checklist prose, and the known-password SHA-1 corpus. A synthetic credential beginning with the public alphabet on the excepted SFTP source path still fails the same Git-history scanner. Gitleaks 8.30.1 completed the full history scan of 1,167 commits with no remaining findings.

Installer authenticity remains deferred until independent Ed25519 signing-key custody, the app's public key, and key rotation are scoped. The signing key must have a separate trust boundary from the GitHub account it protects.

Archive expansion limits and Assistant write confirmations each need their own focused scoping pass before planning changes.
