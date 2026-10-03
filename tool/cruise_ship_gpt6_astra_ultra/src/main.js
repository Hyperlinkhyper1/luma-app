import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { SSAOPass } from 'three/addons/postprocessing/SSAOPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import { ShaderPass } from 'three/addons/postprocessing/ShaderPass.js';
import { FXAAShader } from 'three/addons/shaders/FXAAShader.js';
import { buildShip } from './ship.js';
import { createEnvironment } from './environment.js';
import { CruiseAudio } from './audio.js';
import { Navigator } from './navigation.js';
import { captureMouse, sendHostMessage } from './host.js';

const $ = id => document.getElementById(id);
const DEFAULTS = { hour: 16.5, paused: false, dayLength: 24, weather: 'auto', lightning: true, quality: 'high', resolution: 1, fov: 70, volume: .55, headBob: false, cameraRoll: true, showFps: false };
const STORAGE = 'luma.cruise_ship.gpt6_astra_ultra.v1';
const settings = { ...DEFAULTS };
const choices = { weather: ['auto', 'clear', 'overcast', 'fog', 'rain', 'storm'], quality: ['low', 'medium', 'high', 'ultra'] };
const ranges = { hour: [0, 23.99], dayLength: [1, 1440], resolution: [.5, 1.5], fov: [50, 95], volume: [0, 1] };
try {
  const saved = JSON.parse(localStorage.getItem(STORAGE) || '{}');
  for (const k of Object.keys(DEFAULTS)) {
    const v = saved[k];
    if (typeof v !== typeof DEFAULTS[k]) continue;
    if (choices[k] && !choices[k].includes(v)) continue;
    if (ranges[k] && (!Number.isFinite(v) || v < ranges[k][0] || v > ranges[k][1])) continue;
    settings[k] = v;
  }
} catch {}
const save = () => { try { localStorage.setItem(STORAGE, JSON.stringify(settings)); } catch {} };
const bridge = sendHostMessage;
let failed = false;
function fatal(error) {
  if (failed) return;
  failed = true;
  const message = error?.message || String(error);
  $('loading').hidden = $('welcome').hidden = $('settings').hidden = $('map').hidden = true;
  $('errorText').textContent = message;
  $('error').hidden = false;
  document.exitPointerLock?.();
  bridge({ type: 'cruise-error', message });
  if (window.cruiseDebug) window.cruiseDebug.error = message;
}
addEventListener('error', e => fatal(e.error || e.message));
addEventListener('unhandledrejection', e => fatal(e.reason));
$('retry').onclick = () => location.reload();
window.cruiseDebug = { ready: false, error: null };

async function boot() {
  const canvas = $('scene');
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: false, powerPreference: 'high-performance' });
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.12;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFShadowMap;
  renderer.info.autoReset = false;
  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(settings.fov, innerWidth / innerHeight, .12, 18000);
  $('progress').textContent = 'Building decks, lifeboats and the skyline…';
  await new Promise(r => setTimeout(r, 30));
  const ship = buildShip();
  scene.add(ship.root);
  const navigator = new Navigator(ship.surfaces, ship.obstacles);
  const first = ship.spots.find(s => s.id === 'deck7-starboard') || ship.spots[0];
  if (!first || !navigator.place(first)) throw new Error('The deck 7 boarding location has no safe walking surface.');
  let yaw = first.yaw ?? 0;
  let pitch = first.pitch ?? .12;
  let mode = 'walk';
  let boarded = false;
  let uiOpen = false;
  let elapsed = 0;
  let autoElapsed = 0;
  let autoIndex = 0;
  let speed = 0;
  let crouch = 0;
  const weatherSequence = ['clear', 'overcast', 'rain', 'fog', 'clear', 'storm'];
  const keys = new Set();
  const free = new THREE.Vector3(-190, 33, 140);
  const tender = { x: -35, z: 74, heading: .25, speed: 0 };
  let savedLook = { yaw, pitch };
  const environment = createEnvironment(scene, renderer, camera);
  const audio = new CruiseAudio();
  audio.setVolume(settings.volume);
  const composer = new EffectComposer(renderer);
  composer.addPass(new RenderPass(scene, camera));
  const ao = new SSAOPass(scene, camera, innerWidth, innerHeight, 12);
  ao.kernelRadius = 2.2;
  ao.minDistance = .001;
  ao.maxDistance = .16;
  composer.addPass(ao);
  const bloom = new UnrealBloomPass(new THREE.Vector2(innerWidth, innerHeight), .16, .35, 1.35);
  composer.addPass(bloom);
  composer.addPass(new OutputPass());
  const antialias = new ShaderPass(FXAAShader);
  composer.addPass(antialias);

  const tenderRoot = new THREE.Group();
  const tenderHull = new THREE.Mesh(new THREE.CapsuleGeometry(1.65, 5, 5, 16), new THREE.MeshStandardMaterial({ color: 0xe9e4d9, roughness: .45 }));
  tenderHull.rotation.z = Math.PI / 2;
  tenderHull.scale.z = .75;
  tenderHull.position.y = -.8;
  tenderRoot.add(tenderHull);
  const rim = new THREE.Mesh(new THREE.BoxGeometry(6.5, .7, 2.4), new THREE.MeshStandardMaterial({ color: 0xc96627, roughness: .55 }));
  rim.position.y = .2;
  tenderRoot.add(rim);
  const boatFloor = new THREE.Mesh(new THREE.BoxGeometry(5.8, .1, 1.95), new THREE.MeshStandardMaterial({ color: 0x6e7472, roughness: .9 }));
  boatFloor.position.y = .65;
  tenderRoot.add(boatFloor);
  for (const x of [-1.8, .3]) {
    const seat = new THREE.Mesh(new THREE.BoxGeometry(.65, .25, 1.85), new THREE.MeshStandardMaterial({ color: 0xe9e4d9 }));
    seat.position.set(x, .95, 0);
    tenderRoot.add(seat);
  }
  tenderRoot.visible = false;
  scene.add(tenderRoot);

  const target = new THREE.Vector3();
  const eye = new THREE.Vector3();
  const dir = new THREE.Vector3();
  const clockText = () => `${String(Math.floor(settings.hour)).padStart(2, '0')}:${String(Math.floor(settings.hour % 1 * 60)).padStart(2, '0')}`;
  const weatherNow = () => settings.weather === 'auto' ? weatherSequence[autoIndex % weatherSequence.length] : settings.weather;

  function resize() {
    if (innerWidth < 2 || innerHeight < 2) return;
    camera.aspect = innerWidth / innerHeight;
    camera.fov = settings.fov;
    camera.updateProjectionMatrix();
    const cap = settings.quality === 'ultra' ? 2 : 1.5;
    const presetScale = settings.quality === 'low' ? .7 : settings.quality === 'medium' ? .85 : 1;
    renderer.setPixelRatio(Math.min(devicePixelRatio || 1, cap) * settings.resolution * presetScale);
    renderer.setSize(innerWidth, innerHeight);
    composer.setPixelRatio(renderer.getPixelRatio());
    composer.setSize(innerWidth, innerHeight);
    antialias.uniforms.resolution.value.set(1 / (innerWidth * renderer.getPixelRatio()), 1 / (innerHeight * renderer.getPixelRatio()));
    ao.enabled = settings.quality === 'high' || settings.quality === 'ultra';
    bloom.enabled = settings.quality !== 'low';
    renderer.shadowMap.enabled = settings.quality !== 'low';
    $('fps').hidden = !settings.showFps;
  }

  function syncSettings() {
    for (const [k, v] of Object.entries(settings)) {
      const el = $(k);
      if (!el) continue;
      if (el.type === 'checkbox') el.checked = v;
      else el.value = v;
    }
    $('hourOutput').textContent = clockText();
    $('resolutionOutput').textContent = `${Math.round(settings.resolution * 100)}%`;
    $('fovOutput').textContent = `${settings.fov}°`;
    audio.setVolume(settings.volume);
    resize();
  }

  function closeUI(lock = false) {
    $('settings').hidden = $('map').hidden = true;
    uiOpen = false;
    keys.clear();
    if (lock && boarded) lockMouse();
  }

  function openUI(which) {
    if (!boarded) return;
    document.exitPointerLock?.();
    keys.clear();
    uiOpen = true;
    $('settings').hidden = which !== 'settings';
    $('map').hidden = which !== 'map';
    if (which === 'settings') syncSettings();
  }

  function lockMouse() {
    if (uiOpen || !boarded) return;
    captureMouse(canvas, () => { $('hint').textContent = 'Click the scene to capture the mouse · Drag to look if capture is unavailable'; });
  }

  function setMode(next) {
    if (!['walk', 'tender', 'free'].includes(next)) return false;
    if (mode === 'walk' && next !== 'walk') savedLook = { yaw, pitch };
    if (next === 'walk') { yaw = savedLook.yaw; pitch = savedLook.pitch; }
    if (next === 'tender' && mode !== 'tender') { yaw = -Math.PI / 2; pitch = .24; }
    if (next === 'free' && mode !== 'free') { yaw = -.64; pitch = -.1; }
    mode = next;
    keys.clear();
    tenderRoot.visible = mode === 'tender';
    return true;
  }

  function teleport(id) {
    const spot = ship.spots.find(s => s.id === id);
    if (!spot || !navigator.place(spot)) return false;
    setMode('walk');
    yaw = spot.yaw ?? 0;
    pitch = spot.pitch ?? .05;
    savedLook = { yaw, pitch };
    closeUI(true);
    return true;
  }

  function movePlayer(dt) {
    speed = 0;
    if (!boarded || uiOpen) return;
    const forward = (keys.has('KeyW') || keys.has('ArrowUp') ? 1 : 0) - (keys.has('KeyS') || keys.has('ArrowDown') ? 1 : 0);
    const side = (keys.has('KeyD') || keys.has('ArrowRight') ? 1 : 0) - (keys.has('KeyA') || keys.has('ArrowLeft') ? 1 : 0);
    const fast = keys.has('ShiftLeft') || keys.has('ShiftRight');
    if (mode === 'tender') {
      tender.speed += (forward * (fast ? 12 : 5) - tender.speed) * Math.min(1, dt * 1.2);
      tender.heading += side * dt * .48;
      const nx = tender.x + Math.cos(tender.heading) * tender.speed * dt;
      const nz = tender.z + Math.sin(tender.heading) * tender.speed * dt;
      const hullDistance = Math.pow(nx / 181, 6) + Math.pow(nz / 29, 2);
      if (hullDistance >= 1 && Math.hypot(nx, nz) < 1600) { tender.x = nx; tender.z = nz; }
      else tender.speed *= -.2;
      speed = Math.abs(tender.speed);
      return;
    }
    const diagonal = Math.hypot(forward, side) || 1;
    const crouching = keys.has('KeyC') || keys.has('ControlLeft');
    crouch += ((crouching && mode === 'walk' ? .62 : 0) - crouch) * Math.min(1, dt * 9);
    const walkSpeed = mode === 'free' ? (fast ? 65 : 18) : crouching ? .85 : fast ? 3.5 : 1.55;
    const dx = (Math.cos(yaw) * forward - Math.sin(yaw) * side) / diagonal * walkSpeed * dt;
    const dz = (Math.sin(yaw) * forward + Math.cos(yaw) * side) / diagonal * walkSpeed * dt;
    if (mode === 'walk') {
      navigator.height = 1.72 - crouch;
      speed = navigator.move(dx, dz) / Math.max(dt, .001);
    } else {
      free.x += dx;
      free.z += dz;
      free.y += ((keys.has('KeyE') ? 1 : 0) - (keys.has('KeyQ') ? 1 : 0)) * walkSpeed * dt;
      free.y = THREE.MathUtils.clamp(free.y, .8, 900);
      free.x = THREE.MathUtils.clamp(free.x, -3000, 3000);
      free.z = THREE.MathUtils.clamp(free.z, -3000, 3000);
    }
  }

  function placeCamera() {
    const roll = settings.cameraRoll ? Math.sin(elapsed * .19) * (.0014 + environment.storm * .0025) : 0;
    const tilt = settings.cameraRoll ? Math.sin(elapsed * .13) * .0009 : 0;
    ship.root.rotation.set(0, 0, roll);
    ship.root.rotation.x = tilt;
    ship.root.updateMatrixWorld(true);
    if (mode === 'walk') {
      const p = navigator.position;
      const bob = settings.headBob && speed > .2 ? Math.sin(navigator.distance * 8) * .02 : 0;
      eye.set(p.x, p.y + 1.7 - crouch + bob, p.z);
      dir.set(Math.cos(yaw) * Math.cos(pitch), Math.sin(pitch), Math.sin(yaw) * Math.cos(pitch));
      target.copy(eye).add(dir);
      ship.root.localToWorld(eye);
      ship.root.localToWorld(target);
      camera.up.set(0, 1, 0).applyQuaternion(ship.root.quaternion);
    } else if (mode === 'tender') {
      const water = environment.seaHeight(tender.x, tender.z);
      tenderRoot.position.set(tender.x, water, tender.z);
      tenderRoot.rotation.set(Math.sin(elapsed * .9) * .025, -tender.heading, Math.sin(elapsed * .7) * .02);
      eye.set(tender.x, water + 2.15, tender.z);
      dir.set(Math.cos(yaw) * Math.cos(pitch), Math.sin(pitch), Math.sin(yaw) * Math.cos(pitch));
      target.copy(eye).add(dir);
      camera.up.set(0, 1, 0);
    } else {
      eye.copy(free);
      dir.set(Math.cos(yaw) * Math.cos(pitch), Math.sin(pitch), Math.sin(yaw) * Math.cos(pitch));
      target.copy(eye).add(dir);
      camera.up.set(0, 1, 0);
    }
    camera.position.copy(eye);
    camera.lookAt(target);
  }

  let dragging = false;
  canvas.addEventListener('pointerdown', e => { if (e.button === 0) { dragging = true; lockMouse(); } });
  addEventListener('pointerup', () => { dragging = false; });
  addEventListener('pointermove', e => {
    if (!boarded || uiOpen || (document.pointerLockElement !== canvas && !dragging)) return;
    yaw += e.movementX * .002;
    pitch = THREE.MathUtils.clamp(pitch - e.movementY * .002, -1.48, 1.48);
  });
  addEventListener('pointerlockchange', () => {
    $('hint').textContent = document.pointerLockElement === canvas ? '' : 'Click to look around · Drag if mouse lock is unavailable';
  });
  addEventListener('keydown', e => {
    if (!boarded) return;
    if (e.code === 'Escape') { e.preventDefault(); if (uiOpen) closeUI(); else openUI('settings'); return; }
    if (uiOpen) return;
    if (['Tab', 'Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.code)) e.preventDefault();
    keys.add(e.code);
    if (e.repeat) return;
    if (e.code === 'KeyM') openUI('map');
    if (e.code === 'KeyV') setMode(['walk', 'tender', 'free'][(['walk', 'tender', 'free'].indexOf(mode) + 1) % 3]);
    if (e.code === 'KeyF') document.body.classList.toggle('cinematic');
    if (e.code === 'KeyE' && mode === 'walk') openUI('map');
  });
  addEventListener('keyup', e => keys.delete(e.code));
  addEventListener('blur', () => { keys.clear(); dragging = false; tender.speed = 0; });
  document.addEventListener('visibilitychange', () => { keys.clear(); audio.setMuted(document.hidden); });
  canvas.addEventListener('webglcontextlost', e => { e.preventDefault(); fatal('The graphics device was interrupted. Reload the scene to restore it.'); });
  addEventListener('resize', resize);
  $('board').onclick = async () => {
    boarded = true;
    $('welcome').hidden = true;
    $('hud').hidden = false;
    lockMouse();
    try { await audio.start(); } catch {}
  };
  $('menuButton').onclick = () => openUI('settings');
  $('mapButton').onclick = () => openUI('map');
  $('modeButton').onclick = () => setMode(['walk', 'tender', 'free'][(['walk', 'tender', 'free'].indexOf(mode) + 1) % 3]);
  document.querySelectorAll('[data-close]').forEach(b => { b.onclick = () => closeUI(true); });
  document.querySelectorAll('[data-mode]').forEach(b => { b.onclick = () => { setMode(b.dataset.mode); closeUI(true); }; });
  for (const spot of ship.spots) {
    if (spot.id.startsWith('stairs-')) continue;
    const b = document.createElement('button');
    const label = document.createElement('span');
    label.textContent = spot.label;
    const deck = document.createElement('small');
    deck.textContent = `DECK ${spot.deck}`;
    b.append(label, deck);
    b.onclick = () => teleport(spot.id);
    $('destinations').append(b);
  }
  for (const k of Object.keys(DEFAULTS)) {
    $(k)?.addEventListener('input', e => {
      settings[k] = e.target.type === 'checkbox' ? e.target.checked : typeof DEFAULTS[k] === 'number' ? Number(e.target.value) : e.target.value;
      save();
      if (k !== 'hour') syncSettings();
      else $('hourOutput').textContent = clockText();
    });
  }
  $('reset').onclick = () => { Object.assign(settings, DEFAULTS); save(); syncSettings(); };

  const frameTimes = [];
  let last = performance.now();
  let hudElapsed = 0;
  function step(dt) {
    elapsed += dt;
    if (!settings.paused) settings.hour = (settings.hour + dt * 24 / (settings.dayLength * 60)) % 24;
    autoElapsed += dt;
    if (autoElapsed > 150) { autoIndex++; autoElapsed = 0; }
    movePlayer(dt);
    placeCamera();
    environment.update(dt, { hour: settings.hour, weather: weatherNow(), quality: settings.quality, lightning: settings.lightning });
    ship.setNight(environment.night || 0);
    ship.setWet(environment.wet || 0);
    audio.update(dt, { mode, speed, night: environment.night || 0, wet: environment.wet || 0, storm: environment.storm || 0, flash: environment.flash || 0 });
    hudElapsed += dt;
    if (hudElapsed > .2) {
      hudElapsed = 0;
      $('timeLabel').textContent = clockText();
      $('weatherLabel').textContent = weatherNow().toUpperCase();
      $('modeLabel').textContent = { walk: 'ON FOOT', tender: 'TENDER / SEA LEVEL', free: 'FREE CAMERA' }[mode];
      const s = navigator.surface;
      const deck = s?.deck || 7;
      $('deckLabel').textContent = mode === 'walk' ? `DECK ${deck} · ${navigator.position.z >= 0 ? 'STARBOARD' : 'PORT'}` : 'MSC VIRTUOSA · OPEN SEA';
      $('placeLabel').textContent = mode === 'tender' ? 'Beneath the skyline' : mode === 'free' ? 'A ship without horizons' : deck === 7 ? 'Lifeboat promenade' : deck >= 18 ? 'Above the ocean' : 'The upper decks';
      if (settings.showFps && frameTimes.length) {
        const ms = frameTimes.reduce((a, b) => a + b) / frameTimes.length;
        $('fps').textContent = `${Math.round(1000 / ms)} FPS · ${ms.toFixed(1)} ms\n${renderer.info.render.calls} draws · ${(renderer.info.render.triangles / 1000).toFixed(0)}k triangles`;
      }
    }
  }
  function frame(now) {
    if (failed) return;
    const raw = now - last;
    last = now;
    const dt = Math.min(.05, Math.max(.001, raw / 1000));
    if (!document.hidden) {
      if (raw < 1000 && raw > 0) { frameTimes.push(raw); if (frameTimes.length > 300) frameTimes.shift(); }
      try { step(dt); renderer.info.reset(); composer.render(); } catch (error) { fatal(error); return; }
    }
    requestAnimationFrame(frame);
  }
  const gl = renderer.getContext();
  const debugInfo = gl.getExtension('WEBGL_debug_renderer_info');
  Object.assign(window.cruiseDebug, {
    identity: { id: 'cruise_ship_gpt6_astra_ultra', model: 'GPT 6 Astra (Ultra)', kind: 'cruise_ship' },
    renderer: debugInfo ? gl.getParameter(debugInfo.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER),
    setTime(hour) { settings.hour = ((Number(hour) % 24) + 24) % 24; settings.paused = true; syncSettings(); },
    setWeather(weather) { if (weather === 'thunderstorm') weather = 'storm'; if (!choices.weather.includes(weather)) return false; settings.weather = weather; environment.update(120, { hour: settings.hour, weather: weatherNow(), quality: settings.quality, lightning: settings.lightning }); return true; },
    setView(view) { if (ship.spots.some(s => s.id === view)) return teleport(view); return setMode(view); },
    teleport,
    setCamera({ x, y, z, yaw: a = yaw, pitch: b = pitch }) { setMode('free'); free.set(x, y, z); yaw = a; pitch = b; placeCamera(); },
    hideUI(hidden = true) { document.body.classList.toggle('cinematic', hidden); $('welcome').hidden = true; closeUI(); },
    start() { boarded = true; $('welcome').hidden = true; $('hud').hidden = false; },
    setKey(key, down) { if (down) keys.add(key); else keys.delete(key); },
    advance(seconds) { for (let t = 0; t < seconds; t += 1 / 60) step(Math.min(1 / 60, seconds - t)); composer.render(); },
    move(dx, dz) { return navigator.move(dx, dz); },
    stats() { const sorted = [...frameTimes].sort((a, b) => a - b); return { mode, position: { ...navigator.position }, camera: camera.position.toArray(), deck: navigator.surface?.deck, hour: settings.hour, weather: weatherNow(), quality: settings.quality, audio: audio.context?.state || 'inactive', pointerLocked: document.pointerLockElement === canvas, samples: sorted.length, fps: sorted.length ? 1000 / (sorted.reduce((a, b) => a + b) / sorted.length) : 0, p95ms: sorted[Math.floor(sorted.length * .95)] || 0, calls: renderer.info.render.calls, triangles: renderer.info.render.triangles, surfaces: ship.surfaces.length, obstacles: ship.obstacles.length, size: [canvas.width, canvas.height] }; },
    resetStats() { frameTimes.length = 0; },
    navigation: { surfaces: ship.surfaces, obstacles: ship.obstacles, spots: ship.spots },
    validateSpawns() { const old = { ...navigator.position }; const current = navigator.surface; const results = ship.spots.map(s => ({ id: s.id, valid: navigator.place(s) })); navigator.position = old; navigator.surface = current; return results; },
    simulateContextLoss() { gl.getExtension('WEBGL_lose_context')?.loseContext(); },
  });
  syncSettings();
  $('progress').textContent = 'Lighting the promenade…';
  await new Promise(r => setTimeout(r, 30));
  placeCamera();
  environment.update(120, { hour: settings.hour, weather: weatherNow(), quality: settings.quality, lightning: false });
  step(.001);
  composer.render();
  window.cruiseDebug.ready = true;
  $('loading').hidden = true;
  $('welcome').hidden = false;
  bridge({ type: 'cruise-ready' });
  last = performance.now();
  requestAnimationFrame(frame);
}
boot().catch(fatal);
