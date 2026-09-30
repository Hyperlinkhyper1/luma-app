// Weather over the island: rain, storms and thunderstorms.
//
// Rain is a cloud of streaks round the camera, moved entirely on the GPU and
// kept off anything with a roof over it by a heightmap of the world, the way
// the game stops rain at the highest block. Lightning is a jagged bolt far
// off with a flash that lights the sky and everything the sky reaches. The
// sound is synthesised here — rain drop by drop, wind and thunder — so nothing
// of the game's is needed.
(() => {
  'use strict';

  const MODES = ['clear', 'rain', 'storm', 'thunder', 'cycle'];
  // What each kind of weather settles to: how hard it rains, how hard the
  // wind blows, and whether there is lightning.
  const STATES = {
    clear: {rain: 0, wind: 0, thunder: false},
    rain: {rain: 0.55, wind: 0.12, thunder: false},
    storm: {rain: 1, wind: 0.85, thunder: false},
    thunder: {rain: 1, wind: 0.6, thunder: true},
  };

  const RAIN_VERT = /* glsl */ `
    attribute vec4 seed;
    attribute vec2 corner;
    uniform vec3 center;
    uniform float time;
    uniform float radius;
    uniform float span;
    uniform float amount;
    uniform float fallSpeed;
    uniform float dropLength;
    uniform float width;
    uniform vec2 wind;
    varying float vFade;
    varying vec3 vWorld;
    void main() {
      // Each drop keeps its place in the world; the window of rain round
      // the camera wraps rather than following it.
      if (seed.w > amount) { gl_Position = vec4(2.0, 2.0, 2.0, 1.0); return; }
      float size = radius * 2.0;
      float fall = fallSpeed * (0.85 + fract(seed.w * 7.13) * 0.3);
      float top = center.y + span * 0.5;
      float y = top - mod(time * fall + seed.z * span, span);
      // The wind carries each drop sideways as it falls.
      vec2 drift = wind * ((top - y) / fall);
      vec2 base = center.xz - radius;
      vec2 xz = base + mod(seed.xy * size + drift - base, size);
      vec3 dir = normalize(vec3(wind.x, -fall, wind.y));
      vec3 head = vec3(xz.x, y, xz.y);
      vec3 p = head - dir * corner.y * dropLength;
      vec3 side = normalize(cross(dir, cameraPosition - head));
      p += side * corner.x * width;
      vWorld = p;
      vFade = (1.0 - smoothstep(radius * 0.55, radius, length(xz - center.xz))) * (1.0 - corner.y * 0.65);
      gl_Position = projectionMatrix * viewMatrix * vec4(p, 1.0);
    }
  `;

  const RAIN_FRAG = /* glsl */ `
    uniform sampler2D heightMap;
    uniform vec4 hmBox;
    uniform vec3 rainColor;
    uniform float opacity;
    varying float vFade;
    varying vec3 vWorld;
    void main() {
      vec2 cell = floor(vWorld.xz) - hmBox.xy;
      if (cell.x >= 0.0 && cell.y >= 0.0 && cell.x < hmBox.z && cell.y < hmBox.w) {
        float h = texture2D(heightMap, (cell + 0.5) / hmBox.zw).r * 255.0 - 64.0;
        if (vWorld.y < h) discard;
      }
      gl_FragColor = vec4(rainColor, opacity * vFade);
    }
  `;

  const BOLT_VERT = /* glsl */ `
    attribute float glow;
    varying float vGlow;
    void main() {
      vGlow = glow;
      gl_Position = projectionMatrix * viewMatrix * modelMatrix * vec4(position, 1.0);
    }
  `;
  const BOLT_FRAG = /* glsl */ `
    uniform float brightness;
    varying float vGlow;
    void main() {
      gl_FragColor = vec4(vec3(2.6, 2.8, 3.6) * brightness * vGlow, 1.0);
    }
  `;

  // ── Sound ──────────────────────────────────────────────────────────────
  // Browsers only start audio after the reader has touched the page, so
  // everything is built on the first click or key press.
  //
  // Rain outdoors is a real recording (rain_audio.js), dulled through the
  // walls indoors. If it cannot be decoded, the rain is written drop by
  // drop instead: sharp ticks where drops hit leaves and ground and little
  // "plinks" where they land in water, over a soft wash. Thunder is written fresh for every strike: close by, a
  // tearing crack of discharges and a boom; then a low rumble that rolls in
  // several swells as the sound comes back from different parts of the bolt.
  function createAudio() {
    const A = {ctx: null, volume: 1, muffled: 0, wanted: true};
    const AC = window.AudioContext || window.webkitAudioContext;

    function noise(seconds, brown) {
      const ctx = A.ctx;
      const buffer = ctx.createBuffer(1, Math.floor(ctx.sampleRate * seconds), ctx.sampleRate);
      const data = buffer.getChannelData(0);
      let last = 0;
      for (let i = 0; i < data.length; i++) {
        const white = Math.random() * 2 - 1;
        if (brown) { last = (last + 0.02 * white) / 1.02; data[i] = last * 3.5; } else data[i] = white;
      }
      return buffer;
    }

    // Scales channels so their loudest sample sits at `peak`.
    function normalise(chans, peak) {
      let max = 1e-6;
      for (const c of chans) for (let i = 0; i < c.length; i++) max = Math.max(max, Math.abs(c[i]));
      for (const c of chans) for (let i = 0; i < c.length; i++) c[i] *= peak / max;
    }

    // Writing sound takes a while, so it is done a few milliseconds at a
    // time between frames: the writers are generators that yield now and
    // then, and `work` runs one in slices until it hands back its buffer.
    function work(gen, done) {
      const job = {buffer: null, gen};
      const step = () => {
        if (job.buffer) return;
        const end = performance.now() + 5;
        let r;
        do r = gen.next(); while (!r.done && performance.now() < end);
        if (r.done) { job.buffer = r.value; done?.(r.value); } else setTimeout(step, 0);
      };
      setTimeout(step, 0);
      return job;
    }
    // Finishes a job at once, when its sound is wanted now.
    function finish(job) {
      if (!job.buffer) {
        let r;
        do r = job.gen.next(); while (!r.done);
        job.buffer = r.value;
      }
      return job.buffer;
    }

    // A seamless stereo loop of rain, `perSecond` drops a second. `kind` is
    // 'open' (leaves, grass and puddles) or 'roof' (drumming on the boards
    // overhead: dull knocks, no bubbles).
    function* rainLoop(seconds, perSecond, kind) {
      const ctx = A.ctx, sr = ctx.sampleRate, n = Math.floor(sr * seconds);
      const buffer = ctx.createBuffer(2, n, sr);
      const L = buffer.getChannelData(0), R = buffer.getChannelData(1);
      const roof = kind === 'roof';
      // The wash: pink noise with its low end taken out, swelling slowly.
      // It is written a little long and its tail folded over its head, so
      // the loop has no seam.
      const fade = Math.floor(sr * 0.5);
      const cut = roof ? 0.02 : 0.05, soft = roof ? 0.08 : 0.6;
      for (const out of [L, R]) {
        const w = new Float32Array(n + fade);
        let b0 = 0, b1 = 0, b2 = 0, lp = 0, lp2 = 0, swell = 0.6;
        for (let i = 0; i < w.length; i++) {
          const white = Math.random() * 2 - 1;
          b0 = 0.99765 * b0 + white * 0.099; b1 = 0.963 * b1 + white * 0.2965; b2 = 0.57 * b2 + white * 1.0526;
          const pink = (b0 + b1 + b2 + white * 0.1848) * 0.2;
          lp += (pink - lp) * cut;
          lp2 += (pink - lp - lp2) * soft;
          if (i % 256 === 0) swell = Math.max(0.3, Math.min(1, swell + (Math.random() - 0.5) * 0.02));
          if (i % 8192 === 0) yield;
          w[i] = lp2 * swell;
        }
        const level = roof ? 0.5 : 0.35;
        for (let i = 0; i < n; i++) out[i] = (i < fade ? w[i] * (i / fade) + w[n + i] * (1 - i / fade) : w[i]) * level;
      }
      // The drops, each placed round the loop so the ones near its end wrap
      // onto its start.
      const count = Math.floor(perSecond * seconds);
      for (let d = 0; d < count; d++) {
        if (d % 64 === 0) yield;
        const at = Math.floor(Math.random() * n);
        const pan = Math.random();
        const gl = Math.sqrt(1 - pan), gr = Math.sqrt(pan);
        // Most drops are faint and far; now and then one is close.
        const amp = 0.04 + 0.9 * Math.pow(Math.random(), 4);
        if (!roof && Math.random() < 0.14) {
          // A bubble rings at a pitch set by its size and rises as it
          // shrinks to the surface.
          const f0 = 1100 + Math.random() * 2600, len = Math.floor(sr * (0.008 + Math.random() * 0.02));
          let ph = 0;
          for (let k = 0; k < len; k++) {
            const u = k / len;
            ph += 2 * Math.PI * f0 * (1 + 0.7 * u) / sr;
            const v = Math.sin(ph) * Math.exp(-u * 4.5) * Math.min(1, k / (sr * 0.0006)) * amp * 0.55;
            const j = (at + k) % n;
            L[j] += v * gl; R[j] += v * gr;
          }
        } else {
          // An impact: a click of noise, crisp on leaves, a dull knock on
          // the roof.
          const len = Math.floor(sr * (roof ? 0.004 + Math.random() * 0.01 : 0.0006 + Math.random() * 0.003));
          const tau = len * (roof ? 0.35 : 0.25);
          let prev = 0, low = 0;
          for (let k = 0; k < len; k++) {
            const white = Math.random() * 2 - 1;
            let v;
            if (roof) { low += (white - low) * 0.12; v = low * 2.2; } else { v = white - prev * 0.85; prev = white; }
            v *= Math.exp(-k / tau) * amp;
            const j = (at + k) % n;
            L[j] += v * gl; R[j] += v * gr;
          }
        }
      }
      normalise([L, R], 0.9);
      return buffer;
    }

    // One clap of thunder, `near` 0 (far off) to 1 (overhead), as a stereo
    // buffer.
    function* thunderClap(near) {
      const ctx = A.ctx, sr = ctx.sampleRate;
      const dur = 5.5 + (1 - near) * 3 + Math.random() * 1.5, n = Math.floor(sr * dur);
      const buffer = ctx.createBuffer(2, n, sr);
      const chans = [buffer.getChannelData(0), buffer.getChannelData(1)];
      // When the rolls come: the nearest part of the bolt first and loudest,
      // the rest bunched early and trailing off. Far away they spread out
      // and the start is soft.
      const rolls = [];
      const count = 4 + Math.floor(Math.random() * 5);
      for (let i = 0; i < count; i++) {
        rolls.push({
          at: i === 0 ? (1 - near) * 0.25 : (1 - near) * 0.3 + Math.pow(Math.random(), 1.6) * dur * (0.45 + (1 - near) * 0.2),
          amp: i === 0 ? 1 : 0.25 + Math.random() * 0.7,
          rise: i === 0 ? 0.02 + (1 - near) * 0.35 : 0.08 + Math.random() * 0.3,
          fall: 0.5 + Math.random() * 1.6 + (1 - near) * 0.8,
          side: Math.random() * 2 - 1,
        });
      }
      const grainStep = Math.floor(sr / 14);
      for (const [c, out] of chans.entries()) {
        const side = c ? 1 : -1;
        let brown = 0, lp1 = 0, lp2 = 0, grain = 1, grainGoal = 1, env = 0, a = 1, rattleLevel = 0;
        for (let i = 0; i < n; i++) {
          const t = i / sr;
          if (i % 32 === 0) {
            if (i % 8192 === 0) yield;
            env = 0;
            for (const r of rolls) {
              if (t < r.at) continue;
              const s = t - r.at;
              env += r.amp * (1 + r.side * side * 0.35) * (1 - Math.exp(-s / r.rise)) * Math.exp(-s / r.fall);
            }
            env *= Math.min(1, (dur - t) / 0.8);
            // Deep noise whose top end sinks as the thunder rolls away;
            // enough of it stays above 100 Hz to be heard on small speakers.
            const fc = (150 + near * 900) * Math.exp(-t * 0.3) + 90;
            a = Math.min(1, 2 * Math.PI * fc / sr);
            // Near by, a rattle of higher sound rides on the first seconds.
            rattleLevel = near > 0.3 ? 0.1 * near * Math.exp(-t * 1.4) : 0;
          }
          // The rumble's grain: its loudness flutters a dozen times a second.
          if (i % grainStep === 0) grainGoal = 0.45 + Math.random() * 0.75;
          grain += (grainGoal - grain) * 0.0015;
          const white = Math.random() * 2 - 1;
          brown = brown * 0.97 + white * 0.2;
          lp1 += (brown - lp1) * a; lp2 += (lp1 - lp2) * a;
          out[i] = (lp2 * 1.6 + (white - lp1) * rattleLevel) * env * grain;
        }
      }
      if (near > 0.35) {
        // The crack: a tearing run of discharges, quicker and quieter as it
        // goes, then the boom of the channel's air expanding.
        const pan = Math.random();
        let at = Math.floor(sr * 0.01), amp = near;
        const clicks = 12 + Math.floor(near * 30);
        for (let c = 0; c < clicks; c++) {
          const len = Math.floor(sr * (0.002 + Math.random() * 0.005));
          let prev = 0;
          for (let k = 0; k < len && at + k < n; k++) {
            const white = Math.random() * 2 - 1;
            const v = (white - prev * 0.6) * Math.exp(-k / (len * 0.3)) * amp * (0.5 + Math.random() * 0.5);
            prev = white;
            chans[0][at + k] += v * Math.sqrt(1 - pan) * 1.4;
            chans[1][at + k] += v * Math.sqrt(pan) * 1.4;
          }
          at += Math.floor(sr * (0.003 + Math.random() * 0.02 * (1 + c / clicks)));
          amp *= 0.93;
        }
        const boom = Math.floor(sr * 0.22), from = Math.floor(sr * 0.02);
        for (let k = 0; k < boom; k++) {
          const v = Math.sin(2 * Math.PI * 38 * k / sr) * Math.sin(Math.PI * k / boom) * near * 1.2;
          chans[0][from + k] += v;
          chans[1][from + k] += v;
        }
      }
      normalise(chans, 0.95);
      return buffer;
    }

    function loop(buffer, into) {
      const src = A.ctx.createBufferSource();
      src.buffer = buffer;
      src.loop = true;
      src.connect(into);
      src.start(0, Math.random() * buffer.duration);
      return src;
    }

    // The recording, decoded and made seamless: its last seconds are faded
    // out over its first as those fade in, and the rest is dropped, so the
    // end runs straight into the start. Any padding the codec left at
    // either end falls where it is faded to nothing.
    function recording() {
      const data = window.LibraryRainRecording;
      if (!data) return Promise.reject(new Error('no recording'));
      const bytes = Uint8Array.from(atob(data), c => c.charCodeAt(0));
      return new Promise((ok, fail) => A.ctx.decodeAudioData(bytes.buffer, ok, fail)).then(src => {
        const sr = src.sampleRate, fade = Math.floor(sr * 3);
        const n = src.length - fade;
        if (n <= fade) throw new Error('recording too short');
        const out = A.ctx.createBuffer(src.numberOfChannels, n, sr);
        for (let c = 0; c < src.numberOfChannels; c++) {
          const from = src.getChannelData(c), to = out.getChannelData(c);
          to.set(from.subarray(0, n));
          for (let i = 0; i < fade; i++) {
            const w = i / fade;
            to[i] = from[i] * Math.sin(w * Math.PI / 2) + from[n + i] * Math.cos(w * Math.PI / 2);
          }
        }
        return out;
      });
    }

    function build() {
      if (A.ctx || !AC) return;
      try { A.ctx = new AC(); } catch { return; }
      const ctx = A.ctx;
      A.brown = noise(6, true);
      A.master = ctx.createGain();
      A.master.gain.value = A.volume;
      A.master.connect(ctx.destination);
      // Rain: a shower's loop and a downpour's, faded between by how hard
      // it rains, dulled by the walls indoors, where the drumming on the
      // roof takes over.
      A.rainMuffle = ctx.createBiquadFilter(); A.rainMuffle.type = 'lowpass'; A.rainMuffle.frequency.value = 16000; A.rainMuffle.Q.value = 0.5;
      A.rainMuffle.connect(A.master);
      A.lightGain = ctx.createGain(); A.lightGain.gain.value = 0; A.lightGain.connect(A.rainMuffle);
      A.heavyGain = ctx.createGain(); A.heavyGain.gain.value = 0; A.heavyGain.connect(A.rainMuffle);
      A.roofGain = ctx.createGain(); A.roofGain.gain.value = 0; A.roofGain.connect(A.master);
      A.recordedGain = ctx.createGain(); A.recordedGain.gain.value = 0; A.recordedGain.connect(A.rainMuffle);
      const written = () => {
        work(rainLoop(7, 220, 'open'), b => loop(b, A.lightGain));
        work(rainLoop(9, 1100, 'open'), b => loop(b, A.heavyGain));
        work(rainLoop(8, 500, 'roof'), b => loop(b, A.roofGain));
      };
      recording().then(b => { A.recorded = true; loop(b, A.recordedGain); }, written);
      // Wind: brown noise through a band that wanders.
      A.windBand = ctx.createBiquadFilter(); A.windBand.type = 'bandpass'; A.windBand.frequency.value = 320; A.windBand.Q.value = 0.9;
      A.windGain = ctx.createGain(); A.windGain.gain.value = 0;
      loop(A.brown, A.windBand); A.windBand.connect(A.windGain); A.windGain.connect(A.master);
    }

    function unlock() {
      if (!A.wanted) return;
      build();
      if (A.ctx && A.ctx.state === 'suspended') A.ctx.resume().catch(() => {});
    }
    addEventListener('pointerdown', unlock, true);
    addEventListener('keydown', unlock, true);

    let windPhase = Math.random() * 10;
    A.update = (dt, rain, wind, inside) => {
      if (!A.ctx || A.ctx.state !== 'running') return;
      const t = A.ctx.currentTime;
      A.muffled += ((inside ? 1 : 0) - A.muffled) * Math.min(1, dt * 3);
      const m = A.muffled;
      // A shower thickens into a downpour from about half strength.
      const heavy = Math.max(0, Math.min(1, (rain - 0.35) / 0.55));
      A.lightGain.gain.setTargetAtTime(rain * 0.55 * (1 - heavy * 0.7) * (1 - m * 0.55), t, 0.4);
      A.heavyGain.gain.setTargetAtTime(rain * 0.6 * heavy * (1 - m * 0.55), t, 0.4);
      A.rainMuffle.frequency.setTargetAtTime(A.recorded ? 16000 * Math.pow(650 / 16000, m) : 16000 - m * 14800, t, 0.3);
      A.roofGain.gain.setTargetAtTime(rain * m * 0.5, t, 0.3);
      // The recording is a downpour; a shower is the same rain, quieter.
      A.recordedGain.gain.setTargetAtTime(Math.pow(rain, 0.8) * 0.9 * (1 - m * 0.35), t, 0.4);
      windPhase += dt * (0.2 + wind * 0.4);
      const gust = 0.6 + 0.4 * Math.sin(windPhase) * Math.sin(windPhase * 0.37 + 1.3);
      A.windGain.gain.setTargetAtTime(wind * gust * (0.5 - m * 0.3), t, 0.4);
      A.windBand.frequency.setTargetAtTime(220 + gust * 380, t, 0.5);
    };

    const nearness = distance => Math.max(0, Math.min(1, 1 - distance / 90));
    // Starts writing the clap for a strike `distance` blocks away as the
    // flash is seen, so it is ready by the time its sound arrives.
    A.prepareThunder = distance => (A.ctx && A.ctx.state === 'running' ? work(thunderClap(nearness(distance))) : null);
    // Plays the clap for a strike `distance` blocks away.
    A.thunder = (distance, job) => {
      if (!A.ctx || A.ctx.state !== 'running') return;
      const ctx = A.ctx;
      const near = nearness(distance);
      const src = ctx.createBufferSource();
      src.buffer = finish(job || {gen: thunderClap(near)});
      const muffle = ctx.createBiquadFilter();
      muffle.type = 'lowpass';
      muffle.frequency.value = 16000 - A.muffled * 14000;
      const gain = ctx.createGain();
      gain.gain.value = (0.5 + near * 0.5) * (1 - A.muffled * 0.3);
      src.connect(muffle); muffle.connect(gain); gain.connect(A.master);
      src.start(ctx.currentTime);
    };

    A.setVolume = v => {
      A.volume = v;
      if (A.master) A.master.gain.setTargetAtTime(v, A.ctx.currentTime, 0.1);
    };
    // Hidden pages stay silent.
    A.pause = () => { A.wanted = false; A.ctx?.suspend().catch(() => {}); };
    A.resume = () => { A.wanted = true; if (A.ctx && A.ctx.state === 'suspended') A.ctx.resume().catch(() => {}); };
    return A;
  }

  // ── Weather ────────────────────────────────────────────────────────────
  function create(T, R) {
    const U = R.U;
    const DROPS = 5200;
    const seeds = new Float32Array(DROPS * 4 * 4), corners = new Float32Array(DROPS * 4 * 2);
    const index = new Uint32Array(DROPS * 6);
    for (let i = 0; i < DROPS; i++) {
      const s = [Math.random(), Math.random(), Math.random(), Math.random()];
      const c = [[-1, 0], [1, 0], [1, 1], [-1, 1]];
      for (let k = 0; k < 4; k++) {
        seeds.set(s, (i * 4 + k) * 4);
        corners.set(c[k], (i * 4 + k) * 2);
      }
      index.set([i * 4, i * 4 + 1, i * 4 + 2, i * 4, i * 4 + 2, i * 4 + 3], i * 6);
    }
    const geo = new T.BufferGeometry();
    geo.setAttribute('position', new T.Float32BufferAttribute(new Float32Array(DROPS * 4 * 3), 3));
    geo.setAttribute('seed', new T.Float32BufferAttribute(seeds, 4));
    geo.setAttribute('corner', new T.Float32BufferAttribute(corners, 2));
    geo.setIndex(new T.Uint32BufferAttribute(index, 1));
    const rainU = {
      center: {value: new T.Vector3()}, time: U.time, radius: {value: 16}, span: {value: 26}, amount: {value: 0},
      fallSpeed: {value: 16}, dropLength: {value: 0.9}, width: {value: 0.012}, wind: {value: new T.Vector2()},
      heightMap: {value: null}, hmBox: {value: new T.Vector4(0, 0, 1, 1)}, rainColor: {value: new T.Color(0.6, 0.66, 0.78)}, opacity: {value: 0.4},
    };
    const rain = new T.Mesh(geo, new T.ShaderMaterial({
      uniforms: rainU, vertexShader: RAIN_VERT, fragmentShader: RAIN_FRAG, transparent: true, depthWrite: false,
    }));
    rain.frustumCulled = false;
    rain.renderOrder = 4;
    rain.userData.noShadow = true;
    rain.visible = false;
    R.scene.add(rain);

    const boltU = {brightness: {value: 0}};
    const boltMat = new T.ShaderMaterial({uniforms: boltU, vertexShader: BOLT_VERT, fragmentShader: BOLT_FRAG, transparent: true, depthWrite: false, blending: T.AdditiveBlending, side: T.DoubleSide});
    let bolt = null;

    const audio = createAudio();
    const W = {
      mode: 'clear', state: 'clear', rain: 0, wind: 0, windAngle: Math.random() * Math.PI * 2,
      nextChange: 0, nextStrike: 4, flash: 0, strikeAge: 9, pendingThunder: [], built: null,
      reducedFlash: false, particleScale: 1, audio, MODES,
    };

    W.setWorld = built => {
      W.built = built;
      const hm = built.heightmap;
      rainU.heightMap.value?.dispose();
      const tex = new T.DataTexture(hm.data, hm.sx, hm.sz, T.RGBAFormat, T.UnsignedByteType);
      tex.magFilter = T.NearestFilter; tex.minFilter = T.NearestFilter;
      tex.generateMipmaps = false; tex.flipY = false;
      tex.needsUpdate = true;
      rainU.heightMap.value = tex;
      rainU.hmBox.value.set(hm.x0, hm.z0, hm.sx, hm.sz);
    };

    W.setMode = mode => {
      W.mode = MODES.includes(mode) ? mode : 'clear';
      if (W.mode !== 'cycle') W.state = W.mode;
      else { W.state = 'clear'; W.nextChange = 30 + Math.random() * 60; }
    };

    // Changing weather: mostly fair, sometimes rain, now and then a storm.
    function pickNext() {
      const roll = Math.random();
      return roll < 0.45 ? 'clear' : roll < 0.75 ? 'rain' : roll < 0.88 ? 'storm' : 'thunder';
    }

    function strike(camera) {
      const b = W.built;
      if (!b) return;
      // Somewhere off over the cloud sea, now and then on the island itself.
      const onIsland = Math.random() < 0.18;
      const a = Math.random() * Math.PI * 2;
      const d = onIsland ? 8 + Math.random() * 10 : 30 + Math.random() * 45;
      const cx = (b.hall.x0 + b.hall.x1) / 2, cz = (b.hall.z0 + b.hall.z1) / 2;
      const x = cx + Math.cos(a) * d, z = cz + Math.sin(a) * d;
      const ground = onIsland ? Math.max(0, b.heightmap.at(x, z)) : -18 - Math.random() * 10;
      makeBolt([x, ground, z], camera);
      W.flash = W.reducedFlash ? 0.25 : 1;
      W.strikeAge = 0;
      const dist = Math.hypot(x - camera.position.x, z - camera.position.z);
      W.pendingThunder.push({at: Math.min(2.8, dist / 80), dist, clap: audio.prepareThunder(dist)});
    }

    // A jagged bolt with a branch or two, as ribbons turned to the camera.
    function makeBolt(ground, camera) {
      if (bolt) { R.scene.remove(bolt); bolt.geometry.dispose(); }
      const pos = [], glow = [];
      const view = camera.position;
      const ribbon = (points, width, g) => {
        for (let i = 0; i < points.length - 1; i++) {
          const a = points[i], c = points[i + 1];
          const dir = new T.Vector3(c[0] - a[0], c[1] - a[1], c[2] - a[2]).normalize();
          const toCam = new T.Vector3(view.x - a[0], view.y - a[1], view.z - a[2]).normalize();
          const side = new T.Vector3().crossVectors(dir, toCam).normalize().multiplyScalar(width);
          const q = [[a, -1], [a, 1], [c, 1], [a, -1], [c, 1], [c, -1]];
          for (const [p, s] of q) { pos.push(p[0] + side.x * s, p[1] + side.y * s, p[2] + side.z * s); glow.push(g); }
        }
      };
      const main = [];
      let [x, y, z] = [ground[0] + (Math.random() - 0.5) * 6, 70, ground[2] + (Math.random() - 0.5) * 6];
      const steps = 22;
      for (let i = 0; i <= steps; i++) {
        const t = i / steps;
        main.push([x, y, z]);
        y = 70 + (ground[1] - 70) * ((i + 1) / steps);
        x += (Math.random() - 0.5) * 2.4 + (ground[0] - x) * t * 0.35;
        z += (Math.random() - 0.5) * 2.4 + (ground[2] - z) * t * 0.35;
      }
      main[main.length - 1] = ground.slice();
      ribbon(main, 0.28, 1);
      ribbon(main, 0.9, 0.18);
      for (let b = 0; b < 2; b++) {
        const from = main[4 + Math.floor(Math.random() * 10)];
        const branch = [from.slice()];
        let [bx, by, bz] = from;
        const dx = (Math.random() - 0.5) * 3, dz = (Math.random() - 0.5) * 3;
        for (let i = 0; i < 6; i++) { bx += dx + (Math.random() - 0.5) * 1.5; by -= 2.2 + Math.random() * 2; bz += dz + (Math.random() - 0.5) * 1.5; branch.push([bx, by, bz]); }
        ribbon(branch, 0.16, 0.7);
      }
      const g = new T.BufferGeometry();
      g.setAttribute('position', new T.Float32BufferAttribute(pos, 3));
      g.setAttribute('glow', new T.Float32BufferAttribute(glow, 1));
      bolt = new T.Mesh(g, boltMat);
      bolt.frustumCulled = false;
      bolt.renderOrder = 5;
      bolt.userData.noShadow = true;
      R.scene.add(bolt);
    }

    // Moves the weather on by `dt`; `inside` is whether the camera is
    // under the roof.
    W.step = (dt, camera, inside) => {
      if (W.mode === 'cycle') {
        W.nextChange -= dt;
        if (W.nextChange <= 0) { W.state = pickNext(); W.nextChange = 120 + Math.random() * 240; }
      }
      const goal = STATES[W.state] || STATES.clear;
      // Weather rolls in over a few seconds rather than switching.
      const k = Math.min(1, dt * 0.18);
      W.rain += (goal.rain - W.rain) * k;
      W.wind += (goal.wind - W.wind) * k;
      if (W.rain < 0.002 && goal.rain === 0) W.rain = 0;
      W.windAngle += dt * 0.02;

      rain.visible = W.rain > 0.003;
      rainU.amount.value = Math.min(1, W.rain * 1.05) * W.particleScale;
      rainU.center.value.copy(camera.position);
      rainU.wind.value.set(Math.cos(W.windAngle), Math.sin(W.windAngle)).multiplyScalar(W.wind * 7);
      rainU.dropLength.value = 0.7 + W.rain * 0.5;

      // Lightning in a thunderstorm, once the rain has properly set in.
      W.nextStrike -= dt;
      if (goal.thunder && W.rain > 0.6 && W.nextStrike <= 0) {
        strike(camera);
        W.nextStrike = 5 + Math.random() * 16;
      }
      W.strikeAge += dt;
      if (bolt) {
        // The bolt flickers for a moment, then is gone.
        const on = W.strikeAge < 0.07 || (W.strikeAge > 0.12 && W.strikeAge < 0.2) || (W.strikeAge > 0.26 && W.strikeAge < 0.36);
        boltU.brightness.value = on ? 1 : 0;
        bolt.visible = on;
        if (W.strikeAge > 0.5) { R.scene.remove(bolt); bolt.geometry.dispose(); bolt = null; }
      }
      const flicker = W.reducedFlash ? 1 : W.strikeAge < 0.36 ? (Math.sin(W.strikeAge * 60) > -0.3 ? 1 : 0.35) : 1;
      W.flash = Math.max(0, W.flash - dt * 2.2);
      U.flash.value = W.flash * flicker;
      U.overcast.value = Math.min(1, W.rain * 1.1);
      R.glassMaterial.uniforms.wet.value = Math.min(1, W.rain * 1.4);
      rainU.rainColor.value.setRGB(0.5 + U.flash.value, 0.55 + U.flash.value, 0.66 + U.flash.value);

      for (const t of W.pendingThunder) t.at -= dt;
      while (W.pendingThunder.length && W.pendingThunder[0].at <= 0) {
        const t = W.pendingThunder.shift();
        audio.thunder(t.dist, t.clap);
      }
      audio.update(dt, W.rain, W.wind, inside);
    };

    // How the daylight changes under cloud, applied on top of the time of
    // day: the sun and sky dim and grey, the air thickens.
    W.grade = (U, sky, exposure) => {
      const w = Math.min(1, W.rain * 1.1);
      U.fogDensity.value = 0.012 + 0.03 * w;
      if (w <= 0) return exposure;
      const grey = c => { const l = c.r * 0.3 + c.g * 0.59 + c.b * 0.11; c.r += (l * 0.9 - c.r) * w * 0.7; c.g += (l * 0.95 - c.g) * w * 0.7; c.b += (l * 1.08 - c.b) * w * 0.7; };
      U.sunColor.value.multiplyScalar(1 - 0.85 * w);
      U.skyColor.value.multiplyScalar(1 - 0.35 * w); grey(U.skyColor.value);
      sky.zenith.value.multiplyScalar(1 - 0.45 * w); grey(sky.zenith.value);
      sky.horizon.value.multiplyScalar(1 - 0.5 * w); grey(sky.horizon.value);
      U.fogColor.value.multiplyScalar(1 - 0.35 * w); grey(U.fogColor.value);
      return exposure * (1 - 0.06 * w);
    };

    W.setMode('clear');
    return W;
  }

  window.LibraryWeather = {create, MODES};
})();
