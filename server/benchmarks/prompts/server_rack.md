Create a highly detailed interactive 3D server-rack architecture simulator as EXACTLY ONE self-contained HTML file.

The purpose of this benchmark is to test BOTH:

1. Your ability to create complex, polished 3D geometry in HTML/JavaScript.
2. Your actual understanding of enterprise server architecture, server racks, cooling, storage, power, networking, redundancy, serviceability, and different server design archetypes.

The result should feel like a combination of:

- a server manufacturer's interactive product viewer
- a datacenter engineering simulator
- an educational server-hardware visualization
- a technical CAD-style cutaway
- an interactive rack-planning tool

Technical correctness matters just as much as visual quality.

==================================================
ALLOWED DEPENDENCIES
==================================================

Use Three.js for 3D rendering.

Three.js and official Three.js helper modules such as OrbitControls may be loaded from a public CDN (unpkg.com or cdn.jsdelivr.net).

Do NOT use:

- external 3D models, GLTF or OBJ files
- external textures or images
- external CSS
- external application JavaScript
- React, Vue or Angular
- npm, a bundler, a backend or a build step

All server hardware geometry must be procedurally constructed in JavaScript.

CSS must be inside <style>...</style>.
JavaScript must be inside <script type="module">...</script>.

==================================================
SINGLE SLICE TARGET LOOK
==================================================

This describes the look to aim for in SINGLE SLICE MODE.

The target is one rack-server-style chassis viewed from above at a slight angle with the top removed, exposing the detailed internals.

Important visual characteristics to reproduce conceptually:

- whole chassis visible
- horizontal server orientation
- top cover removed
- detailed internal PCB
- multiple processor / accelerator regions
- rows of memory modules
- structural metal chassis
- internal partitions
- cooling areas
- high component density
- clean technical product-render appearance
- realistic enterprise hardware proportions

Do NOT copy an exact existing server.

Create original generic enterprise server architectures.

==================================================
APPLICATION NAME
==================================================

Display the title:

SERVER ARCHITECTURE LAB

==================================================
TWO PRIMARY VIEW MODES
==================================================

The application MUST have two fundamentally different modes:

1. FULL RACK MODE
2. SINGLE SLICE MODE

They MUST exist inside the SAME HTML application.

Do not navigate to another page.

Do not load another HTML file.

Use scene groups, state changes, animations, level-of-detail changes, or similar techniques.

Provide clearly visible controls:

[RACK VIEW]
[SLICE VIEW]

==================================================
MODE 1 — FULL RACK VIEW
==================================================

The default view should show the COMPLETE rack.

Create a realistic standard approximately 42U datacenter rack.

Use the approximate standard:

1U = 44.45 mm

The rack should visibly include:

- front vertical rails
- rear vertical rails
- rack-unit mounting holes
- rack-unit numbers
- structural frame
- top frame
- bottom frame
- equipment rails
- optional front door
- optional rear door
- removable side panels
- feet or casters
- cable-management areas
- rear cable-management space
- vertical PDUs
- empty rack spaces
- blanking panels

The initial camera must show the entire rack.

Do not crop off the top or bottom.

The rack should look physically plausible rather than like a shelf full of cubes.

==================================================
RACK CAMERA PRESETS
==================================================

Provide:

FULL RACK FRONT
FULL RACK 3/4
FULL RACK SIDE
FULL RACK REAR

The user must also be able to freely orbit, zoom and pan using OrbitControls.

==================================================
RACK POPULATION
==================================================

Populate the rack with multiple different server systems.

Use a believable rack layout, for example:

U42-U39  4U AI / GPU server
U38-U37  2U virtualization server
U36      1U general-purpose compute server
U35      1U general-purpose compute server
U34-U31  4U storage server
U30      1U network appliance
U29-U28  2U database / high-memory server

Other positions may contain:

- switches
- blanking panels
- additional servers
- storage
- empty units
- cable-management panels

Do NOT fill every rack unit unnecessarily.

The rack should look intentionally engineered.

==================================================
SERVER SELECTION
==================================================

Every installed server must be selectable.

Hovering over a server should subtly highlight it.

Clicking a server should:

- highlight its occupied rack units
- show its name
- show rack position
- show form factor
- show purpose
- make it the currently selected server

Example:

AI COMPUTE NODE
Rack position: U39-U42
Height: 4U
Purpose: GPU compute and machine learning

Provide an INSPECT SLICE control.

Selecting this should enter Single Slice Mode.

==================================================
MODE 2 — SINGLE SLICE VIEW
==================================================

This is one of the most important parts of the benchmark.

Single Slice Mode should isolate ONE selected server from the rack.

It must match the presentation described in SINGLE SLICE TARGET LOOK above.

The server should be:

- horizontal
- shown as a complete chassis
- viewed from above at a slight angle
- top cover removed
- internally detailed
- centered in the scene
- large enough for close inspection

Do NOT make Single Slice Mode simply zoom the camera into the rack.

It must be a proper isolated inspection environment.

==================================================
SLICE TRANSITION
==================================================

When INSPECT SLICE is selected:

1. unlock the server visually
2. slide it forward on rack rails
3. move it roughly 60-80% out of the rack
4. smoothly move the camera toward it
5. fade or hide the rest of the rack
6. isolate the server
7. remove or slide away the top cover
8. enable a higher-detail representation
9. settle the camera into the Whole Slice view

The user should clearly understand that this is the SAME server that was inside the rack.

==================================================
WHOLE SLICE PRESENTATION
==================================================

The default Single Slice camera should show the complete chassis.

Approximate camera angle:

- 25-45 degrees above the server
- slightly looking downward
- three-quarter engineering view
- enough perspective to see depth
- entire chassis visible

Do not initially zoom only into the motherboard.

The appearance should resemble a professional CAD/product visualization.

==================================================
SERVER INTERNAL LAYOUT
==================================================

Each server must contain meaningful internal hardware.

Do not create empty metal boxes.

The viewer should be able to recognize:

FRONT: storage bays, intake areas, backplanes

CENTER: fan wall, CPUs, RAM, chipset / motherboard, GPUs where applicable, risers, expansion cards

REAR: PSUs, networking, PCIe I/O, management interfaces, rear exhaust

Different archetypes MUST have genuinely different internal layouts.

==================================================
SERVER ARCHETYPES
==================================================

Create at least FIVE major reusable server archetypes.

ARCHETYPE 1 — GENERAL PURPOSE COMPUTE

Form factor: 1U
Purpose: web hosting, APIs, lightweight services, application hosting, general compute
Architecture:
- 2 CPU sockets
- approximately 16-24 DIMM slots
- compact passive CPU heatsinks
- ECC memory
- front hot-swap drive bays
- fan wall
- PCIe riser
- redundant PSUs
- multiple NICs
- dedicated management interface
- BMC area
Design priority: balance. CPU, memory, networking, storage, power consumption and cost should all be moderate.

ARCHETYPE 2 — VIRTUALIZATION SERVER

Form factor: 2U
Purpose: virtualization, VM hosting, container hosting, private cloud, hypervisor workloads
Architecture:
- dual high-core-count CPUs
- very large ECC memory population
- approximately 24-32 DIMM slots
- several PCIe slots
- high-speed networking
- storage controller or HBA
- redundant PSUs
- hot-swappable fan modules
It should visually emphasize CPU density plus memory capacity, with substantially more memory than the general-purpose server.

ARCHETYPE 3 — GPU / AI COMPUTE SERVER

Form factor: 4U
Purpose: machine learning, AI training, AI inference, scientific computing, rendering, accelerator workloads
Architecture:
- 2 CPU sockets
- large ECC memory configuration
- 4-8 GPU accelerator modules
- GPU interconnect region
- high-speed PCIe architecture
- large power distribution section
- extremely high airflow
- multiple fan banks
- multiple high-output redundant PSUs
- high-speed NICs
- NVMe storage
The internal layout must visibly account for GPU physical size, GPU cooling, GPU power, CPU-to-GPU connectivity, GPU interconnect and high-speed networking.
Do NOT randomly place desktop gaming GPUs inside the chassis. The layout should resemble a purpose-built datacenter accelerator system.

ARCHETYPE 4 — STORAGE SERVER

Form factor: 4U
Purpose: NAS, backups, object storage, archival storage, large storage pools
Architecture:
- approximately 24-36 hot-swappable drive bays
- clear drive cages
- SATA/SAS/NVMe backplane
- HBA / storage controller
- moderate CPU resources
- ECC memory
- redundant PSUs
- fan wall
- networking
The storage architecture should visually communicate: DRIVE → BACKPLANE → HBA / STORAGE CONTROLLER → CPU / MEMORY → NETWORK.
The front of this server should be dominated by storage.

ARCHETYPE 5 — DATABASE / HIGH-MEMORY SERVER

Form factor: 2U
Purpose: databases, analytics, transactional systems, large in-memory workloads
Architecture:
- high-core-count CPUs
- very large DIMM population
- ECC memory
- multiple NVMe drives
- high-speed networking
- redundant PSUs
- strong cooling
- multiple PCIe devices
Design priorities: memory capacity, memory bandwidth, CPU performance, storage latency, network throughput.

OPTIONAL ARCHETYPE 6 — NETWORK APPLIANCE

If practical, create a network appliance.
Form factor: 1U
Purpose: routing, firewalling, load balancing, switching
Architecture:
- network-oriented CPU
- smaller memory capacity
- multiple SFP/SFP+/QSFP style ports
- redundant PSUs
- strong front-to-rear airflow
- minimal local storage

==================================================
CPU DETAIL
==================================================

CPU regions must look convincing.

Include sockets, CPU package, heatsinks, retention hardware, nearby VRMs, capacitors, power-delivery circuitry and motherboard routing around the socket.

For dual-socket servers, show two distinct CPU areas.

CPU heatsinks should be aligned with airflow.

==================================================
MEMORY DETAIL
==================================================

DIMMs must be arranged logically around CPU sockets.

Do NOT randomly place RAM.

Use realistic memory-channel style layouts.

Include empty DIMM slots, populated DIMMs, DIMM PCBs, memory chips, slot latches and repeating memory banks.

Where appropriate show labels such as A1, A2, A3, B1, B2 or similar conceptual labels.

==================================================
MOTHERBOARD DETAIL
==================================================

The mainboard should contain visually recognizable structures such as PCB, traces, VRMs, capacitors, chipsets, BMC, PCIe slots, sockets, headers, connectors, power connectors, riser connectors and storage connectors.

It does not need to electrically simulate every trace.

However, it should look like a serious server motherboard rather than a decorative green rectangle.

==================================================
PCIe AND RISERS
==================================================

Show realistic PCIe slots, riser cards, NICs, HBAs, accelerator cards, connectors and brackets.

PCIe devices should connect logically to the motherboard.

Avoid floating cards or impossible placement.

==================================================
STORAGE DETAIL
==================================================

Create realistic drive systems.

Support visual distinction between 2.5-inch drives, 3.5-inch drives and NVMe/U.2 style drives.

Hot-swap drives should have a carrier, faceplate, latch, ventilation and status LED.

Storage servers must include an actual visible backplane.

==================================================
POWER SUPPLIES
==================================================

Enterprise servers should use redundant PSUs where appropriate.

Show PSU housing, handle, exhaust grille, connectors, status indicators, internal location and power distribution connection.

High-end GPU systems may have more than two PSUs.

==================================================
NETWORKING
==================================================

Show realistic networking hardware.

Possible ports: RJ45, SFP, SFP+, QSFP, management Ethernet.

Include a dedicated management port where appropriate.

Network interfaces should live in believable rear-I/O or expansion-card locations.

==================================================
COOLING
==================================================

Cooling is a major benchmark requirement.

Include fan wall, hot-swappable fan modules, fan blades, fan guards, fan housings, passive heatsinks, airflow ducts, perforated surfaces, intake zones and exhaust zones.

High-density servers must look substantially more cooling-intensive.

GPU systems should have noticeably larger airflow requirements.

==================================================
AIRFLOW VISUALIZATION
==================================================

Add a SHOW AIRFLOW toggle.

When enabled, visualize airflow with particles, arrows, animated lines, translucent streams or another performant technique.

Typical server airflow:

FRONT → DRIVE / INTAKE → FAN WALL → CPU / RAM → GPU / PCIe → REAR EXHAUST

Storage server airflow should pass through drive cages.

GPU server airflow should show strong flow across accelerators.

Airflow must not simply pass through solid metal objects.

Try to route airflow approximately around physical structures.

The visualization should explain WHY components are arranged in their positions.

==================================================
POWER PATH VISUALIZATION
==================================================

Add a SHOW POWER PATH toggle.

Visualize approximate logical power flow:

AC INPUT → PSU → POWER DISTRIBUTION → MOTHERBOARD → CPU → MEMORY → STORAGE → GPU / PCIe

Use animated or glowing lines.

For redundant PSUs, show multiple sources.

==================================================
DATA PATH VISUALIZATION
==================================================

Add a SHOW DATA PATHS toggle.

GPU server example: NVMe ↓ CPU ←→ RAM ↓ PCIe ↓ GPU; GPU ↓ HIGH-SPEED NIC ↓ NETWORK

Storage server example: DRIVES ↓ BACKPLANE ↓ HBA ↓ CPU ↓ NETWORK

Database server example: NVMe ↓ CPU ↔ RAM ↓ NETWORK

These are conceptual educational paths.

Do not claim they are exact PCB traces.

==================================================
SINGLE SLICE CAMERA PRESETS
==================================================

Provide:

WHOLE SLICE: the entire open server, as in the SINGLE SLICE TARGET LOOK.
TOP DOWN: the chassis almost directly from above.
3/4 ENGINEERING VIEW: approximately 30-40 degrees above the server.
FRONT INTERNALS: looks from the front toward fans and compute hardware.
REAR INTERNALS: PSUs, networking and PCIe.
CPU + MEMORY: processor sockets and DIMM banks.
GPU AREA: GPU accelerators and interconnects.
STORAGE AREA: drives, backplane and storage controller.

==================================================
OPEN COVER
==================================================

Provide OPEN COVER and optionally CLOSE COVER.

The top server cover should slide backward, lift upward, or use another plausible service-removal animation.

It should not simply disappear instantly unless performance requires it.

==================================================
CHASSIS CUTAWAY
==================================================

Provide CHASSIS CUTAWAY.

This should fade or hide selected structural metal that blocks the internal hardware.

Internals remain opaque.

The user should still understand the shape of the chassis.

==================================================
EXPLODED VIEW
==================================================

Provide EXPLODED VIEW.

Separate major components while preserving spatial relationships.

Possible exploded stack: TOP COVER, GPU / RISER ASSEMBLY, AIR DUCT, CPU + MEMORY AREA, FAN WALL, MAINBOARD, STORAGE BACKPLANE, POWER SYSTEM, BASE CHASSIS.

Do not move components so far apart that the design becomes confusing.

Animate the transition.

==================================================
COMPONENT SELECTION
==================================================

Individual components should be selectable where practical.

Hover: subtle highlight.

Click: open an information panel.

Examples:

CPU 1 — Type: Server CPU. Role: General processing. Socket: CPU 1. Approximate power: 280 W. Cooling: Passive heatsink using chassis airflow.

GPU Accelerator #3 — Role: AI / compute acceleration. Connection: PCIe / accelerator interconnect. Approximate power: 600 W. Cooling: High-pressure chassis airflow.

DIMM A6 — Type: ECC RDIMM. Capacity: 64 GB. CPU: CPU 1. Memory Channel: C.

The exact specs may be fictional but should remain realistic and internally consistent.

==================================================
SERVER HEALTH SIMULATION
==================================================

Display a small server-monitoring panel for the selected server.

Possible metrics: CPU 1 temperature, CPU 2 temperature, GPU temperature, memory utilization, storage utilization, network traffic, fan RPM, power consumption.

Example: CPU 1 71°C, CPU 2 68°C, GPU Average 76°C, Memory 612 / 1024 GB, Power 4.8 kW, Fans 11,200 RPM, Network 78 Gbit/s.

Values may be simulated.

Update them slowly.

Keep ranges believable.

Do not wildly randomize them every frame.

==================================================
FAILURE SIMULATION
==================================================

Add SIMULATE FAILURE with the options:

FAN FAILURE, PSU FAILURE, DRIVE FAILURE, GPU OVERHEAT, NETWORK LINK FAILURE

FAN FAILURE: one fan stops, the fan indicator changes, nearby fans increase RPM, temperature slowly increases.

PSU FAILURE: one PSU goes offline, the remaining PSU(s) continue operation, active PSU load increases.

DRIVE FAILURE: one drive indicates failed/degraded, the storage array reports degraded status.

GPU OVERHEAT: GPU temperature increases, fan RPM increases, a warning appears.

NETWORK LINK FAILURE: one port loses link, its indicator turns off, a warning appears.

The purpose is to show why redundancy and monitoring exist.

==================================================
ARCHETYPE INFORMATION
==================================================

When selecting a server, show a summary.

Example:

AI COMPUTE NODE, 4U
Purpose: Large-scale GPU compute
CPUs: 2
GPUs: 8
RAM: 1 TB
Storage: 8x NVMe
Network: 2x high-speed NIC
PSUs: 4 redundant high-output modules
Approximate power: 6-10 kW
Primary design priority: GPU density and cooling

Then show a short explanation of WHY the architecture is designed that way.

Example:

"GPU servers use very high airflow and large power systems because accelerator modules can dissipate several hundred watts each. Short front-to-rear airflow paths reduce pressure losses and help cool densely packed accelerators."

==================================================
ARCHETYPE COMPARISON
==================================================

Add a comparison mode.

Compare: GENERAL PURPOSE, VIRTUALIZATION, GPU / AI, STORAGE, DATABASE

Use conceptual bar indicators for: CPU capability, GPU capability, memory capacity, storage capacity, network capability, power consumption, cooling requirement, implementation complexity.

Do NOT invent fake benchmark numbers and present them as measured results.

These indicators are architectural comparisons only.

==================================================
RACK-LEVEL POWER
==================================================

Show a rack power summary.

Example conceptual display:

RACK POWER
AI Server 7.2 kW
Virtualization 1.1 kW
Compute Node 1 0.7 kW
Compute Node 2 0.7 kW
Storage Server 1.0 kW
Database 1.6 kW
Network 0.4 kW
TOTAL 12.7 kW

Also show ESTIMATED HEAT OUTPUT.

Explain visually that nearly all consumed server electrical power eventually becomes heat that the datacenter cooling system must remove.

==================================================
REAR OF RACK
==================================================

The rear of the rack must NOT be empty.

Show PSU exhausts, NICs, management ports, network ports, power cables, network cables, vertical PDUs and cable management.

Use manageable cable complexity.

Avoid thousands of expensive curve objects.

==================================================
PDUs
==================================================

Include vertical rack PDUs where practical.

Servers should conceptually connect their PSUs to redundant power feeds, for example PDU A and PDU B.

High-availability servers should connect redundant PSUs to different feeds.

==================================================
CABLE MANAGEMENT
==================================================

Add some realistic rear cabling: power cables, network cables, high-speed interconnects.

Cables should be organized around cable-management channels.

Do not create random spaghetti everywhere.

==================================================
RETURN TO RACK
==================================================

Provide RETURN TO RACK.

When activated:

1. return exploded components to normal if needed
2. restore cover if appropriate
3. move server back toward rack
4. bring rack into view
5. align server with original rack units
6. slide server back into rails
7. restore Full Rack camera

==================================================
SERVER SWITCHING IN SLICE VIEW
==================================================

While inspecting a slice, provide < PREVIOUS SERVER and NEXT SERVER >.

Display, for example: SERVER 03 / 08, AI COMPUTE NODE, 4U, U39-U42.

Switching servers should replace the hardware with that server's actual architecture.

Do NOT reuse exactly the same internal layout for every server.

==================================================
DETAIL DIFFERENCES BETWEEN ARCHETYPES
==================================================

A knowledgeable viewer should be able to infer the server's purpose visually.

GENERAL PURPOSE: balanced, moderate memory, moderate storage, modest expansion
VIRTUALIZATION: huge DIMM population, strong CPU emphasis, significant networking
GPU / AI: dominant GPU area, extreme cooling, large power system, accelerator interconnect
STORAGE: huge drive section, obvious backplane, storage controller, moderate CPU section
DATABASE: dense memory, NVMe storage, powerful CPUs, strong networking

==================================================
LEVEL OF DETAIL
==================================================

Use different detail levels where useful.

FULL RACK MODE: optimize geometry. Do not render tiny motherboard capacitors inside every closed server if they are invisible.

SINGLE SLICE MODE: enable high-detail geometry such as PCB traces, capacitors, VRMs, DIMM sockets, DIMMs, heatsink fins, fan blades, drive carriers, connectors, PCIe slots, risers, motherboard headers, screws, rails, structural supports, power connectors, network ports and backplanes.

The slice should withstand close visual inspection.

==================================================
PERFORMANCE
==================================================

Aim for approximately 60 FPS on a reasonable desktop GPU.

Use techniques such as InstancedMesh, shared BufferGeometry, shared materials, reduced geometry in rack mode, hidden object disabling, level of detail and efficient update loops.

Repeated objects that should ideally use instancing include DIMMs, rack holes, drives, fans, LEDs, screws and repeated capacitors.

Avoid creating unnecessary unique geometries.

In the top UI show, where practical, FPS, DRAW CALLS and TRIANGLES, updating live.

==================================================
VISUAL STYLE
==================================================

Use a professional enterprise engineering style.

Preferred materials: dark powder-coated metal, matte black chassis, brushed metal, green or dark server PCBs, black ICs, silver heatsinks, copper details where appropriate, gold electrical contacts, dark fan modules.

Use small functional status LEDs.

Avoid excessive RGB lighting.

Avoid turning the scene into a cyberpunk gaming PC.

==================================================
LIGHTING AND BACKGROUND
==================================================

Include ambient or hemisphere lighting, directional or area-style key lighting, soft shadows where practical, physically plausible materials, restrained reflections and appropriate tone mapping.

The server internals should remain readable. Do not make the scene extremely dark.

Use a restrained neutral technical background (dark gray, subtle studio environment, engineering visualization background). Avoid distracting scenery.

==================================================
UI LAYOUT
==================================================

Create a modern technical interface.

TOP BAR: SERVER ARCHITECTURE LAB, plus FPS, Draw calls, Triangles.

LEFT PANEL: rack overview, server list, rack unit position, current archetype.

RIGHT PANEL: selected server information, selected component information, health monitoring, architecture explanation.

BOTTOM TOOLBAR: [RACK VIEW] [SLICE VIEW] [OPEN COVER] [CUTAWAY] [EXPLODE] [AIRFLOW] [POWER] [DATA] [FAILURES] [RESET]

Use clear active/inactive button states.

==================================================
INTERACTION
==================================================

Support orbit, pan, zoom, hover selection, click selection, UI selection, server inspection and component inspection.

Use Raycaster or another appropriate Three.js selection method.

==================================================
RESET
==================================================

Provide RESET.

It should cancel failure simulation, disable airflow, power paths and data paths, restore exploded geometry, restore chassis state, restore the camera and restore server transforms.

==================================================
ENGINEERING RULES
==================================================

The server layouts must demonstrate actual understanding of server hardware.

Avoid:

- desktop PC layouts inside rack servers
- tower-style motherboards
- random RAM placement
- GPUs blocking all airflow
- impossible GPU orientations
- power supplies in inaccessible locations
- storage drives with no backplane
- fans facing meaningless directions
- CPU heatsinks perpendicular to airflow without explanation
- inaccessible hot-swap hardware
- enormous unused spaces in high-density systems
- random decorative circuit boards
- PCIe cards not connected logically to motherboard/riser systems
- high-end enterprise systems with unexplained single PSUs
- server fronts with no intake
- completely blank server rears
- impossible component overlap
- cables passing directly through metal
- airflow passing directly through solid walls
- memory banks unrelated to CPU sockets

==================================================
SERVICEABILITY
==================================================

Server design should consider maintenance. Where applicable: drives front-accessible, PSUs rear-accessible, fans replaceable, PCIe assemblies removable, covers removable, and no major component requiring impossible disassembly.

==================================================
SERVER ARCHITECTURE REASONING
==================================================

Treat each server as an engineered system.

For every archetype, the hardware layout should visibly reflect its intended workload.

GENERAL PURPOSE: balance
VIRTUALIZATION: CPU + RAM density
GPU / AI: accelerators + cooling + power
STORAGE: drive density + backplane architecture
DATABASE: memory + CPU + low-latency storage + networking

Someone familiar with server hardware should be able to identify the likely role of the machine simply by looking at its internals.

==================================================
FULL RACK VS SINGLE SLICE
==================================================

This distinction is absolutely mandatory.

FULL RACK MODE tests: rack design, rack unit sizing, density, server placement, rack organization, rear cabling, power distribution, macro-level architecture.

SINGLE SLICE MODE tests: internal server architecture, motherboard design, CPUs, memory, storage, GPUs, fans, power delivery, networking, serviceability, component-level detail.

A visually impressive rack containing plain server boxes is NOT sufficient.

A visually impressive motherboard with no believable rack is also NOT sufficient.

Both scales must be implemented.

The Single Slice view should be visually close in spirit to the SINGLE SLICE TARGET LOOK described above: a complete open server, top cover removed, viewed from an elevated 3/4 angle, with a detailed chassis, clearly divided hardware zones, dense but organized hardware and realistic enterprise proportions. It should feel like a premium hardware engineering render.

==================================================
QUALITY EXPECTATIONS
==================================================

The project will be evaluated on:

3D MODELING QUALITY: geometry, proportions, component detail, rack accuracy, visual hierarchy, server uniqueness
RENDERING QUALITY: lighting, materials, shadows, camera composition, anti-aliasing, readability
INTERACTION QUALITY: smooth rack-to-slice transition, selection, camera movement, exploded views, cover animation, reset behavior
SERVER ENGINEERING KNOWLEDGE: rack units, CPUs, memory channels, PCIe, risers, storage backplanes, redundant power, networking, fans, airflow, cooling, maintenance, rack power, cabling
SOFTWARE QUALITY: readable code, modular functions/classes, reusable procedural geometry, reasonable performance, limited duplication, sensible state management

==================================================
FINAL TARGET
==================================================

The final application should make it possible to:

1. View an entire realistic 42U rack.
2. Rotate around it.
3. Select an individual server.
4. Pull that server out on rails.
5. Enter Single Slice Mode.
6. View the complete open chassis as described in the SINGLE SLICE TARGET LOOK.
7. Inspect CPUs, DIMMs, storage, GPUs, fans, networking and PSUs.
8. Use cutaway and exploded views.
9. Visualize airflow.
10. Visualize power paths.
11. Visualize conceptual data paths.
12. Simulate component failures.
13. Compare different server archetypes.
14. Return to the complete rack.
15. Do all of this inside ONE HTML FILE.

Do not sacrifice engineering correctness for decorative complexity.

Do not create a generic sci-fi machine.

Create a believable enterprise server architecture laboratory.

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
