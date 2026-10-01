const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

// The wandering trader's page code, run without a browser: just enough of
// a DOM for the post and the shop to wire their buttons up.
const scene = path.join(__dirname, '../assets/text_library/scene');
const element = () => ({style: {}, children: [], addEventListener() {}, querySelector: () => null, replaceChildren() {}, classList: {toggle() {}, add() {}, remove() {}}});
const canvas = () => ({width: 0, height: 0, getContext: () => ({fillRect() {}, set fillStyle(_) {}}), toDataURL: () => 'data:'});
const context = {
  window: {}, console, performance, setTimeout,
  document: {getElementById: element, createElement: canvas},
};
vm.createContext(context);
for (const file of ['textures.js', 'world.js', 'goods.js', 'mail.js', 'market.js']) {
  vm.runInContext(fs.readFileSync(path.join(scene, file), 'utf8'), context, {filename: file});
  Object.assign(context, context.window);
}
const {LibraryGoods: Goods, LibraryMarket, LibraryMail, LibraryTextures} = context.window;

function newMarket() {
  const sent = [];
  const send = m => sent.push(JSON.parse(JSON.stringify(m)));
  const post = LibraryMail.create({send, reducedMotion: () => true});
  const market = LibraryMarket.create({send, catalog: Goods.CATALOG, reducedMotion: () => true});
  return {post, market, sent};
}

test('he comes on the half hour, warns before he packs up, and is gone on the hour', () => {
  const {market} = newMarket();
  const events = [];
  market.onChange(what => events.push(what));
  market.load(null);
  assert.equal(market.present, false);
  assert.equal(market.nextIn(), LibraryMarket.ARRIVE);
  for (let t = 0; t < LibraryMarket.ARRIVE - 1; t++) market.tick(1);
  assert.equal(market.present, false);
  market.tick(2);
  assert.equal(market.present, true);
  assert.ok(market.leavesIn() <= LibraryMarket.STAY);
  for (let t = 0; t < LibraryMarket.STAY - LibraryMarket.WARN; t++) market.tick(1);
  market.tick(1);
  assert.ok(events.includes('warn'));
  while (market.present) market.tick(1);
  assert.deepEqual(events.filter(e => e !== 'load'), ['arrive', 'warn', 'leave']);
  assert.ok(market.state.clock < 5, 'a new hour starts');
  assert.equal(market.state.warned, false);
});

test('buying spends coins in hand first, then the vault, and only while he is here', () => {
  const {post, market} = newMarket();
  post.load({hand: 30, vault: 100});
  market.load(null);
  assert.equal(market.buy('bed', post), false, 'not before he comes');
  market.load({clock: LibraryMarket.ARRIVE});
  assert.equal(market.buy('bed', post), true);
  assert.equal(post.state.hand, 0);
  assert.equal(post.state.vault, 70);
  assert.equal(market.buy('swing', post), false, 'too dear');
  assert.equal(post.state.vault, 70, 'nothing spent on a failed buy');
  assert.equal(market.buy('candelabra', post), true);
  assert.equal(market.buy('candelabra', post), true);
  assert.deepEqual({...market.state.crate}, {bed: 1, candelabra: 2});
  assert.equal(post.state.vault, 30);
});

test('placing takes a piece out of the crate; picking it up puts it back', () => {
  const {post, market, sent} = newMarket();
  post.load({vault: 500});
  market.load({clock: LibraryMarket.ARRIVE});
  market.buy('telescope', post);
  assert.equal(market.place({id: 'aquarium', x: 0, z: 0, floor: 0, rot: 0}), null, 'nothing to place');
  const p = market.place({id: 'telescope', x: 3, z: -4, floor: 0, rot: 2});
  assert.ok(p);
  assert.equal(market.count('telescope'), 0);
  assert.equal(market.state.placed.length, 1);
  assert.equal(market.pickUp(p), true);
  assert.equal(market.count('telescope'), 1);
  assert.equal(market.state.placed.length, 0);
  const saved = sent.filter(m => m.type === 'market').at(-1).state;
  assert.deepEqual(saved.crate, {telescope: 1});
});

test('saved state is cleaned against the catalogue', () => {
  const ids = new Set(Goods.CATALOG.map(c => c.id));
  const s = LibraryMarket.clean({
    clock: -20,
    crate: {bed: 2.9, rocket: 4, swing: -1},
    placed: [{id: 'bed', x: 1.2, z: 2, rot: 5}, {id: 'rocket', x: 0, z: 0}, {id: 'gramophone', x: 'here', z: 0}],
  }, ids);
  assert.equal(s.clock, 0);
  assert.deepEqual({...s.crate}, {bed: 2});
  assert.equal(s.placed.length, 1);
  assert.deepEqual({...s.placed[0]}, {id: 'bed', x: 1, z: 2, floor: 0, rot: 1});
});

test('a quarter turn of a piece is the same turn the page gives its mesh', () => {
  for (let rot = 0; rot < 4; rot++) {
    const a = rot * Math.PI / 2, c = Math.cos(a), s = Math.sin(a);
    for (const [x, z] of [[1, 0], [0, 1], [0.3, -0.7]]) {
      const [tx, tz] = Goods.turn([x, z], rot);
      assert.ok(Math.abs(tx - (x * c + z * s)) < 1e-9 && Math.abs(tz - (-x * s + z * c)) < 1e-9, `rot ${rot}`);
    }
  }
  assert.deepEqual(Array.from(Goods.footprint('swing', 1)), [1, 3]);
});

test('every piece builds inside its footprint, from textures the atlas has', () => {
  const used = new Set();
  const atlas = {index: new Proxy({}, {get: (_, name) => { used.add(name); return {cell: 0, frames: 1, frameTime: 1}; }})};
  const within = (v, lo, hi) => v >= lo - 1e-6 && v <= hi + 1e-6;
  for (const item of Goods.CATALOG) {
    const [w, d] = item.size;
    const p = Goods.build(item.id, atlas);
    assert.ok(p.main.count > 0, `${item.id} has geometry`);
    for (const [x0, z0, x1, z1] of p.solid) assert.ok(x0 >= 0 && z0 >= 0 && x1 <= w && z1 <= d && x0 < x1 && z0 < z1, `${item.id} solid`);
    const [lo, hi] = p.pick;
    assert.ok(within(lo[0], -w / 2, w / 2) && within(hi[0], -w / 2, w / 2) && within(lo[2], -d / 2, d / 2) && within(hi[2], -d / 2, d / 2), `${item.id} pick box in footprint`);
    assert.ok(hi[1] <= item.height, `${item.id} fits the air it asks for`);
    for (let i = 0; i < p.main.pos.length; i += 3) {
      assert.ok(within(p.main.pos[i], -w / 2 - 0.05, w / 2 + 0.05) && within(p.main.pos[i + 2], -d / 2 - 0.05, d / 2 + 0.05), `${item.id} stays on its footprint`);
      assert.ok(p.main.pos[i + 1] <= item.height + 1e-6, `${item.id} below its height`);
    }
  }
  const seats = Object.fromEntries(Goods.CATALOG.map(c => [c.id, Goods.build(c.id, atlas).seat || null]));
  assert.ok(seats.bed && seats.swing && seats.telescope, 'the bed, swing and telescope can be used');
  assert.ok(seats.telescope.fov && seats.telescope.telescope);
  assert.ok(Goods.build('swing', atlas).parts.seat.count > 0, 'the swing has a bench to sway');
  assert.ok(Goods.build('candelabra', atlas).flames.length === 3, 'three candles');
  const missing = [...used].filter(name => !LibraryTextures.has(name) && name !== 'solid' && name !== 'oak_planks');
  assert.deepEqual(missing, []);
});
