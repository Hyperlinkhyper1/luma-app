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
    return JSON.stringify(drawings.length ? {v: 1, spans: out, drawings} : {v: 1, spans: out});
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
    drawings = parseDrawings(json || '');
    history.length = 0; undone.length = 0;
  }

  const plainText = json => parseBody(json).map(s => s.t).join('');

  function parseDrawings(json) {
    try {
      const v = JSON.parse(json);
      if (v && Array.isArray(v.drawings)) return v.drawings.filter(d => d && typeof d.k === 'string' && Number.isFinite(d.p));
    } catch {
      // Plain text body: no drawings.
    }
    return [];
  }
  // Blank means nothing written and nothing drawn.
  const isBlank = json => !plainText(json).trim() && !parseDrawings(json || '').length;

  // ── Paging ─────────────────────────────────────────────────────────────
  const stride = () => (116 + 20) * gui.scale;

  function measure() {
    const drawn = drawings.reduce((m, d) => Math.max(m, d.p + 1), 1);
    const text = Math.max(1, Math.round((flow.scrollWidth + 20 * gui.scale) / stride()));
    pages = Math.max(text, drawn);
    paintArt();
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
    if ((cmd === 'undo' || cmd === 'redo') && lastKind === 'art' && undoArt(cmd === 'redo')) return;
    flow.focus();
    document.execCommand('styleWithCSS', false, true);
    if (cmd === 'clear') {
      document.execCommand('removeFormat');
      document.execCommand('foreColor', false, '#000000');
    } else if (cmd === 'undo' || cmd === 'redo') {
      // With no typing left to take back, fall through to the drawings.
      const before = flow.innerHTML;
      document.execCommand(cmd);
      if (flow.innerHTML === before && undoArt(cmd === 'redo')) return;
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
      b.classList.remove('on');
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
      b.type = 'button'; b.className = 'ink'; b.dataset.color = id;
      b.setAttribute('role', 'radio');
      b.setAttribute('aria-label', id.replace('_', ' '));
      b.style.background = hex;
      b.addEventListener('mousedown', e => e.preventDefault());
      hoverTip(b, () => id.replace('_', ' '));
      b.onclick = () => { drawInk = id; command('foreColor', hex); };
      return b;
    }));
  }

  // ── Drawing ────────────────────────────────────────────────────────────
  // A few shapes to make little pictures with: pick one and drag on the
  // page to draw it that size, or drag it off the palette onto the page to
  // stamp it. They are drawn on the page's own pixel grid, one GUI pixel to
  // a canvas pixel, so they come out as blocky as the lettering. Each is
  // kept as {k, p, x0, y0, x1, y1, c, f}: kind, page, corners in page
  // pixels, ink colour and whether it is filled.
  const PAGE_W = 116, PAGE_H = 126, GAP = 20;
  const art = $('book-art');
  let drawings = [];
  let tool = null, filled = true, drawInk = 'black';
  let drag = null;
  const undone = [], history = [];

  // Whether (u, v), across a shape's box from 0 to 1, lies inside it.
  const star = Array.from({length: 10}, (_, i) => {
    const a = -Math.PI / 2 + i * Math.PI / 5, r = i % 2 ? 0.4 : 1;
    return [0.5 + Math.cos(a) * r * 0.5, 0.53 + Math.sin(a) * r * 0.5];
  });
  function inPolygon(pts, u, v) {
    let inside = false;
    for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
      const [xi, yi] = pts[i], [xj, yj] = pts[j];
      if ((yi > v) !== (yj > v) && u < (xj - xi) * (v - yi) / (yj - yi) + xi) inside = !inside;
    }
    return inside;
  }
  const INSIDE = {
    circle: (u, v) => (u - 0.5) ** 2 + (v - 0.5) ** 2 <= 0.25,
    square: () => true,
    triangle: (u, v) => v >= 1 - 2 * Math.min(u, 1 - u) - 1e-9,
    star: (u, v) => inPolygon(star, u, v),
    heart: (u, v) => {
      const x = (u - 0.5) * 2.6, y = (0.58 - v) * 2.6;
      return (x * x + y * y - 1) ** 3 - x * x * y ** 3 <= 0;
    },
  };
  const SHAPE_KINDS = ['circle', 'square', 'triangle', 'star', 'heart', 'line'];
  // The palette's own little icons, drawn the same way at 7 pixels.
  const ICON = 7;

  // Every pixel a drawing covers, in page pixels.
  function pixels(d) {
    const out = [];
    if (d.k === 'line') {
      let x = Math.round(d.x0), y = Math.round(d.y0);
      const x1 = Math.round(d.x1), y1 = Math.round(d.y1);
      const dx = Math.abs(x1 - x), dy = -Math.abs(y1 - y), sx = x < x1 ? 1 : -1, sy = y < y1 ? 1 : -1;
      let err = dx + dy;
      for (;;) {
        out.push([x, y]);
        if (d.f) out.push([x + 1, y], [x, y + 1], [x + 1, y + 1]);
        if (x === x1 && y === y1) break;
        const e2 = 2 * err;
        if (e2 >= dy) { err += dy; x += sx; }
        if (e2 <= dx) { err += dx; y += sy; }
      }
      return out;
    }
    const x0 = Math.round(Math.min(d.x0, d.x1)), x1 = Math.round(Math.max(d.x0, d.x1));
    const y0 = Math.round(Math.min(d.y0, d.y1)), y1 = Math.round(Math.max(d.y0, d.y1));
    const w = x1 - x0 + 1, h = y1 - y0 + 1;
    const test = INSIDE[d.k] || INSIDE.square;
    const inside = (i, j) => i >= 0 && j >= 0 && i < w && j < h && test((i + 0.5) / w, (j + 0.5) / h);
    for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
      if (!inside(i, j)) continue;
      if (!d.f && inside(i - 1, j) && inside(i + 1, j) && inside(i, j - 1) && inside(i, j + 1)) continue;
      out.push([x0 + i, y0 + j]);
    }
    return out;
  }

  function paintArt(extra) {
    const w = pages * (PAGE_W + GAP) - GAP;
    if (art.width !== w) art.width = w;
    art.height = PAGE_H;
    art.style.width = `${w * gui.scale}px`;
    art.style.height = `${PAGE_H * gui.scale}px`;
    const g = art.getContext('2d');
    g.clearRect(0, 0, art.width, art.height);
    for (const d of extra ? [...drawings, extra] : drawings) {
      g.fillStyle = HEX_BY_ID.get(d.c) || '#000000';
      const left = d.p * (PAGE_W + GAP);
      for (const [x, y] of pixels(d)) if (x >= 0 && y >= 0 && x < PAGE_W && y < PAGE_H) g.fillRect(left + x, y, 1, 1);
    }
    art.classList.toggle('drawing', !!tool);
  }

  // Where a pointer is on the current page, in page pixels.
  function pagePoint(e) {
    const r = viewport.getBoundingClientRect();
    return [
      Math.max(0, Math.min(PAGE_W - 1, Math.floor((e.clientX - r.left) / gui.scale))),
      Math.max(0, Math.min(PAGE_H - 1, Math.floor((e.clientY - r.top) / gui.scale))),
    ];
  }
  const overPage = e => {
    const r = viewport.getBoundingClientRect();
    return e.clientX >= r.left && e.clientX < r.right && e.clientY >= r.top && e.clientY < r.bottom;
  };

  function remember() {
    history.push(JSON.stringify(drawings));
    if (history.length > 100) history.shift();
    undone.length = 0;
  }
  function addDrawing(d) {
    remember();
    drawings.push(d);
    paintArt();
    changed(true);
  }
  // A shape `size` pixels across, centred where it was dropped.
  function stamp(kind, [x, y], size = 12) {
    const h = size / 2;
    const d = kind === 'line' ? {x0: x - h, y0: y + h, x1: x + h, y1: y - h} : {x0: x - h, y0: y - h, x1: x + h - 1, y1: y + h - 1};
    addDrawing({k: kind, p: page, ...d, c: drawInk, f: filled});
  }

  art.addEventListener('pointerdown', e => {
    if (!tool || e.button !== 0) return;
    e.preventDefault();
    try { art.setPointerCapture(e.pointerId); } catch { /* pointer already gone */ }
    const [x, y] = pagePoint(e);
    drag = {x0: x, y0: y, x1: x, y1: y};
  });
  art.addEventListener('pointermove', e => {
    if (!drag) return;
    const [x, y] = pagePoint(e);
    // Shift keeps it round, square or level.
    if (e.shiftKey && tool !== 'line') {
      const s = Math.max(Math.abs(x - drag.x0), Math.abs(y - drag.y0));
      drag.x1 = drag.x0 + Math.sign(x - drag.x0 || 1) * s; drag.y1 = drag.y0 + Math.sign(y - drag.y0 || 1) * s;
    } else { drag.x1 = x; drag.y1 = y; }
    paintArt({k: tool, p: page, ...drag, c: drawInk, f: filled});
  });
  art.addEventListener('pointerup', () => {
    if (!drag) return;
    const d = drag;
    drag = null;
    if (Math.abs(d.x1 - d.x0) < 2 && Math.abs(d.y1 - d.y0) < 2) stamp(tool, [d.x0, d.y0]);
    else addDrawing({k: tool, p: page, ...d, c: drawInk, f: filled});
  });
  art.addEventListener('pointercancel', () => { drag = null; paintArt(); });
  // A right-click takes away the topmost drawing under the pointer.
  art.addEventListener('contextmenu', e => {
    e.preventDefault();
    const [x, y] = pagePoint(e);
    for (let i = drawings.length - 1; i >= 0; i--) {
      const d = drawings[i];
      if (d.p !== page || !pixels({...d, f: true}).some(([px, py]) => Math.abs(px - x) <= 1 && Math.abs(py - y) <= 1)) continue;
      remember();
      drawings.splice(i, 1);
      paintArt();
      changed(true);
      return;
    }
  });

  function iconCanvas(kind, fill) {
    const c = document.createElement('canvas');
    c.width = c.height = ICON;
    const g = c.getContext('2d');
    g.fillStyle = '#1a1208';
    const d = kind === 'line' ? {k: kind, x0: 0, y0: ICON - 1, x1: ICON - 1, y1: 0, f: false} : {k: kind, x0: 0, y0: 0, x1: ICON - 1, y1: ICON - 1, f: fill};
    for (const [x, y] of pixels(d)) g.fillRect(x, y, 1, 1);
    return c;
  }

  function setTool(kind) {
    tool = kind;
    for (const b of $('shapes').querySelectorAll('[data-shape]')) b.setAttribute('aria-checked', String(b.dataset.shape === tool));
    paintArt();
  }

  function buildShapes() {
    const buttons = SHAPE_KINDS.map(kind => {
      const b = document.createElement('button');
      b.type = 'button'; b.className = 'shape'; b.dataset.shape = kind;
      b.setAttribute('role', 'radio');
      b.setAttribute('aria-checked', 'false');
      const label = () => gui.t('shape' + kind[0].toUpperCase() + kind.slice(1));
      b.setAttribute('aria-label', label());
      b.append(iconCanvas(kind, true));
      hoverTip(b, () => `${label()} · ${gui.t('drawHint')}`);
      b.addEventListener('mousedown', e => e.preventDefault());
      // A click picks the shape (or puts it down again); dragging it off
      // the palette onto the page stamps one there.
      b.addEventListener('pointerdown', e => {
        if (e.button !== 0) return;
        try { b.setPointerCapture(e.pointerId); } catch { /* pointer already gone */ }
        const start = [e.clientX, e.clientY];
        let ghost = null;
        const move = ev => {
          if (!ghost && Math.hypot(ev.clientX - start[0], ev.clientY - start[1]) < 5) return;
          if (!ghost) {
            ghost = iconCanvas(kind, filled);
            ghost.className = 'shape-ghost';
            document.body.append(ghost);
          }
          ghost.style.left = `${ev.clientX}px`;
          ghost.style.top = `${ev.clientY}px`;
        };
        const up = ev => {
          b.removeEventListener('pointermove', move);
          b.removeEventListener('pointerup', up);
          b.removeEventListener('pointercancel', up);
          if (!ghost) { setTool(tool === kind ? null : kind); return; }
          ghost.remove();
          if (ev.type === 'pointerup' && overPage(ev)) { setTool(kind); stamp(kind, pagePoint(ev)); }
        };
        b.addEventListener('pointermove', move);
        b.addEventListener('pointerup', up);
        b.addEventListener('pointercancel', up);
      });
      return b;
    });
    const fill = document.createElement('button');
    fill.type = 'button'; fill.className = 'shape fill';
    const paintFill = () => {
      fill.replaceChildren(iconCanvas('square', filled));
      fill.setAttribute('aria-pressed', String(filled));
      fill.setAttribute('aria-label', gui.t('shapeFill'));
    };
    fill.addEventListener('mousedown', e => e.preventDefault());
    hoverTip(fill, () => gui.t('shapeFill'));
    fill.onclick = () => { filled = !filled; paintFill(); };
    paintFill();
    $('shapes').replaceChildren(...buttons, fill);
  }

  // Undo and redo take back whichever came last: typing or drawing.
  function undoArt(redo) {
    const from = redo ? undone : history, to = redo ? history : undone;
    if (!from.length) return false;
    to.push(JSON.stringify(drawings));
    drawings = JSON.parse(from.pop());
    paintArt();
    changed(true);
    return true;
  }

  function buildCovers() {
    $('cover-colors').replaceChildren(...LibraryWorld.DYES.map((c, i) => {
      const b = document.createElement('button');
      b.type = 'button'; b.className = 'swatch'; b.setAttribute('role', 'radio');
      b.style.background = `rgb(${LibraryWorld.coverRgb(i).join(',')})`;
      b.setAttribute('aria-label', `${gui.t('cover')} ${i + 1}`);
      b.onclick = () => { cover = i; markCover(); };
      return b;
    }));
    markCover();
  }
  const markCover = () => [...$('cover-colors').children].forEach((b, i) => b.setAttribute('aria-checked', String(i === cover)));

  let lastKind = 'text';
  function changed(byDrawing = false) {
    lastKind = byDrawing === true ? 'art' : 'text';
    requestAnimationFrame(measure);
    clearTimeout(inputTimer);
    inputTimer = setTimeout(() => handlers?.onInput?.(serialize()), 1200);
  }

  // ── Screens ────────────────────────────────────────────────────────────
  function showEditor() {
    mode = 'edit';
    $('bookui').hidden = false;
    $('tools').hidden = false;
    $('history').hidden = false;
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
    $('history').hidden = true;
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
  // The game-style tooltip beside whatever the pointer rests on.
  function hoverTip(el, text) {
    el.addEventListener('pointerenter', e => { if (e.pointerType === 'mouse') gui.tooltip([text()], e.clientX, e.clientY); });
    el.addEventListener('pointermove', e => { if (e.pointerType === 'mouse') gui.tooltip([text()], e.clientX, e.clientY); });
    el.addEventListener('pointerleave', () => gui.tooltip(null));
  }

  for (const b of document.querySelectorAll('#tools [data-cmd], #history [data-cmd]')) {
    b.addEventListener('mousedown', e => e.preventDefault());
    b.onclick = () => command(b.dataset.cmd);
    hoverTip(b, () => b.getAttribute('aria-label') || '');
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
  // Ctrl+Z / Ctrl+Y (or Ctrl+Shift+Z) go through the same undo as the
  // buttons, so shapes come back off the page too, not just typing.
  document.addEventListener('keydown', e => {
    if ($('bookui').hidden || mode !== 'edit' || drag || !(e.ctrlKey || e.metaKey) || e.altKey) return;
    const k = e.key.toLowerCase();
    if (k !== 'z' && k !== 'y') return;
    e.preventDefault();
    command(k === 'y' || e.shiftKey ? 'redo' : 'undo');
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
  buildShapes();

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
      gui.tooltip(null);
      handlers = null;
      $('bookui').hidden = true;
      flow.blur();
    },
    get open() { return !$('bookui').hidden; },
    serialize,
    plainText,
    isBlank,
    // For the structural check: round-trips a body through the DOM.
    _roundTrip(json) { render(json); return serialize(); },
  };
})();
