# Airport mode

Windows and Android use the new airport game. Other platforms keep the
original airline game. Start the plugin, name the airline, and choose a hub.
The new airport starts paused with two connected stands and an ATR 72.

## First flights

1. Open Contracts and sign Coastal Connect, then open Planning and drag its
   card from the holding bar onto a stand. Alternatively, open a route, then
   click an empty Planning slot (or use Schedule) to fly the owned ATR.
2. Resume at 1×, 4×, or 12×. One game day takes 24 real minutes at 1×.
3. Follow aircraft, passenger groups, and ground vehicles. Delays and missing
   services reduce contract income. Read the schedule's issue text when a
   flight waits. Fees and operating costs appear in Finances.
4. Build connected taxiways and service roads before adding stands. Press
   **Airport** (or T) to furnish the terminal's three halls. Security and
   amenity queues make additional facilities useful.

Drag to move across the map, right-drag (or Shift/Ctrl-drag) to orbit,
and scroll to zoom. Touch: one finger moves, two fingers pinch to zoom,
drag to move and twist to turn. Construction snaps to
5 m outside and 1 m inside. Rotate uses quarter turns. Reset, fit, cutaway,
grid, quality and performance-stats controls sit under the top bar.
Keyboard: WASD/arrows pan, Q/E turn, +/- zoom, Space pauses, 1/2/3 set the
speed, R rotates, Esc cancels or closes, C and G toggle cutaway and grid,
T switches between the airfield and airport mode, B opens Build, P opens
Planning, F3 shows performance stats.

Build shows category tabs with a 3D preview card per item (rendered from the
same model that gets placed). Outside it builds the airfield; in airport
mode (below) it furnishes the terminal hall by hall.

Stands come in three kinds. Regional stands take aircraft up to 45 t.
Remote stands take anything and need a bus. Contact stands must touch a
terminal; their jet bridge removes the bus and boards 60% faster. Aircraft
park nose-in towards the nearest terminal. Duty-free shops (€14 per
passenger, after security) and lounges (€20, replaces seating) earn retail
income; plants, fountains, information boards and the smaller flight info screen add
a little satisfaction, and each
staffed information desk (5 × 4 m) adds 0.02, up to 0.06 for three.
Cleanliness runs from 60% with no bins to 100% with ten sets of recycling
bins (2 × 1 m, `cleanliness`); the gap above 60% is worth up to +0.05
satisfaction per passenger.
Ticket machines (1 × 1 m) are self check-in: passengers use whichever
check-in desk or machine frees up first, and a machine handles 4 per game
minute. At least one check-in desk (or staffed counter) is still required.
Staffed check-in counters (6 × 5 m) are a full check-in with two agents,
a bag drop and a queue lane, 10 passengers per game minute. Vending machines
(1 × 1 m) stand in for the café: one minute per group and €3 per passenger
instead of three minutes and €8; a restaurant (14 × 10 m) is the other end
of that stop: five minutes, €26 and a small mood boost. A coffee to-go stall (4 × 3 m) is quicker still:
ninety seconds and €6, and a food cart (3 × 2 m) is cheaper still: one
minute and €4, sized to fit tight corners. Fashion boutiques (8 × 6 m) share the duty-free
stop: a passenger browses whichever shop frees up first, three minutes and
€18 in a boutique. A newsstand kiosk (5 × 4 m) is the cheap end: ninety
seconds and €9; a flower shop (6 × 5 m) takes two minutes and earns €16; a duty-free food & drink hall (10 × 8 m) takes two and a
half minutes and earns €20. A perfume boutique (8 × 7 m) is low demand and
high value: two minutes, and a quarter of each group spends €90. Both
share the duty-free stop with the rest. Luxury boutiques (8 × 6 m) take four minutes, earn €26
and lift the passenger's mood a little. VIP lounges & bars (8 × 6 m) are
the premium waiting area next to seating and lounges: €35 per passenger and
+0.08 satisfaction. An arcade (10 × 8 m) is another seating alternative:
€12 per passenger and +0.07 satisfaction. A casino (12 × 10 m) is the most
expensive seating alternative: €40 per passenger and +0.06 satisfaction.

Baggage carousels (10 × 5 m) are required by every medium and long-haul
contract. When such a flight finishes unloading, its passengers walk from the
gate to the least busy connected carousel (at most `carouselCapacity`, 100
people, per carousel; the rest wait at the gate and lose satisfaction). They
wait until the baggage tug has delivered, collect for a few minutes and leave
through the entrance; their mood feeds the contract's satisfaction. In the
scene the bags ride the belt (an instanced mesh in `scene.js`, path from
`AirportModels.loopPoint`), vanish as the group collects them, and the
waiting people stand around the carousel. The model's static luggage only
appears in Build previews.

## Managing and upgrading buildings

Clicking a building opens its management window, like the original game:
a large preview, a **General** tab (status, footprint, what it is locked
by, money invested, Focus / Move / Edit interior) and an **Upgrade** tab,
plus **Flights** on a stand and **Vehicles** at a vehicle depot. The trash
button on the preview asks once before it demolishes.

Every building starts at level 1 and most go up to 5
(`maxFacilityLevel`). `facilityUpgrade(kind)` names the upgraded
attribute and its effect; `upgradeCostAt(def, level)` prices the next
level at 40% of the build cost times the current level. The simulation
applies the levels:

- runways (Surface & lighting): landing and take-off 15% faster per level;
- taxiways (Asphalt): taxi 10% faster, averaged over the taxi path;
- stands (Asphalt): ground handling and boarding 15% faster;
- fuel depot, baggage hall, vehicle depot (Equipment): services 20% faster;
- control tower (Radar): approaches 10% shorter, best tower counts;
- terminal sections (Comfort): +1% satisfaction per level, averaged;
- staffed desks, security, gates, toilets (Staff): 25% faster service;
  an information desk counts once per level;
- shops and food (Stock & staff): 15% more sales, 25% quicker service;
- seating, lounges and the arcade (Comfort): +1% satisfaction and 15% more
  income per level;
- decor and bins count once per level; carousels hand out bags 25% faster.

Hangars, service roads and entrances have no upgrades. Boarding gates have
two, levelled separately (`facilityUpgrades`, stored per id in
`AirportFacility.levels`): **boarding lanes** (one more lane per level) and
**boarding speed** (+1.5 passengers per lane per minute). The `upgrade`
command takes an optional `attribute`; without one it buys the main
upgrade. Levels survive a move and a reload, and demolishing refunds half
of the build cost plus every upgrade. The page mirrors `upgradeCostAt`
only to show the refund.

## One terminal, three parts

The terminal is one building: **Terminal** (`terminal`, 120 × 60 m, €4M).
Build as many sections as you like side by side and they join into one hall
wherever they touch (`hallKinds`). Which part of the terminal a piece of
floor is comes from zoning it, not from the building:

- The **arrival hall** is where passengers come in: the entrance, ticket
  machines, check-in desks and staffed counters, and security through to the
  main hall (`arrivalHallKinds`).
- The **main hall** is everything past security: shops, food, seating,
  toilets, lounges, decor and the boarding gates. Floor with no zone painted
  on it counts as the main hall, and stands nose in to the terminal.
- The **departure hall** is where arriving passengers leave: baggage
  carousels, customs and the check-out (`departureHallKinds`).
- Information desks, boards, panels and bins fit anywhere (`anyHallKinds`).

The names follow the game, not airport signage: the arrival hall is where
you arrive at the airport, the departure hall where you leave it.
`hallZoneOf` sorts a kind into its part, `zoneOfPlacement` says which part a
spot is, and `zoneRefusalFor` (mirrored in `scene_logic.js`) explains a
wrong placement, for example "This goes in the departure hall … Zone a piece
of floor as the departure hall first."

The separate **Arrival hall** and **Departure hall** buildings
(`terminalLandside`, `terminalReclaim`) are `hidden` in the catalog: airports
that already have one keep it, and its floor defaults to that part
(`hallZone`), but no new ones go up — `build` answers "Build a terminal and
zone its floor instead."

The starter airport is four terminal sections — two deep ones airside and a
strip along the road — with the road-side strip zoned arrival (entrance,
check-in, security) and departure (customs, check-out). The forecourt canopy
names whichever arrival and departure floor reaches it (`layout().signs`,
which reads the zones).

### Zoning the floor

Zoning marks out part of the terminal floor as one of the three parts, so
one big hall is split without rebuilding anything. In airport mode, pick
Arrival, Main, Departure or Erase and drag a rectangle over the floor. It
costs nothing.

- `AirportZone` rectangles live in `AirportWorld.zones`, are saved with the
  airport, and are painted in order: the last one wins where they overlap,
  and painting over a zone that is completely covered removes it. Erase
  takes out every zone the rectangle touches.
- `paintZone` snaps to a metre, refuses anything under 2 m and wants all
  four corners inside halls. Zoning is free.
- `zoneOfPlacement` is what placement checks: the paint under the item's
  middle, or the building's own part when the floor is unpainted — the main
  hall for a terminal, and arrival or departure for one of the old separate
  halls. `zoneRefusalFor` gives the reason. (`zoneRefusal` is the same check
  for a bare hall kind.)
- The scene washes each zone in its colour with a border, tags it, and turns
  the floor green or red under the item being placed. `scene_logic.js`
  mirrors `zoneAt` so the placement preview agrees with the simulation.
- Items already standing on floor that is later zoned differently keep
  working; the zone only decides what may be placed from then on.

## Airport mode: the terminal view

The **Airport** switch under the top bar (or T) is the original game's
terminal view. The camera glides in over the halls and stays there
(`airportLimits`): panning stops 70 m past the terminal and zoom out stops at
1.6 × the framing distance. The roofs of the halls come off, their walls drop
to the knee-high base (everything above it is tagged `upper` and baked
apart), each hall area gets a name tag, and the hall lights are on whatever
the time. The camera frames the halls in the part of the screen the side
panel leaves free.

Build opens with the zoning buttons — Arrival, Main, Departure, Erase, which
paint the floor (see above) — and one tab per hall: Arrival hall, Main hall,
Shops, Departure hall and Anywhere. The Main hall tab also carries the
Terminal itself, so the building can grow from inside the mode, and a tab
warns when nothing is zoned that way yet. While an item is being placed, the
floor it may go on turns green and floor that refuses it turns red.
Selecting a section on the airfield offers **Airport mode** framed on it.
Esc closes the panel first, then leaves the mode; the camera returns to
where it was.

## Lighting at night

`models.js` patches every standard material with lit areas (`setLights`):
up to 48 rectangles, each with a strength, the height its lights hang at and
how far apart they are. `scene.js` feeds it (`lightAreas`):

- the halls, lit to their outside walls and on across the joins, under a
  grid of downlights 8 m apart below the 10.6 m ceiling;
- floodlights over the stands (0.7), the fuel, baggage and vehicle depots
  (0.5), hangars (0.35), service roads (0.3) and, faintly, taxiways (0.16).
  When there are too many, the faintest go first.

`lightLevels(indoors, outdoors)` follows the sun: both come up with the dusk.
Indoors they stay at a quarter in daylight in airport mode. The glass keeps
its evening glow, so the facades read as lit from inside.

## The passenger flow is required

`terminalEssentials` lists what every airport needs: entrance, check-in
(desks or a staffed counter; ticket machines alone do not count),
security, a boarding gate, **customs** (8 × 6 m, 6 per game minute) and
**arrivals check-out** (8 × 4 m, 10 per game minute). Without all of them
no contract can be signed or placed and no own flight scheduled, and a
planned flight waits at its stand with "The terminal needs …" until the
missing piece is built. The starter airport includes customs and check-out
in the departure hall. Older saves without them have to build them before
flights continue.

Passengers and aircraft move the whole way:

- departing groups get out at the kerb, walk in, queue through check-in and
  security, wait at the gate, then file out to the aircraft during boarding
  (`walkingOnBoard`) and are hidden once on board (`boarded`);
- every arriving flight, not only those with checked bags, lets its
  passengers off: they walk from the aircraft to the gate (`deplaning`),
  collect bags when the contract needs a carousel, then queue at customs and
  check-out and leave through the departure hall's exit to the kerb. Returning own flights
  bring their passengers home the same way;
- own aircraft are towed from the hangar apron to the stand
  (`positioning`) and back again after their return leg (`toHangar`).

## Movement

One game minute is one real second at 1×, so speeds are chosen to read on
screen: passengers walk 3 m, vehicles drive 40 m and aircraft taxi 60 m per
game minute (`AirportWorld.walkSpeed`, `vehicleSpeed`, `taxiSpeed`).
Because walking takes real time, departing passengers start turning up at
the kerb `checkInOpens` (240) minutes before departure and trickle in
until `checkInCloses` (150) minutes before it, instead of all arriving when
the aircraft lands. Among equally free desks, a group picks the nearest.

- **Routes follow the pavement.** `_route` runs down the centreline of each
  runway, taxiway or service road and turns where two meet, at the
  `_portal` on their shared edge. The scene rounds the corners.
- **Stands line up with their taxiway.** `standNose` points the aircraft at
  the terminal it serves; `standLane` puts the lead-in line in line with a
  taxiway meeting the entry edge end-on, so the yellow line carries straight
  on. The snapshot sends `nose` and `lane`, and the stand model, parking
  spot (`parkingSpot`) and service-vehicle spots all use them.
- **Flights ease.** Each flight stage carries `ease`: the approach comes out
  of the haze 12 km away and slows towards the threshold, the landing roll
  brakes to taxi speed, taxiing pulls away and stops gently, and the
  take-off accelerates down the runway and climbs out to 1,300 m before the
  aircraft is removed. `delay` is measured when pushback starts, so the
  slower movement never costs contract money.
- **Boarding is single file, through a door.** `boardingRate` (gate lanes ×
  speed, ×1.6 over a jet bridge) sets each passenger's `interval`. Passengers
  walk the whole way (`_gateToDoor`) and never through a wall:
  `boardingDoor` puts a doorway in the wall of the gate's hall — at the jet
  bridge's rotunda on a contact stand, else on the wall the stand lies
  beyond, in line with the gate — and the hall model opens it with a GATE
  sign. From there it is the jet bridge (`bridgeRotunda`, `bridgeCab`, the
  same points the scene draws), or `boardingWalk`: a railed, ribbed walkway
  across the apron, painted lanes over the stand itself (a roof there would
  foul the wing) and up the mobile stairs to the front left door. Deplaning
  runs the same path in reverse at the same rate.
- **Vehicles drive, then work.** `arriveAt` is when a vehicle reaches the
  stand; it pulls onto its own spot beside the aircraft and works there until
  `busyUntil`. The pushback tug is sent when boarding starts.
- **Crowds behave like people.** Groups walk as a loose cluster, each person
  keeping their own place and pace. At a desk they queue in snaking rows by
  order of arrival, so the line steps forward as groups are served; at a gate
  they spread through a waiting area; in shops, cafés, lounges and seating
  they go inside. Every passenger keeps a display position that walks towards
  where the simulation puts them (`people` in `scene.js`), so nobody
  teleports when a queue shuffles or a new walk starts.
- **The display clock never runs backwards.** The simulation ticks on a
  200 ms timer that can stall; `displayTime` runs at game speed and eases
  towards the simulation's clock instead of snapping back to it.
- **Landside traffic follows real passengers.** Cars and buses only come for
  people being dropped at the kerb or walking out to it; an idle airport has
  an empty road. Trams and trains keep their timetable. The loop runs in on
  the main road, down the outer forecourt lane to the bus station and back up
  the kerb lane past the doors, all on paved lanes.

## Entrances and exits

An entrance is a doorway, not just furniture. `AirportWorld.entranceDoor`
puts its doors on the nearest outside wall of its hall (a wall shared with
another hall is inside the building) and the kerb `kerbDistance` (9 m)
outside. Departing passengers are dropped at the kerb, walk through the
doors and on to the entrance. The check-out works the same way as the exit:
arrivals walk from it out through the nearest door of the departure hall to
the kerb, and only fall back to an entrance when the check-out has no outside
wall. The snapshot sends that `door` with each entrance and check-out, the
hall model opens the wall there (sliding doors, header, ENTRANCE or EXIT)
and, unless the door is on the landside wall where the forecourt already
covers it, the scene adds a porch roof, a paved apron and a drop-off or
pick-up lane.

## Contracts and planning

Scheduling follows Airport Simulator: First Class. Airlines publish three
offers a day (`sim/airport_contracts.dart`, a pure function of the day
number so every device sees the same market); each stays open two days, and
the first one of a day is always short haul. The three starter offers never
expire. An offer is **regular** (one flight at the same time every day for N
days) or **charter** (N flights placed one by one), with a start slot:
EAM 00–06, AM 06–12, AN 12–18, PM 18–24 or any time. Short haul holds its
stand for 3 h, medium 4 h, long 6 h; the aircraft pushes back 30 minutes
before its slot ends.

Contracts opens as a full-width table like the original: airline, total
reward, slot, aircraft, flight type and service icons per row, with
"Contract details" expanding the terms and the Sign button, a countdown to
the next midnight offers, and a Signed contracts tab.

Signing (`acceptContract`) only puts the contract in Planning's holding bar.
`placeContract` drops it on a stand at a start time: a regular contract
places all remaining days at once, a charter one flight. The whole series
must fit (slot, stand size, runway, free stand on every day), start at least
30 minutes ahead and within 14 days. Regular series must start within 3 days
of signing, charters must all fly within 6; whatever is still unplanned
after that lapses and costs the per-flight penalty. `moveFlight` changes a
flight's stand and time, `unscheduleFlight` returns it to the holding bar,
and cancelling a contract charges every planned and unplanned flight.

The Planning board shows today plus the next 13 days as stands × hours with
slot bands. Drag a holding-bar card or a planned flight: the ghost turns red
and says why when the drop would be refused (the page mirrors the rules; the
simulation still decides). Drop a flight on the holding bar to unplan it.
Clicking an empty slot schedules one of your own aircraft there.
Old saves load: contracts without a stored offer map to the starter offer
and count as fully placed.

Contract cancellation charges the displayed total for unserved flights;
active turnarounds finish. Cancel future owned flights before selling their
aircraft. Occupied or imminently needed infrastructure cannot be removed,
but anything can be moved while in use; a terminal section takes its
furnishings with it, turned with it (`_carry`).

## State and rendering

The camera's near plane follows its height (15%, 0.5–400 m) and the far
plane its distance. With the old fixed 1 m near plane, the few centimetres
between grass, pavement and paint were unresolved from a few hundred metres
up, which flickered. The ground plane is also pushed back with a polygon
offset. Where taxiways, stands and runways touch, `pavementJoins` in
`scene.js` cuts their edge lines and edge lights over the shared stretch
(`cuts` in each model's own frame) and draws joined-up centrelines: a
stand's lead-in runs on to the taxiway centreline, and a taxiway ending on
an offset one curves across.

Which way a taxiway's lines run is `flowAxis` (Dart, mirrored in
`scene.js`): a strip more than twice as long as it is wide runs down its
length, and anything squarer runs the way it is used, which is the axis
with pavement on both sides. A short connector between a taxiway and a
stand is often square or wider than it is long, and taking its footprint
for its direction used to draw its centreline and edge lines across the
traffic, leaving the stand's lead-in hanging. `standLane` and the taxi
routes (`_onCentreline`, `_portal`) read the same axis, so the painted line
and the path the aircraft drives agree.

Time of day comes from game time: sunrise at 06:00, sunset at 20:00. A
shader dome (`sky`) draws the gradient, the sun, the moon and stars; the
palette is keyed on sun elevation. By night the directional light becomes a
dim moon, window glass and lamps light up, and sky reflections fade.
Textured ground materials get a world-space macro-variation noise
(`AirportModels.weather`) so their tiling stops showing, and `bake` shades
vertex colours darker towards the ground as cheap ambient occlusion. The
sky's image-based fill is kept low on purpose so the sun and its shadows
shape the scene.

All airport controls live inside the scene page
(`assets/airline_tycoon/scene/hud.js`). The page sends every change as a
`command` message; `AirportGameView` checks it against an allowlist, runs it
through `AirlineTycoonRepository.airportCommand` and replies with a `result`.
Fleet and Routes stay Flutter widgets and open as full pages, which hides the
scene.

On Windows the page runs in a real WebView2 child window
(`windows/runner/native_webview.cpp`, `_shared/native_webview.dart`), not
`webview_windows`. That package screen-captures WebView2 into a Flutter texture
and relays mouse moves over a platform channel, which held the scene near
13 fps and froze it on every drag. Nothing Flutter draws can cover the native
window, so the window hides whenever a route, dialog or menu is on top, and
no Flutter overlay may be added over the airport. Android keeps
`InAppWebView`, which is already a native view.

Every procedural model is merged by `AirportModels.bake` into at most three
vertex-coloured meshes, and repeated models share geometry through
`instance`. New model code must go through them; unmerged, the starter
airport alone was more than 550 draw calls.

The landside (`assets/airline_tycoon/scene/landside.js`) is the public side of
the terminal: the kerb and its canopy, a bus station, a tram line, an elevated
railway with a station, the access road out to a roundabout, and the hotels,
car parks and multi-storey garage along it. It is scenery only — nothing there
is simulated in Dart, and clicks still fall through to facilities.

`build(facilities)` finds the terminal wall facing away from the runways and
stands and lays the whole district out in a local frame (`u` metres out from
that wall, `v` along it), so the district follows the terminal to whichever
side it belongs on. It is keyed on that frame and only rebuilt when the
terminals move; `updateEnvironment` keeps the treeline out of `district.rect`.
The static half goes through one `bake`, so the district costs about twenty
draw calls plus its moving traffic.

Traffic follows closed polyline routes with rounded corners. Cars are a single
instanced mesh sharing the road route at two lane offsets; buses, trams and
trains are jointed, each carriage riding the same route a fixed distance
behind the one in front, and brake for stops at the bus station, the kerb, the
tram platforms and the railway station. `update(dt, {activity, night, paused,
speed})` comes from `scene.js`: waiting passenger groups and turnarounds in
progress put more cars and buses on the road, night takes them off, and a
paused airport stops them dead. Trams and trains keep their timetable either
way.

Service vehicles are bought from their depot: select a connected vehicle
depot in Build and use its shop. New vehicles spawn at that depot and
return there after each job. The simulation still rejects depot-less
purchases, so old saves fall back to the first connected depot.

## Adding a model

There is no per-model HTML file. The single
`assets/airline_tycoon/scene/index.html` loads one Three.js bundle plus
`scene_logic.js`, `models.js`, `landside.js`, `preview.js`, `hud.js` and
`scene.js`.
Every visible thing is a procedural mesh built in code in
`assets/airline_tycoon/scene/models.js` from boxes, cylinders, spheres,
extrusions and canvas labels, in metres, aircraft nose towards `-Z`.

The usual alternative is external art: model in Blender, export
glTF/FBX, load at runtime with `THREE.GLTFLoader`. That gives richer
shapes but costs bundle size, async loading states, per-model draw
calls and materials, plus licensing/attribution per asset. This game
stays procedural so the bundle is small, thumbnails reuse the same
code, everything works offline, and all art is original.

To add a new building kind `myHall`:

1. Dart catalog in `sim/airport_world.dart` (`airportFacilities`): add an
   `AirportFacilityDef('myHall', 'My hall', width, depth, height, cost,
   blurb, category: 'services')`. Set `interior: true` only for items
   that must sit completely inside a terminal. If it needs a road,
   extend `resolveConnections` (copy the `vehicleDepot`/`fuelDepot`
   pattern) and `effects` if it changes costs.
2. JS mesh in `assets/airline_tycoon/scene/models.js`: write
   `function myHall(g, w, d) { box(...); ... }` using the `box`,
   `cylinder`, `sphere`, `line`, `decal`, `label`, `light`, `pool`
   helpers, staying inside the `w × d` footprint. Tag removable roofs
   with `mesh.userData.roof = true` so cutaway hides them. Wire it in
   `facility()` next to `vehicleDepot`. End with `bake(g, ...)` — never
   skip it — and reuse repeats via `instance('myHall', ...)`.
3. Thumbnails and checks: Build cards render via `scene.js`
   `renderThumbnail`, which calls the same `M.facility`, so no extra
   art is needed. Add the kind to the footprint rotation loop in
   `assets/airline_tycoon/scene/check_scene.cjs` and run
   `node assets/airline_tycoon/scene/check_scene.cjs`.
4. Vehicles and aircraft follow the same pattern: new ground vehicles
   go in `vehicleBody(kind)` plus the `['fuel', ...]` lists in
   `hud.js` (`depotShop`, `vehicleName`) and `airport_world.dart`
   (`buyVehicle`); new aircraft go in `specs`/`aircraftBody` in
   `models.js` plus `data/aircraft.dart`.

`AirportWorld` owns simulation events in game minutes. The repository owns
the clock, commands, finances, save queue and sync. Three.js is a bundled
renderer with no server access or independent simulation. Entity paths
are interpolated between authoritative snapshots. Low quality caps visible
passengers at 36; high quality caps them at 120. Passenger counts are not
reduced by these rendering limits.

Owned aircraft depart and return using the same runway/taxiway reservations
as visiting airlines. Passenger groups navigate around terminal furniture;
finite service vehicles return to their starting depot after each task.
Flight settlement flags and resource tasks survive reloads. Catch-up uses
the same event loop as live play, capped at 12 game days. Paused airports
do not accrue offline time.

The new `airline_tycoon_airport_v2.json` save is separate from
`airline_tycoon_save.json`. Writes are serialized through a temporary file,
with a `.bak` recovery copy. Airport sync uses the separate
`airline_tycoon_airport_v2` collection and refuses cross-version imports.
The legacy file and collection are not modified by airport mode.

## Validation

Run the airport simulation, repository and UI tests together with the
existing airline tests. The scene's isolated JavaScript regression suite
is `node assets/airline_tycoon/scene/check_scene.cjs`. It verifies geometry,
snapshot bridging, construction previews, rotations, rendering budgets and the
landside's orientation, rebuild and traffic;
its renderer is stubbed and it is not GPU verification.

A Windows debug build was verified during implementation. Android SDK and
device availability are required for Android build/device validation.
Real GPU screenshots, a recorded turnaround and 60/30 FPS acceptance on
Windows/Android still require device verification. The available browser
tool blocked local preview navigation during implementation.

All scene models are original procedural meshes. Three.js 0.160.1 is
bundled under its MIT license and listed in the app's license page.
