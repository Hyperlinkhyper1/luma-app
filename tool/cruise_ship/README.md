# MSC Virtuosa — Opus 5.5 (Ultracode)

Cruise Ship Test contestant for luma's AI Usage → Tests → Cruise Ship Test.
A true-scale MSC Virtuosa on an open sea, rendered with three.js WebGPU
(WebGL 2 fallback). Independent of the GPT 6 Astra scene in
`tool/cruise_ship_gpt6_astra_ultra`.

## Build

```powershell
npm ci
npm run dev       # http://localhost:5181/opus_5_5_ultracode.html
npm run build     # -> assets/ai_usage/cruise_ship_tests/opus_5_5_ultracode.html
npm run preview   # serves the built file
```

The build is one self-contained HTML file (scripts and styles inlined, no
network access), because WebView2 refuses module scripts and fetches from
`file://`. Flutter bundles it as an asset; `CruiseShipTestPage` plays it in
`NativeWebview` and offers *Open in browser*.

URL flags: `?webgl` forces the WebGL 2 backend, `?gputime` records GPU pass
timings.

The scene posts `{"type":"cruise-ready"}` to the WebView host once the first
frame is drawn, and `{"type":"cruise-error","message":…}` if it can't start or
loses the GPU.

## Controls

- Walk: WASD / arrows, mouse to look (drag if pointer lock is unavailable),
  Shift run, Ctrl or C crouch, Space jump, E use a door or stairwell.
- V cycles Walk → Tender → Drone. Tender: W/S throttle, A/D steer, R reset.
  Drone: WASD, Space/E up, Q/Ctrl down, Shift faster.
- M deck map, H ship's horn, F1 hide HUD, Esc settings.

Settings (Esc) cover time (24-minute day by default, adjustable, or real
time from the PC clock), weather (auto or a fixed preset), sea state, speed,
port or at sea, graphics quality, controls and audio. They are kept in
local storage when it is available.

## Layout

- `src/core` renderer, post-processing, lighting/exposure, clock, input,
  audio, settings, host messages.
- `src/env` atmosphere, volumetric clouds, ocean, fog, rain and lightning,
  weather, ship motion.
- `src/ship` hull, superstructure, deck 7 promenade and lifeboats, top decks,
  walk collider, shadow proxies. Dimensions live in `dims.js`.
- `src/player` walker, tender, drone. `src/world` port, people, ambient
  traffic. `src/ui` HUD, settings, deck map.
