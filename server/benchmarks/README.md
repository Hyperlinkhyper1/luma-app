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
  scenes/              one self-contained HTML file per scene (<id>.html)
  previews/            optional PNG thumbnail per scene (<id>.png), plus the
                       generic tile artwork (pagoda-preview.png)
```

`scenes/pagoda.html` is the base template new Pagoda scenes are built from.
It is not served (its name matches no benchmark id).

## How serving works

`server/lib/ai_benchmark_store.dart` overlays `<dataDir>/ai_benchmarks/` on
top of this directory: a file the operator dropped into the data directory
wins, everything else falls back to what is checked in here. The manifest is
rebuilt from disk on every request, so there is no refresh or rescan step.

## Adding a scene

1. Drop the scene in as `scenes/<test>_<model>.html` (`pagoda_…` or
   `engine_…`), fully self-contained (inline JS/CSS — the app loads it from
   disk with no network beside it).
2. Optionally add `previews/<test>_<model>.png` (16:10 crops best).
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
