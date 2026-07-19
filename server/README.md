# luma sync server — internals

This document is for people building or maintaining the server itself.

**Deploying your own server?** You want [`../SERVER_SETUP.md`](../SERVER_SETUP.md)
instead — it's a step-by-step guide for self-hosters and doesn't require
reading any of this.

---

## What it does

A small Dart HTTP server (`shelf` + `shelf_router`) that gives the luma app
somewhere to sync to. It's intentionally simple: file-backed JSON storage
(no database server), everything held in memory and written through with
atomic replace.

- **Blob sync** (`/api/v1/sync/<collection>`) — each feature the client
  turns on uploads one opaque, already-encrypted blob per collection with
  optimistic-locking (`X-Base-Version`). The server never sees plaintext.
- **Auth** (`/api/v1/auth/*`) — email/password accounts, but the server
  never sees the real password: the client sends an already-derived *auth
  key*, which the server hashes again (PBKDF2) before storing. Login
  sessions are bearer tokens, stored hashed.
- **Family** (`/api/v1/family/*`) — shared calendar events + membership.
  Deliberately *not* zero-knowledge (sharing across accounts is
  incompatible with per-account key derivation) — secured the same way as
  the rest of the API instead: bearer auth + explicit membership checks.
- **Chat** (`/api/v1/chat/*`) — a dumb relay for the Chat plugin. Stores
  each user's X25519 public key and, once two users connect, opaque
  ciphertext blobs. Never sees a plaintext message or a private key.
- **AI proxy** (`/api/v1/ai/*`) — proxies chat completions to Mistral and
  Google using operator-configured keys (`LUMA_MISTRAL_API_KEY` /
  `LUMA_GOOGLE_API_KEY`), so individual users don't need their own. Usage
  is metered per user against rolling token/message budgets.
- **Admin dashboard** (`/admin`) — a self-contained HTML+JS page (no
  build step, no external assets) showing accounts, storage, activity,
  plugin download stats, live system metrics, and a "Control panel" tab
  that can trigger a self-update (`git pull` + recompile + restart) or
  proxy a groceries-database sync.

## Code layout

```
lib/
  api.dart              Route table + every HTTP handler + the admin dashboard's HTML/CSS/JS
  store.dart             Users, sessions, collection metadata; JSON-file persistence
  family_store.dart       Families, members, invites, shared calendar events
  chat_store.dart         Chat public keys, invites, conversations, messages
  ai_usage_store.dart     Per-user rolling token/message usage for the AI proxy
  mail.dart               SMTP sending (verification links, family/chat invite emails)
  metrics.dart            Live CPU/RAM/network/disk sampling (Windows: PowerShell, Linux: /proc)
  metrics_history.dart     Downsampled metrics history for the dashboard's graphs
  activity.dart           Admin dashboard's persisted activity-feed event type
  rate_limit.dart          In-memory sliding-window rate limiter
  util.dart                PBKDF2, constant-time compare, atomic file writes, shared regexes
bin/
  luma_server.dart         Entry point: reads env, wires up Store/Api, starts the HTTP server
```

`Api` is one large class because every handler needs the same set of
dependencies (`Store`, `ServerConfig`, `Mailer`, …) — splitting it up would
mean threading all of them through multiple classes for no real benefit at
this size.

## Running locally

```powershell
cd server
dart run bin/luma_server.dart      # run from source
.\run_local.ps1                    # PowerShell helper that sets env vars for you
```

Environment variables are documented in [`.env.example`](.env.example) —
copy it to `.env` for local runs, or set the variables directly.

> **Windows tip:** if a local `dart run` intermittently fails with pub-cache
> "cannot find path" errors, that's Windows Defender scanning the pub cache
> mid-build, not a code problem — see section 11 of `../SERVER_SETUP.md`.
> Compiling to an exe (`dart compile exe bin/luma_server.dart`) sidesteps it
> entirely, since the exe reads nothing from the pub cache at runtime.

For a containerized run matching production, see `docker-compose.yml` /
`Dockerfile` / `Caddyfile` — covered in `../SERVER_SETUP.md`.

## Auth model

- The client derives two separate secrets from the account password via
  PBKDF2 (client-side, high iteration count): an *encryption key* (never
  leaves the device) and an *auth key* (sent to the server at login).
- The server hashes the auth key again server-side (PBKDF2, 20k
  iterations — see `_serverHashIterations` in `api.dart`) before comparing
  or storing it. A stolen `users.json` doesn't hand out usable credentials.
- Unknown emails get a stable, HMAC-derived fake KDF salt from
  `/auth/params` so the response looks identical to a real account —
  prevents enumerating registered emails.
- Session tokens are 256-bit random values; only their SHA-256 hash is
  stored. Sliding expiry (`LUMA_TOKEN_TTL_DAYS`, default 90) refreshes past
  the halfway point of the token's remaining life.

## Admin dashboard auth

`/admin/*` requires `LUMA_ADMIN_KEY` to be set — if it isn't, every admin
route 404s instead of being reachable unauthenticated.

The dashboard itself authenticates via a cookie session (`/admin/login`
form → `HttpOnly`, `SameSite=Strict` cookie, 12h TTL, in-memory only) so the
admin key never has to appear in a URL, browser history, or a reverse-proxy
access log line. Non-browser callers (curl, scripts) can still authenticate
directly with the `X-Admin-Key` header or a `?key=` query parameter; hitting
`/admin` that way also opportunistically establishes a session so only the
first request needs the raw key.

Failed admin-key attempts are rate-limited separately from successful
polling (10 failures / 15 min per IP), so the dashboard's own background
polling never locks a legitimate operator out.

## Rate limiting

All in-memory sliding windows (`rate_limit.dart`), reset on restart:

| Limiter | Budget | Applies to |
|---|---|---|
| General | 300 req / min per IP | Everything not listed below |
| Auth | 15 req / 10 min per IP | `/api/v1/auth/*` (except logout) |
| Resend | 3 req / 15 min per email | `/auth/resend-verification` |
| Invite | 10 req / hour per user | `/family/*/invite`, `/chat/invite` (both send email to an arbitrary address) |
| Admin fail | 10 failures / 15 min per IP | `/admin/*` — only failed key attempts count |

## API reference

All endpoints under `https://<server>/api/v1` unless noted.

```
POST /auth/params                {email}                       → KDF salt + iterations
POST /auth/register              {email, authKey, kdfSalt, …}  → token
GET  /auth/verify                ?token=…                       HTML page
POST /auth/resend-verification   {email}
POST /auth/login                 {email, authKey}               → token
POST /auth/logout                                                (auth)
POST /auth/change                {currentAuthKey, newAuthKey,…} (auth)
GET  /auth/sessions                                              (auth) → active sessions
POST /auth/sessions/<id>/revoke                                  (auth)
GET  /account                                                    (auth) → usage, quota, collections
POST /account/delete             {authKey}                       (auth) → wipes everything
GET  /sync/<name>                                                (auth) → encrypted snapshot
PUT  /sync/<name>                (X-Base-Version header)         (auth) → optimistic-locked upload
DELETE /sync/<name>                                               (auth)
GET  /ai/status                                                   (auth) → shared-key usage %
POST /ai/mistral/chat            (OpenAI-compatible body)         (auth) → proxied completion
POST /ai/google/chat             (OpenAI-compatible body)         (auth) → proxied completion
POST /family, GET /family, POST /family/<id>/invite, …            (auth) → see api.dart
POST /chat/invite, GET /chat/conversations, …                     (auth) → see api.dart
GET  /health                                                       public
```

The full route table (including every family/chat sub-route and `/admin/*`)
lives at the top of `Api.handler` in `api.dart` — that's the source of
truth if this list drifts.
