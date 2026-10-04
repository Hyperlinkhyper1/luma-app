import * as THREE from 'three/webgpu';
import { settings } from '../core/settings.js';

// First-person walking, in ship-local coordinates: a capsule slides against
// the ship's collider BVH (three-mesh-bvh shapecast, as in its character
// controller example). The ship's roll and pitch are applied afterwards by
// the camera rig, so you walk on a deck that moves under you.
//
// Yaw: 0 faces the bow, +pi/2 faces starboard.

const GRAVITY = 18;
const RADIUS = 0.3;
const HEIGHT = 1.74;
const EYE = 1.63;
const WALK = 1.5, RUN = 3.6, CROUCH = 0.75;

const _seg = new THREE.Line3();
const _box = new THREE.Box3();
const _tri = new THREE.Vector3();
const _cap = new THREE.Vector3();
const _v = new THREE.Vector3();
const _d = new THREE.Vector3();

export class Walker {
  constructor(collider) {
    this.cols = [collider];
    this.pos = new THREE.Vector3();      // feet
    this.vel = new THREE.Vector3();
    this.yaw = 0;
    this.pitch = 0;
    this.onGround = false;
    this.crouch = 0;
    this.bob = 0;
    this.stepPhase = 0;
    this.speedNow = 0;
    this.onStep = null;                   // callback for footstep sounds
  }

  place(spot) {
    this.pos.set(spot.x, spot.y + 0.05, spot.z);
    this.vel.set(0, 0, 0);
    this.yaw = spot.yaw ?? 0;
    this.pitch = spot.pitch ?? 0;
  }

  look(dx, dy) {
    const c = settings.get().controls;
    const s = 0.0022 * c.sensitivity;
    this.yaw += dx * s;
    this.pitch -= dy * s * (c.invertY ? -1 : 1);
    this.pitch = THREE.MathUtils.clamp(this.pitch, -1.5, 1.5);
  }

  update(dt, input) {
    const k = input;
    const fwd = (k.down('KeyW') || k.down('ArrowUp') ? 1 : 0) - (k.down('KeyS') || k.down('ArrowDown') ? 1 : 0);
    const str = (k.down('KeyD') || k.down('ArrowRight') ? 1 : 0) - (k.down('KeyA') || k.down('ArrowLeft') ? 1 : 0);
    const crouching = k.down('ControlLeft') || k.down('KeyC');
    this.crouch += ((crouching ? 1 : 0) - this.crouch) * Math.min(1, dt * 10);
    const speed = crouching ? CROUCH : (k.down('ShiftLeft') || k.down('ShiftRight') ? RUN : WALK);
    const cy = Math.cos(this.yaw), sy = Math.sin(this.yaw);
    _d.set(cy * fwd - sy * str, 0, sy * fwd + cy * str);
    if (_d.lengthSq() > 1) _d.normalize();
    const target = _d.multiplyScalar(speed);
    // Snappy but not instant acceleration; less control in the air.
    const accel = this.onGround ? 12 : 2;
    this.vel.x += (target.x - this.vel.x) * Math.min(1, dt * accel);
    this.vel.z += (target.z - this.vel.z) * Math.min(1, dt * accel);
    if (this.onGround && k.down('Space') && !this._jumpHeld) { this.vel.y = 4.2; this.onGround = false; }
    this._jumpHeld = k.down('Space');
    this.vel.y -= GRAVITY * dt;

    // Substeps keep fast falls and stairs stable.
    const steps = Math.max(1, Math.ceil(dt / (1 / 120)));
    const h = dt / steps;
    let grounded = false;
    for (let i = 0; i < steps; i++) grounded = this._move(h) || grounded;
    this.onGround = grounded;
    // Over the side into the sea (or off the quay): back on deck.
    if (this.pos.y < 0.3) this.respawn?.();

    // Head bob from horizontal speed.
    const hs = Math.hypot(this.vel.x, this.vel.z);
    this.speedNow = hs;
    if (this.onGround && hs > 0.2) {
      const prev = this.stepPhase;
      this.stepPhase += dt * (1.6 + hs * 0.95);
      if (Math.floor(prev / Math.PI) !== Math.floor(this.stepPhase / Math.PI)) this.onStep?.(hs);
    }
    const bobAmt = settings.get().controls.headBob ? Math.min(1, hs / RUN) : 0;
    this.bob = Math.sin(this.stepPhase * 2) * 0.035 * bobAmt;
  }

  _move(dt) {
    this.pos.addScaledVector(this.vel, dt);
    const r = RADIUS;
    const top = HEIGHT - this.crouch * 0.6 - r;
    _seg.start.set(this.pos.x, this.pos.y + r, this.pos.z);
    _seg.end.set(this.pos.x, this.pos.y + top, this.pos.z);
    _box.makeEmpty();
    _box.expandByPoint(_seg.start);
    _box.expandByPoint(_seg.end);
    _box.min.addScalar(-r);
    _box.max.addScalar(r);
    // The ship, plus the quay when moored (in port the ship frame is the world).
    for (const c of this.cols) {
      if (!c.enabled) continue;
      c.bvh.shapecast({
        intersectsBounds: (box) => box.intersectsBox(_box),
        intersectsTriangle: (tri) => {
          const dist = tri.closestPointToSegment(_seg, _tri, _cap);
          if (dist < r) {
            const depth = r - dist;
            const dir = _cap.sub(_tri).normalize();
            _seg.start.addScaledVector(dir, depth);
            _seg.end.addScaledVector(dir, depth);
          }
        },
      });
    }
    _v.set(_seg.start.x, _seg.start.y - r, _seg.start.z).sub(this.pos);
    const grounded = _v.y > Math.abs(dt * this.vel.y * 0.25);
    const offset = Math.max(0, _v.length() - 1e-5);
    _v.normalize().multiplyScalar(offset);
    this.pos.add(_v);
    if (!grounded) {
      _v.normalize();
      this.vel.addScaledVector(_v, -_v.dot(this.vel));
    } else {
      this.vel.y = 0;
    }
    return grounded;
  }

  /** Eye position in ship-local space. */
  eye(out) {
    return out.set(this.pos.x, this.pos.y + EYE - this.crouch * 0.6 + this.bob, this.pos.z);
  }
}
