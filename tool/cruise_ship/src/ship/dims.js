// MSC Virtuosa (Meraviglia-Plus class) at true scale. Every part of the ship
// is generated from the numbers and outline functions in this file, so the
// proportions can be tuned in one place.
//
// Heights, the stem, the stepped front and the lifeboat positions were
// measured off a broadside photo (La Rochelle, 2021) scaled to the ship's
// 331.4 m length, and checked against photos from ahead and astern.
//
// Ship frame: +x bow, +y up (waterline at 0), +z starboard. Metres.

export const LENGTH = 331.4;
export const BOW_X = 165.7;
export const STERN_X = -165.7;
export const DRAFT = 8.8;
export const DECK_H = 2.9;

/** Floor level of deck n above the waterline. Deck 7 (lifeboats) is at 13.6 m. */
export const deckY = (n) => 13.6 + (n - 7) * DECK_H;

export const PROMENADE_DECK = 7;       // open walkway beside the lifeboats
export const CABIN_DECKS = [9, 10, 11, 12, 13, 14, 15];
export const POOL_DECK = 16;           // main open deck, ~40 m above the sea
export const BRIDGE_DECK = 13;
export const TOP_DECK = 19;

export const HULL_HALF = 21.4;         // half breadth at the waterline (43 m beam)
export const HULL_HALF_TOP = 21.6;     // at deck 7, with a little flare
export const BALCONY_D = 1.6;          // balcony depth, wall to glass
export const CABIN_W = 3.45;           // balcony pitch along the facade

// Deck 7 promenade cross-section (starboard side, mirrored to port).
export const PROM = {
  wallZ: 14.8,          // inner wall (doors, windows)
  railZ: 18.2,          // rail between the walkway and the lifeboat well
  boatZ: 20.8,          // lifeboat centreline
  x0: -137,             // aft end of the open walkway (the dark stern block before it)
  x1: 96,               // forward end
};

// The big side recess (stepped balcony tiers under the pool-deck overhang).
export const RECESS = { x0: -56, x1: 10 };

const smooth = (e0, e1, x) => {
  const t = Math.min(1, Math.max(0, (x - e0) / (e1 - e0)));
  return t * t * (3 - 2 * t);
};

/** Waterline stem and the stem at the top of the bow (deck 9). */
const STEM_WL = 153.5;
const BOW_TOP_Y = 18.8;

/**
 * x where the bow taper starts and where the stem is, at height y. The stem
 * rakes 12.5 m forward between the waterline and the top of the bow, curving
 * forward more toward the top; below the water the bulb noses out ahead of it.
 */
function bowRange(y) {
  if (y >= 0) {
    const t = Math.min(1, y / BOW_TOP_Y);
    return [74 + 32 * t, STEM_WL + 12.5 * Math.pow(t, 1.35)];
  }
  const bulb = 3.6 * Math.exp(-Math.pow((y + 4.6) / 2.5, 2));
  return [74 + y * 2.2, STEM_WL + y * 0.35 + bulb];
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
    // Fuller above the waterline (the bow flares out to a broad, rounded
    // forecastle), finer below it; the bulb is round at its nose.
    const p = y > 0 ? 1.7 + 0.6 * Math.min(1, y / BOW_TOP_Y) : 2.4;
    const q = y > 0 ? 0.62 : 0.7;
    mid *= Math.pow(Math.max(0, 1 - Math.pow(t, p)), q);
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
  return deckY(7) + smooth(110, 141, x) * (BOW_TOP_Y - deckY(7));
}

/** Lowest point of the hull at x (keel line incl. the stern run). */
export function hullBottom(x) {
  if (x < -146) {
    const t = Math.min(1, (-146 - x) / (165.7 - 146));
    return -DRAFT + (DRAFT + 1.6) * Math.pow(t, 1.6);
  }
  // Forefoot: the keel sweeps up into the bulb.
  if (x > 136) return -DRAFT + 3.4 * smooth(136, STEM_WL + 3.6, x);
  return -DRAFT;
}

// ---------------------------------------------------------------------------
// Superstructure plan. Each cabin deck has a wall line (the plane of the
// balcony doors) on the starboard side, from the stern centreline round to
// the bow centreline; port is the mirror image. Balconies stand outboard of
// the wall line by BALCONY_D.

/** Balcony rail (outer face) distance from centreline on the straight sides. */
export const railZ = (n) => HULL_HALF_TOP + 0.05 + 0.04 * (n - 9);
export const wallZ = (n) => railZ(n) - BALCONY_D;
/** Wall line inside the recess: deeper the higher the deck. */
export const recessWallZ = (n) => 16.6 - 0.62 * (n - 9);

/**
 * Front (bow) of the cabin block on deck n. The front steps back as it
 * rises - about 2 m a deck, then more for the top decks - so the ship's
 * forward end is a raked, terraced wedge rather than a wall.
 */
const FRONT = { 9: 139.5, 10: 137, 11: 134.5, 12: 132.5, 13: 131.5, 14: 130, 15: 128.5, 16: 124.5, 17: 120.5, 18: 117, 19: 113 };
export function frontX(n) {
  return FRONT[n] ?? (n < 9 ? FRONT[9] : FRONT[19]);
}
/** Back (stern) of the cabin block on deck n: a flush stack of aft balconies. */
export const backX = () => -160.5;

/** Radius of the cabin block's blank, rounded stern corners. */
export const STERN_CORNER = 7.5;

/**
 * Starboard wall line of a cabin deck as a list of [x, z] points from the
 * stern centreline to the bow centreline. Points carry a tag: 'side',
 * 'recess', 'bend' (the 45-degree transitions), 'bow', 'stern' (the flat
 * aft face) or 'corner' (the blank rounded stern corners).
 */
export function wallLine(n) {
  const pts = [];
  const zw = wallZ(n);
  const zr = recessWallZ(n);
  const xb = backX(n), xf = frontX(n);
  // Stern: a flat aft face of balconies, then a rounded corner of plain
  // white wall (as on the real ship) into the side.
  const rc = STERN_CORNER;
  pts.push([xb, 0, 'stern']);
  pts.push([xb, zw - rc, 'stern']);
  for (let i = 1; i <= 8; i++) {
    const a = (i / 8) * Math.PI / 2;
    pts.push([xb + rc - Math.cos(a) * rc, zw - rc + Math.sin(a) * rc, 'corner']);
  }
  // Side, with the recess.
  const d = zw - zr;
  pts.push([RECESS.x0 - d, zw, 'side']);
  pts.push([RECESS.x0, zr, 'bend']);
  pts.push([RECESS.x1, zr, 'recess']);
  pts.push([RECESS.x1 + d, zw, 'bend']);
  // Bow: elliptical front.
  const bl = BOW_LEN;
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

/** Length of the elliptical bow end of each cabin deck. */
export const BOW_LEN = 24;

// Lifeboats: big enclosed boats and tenders hang in the deck 7 bay.
export const LIFEBOATS = [];
{
  // Four aft of the side recess and six forward of it, as on the real ship.
  const xs = [];
  for (let i = 0; i < 4; i++) xs.push(-128.7 + 17.7 * i);
  for (let i = 0; i < 6; i++) xs.push(-2.9 + 16.9 * i);
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
export const RAFT_RACKS = [-64, -52, -16, 92, 100];
