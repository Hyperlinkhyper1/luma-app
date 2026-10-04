# AI benchmark scenes

The AI Usage plugin's **Tests** tab (Pagoda Test, Engine Test) used to ship
every benchmark scene inside the app bundle. Those scenes are megabytes of
HTML the app has to download, install and update whether anyone opens the tab
or not — so they live here now, on the server, and the app fetches them on
demand and caches them on disk.

## Layout

```
server/benchmarks/
  manifest.json        the roster: id, test kind, model name, description
  scenes/              one self-contained HTML or GLB file per scene
  previews/            optional PNG thumbnail per scene (<id>.png), plus one
                       generic tile artwork per test kind
                       (<kind>-preview.png) shown while a scene has none —
                       a failed render (solid colour, loading screen, consent
                       wall) is worse than no thumbnail, so delete those
                       instead of checking them in
```

`scenes/pagoda.html` is the base template new Pagoda scenes are built from.
It is not served (its name matches no benchmark id).

## How serving works

`server/lib/ai_benchmark_store.dart` overlays `<dataDir>/ai_benchmarks/` on
top of this directory: a file the operator dropped into the data directory
wins, everything else falls back to what is checked in here. The manifest is
rebuilt from disk on every request, so there is no refresh or rescan step.

## Uploading from the admin dashboard

Maintenance tab → **AI benchmark scenes** → *Upload test…* takes the file
plus the test, company, model and reasoning effort, derives the id
(`keyboard_sonnet55_high`) and display name (`Sonnet 5.5 (High)`), and:

1. saves it to `<dataDir>/ai_benchmarks/uploads/` with its stanza in
   `uploads.json`, so the app lists it at once;
2. with `LUMA_BENCHMARK_GITHUB_TOKEN` set (see `server/.env.example`),
   commits the scene and the updated `manifest.json` here as one
   `[skip ci]` commit — `release.yml` also ignores pushes that only touch
   `server/benchmarks/**`, so no release build runs;
3. renders its banner if it has none.

An upload wins over the seed only while it is newer: once "Update & restart
server" pulls the commit in, the seed copy (and any later edit to it) is
served again. The company is stored as an optional `vendor` key; without one
the app still works the company out from the model name.

## Adding a scene by hand

The **AI benchmark banners** card's top-right cog configures an on-demand
render repair model on a server API key. Saving settings accepts its current
token prices and sets a maximum estimated cost per attempt (default $0.25).
Unknown prices, price increases and an input too expensive for that limit
block calls; OpenRouter also receives the accepted token-price caps.

After a render fails, **Repair once** makes one model call with only that
HTML and its recorded render error. It requests minimal exact edits, checks
the candidate in an isolated renderer directory, and saves only a passing
candidate. The original is backed up under `<dataDir>/benchmark_repairs/`;
the existing model label and roster metadata are preserved. Reported usage,
including failed repairs, enters the AI Usage feed of `aydenjue@outlook.com`.
Binary GLB files are unsupported. Rendering, uploads, startup and saving
settings never schedule an AI repair; there are no automatic retries.

1. Drop the scene in as `scenes/<test>_<model>.html` (`pagoda_…` or
   `engine_…`), fully self-contained (inline JS/CSS — the app loads it from
   disk with no network beside it).
2. Optionally add `previews/<test>_<model>.png` (16:10 crops best), or let
   the admin dashboard render it: Maintenance tab → **AI benchmark banners** →
   *Render missing banners* shoots every scene that has none, one by one;
   *Re-render all* redoes them all. Pagoda banners come out consistent
   whatever the scene: fast-forwarded to its brightest time of day and
   framed as the whole garden from an elevated three-quarter angle (see
   `server/tool/`). Rendered banners land in
   `<dataDir>/ai_benchmarks/previews/`, overriding the checked-in ones.
3. Add one stanza to `manifest.json` (or to
   `<dataDir>/ai_benchmarks/manifest.json` to override without touching the
   checkout):

```json
{"id": "pagoda_mymodel01", "kind": "pagoda", "model": "My Model 01",
 "description": "My Model 01 voxel garden benchmark"}
```

The next `GET /api/v1/ai-benchmarks` lists it; no restart needed. Scenes on
disk that the manifest doesn't name still show up (with a derived label), but
prefer the manifest — that is where the display name and description live.

In Docker the checked-in files are baked into the image under
`/seed/benchmarks`; the data volume starts empty and overrides per file.
