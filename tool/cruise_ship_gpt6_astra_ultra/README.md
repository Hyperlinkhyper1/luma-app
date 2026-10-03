# MSC Virtuosa — GPT 6 Astra (Ultra)

Independent cruise ship contestant for Luma's AI Usage → Tests → Cruise Ship Test.
All geometry, materials, sounds and weather are authored here. The Opus scene is a separate project.

## Build and preview

```powershell
npm ci --ignore-scripts
npm run test
npm run build
npm run preview
```

The preview serves the exact generated artifact at `http://127.0.0.1:5187`.
The build writes `server/benchmarks/scenes/cruise_ship_gpt6_astra_ultra/index.html`.
That same file is included in Flutter's assets and served by the benchmark catalog.
There are no runtime network dependencies. Build dependencies and their versions are pinned by the lockfile.

## Controls

- WASD / arrow keys: move; mouse: look; drag works if pointer lock is unavailable.
- Shift: sprint; C / Ctrl: crouch; M: deck map; E: map while walking.
- V: cycle walking, tender and free camera; Q/E: descend/ascend in free camera.
- Tender: W/S throttle and A/D steer; mouse look is independent of steering.
- Escape: release mouse / settings; F: hide interface.

Time, weather, quality, resolution, field of view, audio and comfort settings are in the settings panel.
Settings use guarded local storage and reset safely if local storage is unavailable.

## Reproducible QA

See [VALIDATION.md](VALIDATION.md) for measured hardware, runtime results, test counts and verification limits.

`window.cruiseDebug.ready` is set only after construction and the first rendered frame.
`cruise-ready` and `cruise-error` messages are also sent to the WebView host.

The development API provides `start()`, `setTime(hour)`, `setWeather(name)`,
`setView(modeOrSpotId)`, `setCamera({x,y,z,yaw,pitch})`, `hideUI()`, `stats()`,
`validateSpawns()`, `setKey(code,down)`, `advance(seconds)`, and `simulateContextLoss()`.
`navigation` exposes the separate navigation surfaces, obstacles and named viewpoints.
Weather presets are `clear`, `overcast`, `fog`, `rain`, `storm` and `auto`.
`setTime` pauses the clock for reproducible captures. `setWeather` settles the weather immediately for QA;
normal user changes transition smoothly.

Validate the generated file over both HTTP and `file:///` in Windows WebView2.
Browser rendering and Flutter widget tests provide different evidence from the actual WebView runtime.
Performance depends on hardware and render resolution; report measured hardware and settings.

## Reference and scope

Reference: the supplied photo collage and [MSC's Virtuosa deck plans](https://www.msccruises.ie/content/dam/msc-cruises/b2c-assets/fleet/msc-virtuosa/MSC_VIRTUOSA_DECKPLAN.pdf).
The ship is an artistic exterior recreation. Small fittings and connector passages are approximated.
Cabins and crew spaces remain scenery. No passengers, port setting or full interiors are included.

Third-party engine/build dependencies retain their own licenses; Three.js is MIT licensed.
