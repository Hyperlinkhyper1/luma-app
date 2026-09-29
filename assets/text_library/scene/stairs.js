// One staircase description drives both its timberwork and the walking route.
(() => {
  'use strict';
  const turns = 2, perTurn = 16, count = turns * perTurn;
  const angle = t => Math.PI / 2 + t * turns * Math.PI * 2;
  function point(S, t, radius, square = false) {
    const a = angle(t), x = Math.cos(a), z = Math.sin(a);
    const r = square ? radius / Math.max(Math.abs(x), Math.abs(z)) : radius;
    return [S.cx + 0.5 + x * r, S.cz + 0.5 + z * r];
  }
  function describe(S, base, height) {
    return {base, height, rise: height / count, count, turns};
  }
  function treads(S, flight) {
    return Array.from({length: count}, (_, i) => ({
      top: flight.base + (i + 1) * flight.rise,
      bottom: flight.base + i * flight.rise - 0.125,
      corners: [point(S, i / count, 0.27, true), point(S, i / count, 1.43, true),
        point(S, (i + 1) / count, 1.43, true), point(S, (i + 1) / count, 0.27, true)],
    }));
  }
  const landing = (S, y) => [S.cx + 0.5, y, S.z0 + 3.5];
  function bezier(points, t) {
    const s = 1 - t;
    return [0, 1, 2].map(k => s * s * s * points[0][k] + 3 * s * s * t * points[1][k]
      + 3 * s * t * t * points[2][k] + t * t * t * points[3][k]);
  }
  function route(S, flight, t) {
    t = Math.max(0, Math.min(1, t));
    const low = landing(S, flight.base), high = landing(S, flight.base + flight.height);
    const [x, z] = point(S, 0, 0.95);
    const first = [x, flight.base + flight.rise / 2, z];
    const last = [x, flight.base + flight.height, z];
    const approach = 0.08;
    if (t < approach) return bezier([low, [x, low[1], z + 0.55], [x + 0.35, first[1], z], first], t / approach);
    if (t > 1 - approach) return bezier([last, [x - 0.35, last[1], z], [x, high[1], z + 0.55], high], (t - 1 + approach) / approach);
    const u = (t - approach) / (1 - 2 * approach);
    const p = point(S, u, 0.95);
    return [p[0], Math.min(high[1], flight.base + (u * count + 0.5) * flight.rise), p[1]];
  }
  window.LibraryStairs = {describe, treads, point, route, landing};
})();
