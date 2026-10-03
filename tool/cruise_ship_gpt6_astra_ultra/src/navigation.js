export function surfaceHeight(surface, x, z) {
  if (!surface.axis) return surface.y;
  const a = surface.axis;
  const t = ((a === 'x' ? x : z) - surface[`${a}0`]) / (surface[`${a}1`] - surface[`${a}0`]);
  return surface.y + Math.max(0, Math.min(1, t)) * (surface.y1 - surface.y);
}

export class Navigator {
  constructor(surfaces, obstacles) {
    this.surfaces = surfaces;
    this.obstacles = obstacles;
    this.position = { x: 0, y: 16, z: 18 };
    this.surface = null;
    this.radius = 0.24;
    this.height = 1.72;
    this.distance = 0;
  }

  floorAt(x, z, y, tolerance = 0.48) {
    let best = null;
    let delta = Infinity;
    for (const surface of this.surfaces) {
      if (x < surface.x0 + 0.015 || x > surface.x1 - 0.015 || z < surface.z0 + 0.015 || z > surface.z1 - 0.015) continue;
      const h = surfaceHeight(surface, x, z);
      const d = Math.abs(h - y);
      if (d <= tolerance && d < delta) { best = { surface, y: h }; delta = d; }
    }
    return best;
  }

  blocked(x, y, z) {
    for (const b of this.obstacles) {
      if (y + this.height <= b.y0 + 0.04 || y >= b.y1 - 0.04) continue;
      const cx = Math.max(b.x0, Math.min(b.x1, x));
      const cz = Math.max(b.z0, Math.min(b.z1, z));
      if ((x - cx) ** 2 + (z - cz) ** 2 < this.radius ** 2) return true;
    }
    return false;
  }

  place(spot) {
    const floor = this.floorAt(spot.x, spot.z, spot.y, 0.8);
    if (!floor || this.blocked(spot.x, floor.y, spot.z)) return false;
    this.position = { x: spot.x, y: floor.y, z: spot.z };
    this.surface = floor.surface;
    return true;
  }

  move(dx, dz) {
    const n = Math.max(1, Math.ceil(Math.hypot(dx, dz) / 0.1));
    const start = { ...this.position };
    for (let i = 0; i < n; i++) {
      if (!this.tryMove(dx / n, dz / n)) {
        this.tryMove(dx / n, 0);
        this.tryMove(0, dz / n);
      }
    }
    const moved = Math.hypot(this.position.x - start.x, this.position.z - start.z);
    this.distance += moved;
    return moved;
  }

  tryMove(dx, dz) {
    const p = this.position;
    const x = p.x + dx;
    const z = p.z + dz;
    const floor = this.floorAt(x, z, p.y);
    if (!floor || this.blocked(x, floor.y, z)) return false;
    p.x = x;
    p.y = floor.y;
    p.z = z;
    this.surface = floor.surface;
    return true;
  }
}
