// Keyboard, mouse look and wheel.
//
// Mouse look prefers pointer lock (click to capture, Esc releases). Inside
// luma's embedded WebView2 the lock can be refused, so a drag-to-look mode
// takes over automatically: hold the left button and drag.

export class Input {
  constructor(canvas) {
    this.canvas = canvas;
    this.keys = new Set();
    this.dx = 0; this.dy = 0; this.wheel = 0;
    this.locked = false;
    this.dragLook = false;          // fallback active
    this.dragging = false;
    this.enabled = false;           // false while a menu is open
    this.handlers = new Map();      // code -> fn, for one-shot actions
    this.onUnlock = null;
    this._last = null;
    this._lockPending = false;

    window.addEventListener('keydown', (e) => {
      if (e.code === 'Tab' || e.code === 'F1' || e.code === 'Space' || e.code.startsWith('Arrow')) e.preventDefault();
      if (e.repeat) return;
      const fn = this.handlers.get(e.code);
      if (fn && (this.enabled || e.code === 'Escape' || e.code === 'KeyM')) { fn(e); }
      if (this.enabled) this.keys.add(e.code);
    });
    window.addEventListener('keyup', (e) => this.keys.delete(e.code));
    window.addEventListener('blur', () => this.keys.clear());

    document.addEventListener('pointerlockchange', () => {
      const was = this.locked;
      this.locked = document.pointerLockElement === canvas;
      this._lockPending = false;
      if (was && !this.locked) { this.keys.clear(); this.onUnlock?.(); }
    });
    document.addEventListener('pointerlockerror', () => {
      this._lockPending = false;
      this.dragLook = true;
    });

    canvas.addEventListener('pointerdown', (e) => {
      if (!this.enabled) return;
      canvas.focus();
      if (!this.locked && !this.dragLook && e.pointerType === 'mouse') { this.lock(); }
      if (!this.locked) {
        this.dragging = true;
        this._last = { x: e.clientX, y: e.clientY };
        canvas.setPointerCapture?.(e.pointerId);
        canvas.classList.add('grab');
      }
    });
    canvas.addEventListener('pointermove', (e) => {
      if (!this.enabled) return;
      if (this.locked) {
        // Ignore the occasional huge spike some drivers send on lock.
        if (Math.abs(e.movementX) < 400 && Math.abs(e.movementY) < 400) { this.dx += e.movementX; this.dy += e.movementY; }
      } else if (this.dragging && this._last) {
        this.dx += (e.clientX - this._last.x) * 1.2;
        this.dy += (e.clientY - this._last.y) * 1.2;
        this._last = { x: e.clientX, y: e.clientY };
      }
    });
    const end = (e) => {
      this.dragging = false; this._last = null;
      canvas.classList.remove('grab');
      try { canvas.releasePointerCapture?.(e.pointerId); } catch { /* not captured */ }
    };
    canvas.addEventListener('pointerup', end);
    canvas.addEventListener('pointercancel', end);
    canvas.addEventListener('wheel', (e) => { if (this.enabled) { this.wheel += Math.sign(e.deltaY); e.preventDefault(); } }, { passive: false });
    canvas.addEventListener('contextmenu', (e) => e.preventDefault());
  }

  lock() {
    if (this.locked || this._lockPending || !this.canvas.requestPointerLock) { if (!this.canvas.requestPointerLock) this.dragLook = true; return; }
    this._lockPending = true;
    try {
      const p = this.canvas.requestPointerLock({ unadjustedMovement: true });
      if (p && p.catch) {
        p.catch(() => {
          // unadjustedMovement isn't everywhere; retry plain, then fall back.
          try {
            const p2 = this.canvas.requestPointerLock();
            if (p2 && p2.catch) p2.catch(() => { this._lockPending = false; this.dragLook = true; });
          } catch { this._lockPending = false; this.dragLook = true; }
        });
      }
    } catch { this._lockPending = false; this.dragLook = true; }
    // Some embedders neither lock nor report an error.
    setTimeout(() => { if (this._lockPending && !this.locked) { this._lockPending = false; this.dragLook = true; } }, 600);
  }

  unlock() { if (this.locked) document.exitPointerLock?.(); }

  on(code, fn) { this.handlers.set(code, fn); }

  down(code) { return this.keys.has(code); }

  /** Consume accumulated mouse movement. */
  takeLook() { const r = [this.dx, this.dy]; this.dx = 0; this.dy = 0; return r; }
  takeWheel() { const w = this.wheel; this.wheel = 0; return w; }
}
