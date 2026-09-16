# Airport mode

Windows and Android use the new airport game. Other platforms keep the
original airline game. Start the plugin, name the airline, and choose a hub.
The new airport starts paused with two connected stands and an ATR 72.

## First flights

1. Open Contracts and accept Coastal Connect. Its seven-day schedule fits
   the starter facilities. Alternatively, open a route, then use Schedule
   to book the owned ATR and let the airport assign a free stand.
2. Resume at 1×, 4×, or 12×. One game day takes 24 real minutes at 1×.
3. Follow aircraft, passenger groups, and ground vehicles. Delays and missing
   services reduce contract income. Read the schedule's issue text when a
   flight waits. Fees and operating costs appear in Finances.
4. Build connected taxiways and service roads before adding stands. Place
   passenger facilities inside terminal sections. Use cutaway to see the
   interior. Security and amenity queues make additional facilities useful.

Drag to orbit, right-drag or shift-drag to pan, and scroll to zoom. Touch
supports one-finger orbit and two-finger pan/pinch. Construction snaps to
5 m outside and 1 m inside. Rotate uses quarter turns. Reset, fit, cutaway,
grid, and quality controls are available above the airport.

Contract cancellation charges the displayed total for unserved flights;
active turnarounds finish. Cancel future owned flights before selling their
aircraft. Occupied or imminently needed infrastructure cannot be removed.

## State and rendering

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
snapshot bridging, construction previews, rotations and rendering budgets;
its renderer is stubbed and it is not GPU verification.

A Windows debug build was verified during implementation. Android SDK and
device availability are required for Android build/device validation.
Real GPU screenshots, a recorded turnaround and 60/30 FPS acceptance on
Windows/Android still require device verification. The available browser
tool blocked local preview navigation during implementation.

All scene models are original procedural meshes. Three.js 0.160.1 is
bundled under its MIT license and listed in the app's license page.
