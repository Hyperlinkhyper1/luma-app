# Cruise Ship Test validation

Recorded on 2026-10-03 for **GPT 6 Astra (Ultra)**.

## Automated checks

| Check | Result |
| --- | --- |
| Node navigation and ship tests | 11 passed |
| Focused Flutter tests | 15 passed |
| Focused server tests | 15 passed |
| Final artifact registration/hash tests, rerun | 4 passed |
| Scoped analysis | Clean |
| Official catalog preview generator | 1 OK, 0 failed |

These checks cover the authored navigation, ship routes, registration and focused app/server integration paths. They do not establish runtime rendering or installed-app behavior.

## Native WebView2 measurements

The generated, self-contained `file:///` artifact ran in a standalone WinForms WebView2 harness. Its control remained visible in an offscreen, non-minimized window with background throttling disabled. The full Flutter app was not launched for this check.

The native performance run used HTML with SHA-256 `bacc5781dbf8b0b8916055c211308fb42da8fed04475da0d0b1c4362f2129b8a`, including the final nighttime lighting and relocated pool-side radar pedestals. A subsequent change increased only the fog preset's cloud cover and fog density; the measured clear and storm presets, geometry and shaders are unchanged. The delivered HTML has SHA-256 `b8095485007c8409ea80953eff63e8dd32b7f5b041d6aa8f1f49bc9b733577c6`. Its stronger fog was inspected in Chrome, and the local HTTP preview loaded successfully.

- Runtime: Microsoft Edge WebView2 **154.0.4258.53**.
- CPU: **AMD Ryzen 5 7500X3D 6-Core Processor**, read from the Windows hardware registry.
- GPU: **AMD Radeon RX 9060 XT**, reported by WebGL through ANGLE / Direct3D 11.
- Render buffer: **2560 × 1440**, device scale factor **1**, **High** quality, resolution **100%**.
- Sampling: independent `requestAnimationFrame` intervals, approximately 60 seconds per condition, after warm-up. The other browser scene was closed during sampling.

| Condition | Duration | Frame samples | Mean FPS | p95 interval | p99 interval |
| --- | ---: | ---: | ---: | ---: | ---: |
| Walking on deck 7, clear, 14:00 | 60.0039 s | 10,799 | 179.97 | 5.7 ms | 5.7 ms |
| Exposed pool deck, storm, 16:00 | 60.0031 s | 10,767 | 179.44 | 5.7 ms | 5.8 ms |

Trusted DevTools keyboard input alternated W/S over four approximately 15-second legs during the walking case. The player travelled **93.053 metres** on the same safe promenade segment, without teleporting during the sample. Recorded x positions were `-58 → -34.741 → -58.009 → -34.750 → -58.018`; y remained `16`, z remained `18.1`, and the mode remained `walk`. The storm case used the exposed deck 15 pool viewpoint; camera height was approximately **41.20 metres**, and the native screenshot visibly contains rain.

These rates describe animation-frame timing on this machine and harness. They are not GPU timer-query measurements, display presentation guarantees or a long-run soak test.

## Runtime and interaction checks

- File-URL navigation completed and the host received `cruise-ready` after rendering.
- All **nine** named navigation spawns validated successfully.
- The deck map opened, displayed **seven** public destination buttons, and teleported to a selected destination before closing.
- Settings opened and closed; hour, weather, quality and resolution inputs updated the scene's reported state.
- Resizing the native WinForms host produced a **1280 × 720** render buffer, then restored **2560 × 1440** correctly.
- A trusted boarding click activated a **48 kHz AudioContext** in the `running` state. This verifies audio activation, not an independent listening assessment of the sound mix.
- Pointer lock remained unavailable in the offscreen native harness. Six trusted left-button drag movements, totalling **210 × 18 pixels**, produced a visible change in viewing direction in the before/after captures. Pointer lock succeeded separately in normal Chrome.
- A **synthetic** window blur event cleared held movement: the player moved zero metres in the following 0.5 seconds before key release. This checks the app's blur handler, not an operating-system focus transition.
- Deliberate WebGL context loss emitted `cruise-error` and displayed the expected interruption message and reload button. A trusted Retry click reloaded the artifact, produced a fresh `cruise-ready`, and hid the error. The probe then exited cleanly with code 0.
- Native day, night, storm, context-loss and retry screenshots were captured. The final night capture shows readable hull, balcony and lifeboat detail with illuminated windows; the pool capture shows the relocated pedestals clear of the pool. ANGLE reported nonfatal shader precision/FXAA warnings; initial rendering and the tested interactions completed.

## Evidence and remaining limits

Local evidence is retained under the ignored `.qa/` directory:

- `webview-9239-results.json` and `webview-9239.log`: the final 60-second walking and exposed-storm run above.
- `webview-9239-day.png`, `webview-9239-night.png`, `webview-9239-storm.png`, `webview-9239-context-loss.png`, `webview-9239-retry.png`: native captures.
- `webview-9239-drag-before.png` and `webview-9239-drag-after.png`: drag-look evidence.
- Earlier `webview-9237-*` and `webview-9238-*` evidence is preserved separately. These 15-second runs predate the final visual adjustments; the 9237 samples were also stationary and sheltered. Neither run supplies the final measurements in the table above.
- `webview-probe.cs` and `launch-webview.ps1`: local harness source and launch helper.
- `final-deck7-up.png`, `final-pool.png`, `final-bow.png`, `final-stern.png`, `final-night-promenade.png`, `final-fog.png` and `final-storm.png`: additional browser reference captures. The generated catalog preview frames the complete ship broadside.

The standalone native harness does not establish the complete Flutter embedding's focus, resizing, lifecycle or installed-release behavior. The two one-minute samples are short performance checks; no long-run memory/thermal soak or audible-output assessment was performed.
