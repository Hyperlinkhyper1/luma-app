import * as THREE from 'three/webgpu';
import { Walker } from './walker.js';
import { settings } from '../core/settings.js';

// Play modes and the camera rig. Walking happens in ship space (so the
// deck rolls under you), the drone flies in world space, and the tender
// floats on the sea alongside the hull (see tender.js).

const _m = new THREE.Matrix4();
const _q = new THREE.Quaternion();
const _p = new THREE.Vector3();
const _s = new THREE.Vector3();
const _e = new THREE.Vector3();
const _t = new THREE.Vector3();
const UP = new THREE.Vector3(0, 1, 0);

export const MODES = ['walk', 'tender', 'drone'];
export const MODE_LABEL = { walk: 'WALK', tender: 'TENDER', drone: 'DRONE' };

function dirFrom(yaw, pitch, out) {
  return out.set(Math.cos(pitch) * Math.cos(yaw), Math.sin(pitch), Math.cos(pitch) * Math.sin(yaw));
}

export class Modes {
  constructor({ camera, shipRoot, collider, input, tender }) {
    this.camera = camera;
    this.shipRoot = shipRoot;
    this.input = input;
    this.walker = new Walker(collider);
    this.tender = tender;
    this.mode = 'walk';
    this.drone = { pos: new THREE.Vector3(-260, 60, 220), yaw: -0.7, pitch: -0.1, speed: 25 };
    this.viewLocal = new THREE.Vector3();
    this.onChange = null;
  }

  set(mode) {
    if (!MODES.includes(mode) || mode === this.mode) return;
    const prev = this.mode;
    this.mode = mode;
    if (mode === 'drone') {
      // Start the drone a little behind and above wherever we were looking from.
      _p.copy(this.camera.position);
      dirFrom(this._worldYaw(), 0, _e);
      this.drone.pos.copy(_p).addScaledVector(_e, -12).add(_t.set(0, 6, 0));
      this.drone.yaw = this._worldYaw();
      this.drone.pitch = -0.15;
    }
    if (mode === 'tender') this.tender?.enter(prev === 'walk' ? this.walker.pos : null);
    if (prev === 'tender') this.tender?.exit();
    this.onChange?.(mode);
  }

  next() { this.set(MODES[(MODES.indexOf(this.mode) + 1) % MODES.length]); }

  _worldYaw() {
    if (this.mode === 'drone') return this.drone.yaw;
    if (this.mode === 'tender') return this.tender?.view.yaw ?? 0;
    return this.walker.yaw;
  }

  update(dt) {
    const [dx, dy] = this.input.takeLook();
    const wheel = this.input.takeWheel();
    const c = settings.get().controls;
    if (this.mode === 'walk') {
      this.walker.look(dx, dy);
      this.walker.update(dt, this.input);
      this._rigWalk(c.rollCamera);
    } else if (this.mode === 'drone') {
      this._drone(dt, dx, dy, wheel);
    } else if (this.mode === 'tender' && this.tender) {
      this.tender.update(dt, this.input, dx, dy);
      this.tender.rig(this.camera, c.rollCamera);
      this.viewLocal.copy(this.camera.position);
    }
    this.camera.updateMatrixWorld(true);
  }

  _rigWalk(roll) {
    const w = this.walker;
    w.eye(_e);
    dirFrom(w.yaw, w.pitch, _t);
    _m.lookAt(_e, _t.add(_e), UP);
    _m.setPosition(_e);
    this.viewLocal.copy(_e);
    if (roll) {
      _m.premultiply(this.shipRoot.matrixWorld);
      _m.decompose(this.camera.position, this.camera.quaternion, _s);
    } else {
      // Position follows the ship; orientation stays level with the horizon.
      _p.copy(_e).applyMatrix4(this.shipRoot.matrixWorld);
      _m.decompose(_t, this.camera.quaternion, _s);
      this.camera.position.copy(_p);
    }
  }

  _drone(dt, dx, dy, wheel) {
    const d = this.drone;
    const c = settings.get().controls;
    const s = 0.0022 * c.sensitivity;
    d.yaw += dx * s;
    d.pitch = THREE.MathUtils.clamp(d.pitch - dy * s * (c.invertY ? -1 : 1), -1.5, 1.5);
    if (wheel) d.speed = THREE.MathUtils.clamp(d.speed * (wheel < 0 ? 1.25 : 0.8), 2, 400);
    const k = this.input;
    dirFrom(d.yaw, d.pitch, _e);
    const right = _t.set(-Math.sin(d.yaw), 0, Math.cos(d.yaw));
    const boost = k.down('ShiftLeft') || k.down('ShiftRight') ? 3 : 1;
    const v = d.speed * boost * dt;
    if (k.down('KeyW')) d.pos.addScaledVector(_e, v);
    if (k.down('KeyS')) d.pos.addScaledVector(_e, -v);
    if (k.down('KeyD')) d.pos.addScaledVector(right, v);
    if (k.down('KeyA')) d.pos.addScaledVector(right, -v);
    if (k.down('Space') || k.down('KeyE')) d.pos.y += v;
    if (k.down('KeyQ') || k.down('ControlLeft')) d.pos.y -= v;
    d.pos.y = THREE.MathUtils.clamp(d.pos.y, 1.2, 2500);
    this.camera.position.copy(d.pos);
    dirFrom(d.yaw, d.pitch, _e);
    _m.lookAt(d.pos, _t.copy(d.pos).add(_e), UP);
    this.camera.quaternion.setFromRotationMatrix(_m);
    // ship-local view position (for lamps): inverse ship matrix
    this.viewLocal.copy(d.pos).applyMatrix4(_m.copy(this.shipRoot.matrixWorld).invert());
  }
}
