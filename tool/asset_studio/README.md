# Asset studio thumbnails

The gallery in the AI Usage plugin's **Assets** section shows a baked
isometric render of each model (`assets/asset_studio/thumbs/<id>.png`,
480×320, transparent background) instead of running WebGL per card.

Re-bake them after adding a model to `assets/asset_studio/catalog.json` or
changing one under `assets/asset_studio/models/`:

```bash
node tool/asset_studio/bake_thumbnails.cjs
```

Then open <http://localhost:8129> in any browser. The page renders every
model in the catalogue with the same preview helpers and camera the studio
uses, and posts each PNG back to the script, which writes it into
`assets/asset_studio/thumbs/`. It prints one line per file; stop it with
Ctrl-C when the page says `done`.

Nothing here ships in the app — the script only writes the PNGs that do.
