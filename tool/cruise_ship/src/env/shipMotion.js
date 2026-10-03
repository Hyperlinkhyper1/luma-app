import * as THREE from 'three/webgpu';

// The ship's response to the sea: heave, pitch and roll from the actual
// wave field sampled along the hull, filtered through a damped spring with
// the long natural periods of a 180,000 GT ship and her fin stabilisers.
// In a calm sea it is barely perceptible; in a storm the horizon swings.

export class ShipMotion {
  constructor(ocean) {
    this.ocean = ocean;
    this.state = { roll: 0, pitch: 0, heave: 0 };
    this.vel = { roll: 0, pitch: 0, heave: 0 };
  }

  update(dt, port, t) {
    const o = this.ocean;
    let tRoll = 0, tPitch = 0, tHeave = 0;
    if (port) {
      // Moored: the faintest surge from harbour swell.
      tRoll = Math.sin(t * 0.21) * 0.0004;
      tHeave = Math.sin(t * 0.17) * 0.03;
    } else {
      const N = 46;   // all waves; the hull length filters the short ones
      const hB = (o.heightAt(150, 0, N) + o.heightAt(120, 0, N)) * 0.5;
      const hS = (o.heightAt(-150, 0, N) + o.heightAt(-120, 0, N)) * 0.5;
      const hP = (o.heightAt(-40, -20, N) + o.heightAt(40, -20, N)) * 0.5;
      const hT = (o.heightAt(-40, 20, N) + o.heightAt(40, 20, N)) * 0.5;
      const hC = (hB + hS + hP + hT) * 0.25;
      tPitch = Math.atan2(hB - hS, 270) * 0.55;
      tRoll = -Math.atan2(hT - hP, 40) * 0.32;
      tHeave = hC * 0.45;
      // A long, slow roll that a moving hull always has, scaled by sea state.
      const hs = o.hs || 0.5;
      tRoll += Math.sin(t * (2 * Math.PI / 15.5)) * 0.0011 * hs;
      tPitch += Math.sin(t * (2 * Math.PI / 9.2) + 1.3) * 0.0004 * hs;
    }
    // Critically damped springs with the hull's natural periods.
    const spring = (k, target, period, h) => {
      const w = (2 * Math.PI) / period;
      const x = this.state[k], v = this.vel[k];
      const a = w * w * (target - x) - 2 * 0.55 * w * v;
      this.vel[k] = v + a * h;
      this.state[k] = x + this.vel[k] * h;
    };
    const sub = Math.max(1, Math.ceil(dt / 0.02));
    const h = dt / sub;
    for (let i = 0; i < sub; i++) {
      spring('roll', tRoll, 14, h);
      spring('pitch', tPitch, 8, h);
      spring('heave', tHeave, 7, h);
    }
  }

  apply(root) {
    root.position.set(0, this.state.heave, 0);
    root.rotation.set(this.state.roll, 0, this.state.pitch, 'XZY');
    root.updateMatrixWorld(true);
  }
}
