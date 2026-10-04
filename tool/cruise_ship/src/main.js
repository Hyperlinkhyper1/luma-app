import './ui/styles.css';
import * as THREE from 'three/webgpu';
import { createRenderer } from './core/renderer.js';
import { settings, QUALITY } from './core/settings.js';
import { Clock } from './core/clock.js';
import { Input } from './core/input.js';
import { Post } from './core/post.js';
import { Lighting } from './core/lighting.js';
import { Weather } from './env/weather.js';
import { Sky } from './env/sky.js';
import { Ocean, ocean } from './env/ocean.js';
import { ShipMotion } from './env/shipMotion.js';
import { installFog, updateFog } from './env/fog.js';
import { Rain, Lightning, roofAt } from './env/precip.js';
import { Audio } from './core/audio.js';
import { buildShip } from './ship/index.js';
import { shipU } from './ship/materials.js';
import { Modes, MODE_LABEL } from './player/modes.js';
import { Tender } from './player/tender.js';
import { Port } from './world/port.js';
import { Ambient } from './world/ambient.js';
import { deckY, PROM } from './ship/dims.js';
import { describe } from './ship/areas.js';
import { Hud } from './ui/hud.js';
import { Menu } from './ui/menu.js';
import { DeckMap } from './ui/map.js';
import { tellHost } from './core/host.js';

const $ = (id) => document.getElementById(id);
// Yields so the loading bar can paint. Not tied to requestAnimationFrame,
// which stops entirely in a hidden window.
const tick = () => new Promise((r) => setTimeout(r, 16));

function progress(f, msg) {
  $('loadBar').style.width = `${Math.round(f * 100)}%`;
  if (msg) $('loadStep').textContent = msg;
}

function fatal(msg) {
  $('loading').hidden = true;
  $('fatal').hidden = false;
  $('fatalMsg').textContent = msg;
  tellHost('cruise-error', { message: String(msg).split('\n')[0] });
}

const KNOT = 0.514444;

const MODE_TOAST = {
  walk: 'On deck · V for the tender',
  tender: 'In the tender at sea level · W/S throttle, A/D steer, V for the drone',
  drone: 'Drone · WASD, Space/Q up and down, V to walk again',
};

class App {
  async start() {
    const canvas = $('view');
    progress(0.04, 'Starting the renderer…');
    const { renderer, backend } = await createRenderer(canvas);
    this.renderer = renderer;
    this.backend = backend;
    this.scene = new THREE.Scene();
    const g = settings.get().graphics;
    this.camera = new THREE.PerspectiveCamera(g.fov, innerWidth / Math.max(1, innerHeight), 0.06, 60000);
    this.clock = new Clock();
    this.weather = new Weather();
    this.input = new Input(canvas);

    progress(0.1, 'Generating cloud volumes…');
    await tick();
    this.sky = new Sky(renderer, this.scene, g.clouds);

    progress(0.3, 'Filling the Mediterranean…');
    await tick();
    this.ocean = new Ocean(this.sky);
    this.scene.add(this.ocean.mesh);
    this.motion = new ShipMotion(this.ocean);

    progress(0.4, 'Raising the ship…');
    await tick();
    const ship = await buildShip((f, msg) => progress(0.4 + f * 0.45, msg));
    this.ship = ship;
    this.shipRoot = ship.root;
    this.scene.add(ship.root);
    this.lighting = new Lighting(this.scene, ship.root, ship.pois.lamps);
    installFog(this.scene);
    progress(0.86, 'Charging the clouds…');
    await tick();
    this.rain = new Rain(this.scene, ship.collider);
    this.lightning = new Lightning(this.scene);
    this.lightning.onStrike = (dist, power) => this.audio?.thunder(dist, power);

    progress(0.88, 'Building the quay…');
    await tick();
    this.port = new Port(this.scene, ship.materials);
    ship.pois.spots.push(...this.port.pois.spots);
    ship.pois.doors.push(...this.port.pois.doors);
    ship.pois.doors.push({ x: -25, y: deckY(7), z: PROM.wallZ + 0.6, label: 'Gangway — go ashore', ashore: true, portOnly: true });
    this.port.setVisible(this.inPort());
    this.ambient = new Ambient(this.scene, ship.root);
    this.funnelTop = new THREE.Vector3(-82, deckY(18) + 20.6, 0);
    this.tender = new Tender(this.scene, this.ocean, ship.materials);
    this.modes = new Modes({ camera: this.camera, shipRoot: ship.root, collider: ship.collider, input: this.input, tender: this.tender });
    this.modes.walker.cols.push(this.port.collider);
    this.modes.walker.place(ship.pois.spots.find((s) => s.id === 'deck7-stbd'));
    this.modes.walker.respawn = () => {
      const id = this.inPort() && this.modes.walker.pos.z > 20 ? 'quay' : 'deck7-stbd';
      this.modes.walker.place(ship.pois.spots.find((s) => s.id === id) ?? ship.pois.spots[0]);
      this.hud?.toast('Back aboard');
    };
    this.modes.onChange = (m) => {
      this.hud.setMode(MODE_LABEL[m]);
      this.hud.toast(MODE_TOAST[m]);
    };

    progress(0.9, 'Compiling shaders…');
    this.post = new Post(renderer, this.scene, this.camera);
    this._buildPost();
    settings.onChange((p) => { if (p.startsWith('graphics') || p === '*') this._applyGraphics(); });
    this._resize();
    addEventListener('resize', () => this._resize());

    this.audio = new Audio();
    settings.onChange((p) => { if (p.startsWith('audio') || p === '*') this.audio.applyVolumes(); });
    this.modes.walker.onStep = (speed) => {
      const pos = this.modes.walker.pos;
      const surface = Math.abs(pos.y - deckY(18)) < 0.6 ? 'paint' : (this._onStairs ? 'metal' : 'teak');
      this.audio.step(surface, speed);
    };
    this.hud = new Hud();
    this.menu = new Menu(this);
    this.map = new DeckMap(this, ship.pois);
    this._bindKeys();

    this.t = 0;
    this.distance = 0;
    this.last = performance.now();
    this.frame(0.001);   // warm up shaders before the card is shown
    $('loading').hidden = true;
    $('board').hidden = false;
    $('backendNote').textContent = `Rendering with ${backend}${backend === 'WebGPU' ? '' : ' (WebGPU unavailable)'}.`;
    $('boardBtn').onclick = () => this.board();
    renderer.backend.device?.lost?.then((info) => {
      if (info.reason !== 'destroyed') fatal(`The graphics device was lost: ${info.message || info.reason}`);
    });
    renderer.setAnimationLoop(() => this.frame());
    tellHost('cruise-ready', { backend });
  }

  board() {
    $('board').hidden = true;
    $('hud').hidden = false;
    this.boarded = true;
    this.audio.start();
    this.resume();
  }

  /** Back to the game from a menu: input on, mouse captured again. */
  resume() {
    if (this.menu?.open || this.map?.open) return;
    this.input.enabled = true;
    this.input.lock();
    $('view').focus();
  }

  inPort() { return settings.get().sea.location === 'port'; }

  /** Fade to black, run fn, fade back. */
  async fade(fn) {
    const f = $('fade');
    f.classList.add('on');
    await new Promise((r) => setTimeout(r, 460));
    await fn();
    await new Promise((r) => setTimeout(r, 120));
    f.classList.remove('on');
  }

  teleport(spot) {
    this.fade(() => {
      this.modes.set('walk');
      this.modes.walker.place(spot);
      this.hud.toast(spot.label);
    });
  }

  setLocation(v) {
    this.fade(() => {
      settings.set('sea.location', v);
      this.port?.setVisible(v === 'port');
      if (this.modes.mode === 'walk' && v !== 'port' && this.modes.walker.pos.y < 5) {
        this.modes.walker.place(this.ship.pois.spots.find((p) => p.id === 'deck7-stbd'));
      }
      this.hud.toast(v === 'port' ? 'Moored alongside the quay' : 'At sea, under way');
    });
  }

  /** E: use the nearest door or stairwell. */
  interact() {
    if (this.modes.mode !== 'walk') return;
    const d = this._nearDoor;
    if (!d) return;
    const spot = (id) => this.ship.pois.spots.find((s) => s.id === id);
    if (d.board) this.teleport(spot('deck7-stbd'));
    else if (d.ashore) this.teleport(spot('quay'));
    else this.map.show(d.label.split(' — ')[0]);
  }

  _audio(dt, w, port, speed, windWorld) {
    if (!this.audio.started) return;
    const v = this.modes.viewLocal;
    const walking = this.modes.mode === 'walk';
    const roof = roofAt(this.rain.roof, v.x, v.z);
    const sheltered = v.y < roof - 0.3;
    const edge = v.y < deckY(9) ? PROM.railZ - 1 : 20.5;
    const nearRail = walking ? THREE.MathUtils.smoothstep(Math.abs(v.z), edge - 2, edge + 1) : (this.modes.mode === 'drone' ? 1 : 0.4);
    const poolD = Math.hypot(Math.max(0, Math.abs(v.x - 16) - 38), (v.y - deckY(16) - 1) * 2, Math.max(0, Math.abs(v.z) - 14));
    const funD = Math.hypot(v.x + 78, (v.y - deckY(18) - 10) * 0.7, v.z);
    this._onStairs = false;
    this.audio.update(dt, {
      height: this.camera.position.y,
      nearRail,
      wind: windWorld.length(),
      speed,
      rain: w.rain,
      sheltered,
      day: 1 - this.lighting.night,
      pool: walking ? THREE.MathUtils.clamp(1 - poolD / 40, 0, 1) : 0,
      funnel: THREE.MathUtils.clamp(1 - funD / 70, 0, 1),
      tender: this.modes.mode === 'tender',
      port,
      fog: w.fog,
    });
  }

  _doors() {
    if (this.modes.mode !== 'walk') { this._nearDoor = null; this.hud.prompt(null); return; }
    const p = this.modes.walker.pos;
    let best = null, bd = 2.2;
    for (const d of this.ship.pois.doors) {
      if (d.portOnly && !this.inPort()) continue;
      const dist = Math.hypot(d.x - p.x, (d.y - p.y) * 2, d.z - p.z);
      if (dist < bd) { bd = dist; best = d; }
    }
    this._nearDoor = best;
    this.hud.prompt(best ? `<kbd>E</kbd> ${best.label}` : null);
  }

  _buildPost() {
    const g = settings.get().graphics;
    this.post.build({ ao: g.ao, taa: g.taa, bloom: g.bloom });
  }

  _applyGraphics() {
    const g = settings.get().graphics;
    this.camera.fov = g.fov;
    this.camera.updateProjectionMatrix();
    this._buildPost();
    if (this._cloudQ !== g.clouds) { this._cloudQ = g.clouds; this.sky.clouds.setQuality(g.clouds); }
    this._resize();
    $('fps').hidden = !g.showFps;
  }

  _bindKeys() {
    const I = this.input;
    // Switching view fades through black, so the jump to sea level in the
    // tender reads as a move, not a fall.
    I.on('KeyV', () => { if (!this._switching) { this._switching = true; this.fade(() => this.modes.next()).then(() => { this._switching = false; }); } });
    I.on('F1', () => document.body.classList.toggle('nohud'));
    I.on('KeyE', () => this.interact());
    I.on('KeyH', () => this.audio?.horn());
    I.on('KeyM', () => { if (!this.boarded || this.menu.open) return; this.map.toggle(); });
    I.on('Escape', () => {
      if (!this.boarded) return;
      if (this.map.open) { this.map.hide(); return; }
      this.menu.toggle();
    });
    // Esc while the mouse is captured releases it before the page sees the
    // key, so losing the lock counts as asking for the menu.
    I.onUnlock = () => { if (this.boarded && !this.menu.open && !this.map.open) this.menu.show(); };
  }

  _resize() {
    if (innerWidth < 2 || innerHeight < 2) return;   // hidden window
    const g = settings.get().graphics;
    const dpr = Math.min(devicePixelRatio || 1, 2) * g.renderScale;
    this.renderer.setPixelRatio(dpr);
    this.renderer.setSize(innerWidth, innerHeight, false);
    this.camera.aspect = innerWidth / innerHeight;
    this.camera.updateProjectionMatrix();
    this.sky.resize(innerWidth * dpr, innerHeight * dpr);
  }

  frame(forceDt) {
    const now = performance.now();
    const dt = forceDt ?? Math.min(0.1, (now - this.last) / 1000);
    this.last = now;
    this.t += dt;
    const port = settings.get().sea.location === 'port';
    const speed = port ? 0 : settings.get().sea.knots * KNOT;
    this.distance += speed * dt;
    ocean.shipSpeed.value = speed;

    this.clock.update(dt);
    this.weather.update(dt);
    const w = this.weather.current;
    const windShip = this.weather.windDir - this.clock.heading;
    this.ocean.setSea(this.weather.beaufort(), windShip, windShip + 0.7, port);
    ocean.rain.value = w.rain;

    // Ship moves on the sea, then the viewer moves on the ship.
    this.motion.update(dt, port, this.t);
    this.motion.apply(this.shipRoot);
    shipU.inv.value.copy(this.shipRoot.matrixWorld).invert();
    shipU.wet.value = this.weather.wetness;
    this.modes.update(dt);

    this.ocean.update(this.t, this.distance, this.camera);
    this.sky.update({
      clock: this.clock, weather: this.weather, camera: this.camera, shipDistance: this.distance, dt,
      windEarth: new THREE.Vector2(Math.cos(windShip) * w.wind, Math.sin(windShip) * w.wind),
    });
    this.lighting.update(dt, { clock: this.clock, weather: this.weather, viewLocal: this.modes.viewLocal, snap: this.snapExposure });
    updateFog(this.weather);
    const windWorld = this._wind || (this._wind = new THREE.Vector2());
    // Apparent wind on deck = true wind minus the ship's own motion.
    windWorld.set(Math.cos(windShip) * w.wind - speed, Math.sin(windShip) * w.wind);
    this.rain.update(dt, this.t, this.camera, this.weather, windWorld);
    this.lightning.update(dt, this.weather, this.camera.position);
    this._audio(dt, w, port, speed, windWorld);
    this.ambient.update(dt, this.t, { port, speed, windWorld, day: 1 - this.lighting.night, camera: this.camera, funnelTop: this.funnelTop, shipRoot: this.shipRoot });

    this._doors();
    this.menu.tick();
    this.hud.update({
      time: this.clock.label(),
      weather: this.weather.label(),
      sea: port ? 'Moored' : `${settings.get().sea.knots} kn`,
      place: this.modes.mode === 'walk' ? describe(this.modes.walker.pos) : null,
      mode: this.modes.mode,
      dt,
    });
    this.post.render();
  }
}

const app = new App();
window.__app = app;

if (import.meta.env.DEV) {
  // Render frames on demand and save the canvas to .shots/<name>.jpg. Works
  // while the window is hidden (requestAnimationFrame is paused then).
  window.__shot = async (name = 'shot', frames = 24, W = 1600, H = 900) => {
    const canvas = $('view');
    // A hidden window reports a 0x0 viewport: render at a fixed size.
    app.renderer.setPixelRatio(1);
    app.renderer.setSize(W, H, false);
    app.camera.aspect = W / H;
    app.camera.updateProjectionMatrix();
    app.sky.resize(W, H);
    app.snapExposure = true;
    const dev = app.renderer.backend.device;
    // Per-frame nodes (TRAA, bloom, GTAO) key off the animation loop's frame
    // counter, which doesn't advance while rAF is paused: step it by hand.
    const step = () => {
      const nodes = app.renderer._nodes;
      if (nodes?.nodeFrame) { nodes.nodeFrame.update(); app.renderer.info.frame = nodes.nodeFrame.frameId; }
      app.frame(1 / 60);
    };
    for (let i = 0; i < frames; i++) {
      step();
      if (dev) await dev.queue.onSubmittedWorkDone();
    }
    step();
    const c = document.createElement('canvas');
    c.width = canvas.width; c.height = canvas.height;
    c.getContext('2d').drawImage(canvas, 0, 0);
    window.__lastShot = c;
    const url = c.toDataURL('image/jpeg', 0.88);
    await fetch(`/__shot?name=${encodeURIComponent(name)}`, { method: 'POST', body: url });
    return `${name}: ${c.width}x${c.height}`;
  };
  // Compare against a reference photo: render the ship broadside from far
  // away with a long lens (starboard side, bow to the right), then draw the
  // photo over it, scaled so its stern, bow and waterline land on ours.
  // ref = { url, sternPx, bowPx, wlPx } in the photo's own pixels.
  window.__compare = async (name, ref, { alpha = 0.5, W = 1600, H = 900, dist = 2600, mode = 'blend', cx = 0, cy = 22, span = 370 } = {}) => {
    const cam = app.camera;
    const fov0 = cam.fov;
    app.modes.set('drone');
    const d = app.modes.drone;
    d.pos.set(cx, cy, dist); d.yaw = -Math.PI / 2; d.pitch = 0;
    cam.fov = 2 * Math.atan((span / (W / H)) / 2 / dist) * 180 / Math.PI;
    cam.updateProjectionMatrix();
    await window.__shot(name + '_raw', 24, W, H);
    // The WebGPU canvas is cleared once presented: use the copy __shot kept.
    const gl = window.__lastShot;
    const out = document.createElement('canvas'); out.width = W; out.height = H;
    const g = out.getContext('2d');
    g.drawImage(gl, 0, 0, W, H);
    // Where our stern (waterline) and bow tip land on screen.
    const proj = (x, y) => { const v = new THREE.Vector3(x, y, 0).project(cam); return [(v.x + 1) / 2 * W, (1 - v.y) / 2 * H]; };
    const [sx0, sy0] = proj(-165.7, 0), [sx1] = proj(166.1, 0);
    const img = new Image(); img.crossOrigin = 'anonymous'; img.src = ref.url;
    await new Promise((r, e) => { img.onload = r; img.onerror = e; });
    const k = (sx1 - sx0) / (ref.bowPx - ref.sternPx);
    const ox = sx0 - ref.sternPx * k, oy = sy0 - ref.wlPx * k;
    if (mode === 'stack') {
      // Photo band on top, our render of the same band below, same scale.
      const top = proj(0, 80)[1] - 10, bot = sy0 + 25, bh = bot - top;
      out.height = Math.round(bh * 2 + 6);
      g.fillStyle = '#000'; g.fillRect(0, 0, W, out.height);
      g.drawImage(img, ox, oy - top, img.naturalWidth * k, img.naturalHeight * k);
      g.clearRect(0, bh, W, out.height - bh);
      g.fillRect(0, bh, W, 6);
      g.drawImage(gl, 0, top * gl.height / H, gl.width, bh * gl.height / H, 0, bh + 6, W, bh);
    } else {
      g.globalAlpha = alpha;
      g.drawImage(img, ox, oy, img.naturalWidth * k, img.naturalHeight * k);
    }
    cam.fov = fov0; cam.updateProjectionMatrix();
    await fetch(`/__shot?name=${encodeURIComponent(name)}`, { method: 'POST', body: out.toDataURL('image/jpeg', 0.9) });
    return { k, ox, oy };
  };
  // Put the walker somewhere (ship-local), or the drone at a world position looking at a target.
  window.__walk = (x, y, z, yaw = 0, pitch = 0) => { app.modes.set('walk'); app.modes.walker.place({ x, y, z, yaw, pitch }); };
  window.__fly = (px, py, pz, tx, ty, tz) => {
    app.modes.set('drone');
    const d = app.modes.drone;
    d.pos.set(px, py, pz);
    const dx = tx - px, dy = ty - py, dz = tz - pz;
    d.yaw = Math.atan2(dz, dx);
    d.pitch = Math.atan2(dy, Math.hypot(dx, dz));
  };
}
app.start().catch((e) => { console.error(e); fatal(String(e && e.stack || e)); });
