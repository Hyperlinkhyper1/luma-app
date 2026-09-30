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
  // The walking line: straight in from the landing along a tangent to the
  // circle the feet follow round the post, round that circle, and straight
  // out again along the other tangent. Tangents join a circle without a
  // kink, so the walker never weaves at the foot or the head of the stair.
  // Feet stay on the treads: level off the stair, rising with the treads
  // on it.
  const WALK = 0.95, WELL = 1.43;
  function route(S, flight, t) {
    t = Math.max(0, Math.min(1, t));
    const cx = S.cx + 0.5, cz = S.cz + 0.5;
    const top = flight.base + flight.height;
    const low = landing(S, flight.base), high = landing(S, top);
    const toLanding = Math.atan2(low[2] - cz, low[0] - cx);
    const off = Math.acos(Math.min(1, WALK / Math.hypot(low[0] - cx, low[2] - cz)));
    const a0 = toLanding + off, a1 = toLanding - off + turns * Math.PI * 2;
    const yAt = a => Math.max(flight.base, Math.min(top, flight.base + ((a - Math.PI / 2) / (turns * Math.PI * 2) * count + 0.5) * flight.rise));
    const on = a => [cx + Math.cos(a) * WALK, yAt(a), cz + Math.sin(a) * WALK];
    const inWell = (x, z) => Math.max(Math.abs(x - cx), Math.abs(z - cz)) <= WELL;
    const lerp = (p, q, w) => p.map((v, k) => v + (q[k] - v) * w);
    // Where a straight walk from p to q first steps into the well.
    const edge = (p, q) => {
      for (let i = 0; i <= 64; i++) if (inWell(p[0] + (q[0] - p[0]) * i / 64, p[2] + (q[2] - p[2]) * i / 64)) return i / 64;
      return 1;
    };
    const tA = 0.1, tB = 0.9;
    if (t < tA) {
      const w = t / tA, q = on(a0), e = edge(low, q);
      const p = lerp(low, q, w);
      p[1] = flight.base + (q[1] - flight.base) * Math.max(0, (w - e) / (1 - e || 1));
      return p;
    }
    if (t > tB) {
      const w = (t - tB) / (1 - tB), q = on(a1), e = 1 - edge(high, q);
      const p = lerp(q, high, w);
      p[1] = q[1] + (top - q[1]) * Math.min(1, w / (e || 1));
      return p;
    }
    return on(a0 + (a1 - a0) * (t - tA) / (tB - tA));
  }

  // The climb as a path walked at an even pace: the route (reversed going
  // down) sampled densely and measured, so a distance along it gives a
  // place. `lead`, from where the reader stands through any corners, is
  // joined on as straight walks to the foot of the route. Past either end
  // it carries straight on, which lets the gaze look ahead there.
  function walk(S, flight, dir, lead = []) {
    const pts = [];
    const N = 480;
    for (let i = 0; i <= N; i++) pts.push(route(S, flight, dir > 0 ? i / N : 1 - i / N));
    const head = [];
    lead.forEach((from, j) => {
      const to = lead[j + 1] || pts[0];
      const n = Math.ceil(Math.hypot(to[0] - from[0], to[2] - from[2]) / 0.1);
      for (let i = 0; i < n; i++) head.push(from.map((v, k) => v + (to[k] - v) * i / n));
    });
    pts.unshift(...head);
    const at = [0];
    const kept = [pts[0]];
    for (let i = 1; i < pts.length; i++) {
      const p = pts[i], q = kept[kept.length - 1];
      const d = Math.hypot(p[0] - q[0], p[1] - q[1], p[2] - q[2]);
      if (d < 1e-4) continue;
      kept.push(p);
      at.push(at[at.length - 1] + d);
    }
    const length = at[at.length - 1];
    const lerp = (a, b, f) => a.map((v, k) => v + (b[k] - v) * f);
    function place(s) {
      const n = kept.length - 1;
      if (s === 0) return kept[0].slice();
      if (s === length) return kept[n].slice();
      if (s < 0) return lerp(kept[0], kept[1], s / (at[1] || 1));
      if (s > length) return lerp(kept[n - 1], kept[n], 1 + (s - length) / ((at[n] - at[n - 1]) || 1));
      let lo = 0, hi = n;
      while (hi - lo > 1) { const mid = (lo + hi) >> 1; if (at[mid] <= s) lo = mid; else hi = mid; }
      return lerp(kept[lo], kept[hi], (s - at[lo]) / (at[hi] - at[lo]));
    }
    return {length, place};
  }
  window.LibraryStairs = {describe, treads, point, route, landing, walk};
})();
