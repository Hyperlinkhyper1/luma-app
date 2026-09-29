// Weather over the island: rain, storms and thunderstorms.
//
// Rain is a cloud of streaks round the camera, moved entirely on the GPU and
// kept off anything with a roof over it by a heightmap of the world, the way
// the game stops rain at the highest block. Lightning is a jagged bolt far
// off with a flash that lights the sky and everything the sky reaches. The
// sound is synthesised here from noise — rain, wind and thunder — so nothing
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

    function loop(buffer) {
      const src = A.ctx.createBufferSource();
      src.buffer = buffer;
      src.loop = true;
      src.start();
      return src;
    }

    function build() {
      if (A.ctx || !AC) return;
      try { A.ctx = new AC(); } catch { return; }
      const ctx = A.ctx;
      A.white = noise(3, false);
      A.brown = noise(6, true);
      A.master = ctx.createGain();
      A.master.gain.value = A.volume;
      A.master.connect(ctx.destination);
      // Rain: a hiss, bright outdoors and muffled by the roof indoors, with
      // a low drumming on the roof when inside.
      A.rainHigh = ctx.createBiquadFilter(); A.rainHigh.type = 'highpass'; A.rainHigh.frequency.value = 450;
      A.rainLow = ctx.createBiquadFilter(); A.rainLow.type = 'lowpass'; A.rainLow.frequency.value = 5200;
      A.rainGain = ctx.createGain(); A.rainGain.gain.value = 0;
      loop(A.white).connect(A.rainHigh);
      A.rainHigh.connect(A.rainLow); A.rainLow.connect(A.rainGain); A.rainGain.connect(A.master);
      A.roofLow = ctx.createBiquadFilter(); A.roofLow.type = 'lowpass'; A.roofLow.frequency.value = 380;
      A.roofGain = ctx.createGain(); A.roofGain.gain.value = 0;
      loop(A.brown).connect(A.roofLow); A.roofLow.connect(A.roofGain); A.roofGain.connect(A.master);
      // Wind: brown noise through a band that wanders.
      A.windBand = ctx.createBiquadFilter(); A.windBand.type = 'bandpass'; A.windBand.frequency.value = 320; A.windBand.Q.value = 0.9;
      A.windGain = ctx.createGain(); A.windGain.gain.value = 0;
      loop(A.brown).connect(A.windBand); A.windBand.connect(A.windGain); A.windGain.connect(A.master);
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
      A.rainGain.gain.setTargetAtTime(rain * (0.34 - m * 0.2), t, 0.3);
      A.rainLow.frequency.setTargetAtTime(5200 - m * 4200, t, 0.3);
      A.roofGain.gain.setTargetAtTime(rain * m * 0.5, t, 0.3);
      windPhase += dt * (0.2 + wind * 0.4);
      const gust = 0.6 + 0.4 * Math.sin(windPhase) * Math.sin(windPhase * 0.37 + 1.3);
      A.windGain.gain.setTargetAtTime(wind * gust * (0.5 - m * 0.3), t, 0.4);
      A.windBand.frequency.setTargetAtTime(220 + gust * 380, t, 0.5);
    };

    // A rumble for a strike `distance` blocks away, with a crack when close.
    A.thunder = distance => {
      if (!A.ctx || A.ctx.state !== 'running') return;
      const ctx = A.ctx, t = ctx.currentTime;
      const near = Math.max(0, 1 - distance / 90);
      const src = ctx.createBufferSource();
      src.buffer = A.brown;
      const low = ctx.createBiquadFilter();
      low.type = 'lowpass';
      low.frequency.setValueAtTime(700 + near * 900, t);
      low.frequency.exponentialRampToValueAtTime(90, t + 3.5);
      const gain = ctx.createGain();
      const peak = (0.55 + near * 0.9) * (1 - A.muffled * 0.35);
      gain.gain.setValueAtTime(0.0001, t);
      gain.gain.exponentialRampToValueAtTime(peak, t + 0.05 + (1 - near) * 0.35);
      // A couple of rolling swells as it dies away.
      gain.gain.exponentialRampToValueAtTime(peak * 0.45, t + 1.2);
      gain.gain.exponentialRampToValueAtTime(peak * 0.6, t + 1.8);
      gain.gain.exponentialRampToValueAtTime(0.0001, t + 5.5);
      src.connect(low); low.connect(gain); gain.connect(A.master);
      src.start(t, Math.random() * 2);
      src.stop(t + 6);
      if (near > 0.45) {
        const crack = ctx.createBufferSource();
        crack.buffer = A.white;
        const high = ctx.createBiquadFilter(); high.type = 'highpass'; high.frequency.value = 1200;
        const cg = ctx.createGain();
        cg.gain.setValueAtTime(near * 0.7, t);
        cg.gain.exponentialRampToValueAtTime(0.0001, t + 0.35);
        crack.connect(high); high.connect(cg); cg.connect(A.master);
        crack.start(t, Math.random());
        crack.stop(t + 0.4);
      }
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
      W.pendingThunder.push({at: Math.min(2.8, dist / 80), dist});
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
      while (W.pendingThunder.length && W.pendingThunder[0].at <= 0) audio.thunder(W.pendingThunder.shift().dist);
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
