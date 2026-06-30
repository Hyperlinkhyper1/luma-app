# luma

A clean desktop utility built with Flutter, styled after the Modrinth app: a
fixed left icon rail, a slim top bar, and rounded content cards. luma ships with
two lavender themes — **dark gray lavender** (default) and **white lavender** —
switchable from the toggle in the top-right.

Two tools live in the left rail:

1. **File Converter** — PNG ⇄ JPEG.
2. **Finance** — a local personal-administration app.

All data is stored **locally** on the machine (SQLite); nothing is sent to the
cloud.

## File Converter

- Pick a PNG or JPEG image; the source format is auto-detected from its magic
  bytes and converted to the opposite format.
- JPEG output has an adjustable quality slider; transparent PNGs are flattened
  onto white when converting to JPEG.
- On desktop the result is written to disk via a native Save dialog.

## Finance

A local administration / budgeting tool with five sub-tabs:

- **Overview** — net worth (main balance + pots + investments), this month's
  income/expenses, pot balances, a **weekly spending review** grouped by
  category, an investments summary, and upcoming recurring entries.
- **Transactions** — add expenses/income with amount, date, note, a **company**
  (searchable, from a seeded database of ~50 known merchants), a **category tag**
  (auto-filled from the company, editable), and a **pot**.
- **Pots** — create/edit/delete "potjes", top them up, see balances. Money is
  divided across pots; expenses can be drawn from a pot or the main balance.
- **Recurring** — fixed costs & income (Spotify, salary, …) that repeat weekly
  or monthly, plus **automatic distribution** rules that move money from the
  main balance into pots on a schedule (fixed € or % of balance). Due entries
  are applied on app start (catch-up), or manually via "Apply due now".
- **Stocks** — holdings (ticker, shares, avg cost) with **live prices** fetched
  keyless from Stooq (Yahoo fallback). Prices are shown in each instrument's
  native currency (no FX conversion).

Amounts are stored as integer cents and formatted as EUR (`€1.234,56`).

### Data location

The SQLite database lives in the local app-support directory, e.g.
`C:\Users\<you>\AppData\Roaming\com.luma\luma\luma_finance.sqlite` — local and
not synced to OneDrive.

## Architecture

```
lib/
  main.dart                         App entry, theme mode, DB + repository, FinanceScope
  theme/luma_theme.dart             LumaPalette tokens + dark/light ThemeData
  app/
    app_shell.dart                  Rail + top bar + IndexedStack of destinations
    nav_rail.dart                   Left icon sidebar (File Converter, Finance)
    top_bar.dart                    Title + theme toggle
    widgets.dart                    Shared UI (cards, buttons, pills, StreamData…)
  features/converter/               PNG⇄JPEG converter (+ cross-platform save)
  finance/
    data/database.dart              drift schema + seeding (local SQLite)
    data/seed_data.dart             default categories + known merchants
    logic/money.dart                EUR formatting / parsing (cents)
    logic/finance_logic.dart        balances, recurrence dates, allocation math
    finance_repository.dart         reactive reads, commands, due-rule engine
    finance_scope.dart              InheritedWidget providing the repository
    stock_service.dart              keyless live stock prices
    finance_page.dart               sub-tab shell
    ui/                             overview, transactions, pots, recurring, stocks
```

## Running

Flutter SDK is at `C:\Users\ayden\flutter` (on PATH). Visual Studio 2022 with the
"Desktop development with C++" workload and Windows Developer Mode are installed.

```powershell
flutter run -d windows     # native desktop app
flutter test               # unit + widget tests
flutter analyze
```

### Release build

Icons for pots/categories are stored as codepoints and built dynamically, so
release builds must disable icon tree-shaking:

```powershell
flutter build windows --release --no-tree-shake-icons
```

## Regenerating drift code

After changing tables in `lib/finance/data/database.dart`:

```powershell
dart run build_runner build
```
