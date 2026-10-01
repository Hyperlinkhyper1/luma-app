// The wandering trader. On the same clock as the post (only time the hall
// is open and on screen counts), he comes once an hour and keeps his stall
// in front of the house open for half of it. What the reader buys goes into
// a crate; placed in the hall or out on the island, it is a piece. The app
// keeps all of it; this page times it and draws it.
(() => {
  'use strict';
  const $ = id => document.getElementById(id);

  // One visit an hour: half an hour away, then half an hour at his stall.
  const CYCLE = 3600;
  const STAY = 1800;
  const ARRIVE = CYCLE - STAY;
  // How long before he leaves the reader is told he's packing up.
  const WARN = 300;
  const MAX_PIECES = 200;
  const MAX_STACK = 99;

  const whole = v => (Number.isFinite(Number(v)) ? Math.max(0, Math.floor(Number(v))) : 0);
  const int = v => (Number.isFinite(Number(v)) ? Math.round(Number(v)) : null);

  // Whatever was saved, cleaned up against the catalogue: unknown pieces,
  // unknown pets and nonsense counts are dropped.
  function clean(saved, ids, pets) {
    const s = saved && typeof saved === 'object' ? saved : {};
    const crate = {};
    if (s.crate && typeof s.crate === 'object') {
      for (const [id, n] of Object.entries(s.crate)) if (ids.has(id) && whole(n) > 0) crate[id] = Math.min(MAX_STACK, whole(n));
    }
    const placed = [];
    for (const p of Array.isArray(s.placed) ? s.placed : []) {
      if (!p || !ids.has(p.id) || placed.length >= MAX_PIECES) continue;
      const x = int(p.x), z = int(p.z), floor = int(p.floor), rot = int(p.rot);
      if (x == null || z == null || Math.abs(x) > 512 || Math.abs(z) > 512) continue;
      placed.push({id: p.id, x, z, floor: Math.max(0, Math.min(16, floor ?? 0)), rot: (((rot ?? 0) % 4) + 4) % 4});
    }
    return {clock: Math.min(CYCLE - 1, whole(s.clock)), crate, placed, warned: !!s.warned, pet: pets.includes(s.pet) ? s.pet : null};
  }

  function create({send, catalog, pets = [], reducedMotion}) {
    const items = Object.fromEntries(catalog.map(c => [c.id, c]));
    const ids = new Set(Object.keys(items));
    const state = clean(null, ids, pets);
    let loaded = false, lastSave = 0;
    const listeners = new Set();
    const changed = (what, extra) => { for (const fn of listeners) fn(what, extra); };

    function save() {
      lastSave = performance.now();
      send({type: 'market', state: {clock: Math.floor(state.clock), crate: {...state.crate}, placed: state.placed.map(p => ({...p})), warned: state.warned, pet: state.pet}});
    }

    // He brings one pet each visit, never the same one twice running.
    function choosePet() {
      const others = pets.filter(p => p !== state.pet);
      state.pet = others.length ? others[Math.floor(Math.random() * others.length)] : state.pet;
    }

    const market = {
      state,
      CYCLE, STAY, ARRIVE, WARN,
      get loaded() { return loaded; },
      get present() { return state.clock >= ARRIVE; },
      get pet() { return state.pet; },
      onChange(fn) { listeners.add(fn); },

      load(saved) {
        Object.assign(state, clean(saved, ids, pets));
        loaded = true;
        if (market.present && !state.pet) { choosePet(); save(); }
        changed('load');
      },

      // Counts `seconds` of the hall being open: he arrives when the clock
      // passes the half hour and is gone when it comes round.
      tick(seconds) {
        if (!loaded || !(seconds > 0)) return;
        const was = market.present;
        state.clock += seconds;
        let event = null;
        if (state.clock >= CYCLE) {
          state.clock %= CYCLE;
          event = was ? 'leave' : null;
          state.warned = false;
        } else if (!was && market.present) {
          event = 'arrive';
          state.warned = false;
          choosePet();
        }
        if (market.present && !state.warned && market.leavesIn() <= WARN) {
          state.warned = true;
          save();
          changed('warn');
        }
        if (event) { save(); changed(event); } else if (performance.now() - lastSave > 15000) save();
      },

      // Seconds until he comes, or until he goes.
      nextIn: () => (market.present ? 0 : ARRIVE - state.clock),
      leavesIn: () => (market.present ? CYCLE - state.clock : 0),

      count: id => state.crate[id] || 0,
      crateTotal: () => Object.values(state.crate).reduce((a, n) => a + n, 0),
      placedCount: id => state.placed.filter(p => p.id === id).length,

      // Buys one of `id` with the post's coins. Returns false when he isn't
      // here or the reader can't afford it.
      buy(id, post) {
        const item = items[id];
        if (!item || !market.present || market.count(id) >= MAX_STACK) return false;
        if (!post.spend(item.price)) return false;
        state.crate[id] = market.count(id) + 1;
        save();
        changed('crate', id);
        return true;
      },

      // Takes one out of the crate and stands it at `piece`.
      place(piece) {
        if (!market.count(piece.id) || state.placed.length >= MAX_PIECES) return null;
        state.crate[piece.id]--;
        if (!state.crate[piece.id]) delete state.crate[piece.id];
        const p = {id: piece.id, x: piece.x, z: piece.z, floor: piece.floor, rot: piece.rot};
        state.placed.push(p);
        save();
        changed('placed', p);
        return p;
      },

      // Puts a placed piece back in the crate.
      pickUp(piece) {
        const i = state.placed.indexOf(piece);
        if (i < 0) return false;
        state.placed.splice(i, 1);
        state.crate[piece.id] = Math.min(MAX_STACK, market.count(piece.id) + 1);
        save();
        changed('picked', piece);
        return true;
      },

      save,
    };

    // ── The shop ─────────────────────────────────────────────────────────
    // The trader's goods down the left, the one picked on the right with
    // its price, and the reader's coins along the bottom.
    let shop = null;
    function showShop({gui, post, pictures, coin, select}) {
      return new Promise(resolve => {
        shop = {resolve, gui, post, pictures, coin, picked: select && items[select] ? select : catalog[0].id};
        $('shop').hidden = false;
        $('shop-title').textContent = gui.t('traderName');
        $('shop-done').textContent = gui.t('done');
        $('shop-coin').src = coin;
        $('shop-wallet-coin').src = coin;
        const list = $('shop-list');
        list.replaceChildren(...catalog.map(item => {
          const b = document.createElement('button');
          b.type = 'button';
          b.className = 'trade';
          b.dataset.id = item.id;
          b.setAttribute('role', 'option');
          const img = document.createElement('img');
          img.alt = '';
          img.src = pictures[item.id] || '';
          const name = document.createElement('span');
          name.className = 'name';
          name.textContent = gui.t('item_' + item.id);
          const price = document.createElement('span');
          price.className = 'price';
          const c = document.createElement('img');
          c.alt = '';
          c.src = coin;
          price.append(String(item.price), c);
          b.append(img, name, price);
          b.onclick = () => pick(item.id);
          return b;
        }));
        refreshShop();
        setTimeout(() => list.querySelector(`[data-id="${shop?.picked}"]`)?.focus(), 30);
      });
    }

    function pick(id) {
      if (!shop) return;
      shop.picked = id;
      refreshShop();
    }

    function refreshShop() {
      if (!shop) return;
      const {gui, post, pictures} = shop;
      const item = items[shop.picked];
      const money = post.state.hand + post.state.vault;
      for (const b of $('shop-list').children) {
        const on = b.dataset.id === item.id;
        b.classList.toggle('on', on);
        b.setAttribute('aria-selected', String(on));
        b.classList.toggle('dear', items[b.dataset.id].price > money);
      }
      $('shop-picture').src = pictures[item.id] || '';
      $('shop-name').textContent = gui.t('item_' + item.id);
      $('shop-where').textContent = gui.t({inside: 'whereInside', outside: 'whereOutside', both: 'whereBoth'}[item.where]);
      $('shop-desc').textContent = gui.t('desc_' + item.id);
      $('shop-cost').textContent = String(item.price);
      const owned = market.count(item.id), placed = market.placedCount(item.id);
      $('shop-owned').textContent = [owned ? gui.t('shopOwned', owned) : '', placed ? gui.t('shopPlaced', placed) : ''].filter(Boolean).join(' · ');
      $('shop-owned').hidden = !owned && !placed;
      const afford = money >= item.price;
      const buy = $('shop-buy');
      buy.disabled = !afford || !market.present;
      buy.textContent = afford ? gui.t('shopBuy', item.price) : gui.t('shopTooPoor');
      $('shop-wallet').textContent = gui.t('shopWallet', money, post.state.hand, post.state.vault);
      const left = Math.max(1, Math.ceil(market.leavesIn() / 60));
      $('shop-timer').textContent = market.present ? gui.t('shopLeaves', left) : '';
    }

    function buyPicked() {
      if (!shop) return;
      const id = shop.picked;
      if (!market.buy(id, shop.post)) { refreshShop(); return; }
      const row = $('shop-list').querySelector(`[data-id="${id}"]`);
      if (row && !reducedMotion()) { row.classList.remove('sold'); void row.offsetWidth; row.classList.add('sold'); }
      shop.onBought?.(id);
      refreshShop();
    }

    function closeShop() {
      if (!shop) return;
      const done = shop.resolve;
      shop = null;
      $('shop').hidden = true;
      done();
    }

    // Keyboard: arrows move through the goods, Enter buys, Esc leaves.
    function onKey(e) {
      if (!shop) return;
      if (e.key === 'Escape') { e.stopPropagation(); closeShop(); return; }
      const i = catalog.findIndex(c => c.id === shop.picked);
      if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
        e.preventDefault();
        const next = catalog[(i + (e.key === 'ArrowDown' ? 1 : catalog.length - 1)) % catalog.length].id;
        pick(next);
        $('shop-list').querySelector(`[data-id="${next}"]`)?.focus();
      }
    }

    if ($('shop')) {
      $('shop-buy').onclick = buyPicked;
      $('shop-done').onclick = closeShop;
      $('shop').addEventListener('keydown', onKey);
    }

    Object.assign(market, {
      showShop, closeShop, refreshShop,
      onBought(fn) { if (shop) shop.onBought = fn; },
    });
    Object.defineProperties(market, {
      shopOpen: {get: () => !!shop},
    });
    return market;
  }

  window.LibraryMarket = {create, clean, CYCLE, STAY, ARRIVE, WARN};
})();
