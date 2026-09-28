// The book and quill: an editor laid out like the game's book screen, and
// the signing screen that names the book, labels its spine and picks its
// cover.
//
// Bodies are the same JSON the app stores ({v:1, spans:[{t,b,i,u,s,c}]}), so
// what is written here reads identically in the classic view.
(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const gui = LibraryGui;
  const flow = $('book-flow'), viewport = $('book-viewport');

  let handlers = null;
  let page = 0, pages = 1;
  let mode = 'edit';
  let cover = 12;
  let inputTimer = null;

  // ── Serialising ────────────────────────────────────────────────────────
  const COLOR_BY_HEX = new Map(gui.MC_COLORS.map(([id, hex]) => [hex.toLowerCase(), id]));
  const HEX_BY_ID = new Map(gui.MC_COLORS.map(([id, hex]) => [id, hex]));

  function colorId(css) {
    const m = /rgba?\((\d+),\s*(\d+),\s*(\d+)/.exec(css || '');
    if (!m) return null;
    const rgb = [+m[1], +m[2], +m[3]];
    const hex = '#' + rgb.map(v => v.toString(16).padStart(2, '0')).join('');
    let id = COLOR_BY_HEX.get(hex);
    if (!id) {
      let best = Infinity;
      for (const [cid, h] of gui.MC_COLORS) {
        const c = [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
        const d = (c[0] - rgb[0]) ** 2 + (c[1] - rgb[1]) ** 2 + (c[2] - rgb[2]) ** 2;
        if (d < best) { best = d; id = cid; }
      }
    }
    return id === 'black' ? null : id;
  }

  function styleOf(el) {
    const cs = getComputedStyle(el);
    let u = false, s = false;
    for (let n = el; n && n !== flow.parentNode; n = n.parentElement) {
      const line = getComputedStyle(n).textDecorationLine || '';
      if (line.includes('underline')) u = true;
      if (line.includes('line-through')) s = true;
      if (n === flow) break;
    }
    const st = {};
    if (parseInt(cs.fontWeight, 10) >= 600) st.b = true;
    if (cs.fontStyle === 'italic' || cs.fontStyle.startsWith('oblique')) st.i = true;
    if (u) st.u = true;
    if (s) st.s = true;
    const c = colorId(cs.color);
    if (c) st.c = c;
    return st;
  }

  const BLOCKS = new Set(['DIV', 'P', 'LI', 'H1', 'H2', 'H3', 'BLOCKQUOTE']);

  function serialize() {
    const spans = [];
    const push = (t, st) => {
      if (!t) return;
      const last = spans[spans.length - 1];
      const key = JSON.stringify(st);
      if (last && last.key === key) last.t += t;
      else spans.push({t, key, st});
    };
    const text = () => spans.map(s => s.t).join('');
    const walk = node => {
      for (const child of node.childNodes) {
        if (child.nodeType === Node.TEXT_NODE) {
          push(child.data.replace(/ /g, ' '), styleOf(child.parentElement));
        } else if (child.nodeName === 'BR') {
          // A <br> that only props open an otherwise filled block is not a
          // line of its own.
          const parent = child.parentElement;
          const isLast = !child.nextSibling;
          const blockHasText = parent !== flow && BLOCKS.has(parent.nodeName) && parent.textContent.length > 0;
          if (isLast && blockHasText) continue;
          push('\n', styleOf(parent));
        } else if (child.nodeType === Node.ELEMENT_NODE) {
          const block = BLOCKS.has(child.nodeName);
          if (block && text().length && !text().endsWith('\n')) push('\n', {});
          walk(child);
        }
      }
    };
    walk(flow);
    // One trailing newline is just the editor's end-of-text placeholder.
    const out = spans.map(({t, st}) => ({t, ...st}));
    if (out.length && out[out.length - 1].t.endsWith('\n')) {
      out[out.length - 1].t = out[out.length - 1].t.slice(0, -1);
      if (!out[out.length - 1].t) out.pop();
    }
    return JSON.stringify({v: 1, spans: out});
  }

  function parseBody(json) {
    if (!json) return [];
    try {
      const v = JSON.parse(json);
      if (v && Array.isArray(v.spans)) return v.spans.filter(s => typeof s.t === 'string');
    } catch {
      // Plain text body.
    }
    return [{t: String(json)}];
  }

  function render(json) {
    const frag = document.createDocumentFragment();
    for (const span of parseBody(json)) {
      const parts = span.t.split('\n');
      parts.forEach((part, i) => {
        if (i > 0) frag.append(document.createElement('br'));
        if (!part) return;
        const styled = span.b || span.i || span.u || span.s || span.c;
        if (!styled) { frag.append(part); return; }
        const el = document.createElement('span');
        if (span.b) el.style.fontWeight = '700';
        if (span.i) el.style.fontStyle = 'italic';
        const deco = [span.u && 'underline', span.s && 'line-through'].filter(Boolean).join(' ');
        if (deco) el.style.textDecoration = deco;
        if (span.c && HEX_BY_ID.has(span.c)) el.style.color = HEX_BY_ID.get(span.c);
        el.textContent = part;
        frag.append(el);
      });
    }
    flow.replaceChildren(frag);
    if (flow.lastChild && flow.lastChild.nodeName === 'BR') flow.append(document.createElement('br'));
  }

  const plainText = json => parseBody(json).map(s => s.t).join('');

  // ── Paging ─────────────────────────────────────────────────────────────
  const stride = () => (116 + 20) * gui.scale;

  function measure() {
    pages = Math.max(1, Math.round((flow.scrollWidth + 20 * gui.scale) / stride()));
    if (page >= pages) setPage(pages - 1);
    updateIndicator();
  }

  function setPage(n) {
    page = Math.max(0, Math.min(n, pages - 1));
    viewport.scrollLeft = page * stride();
    updateIndicator();
  }

  function updateIndicator() {
    $('book-page').textContent = mode === 'edit' ? gui.t('page', page + 1, pages) : '';
    $('book-prev').disabled = page <= 0 || mode !== 'edit';
    $('book-next').disabled = mode !== 'edit' || page >= pages - 1;
  }

  // The browser scrolls to the caret on its own, to arbitrary offsets; snap
  // to whichever page the caret is on.
  function followCaret() {
    const sel = getSelection();
    if (!sel.rangeCount || !flow.contains(sel.focusNode)) return;
    const range = sel.getRangeAt(0).cloneRange();
    range.collapse(false);
    let rect = range.getClientRects()[0];
    if (!rect && sel.focusNode.nodeType === Node.ELEMENT_NODE) rect = sel.focusNode.getBoundingClientRect?.();
    if (!rect) return;
    const vp = viewport.getBoundingClientRect();
    const x = rect.left - vp.left + viewport.scrollLeft;
    const target = Math.floor((x + 2) / stride());
    if (target !== page) setPage(target);
  }
  viewport.addEventListener('scroll', () => {
    const snapped = page * stride();
    if (Math.abs(viewport.scrollLeft - snapped) > 1) viewport.scrollLeft = snapped;
  });

  // ── Formatting ─────────────────────────────────────────────────────────
  function command(cmd, value) {
    flow.focus();
    document.execCommand('styleWithCSS', false, true);
    if (cmd === 'clear') {
      document.execCommand('removeFormat');
      document.execCommand('foreColor', false, '#000000');
    } else {
      document.execCommand(cmd, false, value);
    }
    changed();
    refreshTools();
  }

  function refreshTools() {
    if (mode !== 'edit') return;
    for (const b of document.querySelectorAll('#tools [data-cmd]')) {
      if (b.dataset.cmd === 'clear') continue;
      let on = false;
      try { on = document.queryCommandState(b.dataset.cmd); } catch { on = false; }
      b.classList.toggle('on', on);
      b.setAttribute('aria-pressed', String(on));
    }
    let current = null;
    try { current = colorId(document.queryCommandValue('foreColor')); } catch { current = null; }
    for (const slot of $('ink').children) slot.setAttribute('aria-checked', String((slot.dataset.color || null) === (current || 'black')));
  }

  function buildInk() {
    $('ink').replaceChildren(...gui.MC_COLORS.map(([id, hex]) => {
      const b = document.createElement('button');
      b.type = 'button'; b.className = 'slot'; b.dataset.color = id;
      b.setAttribute('role', 'radio');
      b.setAttribute('aria-label', id.replace('_', ' '));
      b.title = id.replace('_', ' ');
      const i = document.createElement('i');
      i.style.background = hex;
      b.append(i);
      b.addEventListener('mousedown', e => e.preventDefault());
      b.onclick = () => command('foreColor', hex);
      return b;
    }));
  }

  function buildCovers() {
    $('cover-colors').replaceChildren(...LibraryWorld.DYES.map((c, i) => {
      const b = document.createElement('button');
      b.type = 'button'; b.className = 'swatch'; b.setAttribute('role', 'radio');
      b.style.background = `rgb(${c.join(',')})`;
      b.setAttribute('aria-label', `${gui.t('cover')} ${i + 1}`);
      b.onclick = () => { cover = i; markCover(); };
      return b;
    }));
    markCover();
  }
  const markCover = () => [...$('cover-colors').children].forEach((b, i) => b.setAttribute('aria-checked', String(i === cover)));

  function changed() {
    requestAnimationFrame(measure);
    clearTimeout(inputTimer);
    inputTimer = setTimeout(() => handlers?.onInput?.(serialize()), 1200);
  }

  // ── Screens ────────────────────────────────────────────────────────────
  function showEditor() {
    mode = 'edit';
    $('bookui').hidden = false;
    $('tools').hidden = false;
    viewport.hidden = false;
    $('sign-screen').hidden = true;
    $('burn-confirm').hidden = true;
    $('book-burn').hidden = true;
    $('book-left').textContent = gui.t('sign');
    $('book-right').textContent = gui.t('done');
    $('book-left').classList.remove('danger');
    $('book-hint').textContent = gui.t('writeHint');
    flow.dataset.hint = '';
    requestAnimationFrame(() => {
      measure();
      flow.focus();
      const sel = getSelection();
      sel.selectAllChildren(flow);
      sel.collapseToEnd();
      followCaret();
      refreshTools();
    });
  }

  function showSign(book) {
    mode = 'sign';
    $('tools').hidden = true;
    viewport.hidden = true;
    $('sign-screen').hidden = false;
    $('burn-confirm').hidden = true;
    $('book-burn').hidden = !handlers?.canBurn;
    $('book-burn').textContent = gui.t('burn');
    $('sign-label').textContent = gui.t('signTitle');
    $('spine-label').textContent = gui.t('spine');
    $('cover-label').textContent = gui.t('cover');
    $('sign-spine').placeholder = gui.t('spineHint');
    $('book-left').textContent = gui.t('signAndShelve');
    $('book-right').textContent = gui.t('cancel');
    $('book-left').classList.remove('danger');
    $('book-hint').textContent = '';
    if (book) {
      $('sign-title').value = book.title || '';
      $('sign-spine').value = book.spineRaw ?? '';
      cover = book.cover ?? 12;
    }
    buildCovers();
    updateIndicator();
    setTimeout(() => $('sign-title').focus(), 30);
  }

  function showBurn() {
    mode = 'burn';
    $('sign-screen').hidden = true;
    $('burn-confirm').hidden = false;
    $('burn-text').textContent = gui.t('burnConfirm');
    $('book-burn').hidden = true;
    $('book-left').textContent = gui.t('burn');
    $('book-left').classList.add('danger');
    $('book-right').textContent = gui.t('cancel');
    $('book-right').focus();
  }

  $('book-left').onclick = () => {
    if (!handlers) return;
    if (mode === 'edit') { clearTimeout(inputTimer); handlers.onSign(serialize()); }
    else if (mode === 'sign') handlers.onShelve({title: $('sign-title').value.trim(), spine: $('sign-spine').value.trim(), cover});
    else if (mode === 'burn') handlers.onBurn();
  };
  $('book-right').onclick = () => {
    if (!handlers) return;
    if (mode === 'edit') { clearTimeout(inputTimer); handlers.onDone(serialize()); }
    else if (mode === 'sign') handlers.onSignBack();
    else if (mode === 'burn') showSign();
  };
  $('book-burn').onclick = showBurn;
  $('book-prev').onclick = () => setPage(page - 1);
  $('book-next').onclick = () => setPage(page + 1);
  for (const b of document.querySelectorAll('#tools [data-cmd]')) {
    b.addEventListener('mousedown', e => e.preventDefault());
    b.onclick = () => command(b.dataset.cmd);
  }

  flow.addEventListener('input', changed);
  flow.addEventListener('paste', e => {
    e.preventDefault();
    const text = e.clipboardData.getData('text/plain');
    document.execCommand('insertText', false, text);
  });
  flow.addEventListener('keydown', e => {
    if (e.key === 'PageDown') { e.preventDefault(); setPage(page + 1); }
    else if (e.key === 'PageUp') { e.preventDefault(); setPage(page - 1); }
    else if (e.ctrlKey && e.key.toLowerCase() === 's') { e.preventDefault(); handlers?.onInput?.(serialize()); }
  });
  document.addEventListener('selectionchange', () => {
    if ($('bookui').hidden || mode !== 'edit') return;
    followCaret();
    refreshTools();
  });
  $('bookui').addEventListener('keydown', e => {
    if (e.key !== 'Escape') return;
    e.stopPropagation();
    if (mode === 'edit') $('book-right').click();
    else if (mode === 'sign') $('book-right').click();
    else if (mode === 'burn') showSign();
  });
  for (const id of ['sign-title', 'sign-spine']) {
    $(id).addEventListener('keydown', e => { if (e.key === 'Enter') { e.preventDefault(); $('book-left').click(); } });
  }
  addEventListener('resize', () => { if (!$('bookui').hidden && mode === 'edit') requestAnimationFrame(() => { measure(); setPage(page); }); });

  buildInk();

  window.LibraryBook = {
    // Opens the editor on [book] ({title, spine, cover, body}).
    openEditor(book, h) {
      handlers = h;
      gui.paintBook();
      render(book.body);
      page = 0;
      showEditor();
    },
    openSign(book, h) {
      handlers = h;
      $('bookui').hidden = false;
      showSign(book);
    },
    backToEditor() { showEditor(); },
    close() {
      clearTimeout(inputTimer);
      handlers = null;
      $('bookui').hidden = true;
      flow.blur();
    },
    get open() { return !$('bookui').hidden; },
    serialize,
    plainText,
    // For the structural check: round-trips a body through the DOM.
    _roundTrip(json) { render(json); return serialize(); },
  };
})();
