import { deckY } from './dims.js';

// Names for where you are standing, for the HUD.

export function deckAt(y) {
  let best = 7;
  for (let n = 0; n <= 20; n++) if (deckY(n) <= y + 0.6) best = n;
  return best;
}

export function describe(pos) {
  const n = deckAt(pos.y);
  const side = pos.z >= 0 ? 'STARBOARD' : 'PORT';
  let area = '';
  if (pos.y < 3 && Math.abs(pos.z) > 25) area = 'QUAY';
  else if (n <= 8) area = Math.abs(pos.z) > 12 ? `PROMENADE · ${side}` : 'PROMENADE';
  else if (n <= 10) area = pos.x > 120 ? 'FORECASTLE' : 'DECK';
  else if (n === 16) area = pos.x < -122 ? 'AFT POOL' : pos.x < 56 ? (Math.abs(pos.z) > 12.5 ? `POOL DECK · ${side}` : 'POOL DECK') : 'STAGE';
  else if (n === 17) area = pos.x < -122 ? 'AFT TERRACE' : `POOL GALLERY · ${side}`;
  else if (n === 18) area = 'SPORTS DECK · FUNNEL';
  else if (n >= 19) area = 'TOP SUN DECK';
  else area = 'DECK';
  return { deck: n, area };
}
