// The HUD around the 3D hall: GUI scale, strings, tooltip, action bar,
// toasts, the name dialog and the settings screen.
(() => {
  'use strict';
  const $ = id => document.getElementById(id);

  // English defaults for running the page on its own; the app sends the
  // user's language in `init`.
  const STRINGS = {
    loading: 'Building your library…', newCase: 'New bookcase', newCaseTitle: 'Name your bookcase', nameHint: 'Subject name',
    build: 'Build', cancel: 'Cancel', back: 'Back', emptySlot: 'Empty slot · click to write a book', page: 'Page {0} of {1}',
    shelfPage: 'Shelf {0} of {1}', books: 'Books: {0}', done: 'Done', sign: 'Sign', signTitle: 'Enter Book Title:', spine: 'Spine',
    spineHint: "Written on the book's spine", cover: 'Cover', signAndShelve: 'Sign and shelve', chooseSlot: 'Choose a slot for your book',
    burn: 'Throw in the fire', burnConfirm: "Burn this book? It can't be taken back out.", bold: 'Bold (Ctrl+B)', italic: 'Italic (Ctrl+I)',
    underline: 'Underline (Ctrl+U)', strike: 'Strikethrough', ink: 'Ink colour', clear: 'Clear formatting', vanilla: 'Textures from {0}',
    builtIn: "Using luma's built-in look-alike textures", download: 'Use vanilla textures',
    downloadNote: 'Downloads the Minecraft client from Mojang once (about 30 MB) and reads its textures. Nothing is uploaded.',
    downloadFailed: "Couldn't fetch the textures. Check your connection and try again.", quality: 'Graphics', qualityLow: 'Fast',
    qualityHigh: 'Fancy', settings: 'Settings', emptyHall: 'Click the empty bookcase to build your first subject',
    advancement: 'Advancement Made!', firstCase: 'Librarian', firstBook: 'Bookworm', rename: 'Rename', untitled: 'Untitled',
    writeHint: 'Ctrl+B bold · Ctrl+I italic · Ctrl+U underline · PgUp/PgDn turn pages',
    moveHint: 'Click a slot to put the book there · Esc to cancel', saveFailed: "That didn't save. Try again.",
  };

  const MC_COLORS = [
    ['black', '#000000'], ['dark_blue', '#0000AA'], ['dark_green', '#00AA00'], ['dark_aqua', '#00AAAA'],
    ['dark_red', '#AA0000'], ['dark_purple', '#AA00AA'], ['gold', '#FFAA00'], ['gray', '#AAAAAA'],
    ['dark_gray', '#555555'], ['blue', '#5555FF'], ['green', '#55FF55'], ['aqua', '#55FFFF'],
    ['red', '#FF5555'], ['light_purple', '#FF55FF'], ['yellow', '#FFFF55'], ['white', '#FFFFFF'],
  ];

  const gui = {
    strings: {...STRINGS},
    scale: 2,
    sprites: {},
    MC_COLORS,

    t(key, ...args) {
      let s = gui.strings[key] ?? STRINGS[key] ?? key;
      args.forEach((a, i) => { s = s.replace(`{${i}}`, a); });
      return s;
    },

    setStrings(strings) {
      Object.assign(gui.strings, strings || {});
      document.documentElement.lang = navigator.language || 'en';
      gui.relabel();
    },

    relabel() {
      $('loading-text').textContent = gui.t('loading');
      $('back').textContent = gui.t('back');
      $('settings-open').setAttribute('aria-label', gui.t('settings'));
      $('settings-open').title = gui.t('settings');
      $('settings-title').textContent = gui.t('settings');
      $('settings-done').textContent = gui.t('done');
      $('download').textContent = gui.t('download');
      $('download-note').textContent = gui.t('downloadNote');
      $('case-prev').setAttribute('aria-label', gui.t('back'));
      for (const b of document.querySelectorAll('[data-cmd]')) {
        const key = {bold: 'bold', italic: 'italic', underline: 'underline', strikeThrough: 'strike', clear: 'clear'}[b.dataset.cmd];
        b.title = gui.t(key);
        b.setAttribute('aria-label', gui.t(key));
      }
      $('ink').setAttribute('aria-label', gui.t('ink'));
    },

    // Integer GUI scale like the game's "Auto": as big as fits.
    rescale() {
      const w = innerWidth, h = innerHeight;
      // Whole steps like the game on big screens; phones get a half step so
      // the text stays readable.
      const raw = Math.min(w / 240, h / 250);
      const s = Math.min(4, raw >= 2 ? Math.floor(Math.min(w / 330, h / 250)) || 2 : Math.max(1, Math.floor(raw * 2) / 2));
      gui.scale = s;
      document.documentElement.style.setProperty('--g', s);
    },

    // Wires vanilla GUI sprites in as CSS custom properties.
    applySprites(files) {
      const url = path => (files[path] ? `url(data:image/png;base64,${files[path]})` : null);
      const root = document.documentElement.style;
      const map = {
        '--btn': 'textures/gui/sprites/widget/button.png',
        '--btn-hover': 'textures/gui/sprites/widget/button_highlighted.png',
        '--btn-off': 'textures/gui/sprites/widget/button_disabled.png',
        '--book': 'textures/gui/book.png',
        '--arrow-fwd': 'textures/gui/sprites/widget/page_forward.png',
        '--arrow-fwd-hover': 'textures/gui/sprites/widget/page_forward_highlighted.png',
        '--arrow-back': 'textures/gui/sprites/widget/page_backward.png',
        '--arrow-back-hover': 'textures/gui/sprites/widget/page_backward_highlighted.png',
        '--toast': 'textures/gui/sprites/toast/advancement.png',
      };
      const have = {};
      for (const [prop, path] of Object.entries(map)) {
        const u = url(path);
        if (u) { root.setProperty(prop, u); have[prop] = true; }
      }
      gui.sprites = have;
      for (const b of document.querySelectorAll('.mc-button')) b.classList.toggle('sprite', !!have['--btn'] && !b.classList.contains('tool'));
      for (const p of document.querySelectorAll('.mc-page')) p.classList.toggle('drawn', !have['--arrow-fwd']);
    },

    // A procedural book background for when there is no vanilla one.
    paintBook() {
      if (gui.sprites['--book']) return;
      const c = document.createElement('canvas');
      c.width = 256; c.height = 256;
      const x = c.getContext('2d');
      const r = LibraryTextures.rng('bookgui');
      // Leather cover.
      x.fillStyle = '#3b1d0e'; x.fillRect(19, 1, 150, 180);
      x.fillStyle = '#6e3a1c'; x.fillRect(20, 2, 148, 178);
      x.fillStyle = '#8d4d27'; x.fillRect(21, 3, 146, 3);
      // Pages.
      for (let py = 7; py < 176; py++) for (let px = 25; px < 162; px++) {
        const edge = px > 156 ? 0.9 : 1;
        const f = (0.93 + r() * 0.07) * edge;
        x.fillStyle = `rgb(${Math.round(248 * f)},${Math.round(240 * f)},${Math.round(214 * f)})`;
        x.fillRect(px, py, 1, 1);
      }
      x.fillStyle = '#c9b88f'; x.fillRect(25, 7, 1, 169); x.fillRect(161, 7, 1, 169);
      // Red stitching down the spine side.
      x.fillStyle = '#b3261e';
      for (let sy = 10; sy < 170; sy += 8) x.fillRect(27, sy, 1, 5);
      document.documentElement.style.setProperty('--book', `url(${c.toDataURL()})`);
    },

    tooltip(lines, x, y) {
      const tip = $('tooltip');
      if (!lines) { tip.hidden = true; return; }
      tip.replaceChildren(...lines.map((line, i) => {
        const div = document.createElement('div');
        div.textContent = line.text ?? line;
        if (line.cls) div.className = line.cls;
        else if (i > 0) div.className = 'sub';
        return div;
      }));
      tip.hidden = false;
      const g = gui.scale;
      const w = tip.offsetWidth, h = tip.offsetHeight;
      let left = x + 12 * g, top = y - 12 * g;
      if (left + w > innerWidth - 4) left = x - w - 12 * g;
      if (top + h > innerHeight - 4) top = innerHeight - h - 4;
      tip.style.transform = `translate(${Math.max(4, left)}px, ${Math.max(4, top)}px)`;
    },

    heading(title, subtitle) {
      $('title').textContent = title || '';
      $('subtitle').textContent = subtitle || '';
      $('heading').classList.toggle('hidden', !title);
    },

    actionbar(text) {
      const bar = $('actionbar');
      if (text) bar.textContent = text;
      bar.classList.toggle('hidden', !text);
    },

    toast(title, body, icon) {
      const el = document.createElement('div');
      el.className = 'mc-toast' + (gui.sprites['--toast'] ? ' sprite' : '');
      const img = document.createElement('img');
      img.alt = '';
      if (icon) img.src = icon;
      const text = document.createElement('div');
      const t1 = document.createElement('div'); t1.className = 't1'; t1.textContent = title;
      const t2 = document.createElement('div'); t2.className = 't2'; t2.textContent = body;
      text.append(t1, t2);
      el.append(img, text);
      $('toasts').append(el);
      setTimeout(() => el.remove(), 5200);
    },

    // Asks for a bookcase name (and colour). Resolves to {name, color} or
    // null when cancelled.
    askName({title, value = '', color = 14, okLabel}) {
      return new Promise(resolve => {
        const dialog = $('dialog'), input = $('dialog-input'), form = dialog.querySelector('form');
        $('dialog-title').textContent = title;
        $('dialog-ok').textContent = okLabel || gui.t('build');
        $('dialog-cancel').textContent = gui.t('cancel');
        input.placeholder = gui.t('nameHint');
        input.value = value;
        let chosen = color;
        const colors = $('dialog-colors');
        colors.replaceChildren(...LibraryWorld.DYES.map((c, i) => {
          const b = document.createElement('button');
          b.type = 'button'; b.className = 'swatch'; b.setAttribute('role', 'radio');
          b.style.background = `rgb(${c.join(',')})`;
          b.setAttribute('aria-checked', String(i === chosen));
          b.setAttribute('aria-label', String(i + 1));
          b.onclick = () => { chosen = i; for (const s of colors.children) s.setAttribute('aria-checked', String(s === b)); };
          return b;
        }));
        dialog.hidden = false;
        setTimeout(() => input.focus(), 30);
        const finish = result => {
          dialog.hidden = true;
          form.onsubmit = null; $('dialog-cancel').onclick = null; dialog.onkeydown = null;
          resolve(result);
        };
        form.onsubmit = e => {
          e.preventDefault();
          const name = input.value.trim();
          if (!name) { input.focus(); return; }
          finish({name, color: chosen});
        };
        $('dialog-cancel').onclick = () => finish(null);
        dialog.onkeydown = e => { if (e.key === 'Escape') { e.stopPropagation(); finish(null); } };
      });
    },

    isModalOpen() {
      return !$('dialog').hidden || !$('settings').hidden;
    },
  };

  gui.relabel();
  window.LibraryGui = gui;
})();
