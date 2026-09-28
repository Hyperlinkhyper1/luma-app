// One canvas for every piece of writing in the hall: the name sign over each
// bookcase and the spine of every book, drawn pixel-exact with the library
// font and uploaded as a single texture.
//
// Room for 64 signs and 798 spines; anything past that gets a plain board or
// a blank spine rather than failing.
(() => {
  'use strict';

  const SIZE = 2048;
  const SIGN_W = 256, SIGN_H = 64, SIGN_COLS = SIZE / SIGN_W, SIGN_ROWS = 8;
  const SPINE_W = 48, SPINE_H = 80, SPINE_TOP = SIGN_H * SIGN_ROWS;
  const SPINE_COLS = Math.floor(SIZE / SPINE_W), SPINE_ROWS = Math.floor((SIZE - SPINE_TOP) / SPINE_H);

  function create(T, dyes) {
    const canvas = document.createElement('canvas');
    canvas.width = SIZE; canvas.height = SIZE;
    const ctx = canvas.getContext('2d');
    ctx.imageSmoothingEnabled = false;
    const texture = new T.CanvasTexture(canvas);
    texture.flipY = false;
    texture.magFilter = T.NearestFilter;
    texture.minFilter = T.LinearMipmapLinearFilter;
    texture.anisotropy = 4;
    texture.colorSpace = T.SRGBColorSpace;
    let dirty = true;

    const spineCells = new Map(); // book id → {cell, key}
    const signCells = new Map();  // subject id → {cell, key}
    const freeSpines = [], freeSigns = [];
    let nextSpine = 0, nextSign = 0;

    const rgb = i => dyes[i] || dyes[12];
    const css = (c, f = 1) => `rgb(${Math.round(c[0] * f)},${Math.round(c[1] * f)},${Math.round(c[2] * f)})`;

    function uvRect(x, y, w, h) {
      return {u0: x / SIZE, v0: y / SIZE, u1: (x + w) / SIZE, v1: (y + h) / SIZE};
    }

    function drawSpine(x, y, book) {
      const c = rgb(book.cover);
      const dark = (c[0] + c[1] + c[2]) < 200;
      // Leather in chunky texels so it sits with the blocks around it.
      const r = LibraryTextures.rng('spine' + book.id);
      for (let ty = 0; ty < SPINE_H; ty += 4) {
        for (let tx = 0; tx < SPINE_W; tx += 4) {
          ctx.fillStyle = css(c, 0.84 + r() * 0.16);
          ctx.fillRect(x + tx, y + ty, 4, 4);
        }
      }
      ctx.fillStyle = css(c, 0.6);
      ctx.fillRect(x, y, 3, SPINE_H);
      ctx.fillRect(x + SPINE_W - 3, y, 3, SPINE_H);
      // Gilt bands near both ends.
      for (const by of [6, SPINE_H - 10]) {
        ctx.fillStyle = '#e8b43a';
        ctx.fillRect(x + 3, y + by, SPINE_W - 6, 2);
        ctx.fillStyle = '#8a5a14';
        ctx.fillRect(x + 3, y + by + 2, SPINE_W - 6, 1);
      }
      // The label, reading top to bottom as on a real spine.
      const text = (book.spine || book.title || '').trim();
      if (!text) return;
      const span = SPINE_H - 26;
      const ink = dark ? '#f6e7b0' : '#fff6d8';
      const shadow = css(c, 0.35);
      let lines = [text], scale = 2;
      if (PixelFont.measure(text) * 2 > span) {
        scale = 1;
        if (PixelFont.measure(text) > span) lines = wrap(text, span);
      }
      const tmp = document.createElement('canvas');
      tmp.width = span; tmp.height = SPINE_W - 6;
      const t = tmp.getContext('2d');
      const lineH = 9 * scale + 1;
      const blockH = lines.length * lineH;
      lines.forEach((line, i) => {
        const w = PixelFont.measure(line) * scale;
        PixelFont.draw(t, line, Math.floor((span - w) / 2), Math.floor((tmp.height - blockH) / 2) + i * lineH, {scale, color: ink, shadow});
      });
      ctx.save();
      ctx.translate(x + 3 + tmp.height, y + 13);
      ctx.rotate(Math.PI / 2);
      ctx.drawImage(tmp, 0, 0);
      ctx.restore();
    }

    function wrap(text, width) {
      const words = text.split(/\s+/);
      const lines = [''];
      for (const word of words) {
        const trial = lines[lines.length - 1] ? lines[lines.length - 1] + ' ' + word : word;
        if (PixelFont.measure(trial) <= width) lines[lines.length - 1] = trial;
        else if (lines.length < 3) lines.push(word);
        else break;
      }
      return lines.map(line => fit(line, width)).slice(0, 3);
    }

    function fit(text, width) {
      if (PixelFont.measure(text) <= width) return text;
      let out = text;
      while (out.length > 1 && PixelFont.measure(out + '…') > width) out = out.slice(0, -1);
      return out + '…';
    }

    function drawSign(x, y, subject) {
      const r = LibraryTextures.rng('sign' + subject.id);
      // Dark oak boards, three planks tall.
      for (let ty = 0; ty < SIGN_H; ty += 8) {
        for (let tx = 0; tx < SIGN_W; tx += 8) {
          const plank = Math.floor(ty / 21);
          const f = 0.8 + r() * 0.2 - (ty % 21 >= 16 ? 0.25 : 0);
          ctx.fillStyle = css([92 + plank * 4, 62, 34], f);
          ctx.fillRect(x + tx, y + ty, 8, 8);
        }
      }
      ctx.fillStyle = '#2a1a0c';
      ctx.fillRect(x, y, SIGN_W, 4); ctx.fillRect(x, y + SIGN_H - 4, SIGN_W, 4);
      ctx.fillRect(x, y, 4, SIGN_H); ctx.fillRect(x + SIGN_W - 4, y, 4, SIGN_H);
      // A ribbon in the subject's colour down the left edge.
      const c = rgb(subject.color);
      ctx.fillStyle = css(c);
      ctx.fillRect(x + 10, y + 4, 12, SIGN_H - 8);
      ctx.fillStyle = css(c, 0.7);
      ctx.fillRect(x + 20, y + 4, 2, SIGN_H - 8);
      const width = SIGN_W - 44;
      const name = subject.name || '';
      let scale = 3;
      while (scale > 1 && PixelFont.measure(name) * scale > width) scale--;
      const label = fit(name, Math.floor(width / scale));
      const w = PixelFont.measure(label) * scale;
      PixelFont.draw(ctx, label, x + 30 + Math.floor((width - w) / 2), y + Math.floor((SIGN_H - 8 * scale) / 2), {scale, color: '#fff3c9', shadow: '#3b2a12'});
    }

    function clearCell(x, y, w, h) { ctx.clearRect(x, y, w, h); }

    return {
      texture,
      spine(book) {
        const key = `${book.spine}|${book.title}|${book.cover}`;
        let entry = spineCells.get(book.id);
        if (!entry) {
          const cell = freeSpines.length ? freeSpines.pop() : nextSpine < SPINE_COLS * SPINE_ROWS ? nextSpine++ : -1;
          if (cell < 0) return null;
          entry = {cell, key: null};
          spineCells.set(book.id, entry);
        }
        const x = (entry.cell % SPINE_COLS) * SPINE_W, y = SPINE_TOP + Math.floor(entry.cell / SPINE_COLS) * SPINE_H;
        if (entry.key !== key) {
          clearCell(x, y, SPINE_W, SPINE_H);
          drawSpine(x, y, book);
          entry.key = key;
          dirty = true;
        }
        // Inset half a texel so filtering never reaches the next cell.
        return uvRect(x + 0.5, y + 0.5, SPINE_W - 1, SPINE_H - 1);
      },
      sign(subject) {
        const key = `${subject.name}|${subject.color}`;
        let entry = signCells.get(subject.id);
        if (!entry) {
          const cell = freeSigns.length ? freeSigns.pop() : nextSign < SIGN_COLS * SIGN_ROWS ? nextSign++ : -1;
          if (cell < 0) return null;
          entry = {cell, key: null};
          signCells.set(subject.id, entry);
        }
        const x = (entry.cell % SIGN_COLS) * SIGN_W, y = Math.floor(entry.cell / SIGN_COLS) * SIGN_H;
        if (entry.key !== key) {
          clearCell(x, y, SIGN_W, SIGN_H);
          drawSign(x, y, subject);
          entry.key = key;
          dirty = true;
        }
        return uvRect(x + 0.5, y + 0.5, SIGN_W - 1, SIGN_H - 1);
      },
      // Frees cells for books and subjects that no longer exist.
      retain(bookIds, subjectIds) {
        for (const [id, entry] of spineCells) if (!bookIds.has(id)) { spineCells.delete(id); freeSpines.push(entry.cell); }
        for (const [id, entry] of signCells) if (!subjectIds.has(id)) { signCells.delete(id); freeSigns.push(entry.cell); }
      },
      // Everything must be redrawn, e.g. once the vanilla font arrives.
      invalidate() {
        for (const entry of spineCells.values()) entry.key = null;
        for (const entry of signCells.values()) entry.key = null;
      },
      flush() {
        if (!dirty) return;
        texture.needsUpdate = true;
        dirty = false;
      },
    };
  }

  window.LibraryLabels = {create, SIGN_W, SIGN_H};
})();
