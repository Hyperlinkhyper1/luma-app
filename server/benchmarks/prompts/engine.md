# 3D PROCEDURAL V8 ENGINE — CODING BENCHMARK

Create a highly detailed, fully animated, procedurally generated 3D V8
engine as a single HTML page.

This is a coding and reasoning benchmark.

The ENGINE itself is the benchmark.

Do NOT spend time building benchmark dashboards, scoring systems, FPS charts, landing pages, documentation pages, or unrelated UI.

The quality of the result will primarily be judged by:

1. Whether it works
2. Mechanical correctness
3. 3D geometry quality
4. Mathematical correctness
5. Animation correctness
6. Complexity
7. Visual quality
8. Code quality
9. Attention to detail

The final result should demonstrate your ability to reason through and implement a complicated interconnected mechanical system rather than merely produce an attractive 3D scene.


============================================================
REFERENCE
============================================================

Picture a classic cutaway V8 display engine, as seen in engineering
exhibits and technical illustrations.

Use that idea as inspiration for:

- Overall engine complexity
- Visible internal components
- Cutaway presentation
- Mechanical density
- Materials
- Component proportions
- Technical appearance

Create your own procedural interpretation of a detailed V8 engine.

The final engine should immediately and unmistakably look like a V8 engine.


============================================================
CRITICAL SINGLE-FILE REQUIREMENT
============================================================

The ENTIRE implementation must be contained in one HTML page.

Everything must exist inside that page, including:

- HTML
- CSS
- JavaScript
- Engine geometry
- Animation logic
- Mechanical calculations
- Materials
- Lighting
- Effects
- UI
- Shaders, if used

CSS must be embedded in `<style>`.

JavaScript must be embedded in `<script>` or `<script type="module">`.

The result must require NO build step.

Do NOT simplify the engine merely because it must fit inside one file.


============================================================
LIBRARIES
============================================================

Three.js may be imported from a public CDN (unpkg.com or cdn.jsdelivr.net).

Official Three.js modules such as OrbitControls may also be imported.

Avoid unnecessary third-party libraries.

Do NOT use an engine-specific library or physics package that implements the mechanical system for you.

The important engine logic must be implemented by you.


============================================================
NO EXTERNAL VISUAL ASSETS
============================================================

Do NOT use:

- GLB
- GLTF
- OBJ
- FBX
- STL
- Downloaded 3D models
- External engine models
- External textures
- Images
- Videos
- GIFs
- Sprite sheets
- Pre-rendered animations

The engine geometry must be created procedurally by the code inside the page.

Three.js primitives are allowed.

Custom BufferGeometry is allowed.

Generated curves and procedural meshes are allowed.

Canvas-generated textures created by the application itself are allowed if useful.

YOU must construct the engine.


============================================================
DO NOT FAKE THE MECHANICS
============================================================

The moving engine components must form one interconnected mechanical system.

Do NOT create unrelated objects that merely move in approximately appropriate ways.

In particular:

Do NOT animate eight pistons with arbitrary independent sine waves.

Do NOT rotate connecting rods without calculating their relationship to the crankshaft.

Do NOT animate valves randomly.

Do NOT trigger combustion randomly.

Do NOT rotate the camshafts at approximately the correct speed.

Do NOT create decorative mechanical parts that are visibly disconnected.

Engine state must ultimately derive from a shared crankshaft angle.

The engine should behave as one synchronized machine.


============================================================
ENGINE CONFIGURATION
============================================================

Create a naturally aspirated four-stroke 90-degree V8 engine.

The engine must contain 8 cylinders arranged as:

    4 cylinders on the left bank
    4 cylinders on the right bank

The two cylinder banks should form approximately a 90° V angle.

The layout must visually read as a real V8.

The engine should have significant depth along the crankshaft axis rather than appearing like a flat diagram.


============================================================
CRANKSHAFT — MASTER SIMULATION STATE
============================================================

The crankshaft is the heart of the simulation.

Create a proper visible crankshaft containing recognizable:

- Main shaft sections
- Main journals
- Rod journals
- Crank webs
- Crank throws
- Counterweights

Do NOT represent the crankshaft as one simple rotating cylinder.

Implement a believable cross-plane V8 crankshaft.

The crank throws should have appropriate phase relationships rather than all pointing in the same direction.

Maintain a master crankshaft angle (`crankAngle`). All major engine timing must derive from it:

- Crankshaft orientation
- Piston positions
- Connecting rod positions
- Connecting rod angles
- Cylinder cycle phases
- Camshaft orientation
- Valve timing
- Ignition timing
- Combustion effects
- Flywheel orientation


============================================================
PISTON MECHANICS
============================================================

Create eight individual pistons.

Each piston should have recognizable geometry including as practical:

- Piston crown
- Piston skirt
- Wrist-pin area
- Ring grooves
- Piston rings or ring-like details

Piston movement must be mathematically connected to crankshaft rotation.

Use slider-crank kinematics or an equivalent geometrically correct method:

    r = crank radius
    l = connecting rod length
    θ = crank angle

    x = r*cos(θ) + sqrt(l² - r²*sin²(θ))

or an equivalent formulation adapted to your coordinate system.

Reason carefully about coordinate systems and bank orientation.


============================================================
CONNECTING RODS
============================================================

Create eight visible connecting rods.

Each connecting rod must continuously connect the piston wrist pin to the crankshaft rod journal.

The rod must translate, rotate, change angle, follow the crank journal and follow the piston.

Calculate the rod transform from its two endpoints:

1. Calculate wrist-pin position
2. Calculate crank-journal position
3. Find the midpoint
4. Calculate the distance between endpoints
5. Construct the rod to that length
6. Orient the rod along the endpoint vector

The connecting rods must NOT float, disconnect, stretch incorrectly, rotate around the wrong axis or pass through obviously impossible positions.

This is one of the most important parts of the benchmark.


============================================================
CROSS-PLANE V8 PHASING
============================================================

Implement believable crank phasing for a cross-plane V8.

Do NOT place all eight pistons at identical crank phase.

Cylinder phase relationships must be internally consistent with the chosen firing order.

Use a believable V8 firing order such as:

    1 → 8 → 4 → 3 → 6 → 5 → 7 → 2

You may use another real V8 firing order if the entire implementation remains internally consistent.


============================================================
FOUR-STROKE CYCLE
============================================================

The four-stroke cycle (INTAKE, COMPRESSION, POWER, EXHAUST) requires 720° of crankshaft rotation, NOT 360°.

Each cylinder tracks a cycle phase in the range 0° → 720°:

    0°–180°     Intake
    180°–360°   Compression
    360°–540°   Power
    540°–720°   Exhaust

You may shift the convention; what matters is internal consistency.

Power events must occur according to the firing order, distributed through the 720° cycle. The simulation must know which cylinder is intaking, compressing, firing, expanding and exhausting at any moment. Combustion effects must derive from this state.


============================================================
CAMSHAFT SYSTEM
============================================================

Create visible camshaft geometry: central shaft, multiple eccentric cam lobes, and bearing supports.

    camshaft speed = crankshaft speed / 2

This relationship must be exact, and camshaft orientation must be derived from crankshaft orientation.

Where practical, orient the lobes according to valve timing so the viewer can see the camshaft controls valve motion.


============================================================
VALVES, SPRINGS AND VALVE TRAIN
============================================================

Each cylinder must have a visible intake valve and exhaust valve (more if it does not compromise correctness), with recognizable head and stem.

Valves must physically translate along their valve axis.

Valve lift must derive from the cylinder's 720° cycle position:

    INTAKE:       intake valve opens
    COMPRESSION:  both valves closed
    POWER:        both valves closed during the main expansion
    EXHAUST:      exhaust valve opens

Use smooth lift curves; reasonable overlap near TDC is encouraged.

Add procedural valve springs (helical curves / TubeGeometry) that visibly compress as valves open.

Include a consistent actuation system for your chosen architecture (OHV pushrods and rockers, SOHC, DOHC…). Do not randomly combine incompatible parts.


============================================================
TIMING DRIVE AND FLYWHEEL
============================================================

Create a visible timing system (gears, chain or belt) with at least a crank timing gear and cam timing gear(s) whose rotation visibly shows the 2:1 ratio. A cam gear should be about twice the crank gear's effective diameter.

Create a substantial flywheel with outer rim, hub, bolt pattern, cutouts and ring-gear teeth. It rotates exactly with the crankshaft.


============================================================
BLOCK, BORES, HEADS, INTAKE, EXHAUST, ACCESSORIES
============================================================

Create a recognizable block (two banks, bores, crankcase, main bearings) that does NOT hide the internal animation: use cutaways, partial geometry, transparency or open sections.

Make cylinder bores obvious so pistons are seen moving inside them.

Create cylinder heads for both banks that visually connect cylinders, combustion chambers, valves and the cam/rocker system.

Create an intake system (manifold, plenum, runners, throttle body, ports) and curved exhaust headers per bank (procedural curves + TubeGeometry).

Add front-end accessories (crank pulley, accessory pulleys, belt, tensioner), rotating at plausible ratios.


============================================================
COMBUSTION AND FLOW
============================================================

When a cylinder fires, show a brief synchronized combustion effect (emissive flash, glowing volume, procedural particles) in the correct cylinder at the correct phase. At low RPM individual firing events must be clearly visible.

If practical after core mechanics are complete, add subtle bounded particle flow through the intake runners into cylinders on intake, and from exhausting cylinders into the headers.


============================================================
CONTROLS
============================================================

- Default 700 RPM, range about 0–8000, with a slider and STOP / IDLE / 2000 / 4000 / 6000 / 8000 buttons. RPM drives the shared crankshaft simulation.
- Delta-time animation: rotationsPerSecond = RPM / 60, advanced by real frame time. Speed must not depend on frame rate.
- Pause/resume without losing crank position.
- Slow-motion presets: 1×, 0.25×, 0.05×.
- Manual crank mode: scrub the crank through 0°–720°; every dependent component updates.
- Cylinder inspection 1–8: highlight piston, rod and cylinder; show its stroke and 720° cycle angle.
- OrbitControls with HERO / FRONT / SIDE / TOP / INTERNAL presets.
- Exploded-view slider separating heads, intake, exhaust, valve covers and timing components while the internals keep running.
- Visibility toggles: block, pistons, crankshaft, rods, valve train, intake, exhaust, timing.

Keep the interface compact; the engine remains the focus.


============================================================
VISUAL QUALITY
============================================================

Use physically based materials and differentiate components: dark cast-metal block, bright aluminum pistons, forged-steel rods, darker polished crankshaft, polished cams, steel valves, dark springs, aluminum intake, heat-affected exhaust, machined flywheel.

Add useful detail (bolts, flanges, bearing caps, ribs, gear teeth, pulley grooves, valve covers) with shared geometry or InstancedMesh.

Use key, fill, rim and environment lighting with clear highlights and shadows, on a clean neutral floor or grid. The engine is the entire focus.


============================================================
CODE QUALITY, TRANSFORMS AND STABILITY
============================================================

Organize the JavaScript into structures such as Engine, Crankshaft, Cylinder, Piston, ConnectingRod, Valve, Camshaft, TimingSystem. Separate geometry construction, mechanical state, rendering updates and input handling.

Reason explicitly about world, engine, bank and cylinder spaces, the crank axis, journal coordinates, rod orientation and valve axes.

Guard square roots, normalization and quaternion construction: no NaN positions or rotations, no infinite scales, no zero-length look directions.

Use shared geometries/materials, instancing, cached vectors and bounded particles, but do NOT reduce mechanical complexity to maximize FPS.


============================================================
PRIORITY
============================================================

1. Make it run (renderer, scene, camera, loop, no fatal errors)
2. Crankshaft
3. Pistons + connecting rods
4. Cylinder phasing
5. Four-stroke state
6. Camshaft
7. Valve train
8. Timing drive + flywheel
9. Block and heads
10. Intake + exhaust
11. Combustion
12. Inspection features
13. Additional mechanical detail
14. Visual polish

If you run short on output, stop adding lower-priority features and make sure the higher ones are correct. A mechanically correct engine with simple materials is MUCH better than a beautiful engine with fake mechanics.


============================================================
COMMON FAILURES TO AVOID
============================================================

1. All pistons moving together.
2. Bank pistons moving along incorrect axes.
3. Rods floating away from crank journals.
4. Rods changing length.
5. Throws not matching piston motion.
6. Firing order not matching cycle phase.
7. The cycle repeating every 360° instead of 720°.
8. Camshaft at crank speed instead of half speed.
9. Valves opening during the wrong strokes.
10. Combustion in the wrong cylinders.
11. Flywheel rotating independently.
12. Block hiding all internals.
13. Intersections caused by wrong transforms.
14. NaN transforms.
15. Speed depending on FPS.
16. Manual crank not updating every system.
17. Components that look mechanically unrelated.
18. External assets.

The viewer should be able to see a cross-plane crankshaft spinning, eight pistons reciprocating, eight rods articulating, two V-shaped banks, camshafts and lobes turning, valves opening and closing, valve springs, timing components, the flywheel, intake, exhaust headers and individual cylinders firing.

The ENGINE is the benchmark.

============================================================
OUTPUT FORMAT — READ CAREFULLY
============================================================

Reply with ONE complete, self-contained HTML document and nothing else.

- Start your reply with <!DOCTYPE html> and end it with </html>.
- No explanation, summary or notes before or after the document.
- No Markdown code fences.
- No additional files: all CSS and JavaScript go inline in this one page.
- Libraries may only be loaded from the public CDN URLs this prompt allows.
- The page must fill the browser window (no page scrollbars) and start on
  its own when opened. It is shown inside an app's embedded browser.

Your reply is saved byte for byte as the page, so anything outside the
document breaks it.
