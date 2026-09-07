# Hero tile — the purple-wash layout

The spec for `LumaHeroTile` (`hero_tile.dart`), the artwork button used by the
AI Usage plugin's **Tests** section. Read this before adding a second tile or
touching the gradient; the whole point of the recipe is that every tile made
from it looks like it came from the same set.

## What it is

A square artwork tile that behaves as one button. The image fills the tile, a
purple wash owns the bottom third, and the label sits inside that band.

```
┌─────────────────────────┐  0.00
│                         │
│        artwork          │
│                         │
│· · · · · · · · · · · · ·│  0.40   wash starts, still fully transparent
│ ░░░░ transition ░░░░░░  │  0.52 → 0.655   rising alpha
│█████████████████████████│  0.667  solid purple begins — the bottom third
│█ Pagoda Test          → │
│█ Open the test screen   │
└─────────────────────────┘  1.00
```

Numbers are fractions of tile height and are the `stops` in
`HeroTileWash.gradient`.

## The rule that matters

**The purple is painted at runtime, never baked into the PNG.**

The source image goes into `assets/tests/` untouched — no gradient, no band,
no text in the pixels. Everything below `0.40` is Flutter drawing over it. Bake
the wash into the file and it freezes at one aspect ratio, stops following the
palette, and the second tile you make will not match the first.

## The wash

One vertical `LinearGradient`, `topCenter → bottomCenter`, painted over the
image:

| stop    | colour       | alpha | what it does                          |
| ------- | ------------ | ----- | ------------------------------------- |
| `0.40`  | `#7E43C9`    | `00`  | wash begins, invisible                |
| `0.52`  | `#7E43C9`    | `38`  | first haze — the artwork starts to go |
| `0.60`  | `#7E43C9`    | `9E`  | past halfway, image reading as mist   |
| `0.655` | `#7E43C9`    | `EB`  | almost solid, edge of the band        |
| `0.667` | `#7E43C9`    | `FF`  | **bottom third starts, fully opaque** |
| `1.00`  | `#6B31B0`    | `FF`  | deeper floor at the very bottom       |

Two colours, not one: `purple` `#7E43C9` at the top of the band and
`purpleDeep` `#6B31B0` at the bottom. The band is subtly darker at the floor so
it reads as depth rather than as a flat sticker pasted on the picture.

Four stops across `0.40 → 0.667` is what makes the transition look like haze
rather than a cross-fade. Two stops gives a visible straight edge; the extra
steps front-load the alpha ramp so the artwork dissolves early and the band
arrives without a seam. If you shorten the ramp, shorten it from the top
(`0.40`), never from the bottom — `0.667` is load-bearing, it is where "the
bottom third is purple" comes from.

## Text

Lives inside the band, bottom-left, `EdgeInsets.fromLTRB(20, 0, 20, 20)`.

- Title — 21px, `w700`, `letterSpacing: -0.2`, pure white, one line.
- Subtitle — 12.5px, white at 82%, up to two lines, with an
  `arrow_forward_rounded` at 90% on its right.

Both clear WCAG AA on the band: white on `#7E43C9` is 5.9:1, and the 82%
subtitle against `#6B31B0` is 6.0:1. Keep text on the solid part of the band —
put it any higher and it lands on the transition, where the contrast depends on
whatever the artwork happens to be doing that day.

## Interaction

The tile is one button, not a card with a button in it.

- The artwork scales to `1.04` over 320ms on hover; the wash and text stay put,
  so the picture moves under a fixed label.
- The shadow (`purpleDeep`, 16% → 34% alpha) lifts with it.
- The arrow slides right by a quarter of its width.
- The `InkWell` is the **last** child of the `Stack` so the ripple and focus
  ring draw over the artwork instead of under it.
- `Semantics(label: '<title> — <subtitle>', button: true)` — the tile is an
  image with text drawn on it, so it needs a name given to it explicitly.

## Missing artwork

`Image.asset` has an `errorBuilder` that paints `HeroTileWash.fallback` (a pink
→ mauve gradient echoing the reference art) with the tile's `fallbackIcon`. A
tile whose PNG has not been dropped in yet looks deliberate, not broken, and
the wash and label render identically either way.

## Adding another tile

```dart
LumaHeroTile(
  title: 'Something Test',
  subtitle: 'Open the test screen',
  imageAsset: 'assets/tests/something.png',
  fallbackIcon: Icons.science_rounded,
  onTap: () => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const SomethingTestPage()),
  ),
),
```

Add it to the `Wrap` in `tests_tab.dart`. Tiles keep their 340px width and flow
onto the next row rather than stretching — a hero tile stretched to fill a
column loses the crop the artwork was framed for.

Crop guidance for the source image: the tile takes a square from the **top**
(`BoxFit.cover`, `alignment: topCenter`), and the bottom third disappears under
the wash. Keep the subject in the upper two thirds of the frame.
