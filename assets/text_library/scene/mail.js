// The post and the vault. For every half hour the hall is open, a letter
// comes to the mailbox by the front path with 10 to 30 coins in it. Taken out
// and read, the coins are in the reader's hand until they put them in the
// vault in the reading room. The app keeps the count; this page only times
// it and draws it.
(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const gui = window.LibraryGui;

  const MAIL_EVERY = 1800;
  // Letters left in the box pile up to this many; past it the post waits.
  const MAX_LETTERS = 9;
  const MIN_COINS = 10, MAX_COINS = 30;

  const whole = v => (Number.isFinite(Number(v)) ? Math.max(0, Math.floor(Number(v))) : 0);
  // A book review takes one in-game day (the hall's twenty-minute day) to
  // come back, and the reviewer reads one book at a time.
  const REVIEW_WAIT = 1200;
  const MAX_REVIEWED = 500;
  const text = (v, max) => (typeof v === 'string' ? v.slice(0, max) : '');

  // A letter is a number of coins, or a book review: what the reviewer
  // thought, the coins it earned and, when it earned none, the tips.
  function cleanLetter(v) {
    if (typeof v === 'number' || typeof v === 'string') return whole(v) > 0 ? whole(v) : null;
    if (!v || typeof v !== 'object' || v.kind !== 'review') return null;
    return {
      kind: 'review', title: text(v.title, 64), coins: Math.min(50, whole(v.coins)), good: !!v.good,
      verdict: text(v.verdict, 120), praise: text(v.praise, 400),
      tips: (Array.isArray(v.tips) ? v.tips : []).map(t => text(t, 300)).filter(Boolean).slice(0, 4),
    };
  }
  const letterCoins = l => (typeof l === 'number' ? l : l.coins || 0);

  // A gold coin, painted pixel by pixel like an item icon.
  function paintCoin() {
    const c = document.createElement('canvas');
    c.width = 16; c.height = 16;
    const x = c.getContext('2d');
    for (let py = 0; py < 16; py++) for (let px = 0; px < 16; px++) {
      const d = Math.hypot(px - 7.5, py - 7.5);
      if (d > 6.9) continue;
      let col = '#f2c230';
      if (d > 5.9) col = '#8a5a12';
      else if (d > 4.9) col = px + py < 14 ? '#ffe68a' : '#c98f1c';
      else if (px + py < 11) col = '#ffd84a';
      x.fillStyle = col;
      x.fillRect(px, py, 1, 1);
    }
    x.fillStyle = '#c98f1c';
    x.fillRect(7, 5, 2, 6); x.fillRect(6, 5, 1, 1); x.fillRect(9, 10, 1, 1);
    return c.toDataURL();
  }

  function create({send, reducedMotion}) {
    const state = {open: 0, letters: [], hand: 0, vault: 0, reviews: [], reviewed: {}};
    let loaded = false, lastSave = 0;
    const coin = paintCoin();
    const listeners = new Set();
    const changed = what => { for (const fn of listeners) fn(what); };

    function save() {
      lastSave = performance.now();
      send({type: 'mail', state: {
        open: Math.floor(state.open), letters: state.letters.slice(), hand: state.hand, vault: state.vault,
        reviews: state.reviews.map(r => ({wait: Math.ceil(r.wait), letter: r.letter})), reviewed: {...state.reviewed},
      }});
    }

    const post = {
      state,
      coin,
      MAIL_EVERY,
      get loaded() { return loaded; },
      onChange(fn) { listeners.add(fn); },

      // What the app kept, or nothing on a first visit.
      load(saved) {
        const s = saved && typeof saved === 'object' ? saved : {};
        state.open = Math.min(MAIL_EVERY, whole(s.open));
        state.letters = (Array.isArray(s.letters) ? s.letters : []).map(cleanLetter).filter(Boolean).slice(0, MAX_LETTERS);
        state.hand = whole(s.hand);
        state.vault = whole(s.vault);
        state.reviews = (Array.isArray(s.reviews) ? s.reviews : [])
          .map(r => ({wait: Math.min(REVIEW_WAIT, whole(r?.wait)), letter: cleanLetter(r?.letter)}))
          .filter(r => r.letter && typeof r.letter === 'object').slice(0, 1);
        state.reviewed = {};
        if (s.reviewed && typeof s.reviewed === 'object') {
          for (const [id, r] of Object.entries(s.reviewed).slice(-MAX_REVIEWED)) {
            if (/^\d+$/.test(id) && r && typeof r.h === 'string') state.reviewed[id] = {h: r.h.slice(0, 16), paid: Math.min(50, whole(r.paid))};
          }
        }
        loaded = true;
        changed('load');
      },

      // Counts `seconds` of the hall being open; a letter comes in for each
      // half hour of it.
      tick(seconds) {
        if (!loaded || !(seconds > 0)) return;
        state.open += seconds;
        let arrived = 0;
        while (state.open >= MAIL_EVERY) {
          if (state.letters.length >= MAX_LETTERS) { state.open = MAIL_EVERY; break; }
          state.open -= MAIL_EVERY;
          state.letters.push(MIN_COINS + Math.floor(Math.random() * (MAX_COINS - MIN_COINS + 1)));
          arrived++;
        }
        // A review waiting on the reviewer comes in a day after it was sent.
        let reviewed = 0;
        for (const r of state.reviews) r.wait -= seconds;
        while (state.reviews.length && state.reviews[0].wait <= 0 && state.letters.length < MAX_LETTERS) {
          state.letters.push(state.reviews.shift().letter);
          reviewed++;
        }
        if (arrived || reviewed) { save(); changed(reviewed ? 'review' : 'arrived'); } else if (performance.now() - lastSave > 15000) save();
      },

      // Seconds until the next letter comes.
      nextIn: () => Math.max(0, MAIL_EVERY - state.open),

      // The first letter's coins go into the hand.
      takeLetter() {
        if (!state.letters.length) return 0;
        const amount = letterCoins(state.letters.shift());
        state.hand += amount;
        save();
        changed('hand');
        return amount;
      },

      // Everything in the hand goes into the vault.
      deposit() {
        const amount = state.hand;
        if (!amount) return 0;
        state.vault += amount;
        state.hand = 0;
        save();
        changed('vault');
        return amount;
      },

      // Pays `amount`: from the coins in hand first, the rest out of the
      // vault. Spends nothing and returns false when there isn't enough.
      spend(amount) {
        const n = whole(amount);
        if (!n || state.hand + state.vault < n) return false;
        const fromHand = Math.min(state.hand, n);
        state.hand -= fromHand;
        state.vault -= n - fromHand;
        save();
        changed('spend');
        return true;
      },

      // The book waiting on the reviewer, if there is one, and how long its
      // letter still takes.
      get pendingReview() { return state.reviews[0] || null; },

      // Whether a book exactly as it is now was already reviewed.
      wasReviewed: (id, hash) => state.reviewed[id]?.h === hash,

      // Files the reviewer's answer for book `id` (its text hashed to
      // `hash`); its letter comes a day later. A book is paid once for its
      // best review, so sending it again pays only what a better score adds.
      queueReview(id, hash, title, result) {
        if (state.reviews.length) return false;
        const earned = Math.min(50, whole(result.coins));
        const before = state.reviewed[id]?.paid || 0;
        const coins = Math.max(0, earned - before);
        const letter = cleanLetter({
          kind: 'review', title, coins, good: earned > 0, verdict: result.verdict, praise: result.praise,
          tips: coins > 0 ? [] : result.tips,
        });
        state.reviews.push({wait: REVIEW_WAIT, letter});
        delete state.reviewed[id];
        state.reviewed[id] = {h: hash, paid: Math.max(before, earned)};
        const ids = Object.keys(state.reviewed);
        if (ids.length > MAX_REVIEWED) delete state.reviewed[ids[0]];
        save();
        changed('reviewing');
        return true;
      },

      save,
    };

    // ── The letter ───────────────────────────────────────────────────────
    // Out of the box it comes up big as an envelope; opened, the letter
    // itself, with the coins to take.
    let letter = null;
    const screen = $('letter');
    // What a review letter says: the verdict and praise, then either nothing
    // more (its coins are enclosed) or the tips.
    function reviewBody(r) {
      const lines = [r.verdict, r.praise].filter(Boolean);
      if (r.good && !r.coins) lines.push(gui.t('reviewNoBetter'));
      if (r.tips.length) lines.push('', gui.t('reviewTips'), ...r.tips.map(t => '- ' + t));
      return lines.join('\n');
    }
    function showLetter(item) {
      const review = item && typeof item === 'object' ? item : null;
      const amount = review ? review.coins : item;
      return new Promise(resolve => {
        letter = {amount, resolve};
        screen.hidden = false;
        screen.classList.remove('opened');
        $('letter-paper').hidden = true;
        $('envelope').hidden = false;
        $('envelope-hint').textContent = gui.t('letterOpen');
        $('letter-take').hidden = true;
        $('letter-title').textContent = review ? gui.t('reviewTitle', review.title || gui.t('untitled')) : gui.t('letterTitle');
        $('letter-body').textContent = review ? reviewBody(review) : gui.t('letterBody');
        $('letter-sign').textContent = gui.t(review ? 'reviewSign' : 'letterSign');
        $('letter-coin').src = coin;
        $('letter-sum').textContent = gui.t('coins', amount);
        $('letter-coin').parentElement.hidden = !amount;
        $('letter-take').textContent = gui.t(amount ? 'letterTake' : 'reviewThanks');
        $('envelope').setAttribute('aria-label', gui.t('letterOpen'));
        setTimeout(() => $('envelope').focus(), 30);
      });
    }
    function openEnvelope() {
      if (!letter) return;
      screen.classList.add('opened');
      const reveal = () => {
        if (!letter) return;
        $('envelope').hidden = true;
        $('letter-paper').hidden = false;
        $('letter-take').hidden = false;
        $('letter-take').focus();
      };
      setTimeout(reveal, reducedMotion() ? 0 : 380);
    }
    function closeLetter(took) {
      if (!letter) return;
      const done = letter.resolve;
      letter = null;
      const finish = () => { screen.hidden = true; screen.classList.remove('leaving', 'opened'); done(took); };
      if (took && !reducedMotion()) {
        screen.classList.add('leaving');
        setTimeout(finish, 320);
      } else finish();
    }
    $('envelope').onclick = openEnvelope;
    $('letter-take').onclick = () => closeLetter(true);
    screen.addEventListener('keydown', e => {
      if (e.key !== 'Escape') return;
      e.stopPropagation();
      closeLetter(false);
    });

    // ── The vault ────────────────────────────────────────────────────────
    let vaultDone = null;
    function showVault(deposited) {
      return new Promise(resolve => {
        vaultDone = resolve;
        $('vault-title').textContent = gui.t('vault');
        $('vault-coin').src = coin;
        $('vault-sum').textContent = String(state.vault);
        $('vault-unit').textContent = gui.t('coins', '').trim();
        $('vault-note').textContent = deposited ? gui.t('vaultDeposited', deposited) : state.vault ? '' : gui.t('vaultEmpty');
        $('vault-note').hidden = !$('vault-note').textContent;
        $('vault-done').textContent = gui.t('done');
        $('vault').hidden = false;
        // Count up to the new total.
        if (deposited && !reducedMotion()) {
          const from = state.vault - deposited, t0 = performance.now();
          const step = () => {
            if ($('vault').hidden) return;
            const k = Math.min(1, (performance.now() - t0) / 700);
            $('vault-sum').textContent = String(Math.round(from + deposited * (1 - (1 - k) ** 3)));
            if (k < 1) requestAnimationFrame(step);
          };
          step();
        }
        setTimeout(() => $('vault-done').focus(), 30);
      });
    }
    function closeVault() {
      if (!vaultDone) return;
      const done = vaultDone;
      vaultDone = null;
      $('vault').hidden = true;
      done();
    }
    $('vault-done').onclick = closeVault;
    $('vault').addEventListener('keydown', e => {
      if (e.key !== 'Escape') return;
      e.stopPropagation();
      closeVault();
    });

    // The coins in hand, as the game shows a stack in the hotbar.
    function refreshPurse(shown) {
      const purse = $('purse');
      purse.hidden = !(shown && state.hand > 0);
      $('purse-coin').src = coin;
      $('purse-count').textContent = String(state.hand);
      purse.setAttribute('aria-label', gui.t('coins', state.hand));
    }

    Object.assign(post, {showLetter, showVault, refreshPurse});
    // Getters, so they're defined rather than copied as values.
    Object.defineProperties(post, {
      letterOpen: {get: () => !!letter},
      vaultOpen: {get: () => !!vaultDone},
    });
    return post;
  }

  window.LibraryMail = {create, MAIL_EVERY, MAX_LETTERS, MIN_COINS, MAX_COINS};
})();
