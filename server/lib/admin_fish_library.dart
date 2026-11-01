/// The Fishing Waters project's Fish tab: the species library with the
/// in-game 3D models, and the fish editor (quick edits, AI edits and new
/// species). Data comes from /admin/fishing-waters/fish* (see
/// fish_library.dart); this file only holds the markup, styles and script.
///
/// The dashboard's CSP allows inline scripts only, so the model viewer is a
/// small WebGL renderer of its own: the game's fish are nothing but
/// ellipsoids, blocks, wedges and cylinders, which needs no 3D library.
class AdminFishLibrary {
  static const html = '<div class="tab-panel fw-panel" id="fw-panel-fish" role="tabpanel">'
      '<div class="fl-top">'
      '<div class="fl-filters">'
      '<input type="search" id="flSearch" class="fw-search" placeholder="Search fish…" aria-label="Search fish" autocomplete="off">'
      '<select id="flRarity" class="fl-select" aria-label="Rarity"><option value="">All rarities</option></select>'
      '<select id="flPool" class="fl-select" aria-label="Where it bites"><option value="">Everywhere</option></select>'
      '</div>'
      '<div class="fl-actions">'
      '<button type="button" class="btn btn-ghost" id="flReload" title="Reload from GitHub">Reload</button>'
      '<button type="button" class="btn btn-primary" id="flEditorBtn">Fish editor</button>'
      '</div></div>'
      '<p class="fl-meta" id="flMeta" aria-live="polite">Loading the fish library…</p>'
      '<div class="fl-problem" id="flProblem" hidden></div>'
      '<div class="fl-jobs" id="flJobs" hidden></div>'
      '<div class="fl-layout">'
      '<div class="fl-grid" id="flGrid" role="list"></div>'
      '<aside class="card fl-detail" id="flDetail" aria-live="polite">'
      '<div class="fw-empty"><b>Pick a fish</b>Its 3D model and catch data show here.</div>'
      '</aside></div>'
      // The editor
      '<dialog class="fl-dialog" id="flEditor" aria-labelledby="flEditorTitle">'
      '<form method="dialog" class="fl-dialog-head"><h2 id="flEditorTitle">Fish editor</h2>'
      '<button class="fl-x" value="close" aria-label="Close">×</button></form>'
      '<div class="fl-dialog-body" id="flEditorBody"></div>'
      '</dialog>'
      '</div>';

  static const css = r'''
.fl-top{display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap;margin-bottom:10px}
.fl-filters,.fl-actions{display:flex;gap:8px;flex-wrap:wrap;align-items:center}
.fl-select{min-height:36px;padding:6px 10px;border-radius:9px;background:#08161e;border:1px solid #1d3d4c;color:#ece8f7;font:inherit;font-size:13px}
.fl-meta{font-size:12.5px;color:#86a3b0;margin:0 0 14px}
.fl-meta a{color:#9fe3ef}
.fl-problem{border:1px solid #6d5a28;background:#211b0c;color:#f2d68a;border-radius:12px;padding:12px 14px;margin-bottom:14px;font-size:13px}
.fl-problem[hidden],.fl-jobs[hidden]{display:none}
.fl-layout{display:grid;grid-template-columns:minmax(0,1fr) minmax(320px,440px);gap:18px;align-items:start}
.fl-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(190px,1fr));gap:10px}
.fl-card{display:flex;flex-direction:column;gap:6px;text-align:left;padding:12px;border-radius:12px;border:1px solid #173543;background:rgba(9,29,39,.82);color:#ece8f7;font:inherit;cursor:pointer;transition:border-color .15s,background .15s,transform .1s;min-width:0}
.fl-card:hover{border-color:#2f6377}
.fl-card:active{transform:scale(.99)}
.fl-card[aria-current=true]{border-color:#4cc3d9;box-shadow:inset 0 0 0 1px #4cc3d9;background:#0d2a36}
.fl-card:focus-visible{outline:2px solid #4cc3d9;outline-offset:2px}
.fl-card-top{display:flex;align-items:center;gap:8px;min-width:0}
.fl-swatch{width:30px;height:18px;border-radius:9px 4px 4px 9px;flex:none;border:1px solid rgba(255,255,255,.12)}
.fl-card b{font-size:14px;font-weight:650;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.fl-card small{font-size:12px;color:#86a3b0;font-variant-numeric:tabular-nums}
.fl-rar{display:inline-flex;align-items:center;padding:1px 8px;border-radius:999px;font-size:11px;font-weight:650;border:1px solid currentColor;width:max-content}
.fl-tags{display:flex;flex-wrap:wrap;gap:4px}
.fl-tag{font-size:10.5px;padding:1px 7px;border-radius:999px;background:#102733;border:1px solid #214555;color:#9bb6c2;white-space:nowrap}
.fl-tag.warn{background:#2a1d0c;border-color:#6d5a28;color:#f2d68a}
.fl-detail{position:sticky;top:12px;margin-bottom:0}
.fl-detail h3{margin:0;font-size:20px;letter-spacing:-.01em}
.fl-detail-head{display:flex;align-items:flex-start;justify-content:space-between;gap:10px;margin-bottom:12px}
.fl-viewer{position:relative;width:100%;aspect-ratio:4/3;border-radius:12px;overflow:hidden;background:radial-gradient(120% 90% at 50% 30%,#123848 0%,#0a2230 55%,#061620 100%);border:1px solid #173543}
.fl-viewer canvas{width:100%;height:100%;display:block;touch-action:none;cursor:grab}
.fl-viewer canvas:active{cursor:grabbing}
.fl-viewer-msg{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;text-align:center;padding:20px;color:#86a3b0;font-size:13px;pointer-events:none}
.fl-viewer-msg[hidden]{display:none}
.fl-viewer-bar{display:flex;gap:8px;align-items:center;margin-top:8px;flex-wrap:wrap}
.fl-viewer-bar select{flex:1;min-width:140px}
.fl-facts{display:grid;grid-template-columns:auto 1fr;gap:6px 14px;margin:14px 0 0;font-size:13px}
.fl-facts dt{color:#86a3b0}
.fl-facts dd{margin:0;color:#ece8f7;font-variant-numeric:tabular-nums}
.fl-source{margin-top:12px}
.fl-source summary{cursor:pointer;color:#9fe3ef;font-size:13px}
.fl-code{max-height:360px;overflow:auto;background:#06131a;border:1px solid #173543;border-radius:10px;padding:10px 12px;font:12px/1.5 ui-monospace,SFMono-Regular,Consolas,monospace;color:#c3dbe3;white-space:pre;margin:8px 0 0}
.fl-jobs{display:flex;flex-direction:column;gap:8px;margin-bottom:16px}
.fl-job{display:flex;align-items:center;gap:10px;flex-wrap:wrap;padding:10px 12px;border-radius:12px;border:1px solid #1d3d4c;background:#0a1b24;font-size:13px}
.fl-job b{font-weight:650}
.fl-job .stage{color:#86a3b0;font-size:12px;flex:1;min-width:160px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.fl-job .btn{min-height:32px;padding:5px 12px;font-size:12.5px}
.fl-status{font-size:11px;font-weight:650;padding:2px 8px;border-radius:999px;background:#102733;border:1px solid #214555;color:#9bb6c2;text-transform:capitalize}
.fl-status.ready{background:rgba(76,217,138,.12);border-color:rgba(76,217,138,.4);color:#8ff0b8}
.fl-status.failed{background:rgba(236,95,95,.12);border-color:rgba(236,95,95,.35);color:#f2a3a3}
.fl-status.committed{background:rgba(76,195,217,.12);border-color:rgba(76,195,217,.35);color:#9fe3ef}
.fl-status.busy{animation:flPulse 1.6s ease-in-out infinite}
@keyframes flPulse{50%{opacity:.55}}
.fl-dialog{width:min(860px,calc(100vw - 32px));max-height:calc(100vh - 40px);padding:0;border-radius:16px;border:1px solid #1f4252;background:#0a1d27;color:#ece8f7;box-shadow:0 30px 80px rgba(0,0,0,.6)}
.fl-dialog::backdrop{background:rgba(2,10,14,.7);backdrop-filter:blur(2px)}
.fl-dialog-head{display:flex;align-items:center;justify-content:space-between;padding:16px 20px;border-bottom:1px solid #173543;position:sticky;top:0;background:#0a1d27;z-index:2;margin:0}
.fl-dialog-head h2{margin:0;font-size:17px;color:#ece8f7}
.fl-x{width:36px;height:36px;border-radius:9px;border:1px solid #1f4252;background:transparent;color:#bfe0ea;font-size:20px;cursor:pointer}
.fl-dialog-body{padding:18px 20px 22px}
.fl-choices{display:grid;grid-template-columns:1fr 1fr;gap:12px}
.fl-choice{display:flex;flex-direction:column;gap:6px;text-align:left;padding:18px;border-radius:14px;border:1px solid #1f4252;background:#0c2430;color:#ece8f7;font:inherit;cursor:pointer;transition:border-color .15s,background .15s}
.fl-choice:hover{border-color:#4cc3d9;background:#0f2c3a}
.fl-choice b{font-size:15px}
.fl-choice span{font-size:12.5px;color:#9bb6c2;line-height:1.5}
.fl-section{border:1px solid #173543;border-radius:14px;padding:16px;margin-top:14px;background:rgba(6,19,26,.5)}
.fl-section h3{margin:0 0 4px;font-size:14px}
.fl-section > p{margin:0 0 12px;font-size:12.5px;color:#86a3b0}
.fl-form{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:12px}
.fl-form .wide{grid-column:1/-1}
.fl-field{display:flex;flex-direction:column;gap:5px;font-size:12px;color:#9bb6c2;min-width:0}
.fl-field input,.fl-field select,.fl-field textarea{box-sizing:border-box;width:100%;min-width:0;min-height:36px;padding:7px 10px;border-radius:9px;background:#08161e;border:1px solid #1d3d4c;color:#ece8f7;font:inherit;font-size:13px}
.fl-field textarea{min-height:90px;resize:vertical;line-height:1.5}
.fl-field input:focus-visible,.fl-field select:focus-visible,.fl-field textarea:focus-visible{outline:2px solid #4cc3d9;outline-offset:1px}
.fl-pills{display:flex;flex-wrap:wrap;gap:6px}
.fl-pill{position:relative;display:inline-flex;align-items:center;gap:6px;min-height:32px;padding:4px 12px;border-radius:999px;border:1px solid #1f4252;background:#0a1b24;color:#bfe0ea;font:inherit;font-size:12.5px;cursor:pointer;user-select:none}
.fl-pill input{position:absolute;left:0;top:0;width:1px;height:1px;min-height:0;margin:0;padding:0;opacity:0;pointer-events:none}
.fl-pill:has(input:checked){border-color:#4cc3d9;background:#0f2c3a;color:#ecf8fb;box-shadow:inset 0 0 0 1px #4cc3d9}
.fl-pill:has(input:focus-visible){outline:2px solid #4cc3d9;outline-offset:2px}
.fl-pill.biome:not(:has(input:checked)){border-style:dashed}
.fl-hint{font-size:11.5px;color:#6f8f9c;line-height:1.45}
.fl-row{display:flex;gap:10px;align-items:center;flex-wrap:wrap;margin-top:14px}
.fl-row .grow{flex:1}
.fl-msg{font-size:13px;min-height:1em}
.fl-msg.err{color:#f2a3a3}
.fl-msg.ok{color:#8ff0b8}
.fl-msg a{color:#9fe3ef}
.fl-image{display:flex;align-items:center;gap:10px}
.fl-image img{width:64px;height:64px;object-fit:cover;border-radius:9px;border:1px solid #1f4252}
.fl-review{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:14px;margin-top:4px}
.fl-diff{max-height:420px;overflow:auto;background:#06131a;border:1px solid #173543;border-radius:10px;font:12px/1.5 ui-monospace,SFMono-Regular,Consolas,monospace;margin:0;padding:6px 0}
.fl-diff div{white-space:pre;padding:0 10px;color:#9bb6c2}
.fl-diff .add{background:rgba(76,217,138,.12);color:#b6f5cf}
.fl-diff .del{background:rgba(236,95,95,.12);color:#f5c0c0}
.fl-diff .gap{color:#4f6f7c;font-style:italic}
.fl-notes{white-space:pre-wrap;font-size:13px;color:#c3dbe3;background:#0a1b24;border:1px solid #173543;border-radius:10px;padding:10px 12px;margin:10px 0 0;max-height:160px;overflow:auto}
.fl-progress{display:flex;align-items:center;gap:12px;padding:22px;border-radius:12px;background:#0a1b24;border:1px solid #173543;color:#bfe0ea;font-size:14px}
.fl-spinner{width:20px;height:20px;border-radius:50%;border:2px solid #1f4252;border-top-color:#4cc3d9;animation:flSpin .8s linear infinite;flex:none}
@keyframes flSpin{to{transform:rotate(360deg)}}
.fl-back{background:none;border:0;color:#9fe3ef;font:inherit;font-size:13px;cursor:pointer;padding:0;margin-bottom:12px}
@media (max-width:900px){.fl-layout{grid-template-columns:1fr}.fl-detail{position:static}.fl-review{grid-template-columns:1fr}.fl-choices{grid-template-columns:1fr}}
@media (prefers-reduced-motion:reduce){.fl-status.busy,.fl-spinner{animation:none}}
''';

  static const script = r'''
(function () {
  var panel = document.getElementById('fw-panel-fish');
  if (!panel) return;
  function $(id) { return document.getElementById(id); }
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  var RARITY_COLOR = { Junk: '#9d8568', Common: '#c4c4c4', Uncommon: '#6fca7d', Rare: '#52a3e5', Epic: '#b06ce6', Legendary: '#f0b040' };
  var COND_LABEL = { Rain: 'Rain', Clear: 'Clear skies', Storm: 'Storm', Day: 'Daytime', Night: 'Night', Beach: 'Beach' };
  var lib = null, selected = null, providers = null, jobs = [], loaded = false;
  var jobTimer = null, viewer = null, reviewViewer = null;

  function api(path, options) {
    options = options || {};
    var init = { credentials: 'same-origin', headers: { Accept: 'application/json' } };
    if (options.body !== undefined) {
      init.method = options.method || 'POST';
      init.headers['Content-Type'] = 'application/json';
      init.body = JSON.stringify(options.body);
    }
    return fetch(path, init).then(function (r) {
      if (r.redirected || r.status === 401) { location.href = '/admin/login'; throw new Error('Signed out.'); }
      return r.json().catch(function () { return {}; }).then(function (json) {
        if (!r.ok) throw new Error(json.message || 'Request failed (' + r.status + ').');
        return json;
      });
    });
  }
  function store(key, value) {
    try { if (value === undefined) return JSON.parse(localStorage.getItem('fl.' + key) || 'null'); localStorage.setItem('fl.' + key, JSON.stringify(value)); } catch (e) { return null; }
  }

  // ---- 3D viewer -----------------------------------------------------------
  // Draws the wiki's model files (packed Roblox parts) with plain WebGL.
  function shapeGeometry() {
    function sphere() {
      var pos = [], nor = [], idx = [], rings = 18, segs = 28;
      for (var i = 0; i <= rings; i++) {
        var v = i / rings, phi = v * Math.PI;
        for (var j = 0; j <= segs; j++) {
          var u = j / segs, th = u * Math.PI * 2;
          var x = Math.cos(th) * Math.sin(phi), y = Math.cos(phi), z = Math.sin(th) * Math.sin(phi);
          pos.push(x * 0.5, y * 0.5, z * 0.5); nor.push(x, y, z);
        }
      }
      for (i = 0; i < rings; i++) for (j = 0; j < segs; j++) {
        var a = i * (segs + 1) + j, b = a + segs + 1;
        idx.push(a, b, a + 1, b, b + 1, a + 1);
      }
      return flat(pos, nor, idx);
    }
    function flat(pos, nor, idx) {
      var p = [], n = [];
      idx.forEach(function (k) { p.push(pos[k * 3], pos[k * 3 + 1], pos[k * 3 + 2]); n.push(nor[k * 3], nor[k * 3 + 1], nor[k * 3 + 2]); });
      return { pos: new Float32Array(p), nor: new Float32Array(n) };
    }
    function faces(list) {
      var p = [], n = [];
      list.forEach(function (f) {
        var a = f[0], b = f[1], c = f[2];
        var ux = b[0] - a[0], uy = b[1] - a[1], uz = b[2] - a[2], vx = c[0] - a[0], vy = c[1] - a[1], vz = c[2] - a[2];
        var nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx, l = Math.hypot(nx, ny, nz) || 1;
        var tris = f.length === 4 ? [[a, b, c], [a, c, f[3]]] : [[a, b, c]];
        tris.forEach(function (t) { t.forEach(function (v) { p.push(v[0], v[1], v[2]); n.push(nx / l, ny / l, nz / l); }); });
      });
      return { pos: new Float32Array(p), nor: new Float32Array(n) };
    }
    var h = 0.5;
    var box = faces([
      [[h, -h, -h], [h, h, -h], [h, h, h], [h, -h, h]], [[-h, -h, h], [-h, h, h], [-h, h, -h], [-h, -h, -h]],
      [[-h, h, -h], [-h, h, h], [h, h, h], [h, h, -h]], [[-h, -h, h], [-h, -h, -h], [h, -h, -h], [h, -h, h]],
      [[-h, -h, h], [h, -h, h], [h, h, h], [-h, h, h]], [[h, -h, -h], [-h, -h, -h], [-h, h, -h], [h, h, -h]]
    ]);
    // Roblox's wedge: full bottom and back faces, slope rising to the back-top edge.
    var A = [-h, -h, -h], B = [-h, -h, h], C = [-h, h, h], D = [h, -h, -h], E = [h, -h, h], F = [h, h, h];
    var wedge = faces([[A, C, B], [D, E, F], [A, B, E, D], [B, C, F, E], [A, D, F, C]]);
    var cyl = (function () {
      var list = [], segs = 24;
      for (var i = 0; i < segs; i++) {
        var a0 = i / segs * Math.PI * 2, a1 = (i + 1) / segs * Math.PI * 2;
        var p0 = [Math.cos(a0) * h, Math.sin(a0) * h], p1 = [Math.cos(a1) * h, Math.sin(a1) * h];
        list.push([[-h, p0[0], p0[1]], [h, p0[0], p0[1]], [h, p1[0], p1[1]], [-h, p1[0], p1[1]]]);
        list.push([[h, 0, 0], [h, p1[0], p1[1]], [h, p0[0], p0[1]]]);
        list.push([[-h, 0, 0], [-h, p0[0], p0[1]], [-h, p1[0], p1[1]]]);
      }
      var g = faces(list);
      // Smooth the side normals: radial in Y/Z.
      for (var k = 0; k < g.pos.length; k += 3) {
        if (Math.abs(Math.abs(g.nor[k]) - 1) > 0.01) {
          var l = Math.hypot(g.pos[k + 1], g.pos[k + 2]) || 1;
          g.nor[k] = 0; g.nor[k + 1] = g.pos[k + 1] / l; g.nor[k + 2] = g.pos[k + 2] / l;
        }
      }
      return g;
    })();
    return [box, sphere(), wedge, cyl];
  }

  function hexRgb(hex) { var n = parseInt(String(hex).slice(1), 16); return [(n >> 16 & 255) / 255, (n >> 8 & 255) / 255, (n & 255) / 255]; }
  function hsv(hh, s, v) {
    var i = Math.floor(hh * 6), f = hh * 6 - i, p = v * (1 - s), q = v * (1 - f * s), t = v * (1 - (1 - f) * s);
    return [[v, t, p], [q, v, p], [p, v, t], [p, q, v], [t, p, v], [v, p, q]][((i % 6) + 6) % 6];
  }

  function Viewer(box) {
    this.box = box;
    this.canvas = document.createElement('canvas');
    this.msg = document.createElement('div');
    this.msg.className = 'fl-viewer-msg';
    box.appendChild(this.canvas); box.appendChild(this.msg);
    var gl = this.gl = this.canvas.getContext('webgl', { antialias: true, alpha: true, premultipliedAlpha: false });
    if (!gl) { this.message('WebGL is not available in this browser.'); return; }
    var vs = 'attribute vec3 p;attribute vec3 n;uniform mat4 m;uniform mat4 vp;varying vec3 wn;varying vec3 wp;' +
      'void main(){vec4 w=m*vec4(p,1.0);wp=w.xyz;wn=mat3(m)*n;gl_Position=vp*w;}';
    var fs = 'precision mediump float;uniform vec3 c;uniform float a;uniform float glow;uniform vec3 eye;varying vec3 wn;varying vec3 wp;' +
      'void main(){vec3 N=normalize(wn);if(!gl_FrontFacing)N=-N;vec3 L=normalize(vec3(0.45,0.8,0.55));' +
      'float d=max(dot(N,L),0.0);float sky=0.5+0.5*N.y;vec3 V=normalize(eye-wp);float s=pow(max(dot(reflect(-L,N),V),0.0),24.0)*0.25;' +
      'vec3 lit=c*(0.38+0.22*sky+0.62*d)+s;gl_FragColor=vec4(mix(lit,c*1.15,glow),a);}';
    function sh(type, src) { var s = gl.createShader(type); gl.shaderSource(s, src); gl.compileShader(s); return s; }
    var prog = this.prog = gl.createProgram();
    gl.attachShader(prog, sh(gl.VERTEX_SHADER, vs)); gl.attachShader(prog, sh(gl.FRAGMENT_SHADER, fs)); gl.linkProgram(prog);
    this.loc = {};
    var self = this;
    ['m', 'vp', 'c', 'a', 'glow', 'eye'].forEach(function (k) { self.loc[k] = gl.getUniformLocation(prog, k); });
    this.attr = { p: gl.getAttribLocation(prog, 'p'), n: gl.getAttribLocation(prog, 'n') };
    this.geo = shapeGeometry().map(function (g) {
      var pb = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, pb); gl.bufferData(gl.ARRAY_BUFFER, g.pos, gl.STATIC_DRAW);
      var nb = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, nb); gl.bufferData(gl.ARRAY_BUFFER, g.nor, gl.STATIC_DRAW);
      return { p: pb, n: nb, count: g.pos.length / 3 };
    });
    this.yaw = 0; this.pitch = 0; this.zoom = 1; this.parts = []; this.data = null; this.spin = true;
    var drag = null;
    this.canvas.addEventListener('pointerdown', function (e) { drag = { x: e.clientX, y: e.clientY }; self.spin = false; self.canvas.setPointerCapture(e.pointerId); });
    this.canvas.addEventListener('pointermove', function (e) {
      if (!drag) return;
      self.yaw -= (e.clientX - drag.x) * 0.01; self.pitch = Math.max(-1.45, Math.min(1.45, self.pitch + (e.clientY - drag.y) * 0.01));
      drag = { x: e.clientX, y: e.clientY }; self.request();
    });
    this.canvas.addEventListener('pointerup', function () { drag = null; });
    this.canvas.addEventListener('wheel', function (e) { e.preventDefault(); self.zoom = Math.max(0.45, Math.min(2.2, self.zoom * (e.deltaY > 0 ? 1.1 : 0.9))); self.request(); }, { passive: false });
    this.canvas.addEventListener('dblclick', function () { self.yaw = 0; self.pitch = 0; self.zoom = 1; self.request(); });
    if (window.ResizeObserver) new ResizeObserver(function () { self.request(); }).observe(box);
  }
  Viewer.prototype.message = function (text) { this.msg.textContent = text || ''; this.msg.hidden = !text; };
  Viewer.prototype.load = function (url) {
    var self = this;
    this.data = null; this.parts = []; this.message('Loading model…'); this.request();
    if (!this.gl) return Promise.resolve();
    var token = this.token = {};
    return fetch(url, { credentials: 'same-origin' }).then(function (r) {
      if (!r.ok) throw new Error(r.status === 404 ? 'No model exported yet.' : 'Model failed to load.');
      return r.json();
    }).then(function (data) {
      if (self.token !== token) return;
      self.data = data; self.yaw = 0; self.pitch = 0; self.zoom = 1; self.spin = !matchMedia('(prefers-reduced-motion: reduce)').matches;
      self.variant('Normal'); self.message('');
    }).catch(function (e) { if (self.token === token) self.message(e.message); });
  };
  Viewer.prototype.variants = function () { return this.data ? ['Normal'].concat(Object.keys(this.data.variants || {})) : []; };
  Viewer.prototype.variant = function (key) {
    var d = this.data; if (!d) return;
    function unpack(n) {
      return { shape: n[0], size: [n[1], n[2], n[3]], pos: [n[4], n[5], n[6]], r: [n[7], n[8], n[9]], u: [n[10], n[11], n[12]], b: [n[13], n[14], n[15]],
        color: n[16], material: n[17], t: n[18] || 0, rainbow: n[19] };
    }
    var parts = d.parts.map(unpack), v = key !== 'Normal' && d.variants ? d.variants[key] : null;
    if (v) {
      (v.paint || []).forEach(function (p) { var part = parts[p[0]]; if (part) { part.color = p[1]; part.material = p[2]; part.t = p[3] || 0; part.rainbow = p[4]; } });
      (v.add || []).forEach(function (n) { parts.push(unpack(n)); });
    }
    parts.forEach(function (p) {
      var s = p.size, sx = s[0], sy = s[1], sz = s[2];
      if (p.shape === 3) { var dd = Math.min(sy, sz); sy = dd; sz = dd; }
      p.m = new Float32Array([p.r[0] * sx, p.r[1] * sx, p.r[2] * sx, 0, p.u[0] * sy, p.u[1] * sy, p.u[2] * sy, 0, p.b[0] * sz, p.b[1] * sz, p.b[2] * sz, 0, p.pos[0], p.pos[1], p.pos[2], 1]);
      p.rgb = hexRgb(p.color);
    });
    this.parts = parts; this.request();
  };
  Viewer.prototype.request = function () {
    var self = this;
    if (this.frame) return;
    this.frame = requestAnimationFrame(function (t) { self.frame = 0; self.draw(t); });
  };
  Viewer.prototype.draw = function (time) {
    var gl = this.gl, d = this.data;
    if (!gl) return;
    var dpr = Math.min(window.devicePixelRatio || 1, 2), w = Math.round(this.box.clientWidth * dpr), h = Math.round(this.box.clientHeight * dpr);
    if (!w || !h || !document.body.contains(this.box)) return;
    if (this.canvas.width !== w || this.canvas.height !== h) { this.canvas.width = w; this.canvas.height = h; }
    gl.viewport(0, 0, w, h); gl.clearColor(0, 0, 0, 0); gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    if (!d || !this.parts.length) return;
    if (this.spin) this.yaw += 0.004;
    var c = d.boundsCenter, size = d.boundsSize, radius = Math.hypot(size[0], size[1], size[2]) / 2 || 1;
    var view = d.view || [0.18, 0.16, 1], vl = Math.hypot(view[0], view[1], view[2]) || 1;
    var baseYaw = Math.atan2(view[0], view[2]), basePitch = Math.asin(Math.max(-1, Math.min(1, view[1] / vl)));
    var yaw = baseYaw + this.yaw, pitch = Math.max(-1.5, Math.min(1.5, basePitch + this.pitch));
    var fov = 30 * Math.PI / 180, dist = radius / Math.sin(fov / 2) * 1.02 * this.zoom;
    var eye = [c[0] + Math.sin(yaw) * Math.cos(pitch) * dist, c[1] + Math.sin(pitch) * dist, c[2] + Math.cos(yaw) * Math.cos(pitch) * dist];
    var vp = mul(perspective(fov, w / h, dist / 50, dist * 4), lookAt(eye, c));
    gl.useProgram(this.prog); gl.enable(gl.DEPTH_TEST); gl.disable(gl.CULL_FACE);
    gl.uniformMatrix4fv(this.loc.vp, false, vp); gl.uniform3fv(this.loc.eye, eye);
    var hue = (time || 0) / 4000, self = this, animated = this.spin;
    var opaque = this.parts.filter(function (p) { return p.t < 0.02; }), clear = this.parts.filter(function (p) { return p.t >= 0.02 && p.t < 0.99; });
    function drawPart(p) {
      var g = self.geo[p.shape] || self.geo[0], col = p.rgb;
      if (p.rainbow) { col = hsv(((p.rainbow[0] + hue) % 1 + 1) % 1, p.rainbow[1], p.rainbow[2]); animated = true; }
      gl.bindBuffer(gl.ARRAY_BUFFER, g.p); gl.enableVertexAttribArray(self.attr.p); gl.vertexAttribPointer(self.attr.p, 3, gl.FLOAT, false, 0, 0);
      gl.bindBuffer(gl.ARRAY_BUFFER, g.n); gl.enableVertexAttribArray(self.attr.n); gl.vertexAttribPointer(self.attr.n, 3, gl.FLOAT, false, 0, 0);
      gl.uniformMatrix4fv(self.loc.m, false, p.m); gl.uniform3fv(self.loc.c, col);
      gl.uniform1f(self.loc.a, 1 - p.t); gl.uniform1f(self.loc.glow, p.material === 'Neon' ? 0.85 : 0);
      gl.drawArrays(gl.TRIANGLES, 0, g.count);
    }
    gl.disable(gl.BLEND); gl.depthMask(true); opaque.forEach(drawPart);
    gl.enable(gl.BLEND); gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA); gl.depthMask(false); clear.forEach(drawPart); gl.depthMask(true);
    if (animated && !document.hidden) this.request();
  };
  function perspective(fov, aspect, near, far) {
    var f = 1 / Math.tan(fov / 2), nf = 1 / (near - far);
    return [f / aspect, 0, 0, 0, 0, f, 0, 0, 0, 0, (far + near) * nf, -1, 0, 0, 2 * far * near * nf, 0];
  }
  function lookAt(eye, at) {
    var z = norm([eye[0] - at[0], eye[1] - at[1], eye[2] - at[2]]), x = norm(cross([0, 1, 0], z)), y = cross(z, x);
    return [x[0], y[0], z[0], 0, x[1], y[1], z[1], 0, x[2], y[2], z[2], 0, -dot(x, eye), -dot(y, eye), -dot(z, eye), 1];
  }
  function mul(a, b) {
    var o = new Float32Array(16);
    for (var i = 0; i < 4; i++) for (var j = 0; j < 4; j++) { var s = 0; for (var k = 0; k < 4; k++) s += a[k * 4 + j] * b[i * 4 + k]; o[i * 4 + j] = s; }
    return o;
  }
  function norm(v) { var l = Math.hypot(v[0], v[1], v[2]) || 1; return [v[0] / l, v[1] / l, v[2] / l]; }
  function cross(a, b) { return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]; }
  function dot(a, b) { return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]; }

  function variantLabel(key) {
    var parts = key.split('/'), name = parts[0].replace(/\+/g, ' + ').replace('VoidTouched', 'Void Touched');
    return parts[1] ? name + ' · ' + parts[1].replace(/\+/g, ', ') : name;
  }
  function viewerControls(v, select) {
    select.innerHTML = v.variants().map(function (k) { return '<option value="' + esc(k) + '">' + esc(variantLabel(k)) + '</option>'; }).join('');
    select.hidden = v.variants().length < 2;
    select.onchange = function () { v.variant(select.value); };
  }

  // ---- library -------------------------------------------------------------
  function poolName(id) {
    var p = lib && (lib.pools || []).filter(function (x) { return x.id === id; })[0];
    return p ? p.name : id;
  }
  function kindOf(f) {
    if (f.dropOnly) return 'Shark drop';
    if (f.rarity === 'Junk') return 'Junk';
    if (!f.pools.length) return /Crab/.test(f.name) ? 'Crab cage' : 'Mussel net';
    return '';
  }
  function seasonText(f) {
    var s = f.seasons && f.seasons.length ? f.seasons.join(', ') : 'All year';
    return f.requires && f.requires.length ? s + ' · ' + f.requires.map(function (k) { return COND_LABEL[k] || k; }).join(' + ') : s;
  }
  function num(v) { return v == null ? '–' : (Math.round(v * 1000) / 1000).toLocaleString(); }

  function load(fresh) {
    $('flMeta').textContent = 'Loading the fish library…';
    return api('/admin/fishing-waters/fish' + (fresh ? '?fresh=1' : '')).then(function (json) {
      lib = json; loaded = true;
      var rar = $('flRarity'), pool = $('flPool'), r = rar.value, p = pool.value;
      rar.innerHTML = '<option value="">All rarities</option>' + json.rarities.map(function (x) { return '<option>' + esc(x) + '</option>'; }).join('');
      pool.innerHTML = '<option value="">Everywhere</option>' + json.pools.map(function (x) { return '<option value="' + esc(x.id) + '">' + esc(x.name) + '</option>'; }).join('') + '<option value="-">Nets, cages and drops</option>';
      rar.value = r; pool.value = p;
      var models = json.fish.filter(function (f) { return f.model; }).length;
      $('flMeta').innerHTML = esc(json.fish.length) + ' species · ' + models + ' with 3D models · <a href="https://github.com/' + esc(json.repo) + '/tree/' + esc(json.branch) + '/src/shared/Fish" target="_blank" rel="noopener">' + esc(json.repo) + '@' + esc(json.commit.slice(0, 7)) + '</a>' +
        (json.canCommit ? '' : ' · <b>read-only</b>: set LUMA_FISHING_WATERS_GITHUB_TOKEN to edit');
      $('flProblem').hidden = !json.problem; $('flProblem').textContent = json.problem || '';
      renderGrid();
      if (selected) select(selected, true);
    }).catch(function (e) { $('flMeta').textContent = e.message; });
  }
  function filtered() {
    var q = $('flSearch').value.trim().toLowerCase(), r = $('flRarity').value, p = $('flPool').value;
    var order = (lib.rarities || []);
    return lib.fish.filter(function (f) {
      if (q && f.name.toLowerCase().indexOf(q) < 0 && f.id.toLowerCase().indexOf(q) < 0) return false;
      if (r && f.rarity !== r) return false;
      if (p === '-') return !f.pools.length;
      return !p || f.pools.indexOf(p) >= 0;
    }).sort(function (a, b) { return order.indexOf(a.rarity) - order.indexOf(b.rarity) || a.name.localeCompare(b.name); });
  }
  function renderGrid() {
    if (!lib) return;
    var list = filtered();
    $('flGrid').innerHTML = list.length ? list.map(function (f) {
      var color = RARITY_COLOR[f.rarity] || '#9bb6c2', pal = f.palette;
      var swatch = pal ? 'linear-gradient(180deg,' + pal.back + ' 0%,' + pal.body + ' 50%,' + pal.belly + ' 100%)' : '#1f3a46';
      var tags = f.pools.map(function (p) { return '<span class="fl-tag">' + esc(poolName(p)) + '</span>'; }).join('');
      var kind = kindOf(f);
      if (kind) tags += '<span class="fl-tag">' + esc(kind) + '</span>';
      if (!f.hasBuild) tags += '<span class="fl-tag warn">No model</span>';
      return '<button type="button" class="fl-card" role="listitem" data-id="' + esc(f.id) + '" aria-current="' + (f.id === selected) + '">' +
        '<span class="fl-card-top"><span class="fl-swatch" style="background:' + swatch + '"></span><b>' + esc(f.name) + '</b></span>' +
        '<span class="fl-rar" style="color:' + color + '">' + esc(f.rarity) + '</span>' +
        '<small>1 in ' + num(f.odds) + ' · $' + num(f.value) + ' · ' + num(f.averageKg) + ' kg</small>' +
        '<span class="fl-tags">' + tags + '</span></button>';
    }).join('') : '<div class="fw-empty"><b>No fish match</b>Try another filter.</div>';
  }
  $('flGrid').addEventListener('click', function (e) {
    var card = e.target.closest('.fl-card');
    if (card) select(card.dataset.id);
  });
  ['flSearch', 'flRarity', 'flPool'].forEach(function (id) { $(id).addEventListener('input', renderGrid); });
  $('flReload').addEventListener('click', function () { load(true); loadJobs(); });

  function fishById(id) { return lib && lib.fish.filter(function (f) { return f.id === id; })[0]; }
  function select(id, keepView) {
    var f = fishById(id);
    if (!f) return;
    selected = id;
    Array.prototype.forEach.call(document.querySelectorAll('.fl-card'), function (c) { c.setAttribute('aria-current', String(c.dataset.id === id)); });
    var color = RARITY_COLOR[f.rarity] || '#9bb6c2';
    var detail = $('flDetail');
    detail.innerHTML = '<div class="fl-detail-head"><div><h3>' + esc(f.name) + '</h3>' +
      '<span class="fl-rar" style="color:' + color + '">' + esc(f.rarity) + '</span></div>' +
      '<button type="button" class="btn btn-primary" id="flEditThis"' + (lib.canCommit ? '' : ' disabled title="Needs the GitHub token"') + '>Edit</button></div>' +
      '<div class="fl-viewer" id="flViewerBox"></div>' +
      '<div class="fl-viewer-bar"><select class="fl-select" id="flVariant" aria-label="Mutation preview" hidden></select>' +
      '<span class="fl-hint">Drag to turn · scroll to zoom · double-click to reset</span></div>' +
      '<dl class="fl-facts">' +
      '<dt>Id</dt><dd>' + esc(f.id) + '</dd>' +
      '<dt>Odds</dt><dd>1 in ' + num(f.odds) + '</dd>' +
      '<dt>Weight</dt><dd>' + num(f.minKg) + ' – ' + num(f.maxKg) + ' kg (avg ' + num(f.averageKg) + ')</dd>' +
      '<dt>Value</dt><dd>$' + num(f.value) + ' at average weight</dd>' +
      '<dt>Fight</dt><dd>+' + num(f.fight) + '</dd>' +
      '<dt>Bites in</dt><dd>' + esc(f.pools.length ? f.pools.map(poolName).join(', ') : (kindOf(f) || '–')) + '</dd>' +
      '<dt>When</dt><dd>' + esc(seasonText(f)) + '</dd>' +
      '<dt>Model</dt><dd>' + (f.hasBuild ? (f.model ? 'In game and exported' : 'In game; not exported yet (refresh the wiki)') : 'None yet') + '</dd>' +
      '</dl>' +
      '<details class="fl-source" id="flSource"><summary>Luau source</summary><pre class="fl-code">Loading…</pre></details>';
    viewer = new Viewer($('flViewerBox'));
    if (f.hasBuild) {
      viewer.load('/admin/fishing-waters/fish/model/' + encodeURIComponent(f.slug)).then(function () { viewerControls(viewer, $('flVariant')); });
    } else viewer.message('This species has no Build yet. Ask the AI editor for a model.');
    $('flEditThis').onclick = function () { openEditor({ step: 'edit', fish: f.id }); };
    $('flSource').addEventListener('toggle', function () {
      if (!this.open || this.dataset.loaded) return;
      var pre = this.querySelector('pre'), el = this;
      api('/admin/fishing-waters/fish/source/' + encodeURIComponent(f.id)).then(function (j) { pre.textContent = j.source; el.dataset.loaded = '1'; })
        .catch(function (e) { pre.textContent = e.message; });
    });
  }

  // ---- jobs ----------------------------------------------------------------
  var BUSY = { queued: 1, generating: 1, previewing: 1, committing: 1 };
  function loadJobs() {
    clearTimeout(jobTimer);
    return api('/admin/fishing-waters/fish-jobs').then(function (json) {
      jobs = json.jobs; renderJobs();
      var busy = jobs.some(function (j) { return BUSY[j.status]; });
      if (!panel.classList.contains('active') && !$('flEditor').open) return;
      jobTimer = setTimeout(loadJobs, busy ? 2500 : 20000);
      if (reviewing) refreshReview();
    }).catch(function () { jobTimer = setTimeout(loadJobs, 20000); });
  }
  function statusChip(j) {
    var cls = BUSY[j.status] ? 'busy' : j.status;
    return '<span class="fl-status ' + esc(cls) + '">' + esc(j.status) + '</span>';
  }
  function renderJobs() {
    var visible = jobs.filter(function (j) { return j.status !== 'discarded' && (j.status !== 'committed' || Date.now() - j.updatedAt < 6 * 3600 * 1000); }).slice(0, 8);
    var box = $('flJobs');
    box.hidden = !visible.length;
    box.innerHTML = visible.map(function (j) {
      var what = j.mode === 'new' ? 'New: ' + j.name : 'Edit ' + j.fishId;
      var stage = j.status === 'failed' ? j.error : j.status === 'committed' ? 'Committed to GitHub' : j.status === 'ready' ? 'Preview ready for review' : j.stage;
      return '<div class="fl-job">' + statusChip(j) + '<b>' + esc(what) + '</b><span class="stage" title="' + esc(stage) + '">' + esc(stage) + '</span>' +
        '<span class="fl-hint">' + esc(j.model) + '</span>' +
        (j.commitUrl ? '<a class="btn btn-ghost" href="' + esc(j.commitUrl) + '" target="_blank" rel="noopener">Commit</a>' : '') +
        '<button type="button" class="btn ' + (j.status === 'ready' ? 'btn-primary' : 'btn-ghost') + '" data-review="' + esc(j.id) + '">' + (j.status === 'ready' ? 'Review' : 'Open') + '</button></div>';
    }).join('');
  }
  $('flJobs').addEventListener('click', function (e) {
    var b = e.target.closest('[data-review]');
    if (b) openEditor({ step: 'job', job: b.dataset.review });
  });

  // ---- editor --------------------------------------------------------------
  var dialog = $('flEditor'), body = $('flEditorBody'), reviewing = null;
  dialog.addEventListener('close', function () { reviewing = null; reviewViewer = null; body.innerHTML = ''; });
  $('flEditorBtn').addEventListener('click', function () { openEditor({ step: 'choose' }); });

  function openEditor(opts) {
    if (!lib) return;
    if (!dialog.open) dialog.showModal();
    reviewing = null;
    if (opts.step === 'choose') return stepChoose();
    if (opts.step === 'pick') return stepPick();
    if (opts.step === 'edit') return stepEdit(opts.fish);
    if (opts.step === 'new') return stepNew();
    if (opts.step === 'job') return stepJob(opts.job);
  }
  function title(text) { $('flEditorTitle').textContent = text; }
  function back(step, label) { return '<button type="button" class="fl-back" data-step="' + step + '">← ' + esc(label) + '</button>'; }
  body.addEventListener('click', function (e) {
    var b = e.target.closest('[data-step]');
    if (b) openEditor({ step: b.dataset.step, fish: b.dataset.fish });
  });

  function stepChoose() {
    title('Fish editor');
    body.innerHTML = (lib.canCommit ? '' : '<div class="fl-problem">Editing needs <code>LUMA_FISHING_WATERS_GITHUB_TOKEN</code> in the server\'s .env (Contents read/write on ' + esc(lib.repo) + ').</div>') +
      '<div class="fl-choices">' +
      '<button type="button" class="fl-choice" data-step="pick"><b>Edit an existing fish</b><span>Change rarity, price, weights, seasons, weather or where it bites with one click, or describe a bigger change for the AI (new look, rebalance…).</span></button>' +
      '<button type="button" class="fl-choice" data-step="new"><b>Add a new fish</b><span>Name it, choose when and where it bites, optionally upload a reference image, and let the AI write its data and 3D model.</span></button>' +
      '</div>';
  }

  function stepPick() {
    title('Edit a fish');
    body.innerHTML = back('choose', 'Back') +
      '<div class="fl-field"><span>Which fish?</span><input type="search" id="flPickSearch" placeholder="Search…" autocomplete="off"></div>' +
      '<div class="fl-grid" id="flPickGrid" style="margin-top:12px"></div>';
    function draw() {
      var q = $('flPickSearch').value.trim().toLowerCase();
      $('flPickGrid').innerHTML = lib.fish.filter(function (f) { return !q || f.name.toLowerCase().indexOf(q) >= 0; })
        .sort(function (a, b) { return a.name.localeCompare(b.name); })
        .map(function (f) {
          return '<button type="button" class="fl-card" data-step="edit" data-fish="' + esc(f.id) + '"><b>' + esc(f.name) + '</b>' +
            '<span class="fl-rar" style="color:' + (RARITY_COLOR[f.rarity] || '#9bb6c2') + '">' + esc(f.rarity) + '</span></button>';
        }).join('');
    }
    $('flPickSearch').addEventListener('input', draw); draw(); $('flPickSearch').focus();
  }

  function pills(name, options, checked, type, extra) {
    return '<div class="fl-pills" role="group">' + options.map(function (o) {
      var value = typeof o === 'string' ? o : o.value, label = typeof o === 'string' ? o : o.label;
      var cls = typeof o === 'string' || !o.cls ? '' : ' ' + o.cls;
      return '<label class="fl-pill' + cls + '"' + (o.title ? ' title="' + esc(o.title) + '"' : '') + '><input type="' + (type || 'checkbox') + '" name="' + name + '" value="' + esc(value) + '"' +
        (checked.indexOf(value) >= 0 ? ' checked' : '') + (extra || '') + '>' + esc(label) + '</label>';
    }).join('') + '</div>';
  }
  function checkedValues(form, name) {
    return Array.prototype.filter.call(form.querySelectorAll('input[name="' + name + '"]'), function (i) { return i.checked; }).map(function (i) { return i.value; });
  }
  function poolOptions() {
    return lib.pools.map(function (p) {
      var own = lib.fish.filter(function (f) { return f.pools.indexOf(p.id) >= 0; }).length;
      return { value: p.id, label: p.name + (p.inherits && !own ? ' (no own fish yet)' : ''), cls: p.inherits ? 'biome' : '',
        title: p.inherits ? 'Also bites every ' + poolName(p.inherits) + ' species' : '' };
    });
  }
  function conditionFields(requires) {
    var weather = lib.conditions.weather.filter(function (k) { return requires.indexOf(k) >= 0; })[0] || '';
    var time = lib.conditions.time.filter(function (k) { return requires.indexOf(k) >= 0; })[0] || '';
    return '<div class="fl-field wide"><span>Weather</span>' + pills('weather', [{ value: '', label: 'Any' }].concat(lib.conditions.weather.map(function (k) { return { value: k, label: COND_LABEL[k] }; })), [weather], 'radio') + '</div>' +
      '<div class="fl-field wide"><span>Time of day</span>' + pills('time', [{ value: '', label: 'Any' }].concat(lib.conditions.time.map(function (k) { return { value: k, label: COND_LABEL[k] }; })), [time], 'radio') + '</div>' +
      '<div class="fl-field wide"><span>Spot</span>' + pills('place', lib.conditions.place.map(function (k) { return { value: k, label: COND_LABEL[k] + ' only' }; }), requires) + '</div>';
  }
  function readConditions(form) {
    var out = [];
    ['weather', 'time'].forEach(function (n) { var v = (form.querySelector('input[name="' + n + '"]:checked') || {}).value; if (v) out.push(v); });
    return out.concat(checkedValues(form, 'place'));
  }
  function seasonsField(seasons) {
    return '<div class="fl-field wide"><span>Seasons <span class="fl-hint">(none picked = all year)</span></span>' + pills('seasons', lib.seasons, seasons) + '</div>';
  }

  function stepEdit(id) {
    var f = fishById(id);
    if (!f) return stepPick();
    title('Edit ' + f.name);
    body.innerHTML = back('pick', 'Pick another fish') +
      '<form class="fl-section" id="flQuick" novalidate><h3>Quick edit</h3><p>Commits straight to ' + esc(lib.branch) + ' — no AI involved.</p>' +
      '<div class="fl-form">' +
      '<label class="fl-field">Name<input name="name" value="' + esc(f.name) + '" maxlength="60"></label>' +
      '<label class="fl-field">Rarity<select name="rarity">' + lib.rarities.map(function (r) { return '<option' + (r === f.rarity ? ' selected' : '') + '>' + esc(r) + '</option>'; }).join('') + '</select></label>' +
      '<label class="fl-field">Odds (1 in N)<input name="odds" type="number" min="1" step="any" value="' + esc(f.odds) + '"></label>' +
      '<label class="fl-field">Value ($ at avg kg)<input name="value" type="number" min="0" step="any" value="' + esc(f.value) + '"></label>' +
      '<label class="fl-field">Min kg<input name="minKg" type="number" min="0" step="any" value="' + esc(f.minKg) + '"></label>' +
      '<label class="fl-field">Average kg<input name="averageKg" type="number" min="0" step="any" value="' + esc(f.averageKg) + '"></label>' +
      '<label class="fl-field">Max kg (HUGE record)<input name="maxKg" type="number" min="0" step="any" value="' + esc(f.maxKg) + '"></label>' +
      '<label class="fl-field">Fight (0 – 0.3)<input name="fight" type="number" min="0" max="0.3" step="0.01" value="' + esc(f.fight) + '"></label>' +
      seasonsField(f.seasons) + conditionFields(f.requires) +
      (f.pools.length || !kindOf(f) ? '<div class="fl-field wide"><span>Where it bites</span>' + pills('pools', poolOptions(), f.pools) +
        '<span class="fl-hint">Dashed areas are biomes with their own pool; they also bite every Open Sea fish.</span></div>' : '') +
      '</div><div class="fl-row"><span class="fl-msg grow" id="flQuickMsg" role="status"></span>' +
      '<button type="submit" class="btn btn-primary" id="flQuickSave">Save &amp; commit</button></div></form>' +
      '<form class="fl-section" id="flAiEdit" novalidate><h3>AI edit</h3><p>For anything else — a new look, a reworked model, rebalancing. You review a 3D preview and the diff before anything is committed.</p>' +
      '<div class="fl-form"><label class="fl-field wide">What should change?<textarea name="prompt" maxlength="8000" placeholder="e.g. Give it a longer, more pointed snout and bright orange fins; make it a bit heavier."></textarea></label>' +
      imageField() + '</div>' + aiPicker() +
      '<div class="fl-row"><span class="fl-msg grow" id="flAiMsg" role="status"></span><button type="submit" class="btn btn-primary">Generate preview</button></div></form>';
    wireImage(); wirePicker();
    $('flQuick').addEventListener('submit', function (e) {
      e.preventDefault();
      var form = this, changes = {}, msg = $('flQuickMsg');
      function set(key, value, old) { if (JSON.stringify(value) !== JSON.stringify(old)) changes[key] = value; }
      set('name', form.name.value.trim(), f.name);
      set('rarity', form.rarity.value, f.rarity);
      ['odds', 'value', 'minKg', 'averageKg', 'maxKg', 'fight'].forEach(function (k) {
        var v = parseFloat(form[k].value);
        if (!isNaN(v)) set(k, v, f[k]);
      });
      var seasons = checkedValues(form, 'seasons');
      set('seasons', seasons.length === 4 ? [] : seasons, f.seasons);
      set('requires', readConditions(form), f.requires);
      if (form.querySelector('input[name="pools"]')) set('pools', checkedValues(form, 'pools'), f.pools);
      if (!Object.keys(changes).length) { msg.className = 'fl-msg grow'; msg.textContent = 'Nothing changed.'; return; }
      if (changes.pools && !changes.pools.length && f.pools.length && !confirm('With no area picked, ' + f.name + ' stops biting anywhere. Continue?')) return;
      $('flQuickSave').disabled = true; msg.className = 'fl-msg grow'; msg.textContent = 'Committing…';
      api('/admin/fishing-waters/fish/' + encodeURIComponent(f.id) + '/quick', { body: { changes: changes } }).then(function (j) {
        msg.className = 'fl-msg grow ok';
        msg.innerHTML = j.unchanged ? 'Already up to date.' : 'Committed. <a href="' + esc(j.commit) + '" target="_blank" rel="noopener">View on GitHub</a>';
        return load(true).then(function () { var nf = fishById(f.id); if (nf) f = nf; });
      }).catch(function (err) { msg.className = 'fl-msg grow err'; msg.textContent = err.message; })
        .then(function () { $('flQuickSave').disabled = false; });
    });
    $('flAiEdit').addEventListener('submit', function (e) {
      e.preventDefault();
      var prompt = this.prompt.value.trim();
      if (!prompt && !image) { $('flAiMsg').className = 'fl-msg grow err'; $('flAiMsg').textContent = 'Say what to change.'; return; }
      startJob({ mode: 'edit', fishId: f.id, prompt: prompt }, $('flAiMsg'));
    });
  }

  function stepNew() {
    title('Add a new fish');
    body.innerHTML = back('choose', 'Back') +
      '<form class="fl-section" id="flNew" novalidate><h3>The new fish</h3><p>The AI picks weights, value, fight and cargo size in line with fish of the same rarity, and writes the 3D model. You review it before it is committed.</p>' +
      '<div class="fl-form">' +
      '<label class="fl-field">Name<input name="name" maxlength="60" required placeholder="e.g. Ember Snapper"></label>' +
      '<label class="fl-field">Rarity<select name="rarity"><option value="">Let the AI choose</option>' + lib.rarities.filter(function (r) { return r !== 'Junk'; }).map(function (r) { return '<option>' + esc(r) + '</option>'; }).join('') + '</select></label>' +
      seasonsField([]) + conditionFields([]) +
      '<div class="fl-field wide"><span>Where it bites</span>' + pills('pools', poolOptions(), []) +
      '<span class="fl-hint">Dashed areas (biomes) get their own pool the moment a fish names them; players there still catch every Open Sea fish too.</span></div>' +
      '<label class="fl-field wide"><span>Notes for the AI <span class="fl-hint">(optional)</span></span><textarea name="prompt" maxlength="8000" placeholder="Looks, colours, behaviour, how rare or valuable it should feel…"></textarea></label>' +
      imageField() + '</div>' + aiPicker() +
      '<div class="fl-row"><span class="fl-msg grow" id="flNewMsg" role="status"></span><button type="submit" class="btn btn-primary">Generate fish</button></div></form>';
    wireImage(); wirePicker();
    $('flNew').addEventListener('submit', function (e) {
      e.preventDefault();
      var form = this, msg = $('flNewMsg');
      var fields = { name: form.name.value.trim(), seasons: checkedValues(form, 'seasons'), requires: readConditions(form), pools: checkedValues(form, 'pools') };
      if (form.rarity.value) fields.rarity = form.rarity.value;
      if (!fields.name) { msg.className = 'fl-msg grow err'; msg.textContent = 'Give it a name.'; return; }
      if (!fields.pools.length) { msg.className = 'fl-msg grow err'; msg.textContent = 'Pick at least one place it bites.'; return; }
      if (fields.seasons.length === 4) fields.seasons = [];
      startJob({ mode: 'new', fields: fields, prompt: form.prompt.value.trim() }, msg);
    });
  }

  // Reference image, scaled to at most 1024 px so it stays cheap to send.
  var image = null;
  function imageField() {
    image = null;
    return '<div class="fl-field wide"><span>Reference image <span class="fl-hint">(optional; needs a model that reads images)</span></span>' +
      '<div class="fl-image"><input type="file" id="flImage" accept="image/png,image/jpeg,image/webp,image/gif"><img id="flImageThumb" alt="" hidden>' +
      '<button type="button" class="btn btn-ghost" id="flImageClear" hidden>Remove</button></div></div>';
  }
  function wireImage() {
    var input = $('flImage'), thumb = $('flImageThumb'), clear = $('flImageClear');
    input.addEventListener('change', function () {
      var file = input.files[0];
      if (!file) return;
      if (file.size > 20 * 1024 * 1024) { alert('That image is too large.'); input.value = ''; return; }
      var reader = new FileReader();
      reader.onload = function () {
        var img = new Image();
        img.onload = function () {
          var scale = Math.min(1, 1024 / Math.max(img.width, img.height)), c = document.createElement('canvas');
          c.width = Math.round(img.width * scale); c.height = Math.round(img.height * scale);
          c.getContext('2d').drawImage(img, 0, 0, c.width, c.height);
          image = c.toDataURL(file.type === 'image/png' ? 'image/png' : 'image/jpeg', 0.9);
          thumb.src = image; thumb.hidden = false; clear.hidden = false;
        };
        img.src = reader.result;
      };
      reader.readAsDataURL(file);
    });
    clear.addEventListener('click', function () { image = null; input.value = ''; thumb.hidden = true; clear.hidden = true; });
  }

  function aiPicker() {
    return '<div class="fl-form" style="margin-top:12px">' +
      '<label class="fl-field">Provider<select id="flProvider"><option>Loading…</option></select></label>' +
      '<label class="fl-field" style="grid-column:span 2">Model<input id="flModel" list="flModels" autocomplete="off" spellcheck="false" placeholder="Model id"><datalist id="flModels"></datalist></label>' +
      '<label class="fl-field">Effort<select id="flEffort"></select></label>' +
      '<span class="fl-hint wide" id="flModelHint"></span></div>';
  }
  function wirePicker() {
    var prov = $('flProvider'), model = $('flModel'), effort = $('flEffort'), hint = $('flModelHint');
    var saved = store('ai') || {};
    function provider() { return providers && providers.providers.filter(function (p) { return p.id === prov.value; })[0]; }
    function info() { var p = provider(); return p && p.models.filter(function (m) { return m.id === model.value; })[0]; }
    function drawModels() {
      var p = provider();
      if (!p) return;
      $('flModels').innerHTML = p.models.map(function (m) { return '<option value="' + esc(m.id) + '">' + esc(m.name !== m.id ? m.name : '') + '</option>'; }).join('');
      drawEffort();
    }
    function drawEffort() {
      var m = info(), list = m && m.efforts && m.efforts.length ? [''].concat(m.efforts) : providers.efforts, cur = effort.value || saved.effort || '';
      effort.innerHTML = list.map(function (e) { return '<option value="' + esc(e) + '">' + (e ? esc(e) : 'Default') + '</option>'; }).join('');
      effort.value = list.indexOf(cur) >= 0 ? cur : (m && m.defaultEffort) || '';
      var parts = [];
      if (m && m.input != null) parts.push('$' + m.input + ' in / $' + m.output + ' out per M tokens');
      if (m && m.images === false) parts.push('this model cannot read images');
      if (!m && model.value) parts.push('not in the catalogue; sent as typed');
      hint.textContent = parts.join(' · ');
    }
    function fill() {
      prov.innerHTML = providers.providers.map(function (p) { return '<option value="' + esc(p.id) + '"' + (p.configured ? '' : ' disabled') + '>' + esc(p.label) + (p.configured ? '' : ' (no key)') + '</option>'; }).join('');
      var first = providers.providers.filter(function (p) { return p.configured; })[0];
      prov.value = saved.provider && providers.providers.some(function (p) { return p.id === saved.provider && p.configured; }) ? saved.provider : first ? first.id : '';
      model.value = saved.provider === prov.value && saved.model ? saved.model : (provider() && provider().models[0] ? provider().models[0].id : '');
      drawModels();
    }
    prov.addEventListener('change', function () { model.value = provider() && provider().models[0] ? provider().models[0].id : ''; drawModels(); });
    model.addEventListener('change', drawEffort);
    effort.addEventListener('change', function () { saved.effort = effort.value; });
    (providers ? Promise.resolve(providers) : api('/admin/fishing-waters/fish/providers').then(function (j) { providers = j; return j; }))
      .then(fill).catch(function (e) { hint.textContent = e.message; });
  }
  function picked() {
    var choice = { provider: $('flProvider').value, model: $('flModel').value.trim(), effort: $('flEffort').value };
    store('ai', choice);
    return choice;
  }

  function startJob(request, msg) {
    var choice = picked();
    if (!choice.provider || !choice.model) { msg.className = 'fl-msg grow err'; msg.textContent = 'Pick a provider and model.'; return; }
    request.provider = choice.provider; request.model = choice.model; request.effort = choice.effort;
    if (image) request.image = image;
    msg.className = 'fl-msg grow'; msg.textContent = 'Starting…';
    api('/admin/fishing-waters/fish-jobs', { body: request }).then(function (job) {
      jobs.unshift(job); renderJobs(); loadJobs();
      openEditor({ step: 'job', job: job.id });
    }).catch(function (e) { msg.className = 'fl-msg grow err'; msg.textContent = e.message; });
  }

  // ---- review --------------------------------------------------------------
  function lineDiff(a, b) {
    a = (a || '').replace(/\r\n/g, '\n').split('\n'); b = (b || '').replace(/\r\n/g, '\n').split('\n');
    if (a.length * b.length > 4e6) return b.map(function (l) { return ['add', l]; });
    var n = a.length, m = b.length, dp = [];
    for (var i = 0; i <= n; i++) { dp.push(new Uint16Array(m + 1)); }
    for (i = n - 1; i >= 0; i--) for (var j = m - 1; j >= 0; j--) dp[i][j] = a[i] === b[j] ? dp[i + 1][j + 1] + 1 : Math.max(dp[i + 1][j], dp[i][j + 1]);
    var out = []; i = 0; j = 0;
    while (i < n || j < m) {
      if (i < n && j < m && a[i] === b[j]) { out.push(['same', a[i]]); i++; j++; }
      else if (i < n && (j >= m || dp[i + 1][j] >= dp[i][j + 1])) { out.push(['del', a[i]]); i++; }
      else { out.push(['add', b[j]]); j++; }
    }
    // Fold long unchanged runs.
    var folded = [], run = [];
    function flush(end) {
      if (run.length > 6) { folded.push.apply(folded, run.slice(0, 2)); folded.push(['gap', '… ' + (run.length - 4) + ' unchanged lines']); folded.push.apply(folded, run.slice(-2)); }
      else folded.push.apply(folded, run);
      run = [];
    }
    out.forEach(function (d) { if (d[0] === 'same') run.push(d); else { flush(); folded.push(d); } });
    flush();
    return folded;
  }
  function fieldsOf(src) {
    var get = function (k) { var m = new RegExp('^\\t' + k + ' = (.*),\\r?$', 'm').exec(src || ''); return m ? m[1] : null; };
    return ['Name', 'Rarity', 'RarityDenominator', 'MinKg', 'AverageKg', 'MaxKg', 'BaseValue', 'Fight', 'Pools', 'Seasons', 'Requires']
      .map(function (k) { return [k, get(k)]; }).filter(function (p) { return p[1] != null; });
  }

  function stepJob(id) {
    reviewing = id;
    title('Fish job');
    body.innerHTML = '<div class="fl-progress"><span class="fl-spinner"></span>Loading…</div>';
    reviewViewer = null;
    refreshReview(true);
  }
  function refreshReview(first) {
    var id = reviewing;
    if (!id) return;
    api('/admin/fishing-waters/fish-jobs/' + encodeURIComponent(id)).then(function (job) {
      if (reviewing !== id) return;
      var key = job.status + '|' + (job.revisions || []).length + '|' + job.stage;
      if (!first && body.dataset.key === key) return;
      body.dataset.key = key;
      renderReview(job);
    }).catch(function (e) { body.innerHTML = '<p class="fl-msg err">' + esc(e.message) + '</p>'; });
  }
  function renderReview(job) {
    var name = job.mode === 'new' ? (job.fields && job.fields.Name) || job.fishId : job.fishId;
    title((job.mode === 'new' ? 'New fish: ' : 'Edit: ') + name);
    var meta = '<p class="fl-hint">' + esc(job.provider) + ' · ' + esc(job.model) + (job.effort ? ' · ' + esc(job.effort) + ' effort' : '') +
      (job.tokens ? ' · ' + job.tokens.toLocaleString() + ' tokens' : '') + (job.cost ? ' · $' + job.cost.toFixed(4) : '') + '</p>';
    if (BUSY[job.status]) {
      body.innerHTML = meta + '<div class="fl-progress"><span class="fl-spinner"></span><div><b>' + esc(job.status === 'previewing' ? 'Building the 3D preview' : job.status === 'committing' ? 'Committing' : 'Writing the fish') + '</b><br><span class="fl-hint">' + esc(job.stage || 'Queued…') + '</span></div></div>' +
        '<p class="fl-hint">You can close this window; the job keeps running and shows above the library.</p>' +
        '<div class="fl-row"><span class="grow"></span><button type="button" class="btn btn-ghost" id="flDiscard">Cancel job</button></div>';
      $('flDiscard').onclick = function () { act(job, 'discard'); };
      return;
    }
    var diff = lineDiff(job.original || '', job.result || '');
    var facts = fieldsOf(job.result).map(function (p) { return '<dt>' + esc(p[0]) + '</dt><dd>' + esc(p[1]) + '</dd>'; }).join('');
    var head = job.status === 'failed' ? '<div class="fl-problem">' + esc(job.error || 'Failed.') + '</div>' :
      job.status === 'committed' ? '<p class="fl-msg ok">Committed to GitHub. <a href="' + esc(job.commitUrl) + '" target="_blank" rel="noopener">View the commit</a>. The wiki refreshes on its own.</p>' :
      job.status === 'discarded' ? '<p class="fl-msg">Discarded.</p>' : '';
    body.innerHTML = meta + head +
      (job.result ? '<div class="fl-review"><div><div class="fl-viewer" id="flReviewBox"></div>' +
        '<div class="fl-viewer-bar"><select class="fl-select" id="flReviewVariant" aria-label="Mutation preview" hidden></select></div>' +
        '<dl class="fl-facts">' + facts + '</dl>' + (job.notes ? '<div class="fl-notes">' + esc(job.notes) + '</div>' : '') + '</div>' +
        '<div><div class="fl-diff" aria-label="Changes">' + diff.map(function (d) {
          return '<div class="' + (d[0] === 'same' ? '' : d[0]) + '">' + (d[0] === 'add' ? '+ ' : d[0] === 'del' ? '- ' : d[0] === 'gap' ? '' : '  ') + esc(d[1]) + '</div>';
        }).join('') + '</div></div></div>' : '') +
      (job.status === 'ready' || job.status === 'failed' ? '<form class="fl-section" id="flRevise" novalidate><h3>Ask for changes</h3>' +
        '<div class="fl-field"><textarea name="prompt" maxlength="8000" placeholder="e.g. The dorsal fin is too tall; make the belly paler."></textarea></div>' +
        '<div class="fl-row"><span class="fl-msg grow" id="flReviewMsg" role="status"></span>' +
        '<button type="submit" class="btn btn-ghost">Revise</button>' +
        '<button type="button" class="btn btn-ghost" id="flDiscard">Discard</button>' +
        (job.status === 'ready' ? '<button type="button" class="btn btn-primary" id="flApprove">Approve &amp; commit</button>' : '') +
        '</div></form>' : '');
    if (job.result) {
      reviewViewer = new Viewer($('flReviewBox'));
      if (job.hasPreview) reviewViewer.load('/admin/fishing-waters/fish-jobs/' + encodeURIComponent(job.id) + '/preview?v=' + (job.revisions || []).length).then(function () { viewerControls(reviewViewer, $('flReviewVariant')); });
      else reviewViewer.message('No preview was built.');
    }
    var revise = $('flRevise');
    if (revise) revise.addEventListener('submit', function (e) {
      e.preventDefault();
      var text = this.prompt.value.trim();
      if (!text) { $('flReviewMsg').className = 'fl-msg grow err'; $('flReviewMsg').textContent = 'Say what to change.'; return; }
      act(job, 'revise', { prompt: text });
    });
    if ($('flDiscard')) $('flDiscard').onclick = function () { if (confirm('Discard this job?')) act(job, 'discard'); };
    if ($('flApprove')) $('flApprove').onclick = function () { this.disabled = true; act(job, 'approve'); };
  }
  function act(job, action, payload) {
    var msg = $('flReviewMsg');
    if (msg) { msg.className = 'fl-msg grow'; msg.textContent = action === 'approve' ? 'Committing…' : 'Working…'; }
    api('/admin/fishing-waters/fish-jobs/' + encodeURIComponent(job.id) + '/' + action, { body: payload || {} }).then(function (j) {
      body.dataset.key = ''; renderReview(j); loadJobs();
      if (action === 'approve') load(true).then(function () { if (j.fishId) { selected = j.fishId; select(j.fishId); } });
    }).catch(function (e) {
      if (msg) { msg.className = 'fl-msg grow err'; msg.textContent = e.message; }
      if ($('flApprove')) $('flApprove').disabled = false;
    });
  }

  document.addEventListener('fwtab', function (e) {
    if (e.detail !== 'fish') return;
    if (!loaded) load(false);
    loadJobs();
    if (viewer) viewer.request();
  });
})();
''';
}
