/* Subway Builder — geographic helpers. The sim runs in a local meter grid
   (equirectangular around the play anchor — accurate to <0.5% at city scale);
   the map runs in lng/lat. These convert between the two. */
(function () {
  'use strict';
  const SB = (window.SB = window.SB || {});

  const geo = (SB.geo = {
    anchor: null, // {lng, lat}
    _kx: 1, _ky: 110540,

    setAnchor(lng, lat) {
      geo.anchor = { lng, lat };
      geo._ky = 110540;
      geo._kx = 111320 * Math.cos((lat * Math.PI) / 180);
    },

    // lng/lat → meters east/north of the anchor.
    toM(lng, lat) {
      return [(lng - geo.anchor.lng) * geo._kx, (lat - geo.anchor.lat) * geo._ky];
    },
    toLL(x, y) {
      return [geo.anchor.lng + x / geo._kx, geo.anchor.lat + y / geo._ky];
    },

    // Meters between two lng/lat points (equirectangular — fine at city scale).
    distM(aLng, aLat, bLng, bLat) {
      const dx = (bLng - aLng) * geo._kx;
      const dy = (bLat - aLat) * geo._ky;
      return Math.hypot(dx, dy);
    },

    // Ray-cast point-in-ring; pt and ring in meter coords [[x,y],...].
    pointInRing(px, py, ring) {
      let inside = false;
      for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
        const xi = ring[i][0], yi = ring[i][1], xj = ring[j][0], yj = ring[j][1];
        if ((yi > py) !== (yj > py) && px < ((xj - xi) * (py - yi)) / (yj - yi) + xi) {
          inside = !inside;
        }
      }
      return inside;
    },

    // Point in polygon with holes: [outerRing, hole1, ...] (meter coords).
    pointInPoly(px, py, rings) {
      if (!rings.length || !geo.pointInRing(px, py, rings[0])) return false;
      for (let i = 1; i < rings.length; i++) {
        if (geo.pointInRing(px, py, rings[i])) return false;
      }
      return true;
    },

    ringBBox(ring) {
      let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
      for (const [x, y] of ring) {
        if (x < x0) x0 = x; if (x > x1) x1 = x;
        if (y < y0) y0 = y; if (y > y1) y1 = y;
      }
      return [x0, y0, x1, y1];
    },

    ringAreaM2(ring) {
      let a = 0;
      for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
        a += (ring[j][0] + ring[i][0]) * (ring[j][1] - ring[i][1]);
      }
      return Math.abs(a / 2);
    },
  });
})();
