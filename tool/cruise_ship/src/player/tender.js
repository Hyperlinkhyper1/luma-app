import * as THREE from 'three/webgpu';
import { boatParts, boatHullMaterial, BOAT } from '../ship/lifeboat.js';
import { hullHalf } from '../ship/dims.js';
import { settings } from '../core/settings.js';

// The tender: an orange boat at sea level beside the hull, the closest
// thing to standing on the pier in the reference photos and looking up a
// sixty-metre white wall. You ride in the raised conning hatch.
//
// It lives in the ship frame, so while the ship is under way it keeps pace
// (the sea streams past); W/S throttle, A/D steer, R returns to station.
// It floats on the same Gerstner waves as the rendered sea.

const _m = new THREE.Matrix4();
const _q = new THREE.Quaternion();
const _e = new THREE.Euler();
const _v = new THREE.Vector3();
const _t = new THREE.Vector3();
const UP = new THREE.Vector3(0, 1, 0);

export class Tender {
  constructor(scene, ocean, materials) {
    this.ocean = ocean;
    this.group = new THREE.Group();
    this.group.name = 'tender';
    const parts = boatParts(true);
    const mats = { hull: boatHullMaterial(), canopy: materials.boatOrange, fender: materials.rubber, windows: materials.boatWindow, tower: materials.boatOrange, towerGlass: materials.boatWindow, hardware: materials.steelDark };
    for (const [k, g] of Object.entries(parts)) {
      const m = new THREE.Mesh(g, mats[k]);
      m.castShadow = k !== 'towerGlass';
      m.receiveShadow = true;
      this.group.add(m);
    }
    // Open hatch in the conning tower roof, so the view down isn't solid orange.
    this.group.visible = false;
    scene.add(this.group);
    this.station = { x: 6, z: 46, heading: 0 };
    this.pos = new THREE.Vector2(this.station.x, this.station.z);
    this.heading = 0;
    this.speed = 0;
    this.throttle = 0;
    this.turn = 0;
    this.view = { yaw: -0.9, pitch: 0.42 };     // relative to the boat; starts looking up at the ship
    this.att = { roll: 0, pitch: 0, y: 0 };
    this.active = false;
  }

  enter(fromLocal) {
    this.active = true;
    this.group.visible = true;
    // Launch on the side you were standing on (in port, the open water side).
    const port = settings.get().sea.location === 'port';
    const side = port || (fromLocal && fromLocal.z < 0) ? -1 : 1;
    this.station = { x: fromLocal ? THREE.MathUtils.clamp(fromLocal.x, -120, 110) : 6, z: side * 46, heading: 0 };
    this.pos.set(this.station.x, this.station.z);
    this.heading = 0;
    this.speed = 0;
    this.view.yaw = side > 0 ? -1.15 : 1.15;
    this.view.pitch = 0.45;
  }

  exit() { this.active = false; this.group.visible = false; }

  update(dt, input, dx, dy) {
    const c = settings.get().controls;
    const s = 0.0022 * c.sensitivity;
    this.view.yaw += dx * s;
    this.view.pitch = THREE.MathUtils.clamp(this.view.pitch - dy * s * (c.invertY ? -1 : 1), -1.2, 1.45);

    const thr = (input.down('KeyW') ? 1 : 0) - (input.down('KeyS') ? 1 : 0);
    const steer = (input.down('KeyD') ? 1 : 0) - (input.down('KeyA') ? 1 : 0);
    if (input.down('KeyR')) {
      // Back to station: steer toward it gently.
      const tx = this.station.x - this.pos.x, tz = this.station.z - this.pos.y;
      this.pos.x += tx * Math.min(1, dt * 0.6);
      this.pos.y += tz * Math.min(1, dt * 0.6);
      this.heading += (0 - this.heading) * Math.min(1, dt);
      this.speed *= 1 - Math.min(1, dt * 2);
    }
    this.speed += (thr * 7.5 - this.speed) * Math.min(1, dt * (thr ? 0.45 : 0.3));
    const turnRate = steer * (0.12 + Math.min(1, Math.abs(this.speed) / 4) * 0.28);
    this.heading += turnRate * dt * (this.speed < -0.2 ? -1 : 1);
    this.pos.x += Math.cos(this.heading) * this.speed * dt;
    this.pos.y += Math.sin(this.heading) * this.speed * dt;

    // Keep clear of the hull (with fenders' worth of margin) and the ends.
    const hh = hullHalf(this.pos.x, 0.5) + 4.5;
    if (Math.abs(this.pos.y) < hh && this.pos.x > -172 && this.pos.x < 172) {
      this.pos.y = Math.sign(this.pos.y || 1) * hh;
      this.speed *= 0.6;
    }
    // In port the starboard side is the quay.
    if (settings.get().sea.location === 'port' && this.pos.x > -425 && this.pos.x < 435 && this.pos.y > -26) {
      if (this.pos.y > 0 || Math.abs(this.pos.x) > 172) this.pos.y = Math.min(this.pos.y, 22.6);
      if (Math.abs(this.pos.x) > 172 && this.pos.y > 21) { this.pos.y = 21; this.speed *= 0.5; }
    }
    const r = Math.hypot(this.pos.x, this.pos.y);
    if (r > 1400) this.pos.multiplyScalar(1400 / r);

    // Float: heave, pitch and roll from the waves under the boat, quick to respond.
    const ch = Math.cos(this.heading), sh = Math.sin(this.heading);
    const L2 = BOAT.L * 0.4, B2 = BOAT.B * 0.5;
    const h0 = this.ocean.heightAt(this.pos.x, this.pos.y);
    const hb = this.ocean.heightAt(this.pos.x + ch * L2, this.pos.y + sh * L2);
    const hs = this.ocean.heightAt(this.pos.x - ch * L2, this.pos.y - sh * L2);
    const hp = this.ocean.heightAt(this.pos.x + sh * B2, this.pos.y - ch * B2);
    const hst = this.ocean.heightAt(this.pos.x - sh * B2, this.pos.y + ch * B2);
    const k = Math.min(1, dt * 2.5);
    this.att.y += ((h0 + hb + hs) / 3 - this.att.y) * k;
    this.att.pitch += (Math.atan2(hb - hs, 2 * L2) - this.att.pitch) * k;
    this.att.roll += (Math.atan2(hst - hp, 2 * B2) * 0.8 - this.att.roll) * k;

    // Boat transform (world = ship frame; the ship barely moves in its own frame).
    const draftY = -0.7;
    _e.set(this.att.roll, -this.heading, this.att.pitch, 'YXZ');
    _q.setFromEuler(_e);
    this.group.position.set(this.pos.x, this.att.y + draftY, this.pos.y);
    this.group.quaternion.copy(_q);
    this.group.updateMatrixWorld(true);
  }

  /** Camera in the conning hatch, looking where the mouse says. */
  rig(camera, roll) {
    _v.set(-0.2 * BOAT.L + 0.6, BOAT.hull + BOAT.canopy + 1.05, 0).applyMatrix4(this.group.matrixWorld);
    const yaw = this.heading + this.view.yaw;
    const p = this.view.pitch;
    _t.set(Math.cos(p) * Math.cos(yaw), Math.sin(p), Math.cos(p) * Math.sin(yaw));
    _m.lookAt(_v, _t.add(_v), UP);
    camera.position.copy(_v);
    camera.quaternion.setFromRotationMatrix(_m);
    if (roll) {
      // Add the boat's roll and pitch to the view.
      _q.setFromEuler(_e.set(this.att.roll * 0.8, 0, this.att.pitch * 0.8));
      camera.quaternion.premultiply(_q);
    }
  }
}
