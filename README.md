# luma

luma is a private, all-in-one desktop and Android app: a budgeting tool, a
password manager, a file converter, notes, a built-in AI assistant, and a
marketplace of 20+ optional plugins — all in one clean interface, modeled
after the Modrinth app (a fixed left icon rail, a slim top bar, rounded
content cards).

**Everything is local-first.** All of your data lives on your own device in
a local database. Nothing is sent anywhere unless you explicitly turn on
sync — and even then, it's end-to-end encrypted so the server can't read it
either. luma ships with two lavender themes — **dark gray lavender**
(default) and **white lavender** — switchable from the top-right toggle.

---

## Built into every install

### Home
A dashboard giving a quick overview and shortcuts into the other tools.

### File Converter
A hub of eight tools, each its own screen:

| Tool | What it does |
|---|---|
| Audio converter | MP3 · OGG · FLAC · M4A · WAV · AAC |
| Picture converter | PNG · JPG · BMP · TIFF · SVG |
| Video converter | MP4 · MOV · WEBM · OGV · MPG · M4V |
| Image downscaler | Shrink images with smart size/quality options |
| Video downscaler | Compress and shrink video files |
| Image editor | Remove white backgrounds from images |
| Audio editor | Cut, equalize, and preview audio |
| Collage maker | Build photo collages from templates |

### Finance
A local budgeting tool with five sub-tabs:

- **Overview** — net worth (main balance + pots + investments), this
  month's income/expenses, pot balances, a weekly spending review grouped
  by category, an investments summary, and upcoming recurring entries.
- **Transactions** — log expenses/income with a searchable company database
  (~50 known merchants), auto-filled category tags, and pot assignment.
- **Pots** — set money aside into named pots ("potjes"), top them up, track
  balances separately from the main balance.
- **Recurring** — fixed costs & income that repeat weekly or monthly, plus
  automatic distribution rules that move money into pots on a schedule.
- **Stocks** — track holdings with live prices, fetched keyless (no API key
  needed) from Stooq with a Yahoo fallback.

Bank statement import is supported for **ING** (Excel/CSV export) and
**BUUT** (PDF statements), auto-categorized against the merchant database.

### Password Manager
An encrypted local vault for logins:

- Every password (and 2FA secret) is encrypted at rest with its own
  device-local key — unreadable even if someone reads the raw database file.
- Built-in **TOTP/2FA code generation** (RFC 6238) — no separate
  authenticator app needed for accounts you store here.
- **Breach check** flags passwords that match a bundled, fully offline list
  of common/previously-leaked passwords — nothing is looked up online, the
  plaintext password never leaves your device.
- Optional PIN lock before revealing a password.

### Notes
Fast, simple notes — no folders or formatting to fight with.

### Assistant
A built-in AI chat with three modes (Aurora, Nebula, Pulsar — fast to
"smartest"), backed by Mistral and Google's models. If a server operator has
configured a shared key, it works out of the box with a fair per-user usage
allowance; otherwise you can bring your own API key.

---

## Plugins

Beyond the built-ins, luma has a marketplace of optional plugins you install
individually from the **Plugins** tab. Each is self-contained — its own
local data, its own page.

**Utility** — QR Code Generator · Card Wallet (loyalty/membership passes) ·
File Tree (disk space analyzer) · File Viewer (PDF/Word/Excel/image/text
viewer) · Price Tracker (price-history graphs from a pasted product URL) ·
Cloud Files (encrypted file sync) · YouTube Downloader · Auto Clicker ·
Wi-Fi Speed Test

**Productivity** — Errand Manager (recurring chore checklist) · Bulletin
Board (freeform corkboard) · Calendar (month view, repeat rules, reminders)
· Data Management (custom datasets + charts) · Mood Journal · School
(homework, flashcards, GPA calculator, timetable, and more)

**Games** — Server Hosting Tycoon · Subway Builder (real-world transit
simulator on a live 3D map) · Space Colony · City Planner

**Social** — Chat (end-to-end encrypted messaging between luma users) ·
Recipes (a photo-forward recipe collection with Favourites/Public/Private tabs
— publish recipes to a shared catalogue others can rate, review and add photos
to)

**Shopping** — Groceries List (Nova plan exclusive — compare prices across
Dutch supermarkets)

**Analytics** — Usage (tracks foreground app time on your PC)

---

## Accounts, plans & family

luma works fully offline with no account. Signing in unlocks sync and
raises your local storage cap:

| Plan | Local storage | Sync | Family |
|---|---|---|---|
| **Core** (free) | 5 MB | up to 3 features | up to 4 people |
| **Orbit** | 15 MB | up to 5 features | up to 6 people |
| **Nova** | 30 MB | unlimited | up to 12 people |

**Family** sharing lets a group share a calendar and manage members from
the Account tab — invite by email, accept/decline from an in-app inbox.

---

## Sync & privacy

Nothing syncs by default — you turn on individual features from
*Settings → Sync & account*. Two ways to sync between your own devices:

- **Self-hosted server** — end-to-end encrypted: every feature's data is
  encrypted on your device before it ever leaves it, using a key derived
  from your account password. The server only ever stores unreadable
  ciphertext and never sees your password. See
  [`SERVER_SETUP.md`](SERVER_SETUP.md) to run your own.
- **Wi-Fi/LAN sync** — sync directly between devices on the same network,
  no server required.

---

## Platforms

Windows desktop and Android. Built with Flutter.

---

## For developers

Building luma from source, contributing, or running the sync server? See:

- [`AGENTS.md`](AGENTS.md) — project structure, build/test commands,
  coding conventions, plugin development guide.
- [`SERVER_SETUP.md`](SERVER_SETUP.md) — deploying your own sync server.
- [`server/README.md`](server/README.md) — the sync server's internals.
- [`PLUGIN_GUIDE.md`](PLUGIN_GUIDE.md) — building a new plugin.
