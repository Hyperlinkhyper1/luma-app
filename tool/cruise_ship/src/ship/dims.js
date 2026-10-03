// MSC Virtuosa (Meraviglia-Plus class) at true scale. Every part of the ship
// is generated from the numbers and outline functions in this file, so the
// proportions can be tuned in one place.
//
// Ship frame: +x bow, +y up (waterline at 0), +z starboard. Metres.

export const LENGTH = 331.4;
export const BOW_X = 165.7;
export const STERN_X = -165.7;
export const DRAFT = 8.8;
export const DECK_H = 2.95;

/** Floor level of deck n above the waterline. Deck 7 (promenade) is at 20.5 m. */
export const deckY = (n) => 20.5 + (n - 7) * DECK_H;

export const PROMENADE_DECK = 7;       // open walkway beside the lifeboats
export const CABIN_DECKS = [9, 10, 11, 12, 13, 14, 15];
export const POOL_DECK = 16;           // main open deck, ~47 m above the sea
export const BRIDGE_DECK = 12;
export const TOP_DECK = 19;

export const HULL_HALF = 20.2;         // half breadth at the waterline, midbody
export const HULL_HALF_TOP = 20.6;     // at deck 7, with a little flare
export const BALCONY_D = 1.6;          // balcony depth, wall to glass
export const CABIN_W = 3.45;           // balcony pitch along the facade

// Deck 7 promenade cross-section (starboard side, mirrored to port).
export const PROM = {
  wallZ: 13.6,          // inner wall (doors, windows)
  railZ: 17.0,          // rail between the walkway and the lifeboat well
  boatZ: 19.6,          // lifeboat centreline
  x0: -128,             // aft end of the open walkway
  x1: 96,               // forward end
};

// The big side recess (stepped balcony tiers under the pool-deck overhang).
export const RECESS = { x0: -56, x1: 10 };

const smooth = (e0, e1, x) => {
  const t = Math.min(1, Math.max(0, (x - e0) / (e1 - e0)));
  return t * t * (3 - 2 * t);
};

/** x where the bow taper starts and where the stem is, at height y. */
function bowRange(y) {
  const f = Math.min(1, Math.max(0, y / 20.5));
  const yy = Math.max(y, 0);
  const extra = Math.max(0, yy - 20.5) / 5.9;      // forecastle rises to deck 9
  return [86 + 8 * f + extra * 4, 160 + 5.7 * f + extra * 0.0];
}

/**
 * Hull half breadth at ship x and height y (negative y is underwater).
 * Returns 0 forward of the stem / aft of the transom.
 */
export function hullHalf(x, y) {
  let mid = HULL_HALF + (HULL_HALF_TOP - HULL_HALF) * smooth(-2, 14, y);
  // Bilge: the flat bottom turns up into the sides with a 2.8 m radius.
  const yb = -DRAFT;
  if (y < yb + 2.8) {
    const dy = yb + 2.8 - y;
    mid -= 2.8 - Math.sqrt(Math.max(0, 2.8 * 2.8 - dy * dy));
  }
  if (y < yb) return 0;
  const [b0, b1] = bowRange(y);
  if (x > b0) {
    if (x >= b1) return 0;
    const t = (x - b0) / (b1 - b0);
    // Fuller above the waterline (flare), finer below it.
    const p = y > 0 ? 2.0 : 2.6;
    mid *= Math.pow(Math.max(0, 1 - Math.pow(t, p)), 0.62);
  }
  // Stern: broad transom with rounded corners; underwater the hull rises aft.
  if (x < -146) {
    const t = Math.min(1, (-146 - x) / (165.7 - 146));
    mid *= 1 - Math.pow(t, 3.5) * 0.18;
    if (y < 2.0) {
      // the run: bottom sweeps up to meet the transom just above the water
      const bottomAt = -DRAFT + (DRAFT + 1.6) * Math.pow(t, 1.6);
      if (y < bottomAt) return 0;
    }
  }
  if (x < STERN_X) return 0;
  return mid;
}

/** Height of the hull's top edge (the weather deck / forecastle) at x. */
export function hullTop(x) {
  return deckY(7) + smooth(102, 134, x) * (deckY(9) - deckY(7));
}

/** Lowest point of the hull at x (keel line incl. the stern run). */
export function hullBottom(x) {
  if (x < -146) {
    const t = Math.min(1, (-146 - x) / (165.7 - 146));
    return -DRAFT + (DRAFT + 1.6) * Math.pow(t, 1.6);
  }
  if (x > 150) return -DRAFT + (x - 150) * 0.05;
  return -DRAFT;
}

// ---------------------------------------------------------------------------
// Superstructure plan. Each cabin deck has a wall line (the plane of the
// balcony doors) on the starboard side, from the stern centreline round to
// the bow centreline; port is the mirror image. Balconies stand outboard of
// the wall line by BALCONY_D.

/** Balcony rail (outer face) distance from centreline on the straight sides. */
export const railZ = (n) => 20.55 + 0.13 * (n - 9);
export const wallZ = (n) => railZ(n) - BALCONY_D;
/** Wall line inside the recess: deeper the higher the deck. */
export const recessWallZ = (n) => 15.4 - 0.62 * (n - 9);

/** Front (bow) of the cabin block on deck n. */
export function frontX(n) {
  if (n === BRIDGE_DECK) return 150.5;
  if (n < BRIDGE_DECK) return 143.5 + 1.1 * (n - 9);
  return 147.5 - 0.9 * (n - BRIDGE_DECK - 1);
}
/** Back (stern) of the cabin block on deck n: terraces step forward going up. */
export const backX = (n) => -160.2 + 0.85 * Math.max(0, n - 12);

/**
 * Starboard wall line of a cabin deck as a list of [x, z] points from the
 * stern centreline to the bow centreline. Points carry a tag: 'side',
 * 'recess', 'bend' (the 45-degree transitions), 'bow' or 'stern'.
 */
export function wallLine(n) {
  const pts = [];
  const zw = wallZ(n);
  const zr = recessWallZ(n);
  const xb = backX(n), xf = frontX(n);
  // Stern: quarter ellipse from the centreline to the side.
  const sr = 13;
  for (let i = 0; i <= 10; i++) {
    const a = (i / 10) * Math.PI / 2;
    pts.push([xb + sr - Math.cos(a) * sr, Math.sin(a) * zw, 'stern']);
  }
  // Side, with the recess.
  const d = zw - zr;
  pts.push([RECESS.x0 - d, zw, 'side']);
  pts.push([RECESS.x0, zr, 'bend']);
  pts.push([RECESS.x1, zr, 'recess']);
  pts.push([RECESS.x1 + d, zw, 'bend']);
  // Bow: elliptical front.
  const bl = 26;
  const xs = xf - bl;
  pts.push([xs, zw, 'side']);
  for (let i = 1; i <= 14; i++) {
    const t = i / 14;
    const a = t * Math.PI / 2;
    pts.push([xs + Math.sin(a) * bl, Math.cos(a) * zw, 'bow']);
  }
  return pts;
}

/** Nominal wall half-width at x for deck n (straight sides only, ignores ends). */
export function wallZAt(n, x) {
  const zw = wallZ(n), zr = recessWallZ(n), d = zw - zr;
  if (x > RECESS.x0 - d && x < RECESS.x1 + d) {
    if (x < RECESS.x0) return zw - (x - (RECESS.x0 - d));
    if (x > RECESS.x1) return zr + (x - RECESS.x1);
    return zr;
  }
  return zw;
}

// Lifeboats: big enclosed boats and tenders hang in the deck 7 bay.
export const LIFEBOATS = [];
{
  // Two runs either side of the side recess, as on the real ship.
  const xs = [];
  for (let x = -120; x <= -66; x += 17.5) xs.push(x);
  for (let x = -36; x <= 88; x += 17.5) xs.push(x);
  let num = 1;
  // Numbered from forward: odd starboard, even port.
  xs.sort((a, b) => b - a);
  for (const x of xs) {
    const tender = (num % 3) === 2;
    LIFEBOATS.push({ x, side: 1, num, tender });
    LIFEBOATS.push({ x, side: -1, num: num + 1, tender });
    num += 2;
  }
}

/** Liferaft canister racks between the boats. */
export const RAFT_RACKS = [-138, -96, -50, -12, 48, 104];
