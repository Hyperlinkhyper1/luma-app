import { deckY, hullTop, hullBottom, frontX, backX, LIFEBOATS, STERN_X, BOW_X } from '../ship/dims.js';

// Deck map: a side elevation of the ship with the places you can go,
// opened with M, or with E at any door or stairwell.

const $ = (id) => document.getElementById(id);
const SX = (x) => 30 + ((x - STERN_X) / (BOW_X - STERN_X + 8)) * 930;
const SY = (y) => 262 - (y + 10) * 3.1;

export class DeckMap {
  constructor(app, pois) {
    this.app = app;
    this.pois = pois;
    this.el = $('map');
    this.open = false;
    this.el.querySelector('[data-close]').onclick = () => this.hide();
    this.el.addEventListener('pointerdown', (e) => { if (e.target === this.el) this.hide(); });
    this._draw();
  }

  _draw() {
    const svg = $('mapSvg');
    const pts = [];
    for (let x = STERN_X; x <= BOW_X; x += 4) pts.push(`${SX(x).toFixed(1)},${SY(hullTop(x)).toFixed(1)}`);
    for (let x = BOW_X; x >= STERN_X; x -= 4) pts.push(`${SX(x).toFixed(1)},${SY(Math.max(hullBottom(x), -8.8)).toFixed(1)}`);
    let html = '';
    html += `<rect class="water" x="0" y="${SY(0)}" width="1000" height="${300 - SY(0)}"/>`;
    html += `<polygon class="hullp" points="${pts.join(' ')}"/>`;
    // Cabin block, stepped at the ends.
    const blk = [];
    for (let n = 9; n <= 15; n++) blk.push([backX(n), deckY(n)], [backX(n), deckY(n + 1)]);
    const front = [];
    for (let n = 15; n >= 9; n--) front.push([frontX(n), deckY(n + 1)], [frontX(n), deckY(n)]);
    html += `<polygon class="supr" points="${[...blk, ...front].map(([x, y]) => `${SX(x).toFixed(1)},${SY(y).toFixed(1)}`).join(' ')}"/>`;
    // Dark top decks and the funnel.
    const rect = (x0, y0, x1, y1, cls) => `<rect class="${cls}" x="${SX(x0)}" y="${SY(y1)}" width="${SX(x1) - SX(x0)}" height="${SY(y0) - SY(y1)}" rx="2"/>`;
    html += rect(-122, deckY(16), -22, deckY(18), 'dark');
    html += rect(64, deckY(16), frontX(15), deckY(19), 'dark');
    html += rect(55, deckY(16), 64, deckY(19) + 3, 'supr');
    html += `<path class="dark" d="M ${SX(-28)} ${SY(deckY(18))} Q ${SX(-60)} ${SY(deckY(18) + 9)} ${SX(-92)} ${SY(deckY(18) + 16)} Q ${SX(-103)} ${SY(deckY(18) + 18)} ${SX(-106)} ${SY(deckY(18))} Z"/>`;
    for (const b of LIFEBOATS) if (b.side > 0) html += rect(b.x - 7.5, deckY(7) + 1, b.x + 7.5, deckY(7) + 4, 'boat').replace('class="boat"', 'style="fill:#e8571b"');
    html += `<text x="${SX(-150)}" y="${SY(deckY(7)) + 16}">DECK 7</text>`;
    html += `<text x="${SX(-20)}" y="${SY(deckY(19)) - 8}">DECK 16 – 19</text>`;
    for (const s of this.pois.spots) {
      html += `<circle class="spot" data-id="${s.id}" cx="${SX(s.x)}" cy="${SY(s.y + 1.2)}" r="7"><title>${s.label}</title></circle>`;
    }
    html += `<circle id="mapYou" class="you" cx="-20" cy="-20" r="5"/>`;
    svg.innerHTML = html;
    svg.onclick = (e) => {
      const id = e.target?.dataset?.id;
      if (id) this.go(id);
    };
  }

  _list(title) {
    const list = $('mapList');
    list.innerHTML = '';
    const add = (deck, label, fn) => {
      const b = document.createElement('button');
      b.innerHTML = `<b>${deck}</b><span>${label}</span>`;
      b.onclick = fn;
      list.appendChild(b);
    };
    for (const s of this.pois.spots) {
      if (s.portOnly && !this.app.inPort()) continue;
      add(s.deck === 0 ? 'QUAY' : `DECK ${s.deck}`, s.label.replace(/^Deck \d+ · /, ''), () => this.go(s.id));
    }
    add('SEA LEVEL', 'Tender alongside the hull', () => { this.hide(); this.app.modes.set('tender'); });
    add('AIR', 'Drone — free flight around the ship', () => { this.hide(); this.app.modes.set('drone'); });
    this.el.querySelector('h2').textContent = title;
  }

  go(id) {
    const s = this.pois.spots.find((p) => p.id === id);
    if (!s) return;
    this.hide();
    this.app.teleport(s);
  }

  show(title = 'Deck map') {
    this.open = true;
    this._list(title);
    // Where you are now.
    const w = this.app.modes.walker.pos;
    const you = $('mapYou');
    if (you && this.app.modes.mode === 'walk') { you.setAttribute('cx', SX(w.x)); you.setAttribute('cy', SY(w.y + 1.2)); }
    this.el.hidden = false;
    this.app.input.enabled = false;
    this.app.input.unlock();
  }

  hide() {
    if (!this.open) return;
    this.open = false;
    this.el.hidden = true;
    this.app.resume();
  }

  toggle() { this.open ? this.hide() : this.show(); }
}
