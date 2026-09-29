// Rendering: the block shader, a sun shadow map, the sky, and the post
// chain — volumetric light through the windows, bloom, depth of field and a
// filmic grade — that turns plain blocks into a cosy shader-pack look.
(() => {
  'use strict';

  const COMMON = /* glsl */ `
    uniform float time;
    uniform vec3 sunDir;
    uniform vec3 sunColor;
    uniform vec3 skyColor;
    uniform vec3 lampColor;
    uniform vec3 fireColor;
    uniform float lampLevel;
    uniform float fireLevel;
    uniform float skyLevel;
    uniform float firePulse;
    uniform vec3 fireOrigin;
    uniform vec3 fogColor;
    uniform float fogDensity;
  `;

  const BLOCK_VERT = /* glsl */ `
    attribute vec2 uvp;
    attribute vec3 tile;
    attribute vec3 light;
    attribute float ao;
    attribute vec3 tint;
    attribute float emit;
    attribute vec4 label;
    uniform mat4 shadowMatrix;
    varying vec2 vUvp;
    flat varying vec3 vTile;
    varying vec3 vLight;
    varying float vAo;
    varying vec3 vTint;
    varying float vEmit;
    varying vec4 vLabel;
    varying vec3 vNormal;
    varying vec3 vWorld;
    varying vec4 vShadow;
    varying float vDepth;
    void main() {
      vec4 world = modelMatrix * vec4(position, 1.0);
      vWorld = world.xyz;
      vNormal = normalize(mat3(modelMatrix) * normal);
      vShadow = shadowMatrix * vec4(world.xyz + vNormal * 0.035, 1.0);
      vUvp = uvp; vTile = tile; vLight = light; vAo = ao; vTint = tint; vEmit = emit; vLabel = label;
      vec4 view = viewMatrix * world;
      vDepth = -view.z;
      gl_Position = projectionMatrix * view;
    }
  `;

  const ATLAS = /* glsl */ `
    uniform sampler2D atlas;
    uniform vec2 atlasSize;
    uniform float atlasCols;
    uniform sampler2D labels;
    vec4 atlasSample(vec2 p, vec3 t) {
      float cell = t.x;
      if (t.y > 1.5) cell += mod(floor(time * 20.0 / max(t.z, 1.0)), t.y);
      vec2 xy = vec2(mod(cell, atlasCols), floor(cell / atlasCols));
      // Faces longer than a block repeat the texture, as the game's do.
      vec2 wrapped = p - 16.0 * floor(p / 16.0 - 1e-4);
      vec2 inside = step(vec2(0.0), p) * step(p, vec2(16.0));
      vec2 q = mix(wrapped, p, inside);
      vec2 uv = (xy * 32.0 + 8.0 + clamp(q, 0.02, 15.98)) / atlasSize;
      return textureGrad(atlas, uv, dFdx(p) / atlasSize, dFdy(p) / atlasSize);
    }
  `;

  const BLOCK_FRAG = /* glsl */ `
    ${COMMON}
    ${ATLAS}
    uniform sampler2D shadowMap;
    uniform float shadowTexel;
    uniform float shadowOn;
    uniform float opacity;
    uniform vec3 highlight;
    varying vec2 vUvp;
    flat varying vec3 vTile;
    varying vec3 vLight;
    varying float vAo;
    varying vec3 vTint;
    varying float vEmit;
    varying vec4 vLabel;
    varying vec3 vNormal;
    varying vec3 vWorld;
    varying vec4 vShadow;
    varying float vDepth;

    float sunShadow() {
      if (shadowOn < 0.5) return 1.0;
      vec3 p = vShadow.xyz / vShadow.w;
      if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0 || p.z > 1.0) return 1.0;
      float lit = 0.0;
      // Rotated-grid PCF with a per-pixel twist to trade banding for grain.
      float a = fract(sin(dot(gl_FragCoord.xy, vec2(12.9898, 78.233))) * 43758.5453) * 6.2831;
      mat2 rot = mat2(cos(a), -sin(a), sin(a), cos(a));
      for (int i = 0; i < 8; i++) {
        float ang = float(i) * 0.7853981;
        vec2 o = rot * vec2(cos(ang), sin(ang)) * (float(i % 2) + 1.0) * shadowTexel * 1.25;
        float d = texture2D(shadowMap, p.xy + o).r;
        lit += p.z - 0.0009 <= d ? 1.0 : 0.0;
      }
      return lit / 8.0;
    }

    // The game's light curve: dim levels fall off fast, bright ones stay
    // bright. Softened a touch so corners are cosy rather than black.
    float curve(float l) { return mix(l / (4.0 - 3.0 * l), l * l, 0.35); }

    void main() {
      vec4 tex;
      vec3 albedo;
      if (vLabel.z > 0.5) {
        tex = texture2D(labels, vLabel.xy);
        albedo = tex.rgb;
        tex.a = 1.0;
      } else {
        tex = atlasSample(vUvp, vTile);
        if (tex.a < 0.5) discard;
        albedo = tex.rgb * vTint;
      }
      vec3 n = normalize(vNormal);
      if (!gl_FrontFacing) n = -n;

      // Minecraft's per-direction face shading, softened.
      float face = n.y > 0.5 ? 1.0 : n.y < -0.5 ? 0.58 : abs(n.z) > 0.5 ? 0.86 : 0.74;
      face = mix(1.0, face, 0.8);

      float flicker = firePulse * (0.92 + 0.08 * sin(time * 13.0 + vWorld.x * 3.0 + vWorld.y * 5.0));
      float fireFall = 1.0 / (1.0 + 0.04 * dot(vWorld - fireOrigin, vWorld - fireOrigin));
      // Multisampling evaluates edge samples slightly outside the triangle,
      // where interpolated light can dip below zero; pow() of that is NaN.
      vec3 level = clamp(vLight, 0.0, 1.0);
      float occlusion = clamp(vAo, 0.0, 1.0);
      vec3 sky = skyColor * curve(level.x) * skyLevel;
      vec3 lamp = lampColor * pow(curve(level.y), 1.1) * lampLevel;
      vec3 fire = fireColor * pow(curve(level.z), 0.9) * fireLevel * flicker * (0.6 + 0.4 * fireFall);
      float ndl = max(dot(n, sunDir), 0.0);
      float shadow = ndl > 0.0 ? sunShadow() : 0.0;
      vec3 sun = sunColor * ndl * shadow;

      vec3 ambient = vec3(0.05, 0.043, 0.05);
      vec3 color = albedo * ((ambient + sky + lamp + fire) * occlusion * face + sun * mix(0.6, 1.0, occlusion));

      if (vEmit > 0.0) {
        // Emissive faces are lit fully; their brightest texels glow past 1.0
        // so the bloom picks them up. Only open flame (emit above 1.5)
        // flickers; lanterns and lampshades burn steady.
        float lum = dot(albedo, vec3(0.299, 0.587, 0.114));
        float glow = smoothstep(0.35, 0.85, lum);
        float wobble = vEmit > 1.5 ? 0.9 + 0.1 * flicker : 1.0;
        color = max(color, albedo * 0.95) + albedo * glow * vEmit * 2.2 * wobble;
      }
      color += highlight * 0.35;

      float fog = 1.0 - exp(-vDepth * fogDensity);
      color = mix(color, fogColor, fog * 0.55);
      gl_FragColor = vec4(color, opacity);
    }
  `;

  const DEPTH_FRAG = /* glsl */ `
    uniform float time;
    ${ATLAS}
    varying vec2 vUvp;
    flat varying vec3 vTile;
    varying vec4 vLabel;
    void main() {
      if (vLabel.z < 0.5 && atlasSample(vUvp, vTile).a < 0.5) discard;
      gl_FragColor = vec4(1.0);
    }
  `;

  const DEPTH_VERT = /* glsl */ `
    attribute vec2 uvp;
    attribute vec3 tile;
    attribute vec4 label;
    varying vec2 vUvp;
    flat varying vec3 vTile;
    varying vec4 vLabel;
    void main() {
      vUvp = uvp; vTile = tile; vLabel = label;
      gl_Position = projectionMatrix * viewMatrix * modelMatrix * vec4(position, 1.0);
    }
  `;

  const SKY_VERT = /* glsl */ `
    varying vec3 vDir;
    void main() {
      vDir = position;
      vec4 p = projectionMatrix * mat4(mat3(viewMatrix)) * vec4(position, 1.0);
      gl_Position = p.xyww;
    }
  `;

  const SKY_FRAG = /* glsl */ `
    ${COMMON}
    uniform vec3 zenith;
    uniform vec3 horizon;
    uniform float night;
    uniform vec3 sunPos;
    varying vec3 vDir;
    float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
    // Where d lands on a square of half-size [size] facing along [axis]:
    // x, y in -1..1 inside it, or a value past 1 outside.
    vec2 square(vec3 d, vec3 axis, float size) {
      float a = dot(d, axis);
      if (a <= 0.0) return vec2(9.0);
      vec3 t1 = normalize(cross(axis, vec3(0.0, 0.0, 1.0)));
      vec3 t2 = cross(t1, axis);
      return vec2(dot(d, t1), dot(d, t2)) / a / size;
    }
    void main() {
      vec3 d = normalize(vDir);
      float h = clamp(d.y, -0.2, 1.0);
      vec3 col = mix(horizon, zenith, pow(max(h, 0.0), 0.55));
      float s = max(dot(d, sunPos), 0.0);
      col += sunColor * pow(s, 12.0) * 0.35 * (1.0 - night);
      // The game's square sun and moon, on opposite sides of the sky.
      vec2 sq = square(d, sunPos, 0.07);
      if (max(abs(sq.x), abs(sq.y)) < 1.0) col = mix(col, vec3(4.0, 3.4, 2.2), 1.0 - night * 0.9);
      else col += vec3(1.0, 0.8, 0.5) * smoothstep(1.9, 1.0, max(abs(sq.x), abs(sq.y))) * 0.4 * (1.0 - night);
      vec2 mq = square(d, -sunPos, 0.055);
      if (max(abs(mq.x), abs(mq.y)) < 1.0) {
        vec2 cell = floor((mq + 1.0) * 2.0);
        float crater = step(0.72, hash(cell + 3.0));
        col = mix(col, vec3(1.3, 1.35, 1.5) * (1.0 - crater * 0.3), 0.25 + night * 0.75);
      }
      // Blocky clouds on a flat layer, drifting.
      if (d.y > 0.02) {
        vec2 p = d.xz / d.y * 4.0 + vec2(time * 0.08, 0.0);
        vec2 cell = floor(p);
        float c = step(0.58, hash(cell)) * step(0.3, hash(cell + 7.0));
        float fade = smoothstep(0.02, 0.25, d.y);
        col = mix(col, mix(vec3(1.0), sunColor * 0.4 + horizon * 0.6, 0.25) * (1.0 - night * 0.8), c * fade * 0.85);
      }
      // Stars at night.
      vec2 sp = floor(d.xz / max(d.y, 0.05) * 60.0);
      col += night * step(0.9975, hash(sp)) * smoothstep(0.1, 0.4, d.y) * 1.5;
      gl_FragColor = vec4(col, 1.0);
    }
  `;

  const GLASS_FRAG = /* glsl */ `
    ${COMMON}
    varying vec3 vNormal;
    varying vec3 vWorld;
    uniform vec3 cameraPos;
    void main() {
      vec3 v = normalize(cameraPos - vWorld);
      float f = pow(1.0 - abs(dot(normalize(vNormal), v)), 3.0);
      vec3 col = mix(skyColor * 0.6 + sunColor * 0.2, vec3(1.0), 0.2);
      gl_FragColor = vec4(col, 0.05 + f * 0.35);
    }
  `;
  const GLASS_VERT = /* glsl */ `
    varying vec3 vNormal;
    varying vec3 vWorld;
    void main() {
      vec4 w = modelMatrix * vec4(position, 1.0);
      vWorld = w.xyz;
      vNormal = normalize(mat3(modelMatrix) * normal);
      gl_Position = projectionMatrix * viewMatrix * w;
    }
  `;

  // ── Post ───────────────────────────────────────────────────────────────
  const FULL_VERT = /* glsl */ `
    varying vec2 vUv;
    void main() { vUv = uv; gl_Position = vec4(position.xy, 0.0, 1.0); }
  `;

  const DOWN_FRAG = /* glsl */ `
    uniform sampler2D src;
    uniform vec2 texel;
    uniform float threshold;
    varying vec2 vUv;
    vec3 s(vec2 o) { return texture2D(src, vUv + o * texel).rgb; }
    void main() {
      // 13-tap downsample (as in modern bloom), with an optional soft knee.
      vec3 a = s(vec2(-2, 2)), b = s(vec2(0, 2)), c = s(vec2(2, 2));
      vec3 d = s(vec2(-2, 0)), e = s(vec2(0, 0)), f = s(vec2(2, 0));
      vec3 g = s(vec2(-2, -2)), h = s(vec2(0, -2)), i = s(vec2(2, -2));
      vec3 j = s(vec2(-1, 1)), k = s(vec2(1, 1)), l = s(vec2(-1, -1)), m = s(vec2(1, -1));
      vec3 col = e * 0.125 + (a + c + g + i) * 0.03125 + (b + d + f + h) * 0.0625 + (j + k + l + m) * 0.125;
      if (threshold > 0.0) {
        float br = max(col.r, max(col.g, col.b));
        float knee = threshold * 0.5;
        float soft = clamp(br - threshold + knee, 0.0, 2.0 * knee);
        soft = soft * soft / (4.0 * knee + 1e-4);
        col *= max(soft, br - threshold) / max(br, 1e-4);
      }
      gl_FragColor = vec4(col, 1.0);
    }
  `;

  const UP_FRAG = /* glsl */ `
    uniform sampler2D src;
    uniform sampler2D base;
    uniform vec2 texel;
    uniform float radius;
    varying vec2 vUv;
    void main() {
      vec2 t = texel * radius;
      vec3 col = texture2D(src, vUv + vec2(-t.x, t.y)).rgb + texture2D(src, vUv + vec2(0.0, t.y)).rgb * 2.0 + texture2D(src, vUv + vec2(t.x, t.y)).rgb
        + texture2D(src, vUv + vec2(-t.x, 0.0)).rgb * 2.0 + texture2D(src, vUv).rgb * 4.0 + texture2D(src, vUv + vec2(t.x, 0.0)).rgb * 2.0
        + texture2D(src, vUv + vec2(-t.x, -t.y)).rgb + texture2D(src, vUv + vec2(0.0, -t.y)).rgb * 2.0 + texture2D(src, vUv + vec2(t.x, -t.y)).rgb;
      gl_FragColor = vec4(col / 16.0 + texture2D(base, vUv).rgb, 1.0);
    }
  `;

  const BLUR_FRAG = /* glsl */ `
    uniform sampler2D src;
    uniform vec2 dir;
    varying vec2 vUv;
    void main() {
      vec3 c = texture2D(src, vUv).rgb * 0.227;
      c += (texture2D(src, vUv + dir * 1.385).rgb + texture2D(src, vUv - dir * 1.385).rgb) * 0.316;
      c += (texture2D(src, vUv + dir * 3.231).rgb + texture2D(src, vUv - dir * 3.231).rgb) * 0.070;
      gl_FragColor = vec4(c, 1.0);
    }
  `;

  // Ray-marches the sun's shadow map between the camera and each pixel: the
  // lit samples become shafts of light in the dusty air.
  const VOLUME_FRAG = /* glsl */ `
    ${COMMON}
    uniform sampler2D depth;
    uniform sampler2D shadowMap;
    uniform mat4 shadowMatrix;
    uniform mat4 invProj;
    uniform mat4 invView;
    uniform vec3 cameraPos;
    uniform vec3 boxMin;
    uniform vec3 boxMax;
    uniform float steps;
    varying vec2 vUv;
    float ign(vec2 p) { return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715)))); }
    void main() {
      float z = texture2D(depth, vUv).r;
      vec4 clip = vec4(vUv * 2.0 - 1.0, z * 2.0 - 1.0, 1.0);
      vec4 view = invProj * clip; view /= view.w;
      vec3 world = (invView * view).xyz;
      vec3 ray = world - cameraPos;
      float len = min(length(ray), 36.0);
      vec3 dir = normalize(ray);
      float stepLen = len / steps;
      float offset = ign(gl_FragCoord.xy + fract(time) * 17.0);
      float lit = 0.0;
      for (int i = 0; i < 32; i++) {
        if (float(i) >= steps) break;
        vec3 p = cameraPos + dir * (float(i) + offset) * stepLen;
        if (any(lessThan(p, boxMin)) || any(greaterThan(p, boxMax))) continue;
        vec4 s = shadowMatrix * vec4(p, 1.0);
        vec3 q = s.xyz / s.w;
        if (q.x < 0.0 || q.x > 1.0 || q.y < 0.0 || q.y > 1.0) continue;
        lit += q.z - 0.001 <= texture2D(shadowMap, q.xy).r ? 1.0 : 0.0;
      }
      float mu = dot(dir, sunDir);
      float g = 0.55;
      float phase = (1.0 - g * g) / pow(1.0 + g * g - 2.0 * g * mu, 1.5) * 0.08 + 0.02;
      gl_FragColor = vec4(vec3(lit * stepLen * phase), 1.0);
    }
  `;

  const COMPOSITE_FRAG = /* glsl */ `
    ${COMMON}
    uniform sampler2D scene;
    uniform sampler2D bloom;
    uniform sampler2D dofBlur;
    uniform sampler2D volume;
    uniform sampler2D depth;
    uniform vec2 texel;
    uniform float near;
    uniform float far;
    uniform float focus;
    uniform float aperture;
    uniform float blurAll;
    uniform float bloomLevel;
    uniform float volumeLevel;
    uniform float exposure;
    uniform float vignette;
    uniform float fade;
    uniform float grain;
    varying vec2 vUv;

    float linearDepth(float z) {
      float n = z * 2.0 - 1.0;
      return 2.0 * near * far / (far + near - n * (far - near));
    }
    vec3 aces(vec3 x) {
      const float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
      return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
    }
    float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233)) + time) * 43758.5453); }

    void main() {
      vec3 col = texture2D(scene, vUv).rgb;
      float d = linearDepth(texture2D(depth, vUv).r);
      float coc = clamp(abs(d - focus) / max(focus, 0.5) * aperture, 0.0, 1.0);
      coc = max(coc, blurAll);
      vec3 blurred = texture2D(dofBlur, vUv).rgb;
      col = mix(col, blurred, smoothstep(0.0, 1.0, coc));
      col += texture2D(volume, vUv).rgb * sunColor * volumeLevel;
      col += texture2D(bloom, vUv).rgb * bloomLevel;
      col *= exposure;
      col = aces(col);
      // Warm grade: lifted shadows toward amber, gentle saturation.
      float l = dot(col, vec3(0.299, 0.587, 0.114));
      col = mix(vec3(l), col, 1.08);
      col += vec3(0.018, 0.010, 0.0) * (1.0 - l);
      vec2 v = vUv - 0.5;
      col *= 1.0 - dot(v, v) * vignette;
      col = pow(col, vec3(1.0 / 2.2));
      col += (hash(vUv * 1000.0) - 0.5) * grain;
      col *= fade;
      gl_FragColor = vec4(col, 1.0);
    }
  `;

  function create(T, canvas) {
    const renderer = new T.WebGLRenderer({canvas, antialias: false, alpha: false, powerPreference: 'high-performance'});
    renderer.autoClear = true;
    renderer.setClearColor(0x000000, 1);
    renderer.outputColorSpace = T.LinearSRGBColorSpace;
    const gl = renderer.getContext();
    if (!renderer.capabilities.isWebGL2) throw new Error('WebGL 2 is not available.');

    const U = {
      time: {value: 0},
      sunDir: {value: new T.Vector3(0.7, 0.55, -0.35).normalize()},
      sunColor: {value: new T.Color(1.6, 1.25, 0.85)},
      skyColor: {value: new T.Color(0.42, 0.5, 0.62)},
      lampColor: {value: new T.Color(1.9, 1.28, 0.7)},
      fireColor: {value: new T.Color(1.9, 0.95, 0.4)},
      lampLevel: {value: 1},
      fireLevel: {value: 1},
      skyLevel: {value: 1},
      firePulse: {value: 1},
      fireOrigin: {value: new T.Vector3()},
      fogColor: {value: new T.Color(0.09, 0.07, 0.055)},
      fogDensity: {value: 0.018},
      atlas: {value: null},
      atlasSize: {value: new T.Vector2(1, 1)},
      atlasCols: {value: 1},
      labels: {value: null},
      shadowMap: {value: null},
      shadowMatrix: {value: new T.Matrix4()},
      shadowTexel: {value: 1 / 2048},
      shadowOn: {value: 1},
    };

    function blockMaterial(extra = {}) {
      return new T.ShaderMaterial({
        uniforms: {...U, opacity: {value: 1}, highlight: {value: new T.Color(0, 0, 0)}},
        vertexShader: BLOCK_VERT,
        fragmentShader: BLOCK_FRAG,
        side: extra.side || T.FrontSide,
        transparent: !!extra.transparent,
        depthWrite: extra.depthWrite !== false,
      });
    }

    const depthMaterial = new T.ShaderMaterial({
      uniforms: U,
      vertexShader: DEPTH_VERT,
      fragmentShader: DEPTH_FRAG,
      side: T.DoubleSide,
    });

    const glassMaterial = new T.ShaderMaterial({
      uniforms: {...U, cameraPos: {value: new T.Vector3()}},
      vertexShader: GLASS_VERT,
      fragmentShader: GLASS_FRAG,
      transparent: true,
      depthWrite: false,
      side: T.DoubleSide,
    });

    const scene = new T.Scene();
    const camera = new T.PerspectiveCamera(55, 1, 0.05, 200);

    const skyUniforms = {...U, zenith: {value: new T.Color(0.25, 0.42, 0.72)}, horizon: {value: new T.Color(0.95, 0.72, 0.5)}, night: {value: 0}, sunPos: {value: new T.Vector3(0.7, 0.55, -0.35).normalize()}};
    const sky = new T.Mesh(new T.BoxGeometry(100, 100, 100), new T.ShaderMaterial({
      uniforms: skyUniforms, vertexShader: SKY_VERT, fragmentShader: SKY_FRAG, side: T.BackSide, depthWrite: false,
    }));
    sky.frustumCulled = false;
    sky.renderOrder = -10;
    scene.add(sky);

    // ── Shadow map ──────────────────────────────────────────────────────
    let shadowSize = 2048;
    let shadowRT = null;
    const shadowCam = new T.OrthographicCamera(-10, 10, 10, -10, 0.1, 120);
    function ensureShadow(size) {
      if (shadowRT && shadowSize === size) return;
      shadowRT?.dispose();
      shadowSize = size;
      shadowRT = new T.WebGLRenderTarget(size, size, {depthBuffer: true});
      shadowRT.depthTexture = new T.DepthTexture(size, size, T.UnsignedIntType);
      shadowRT.depthTexture.minFilter = T.NearestFilter;
      shadowRT.depthTexture.magFilter = T.NearestFilter;
      U.shadowMap.value = shadowRT.depthTexture;
      U.shadowTexel.value = 1 / size;
    }
    ensureShadow(2048);

    const bias = new T.Matrix4().set(0.5, 0, 0, 0.5, 0, 0.5, 0, 0.5, 0, 0, 0.5, 0.5, 0, 0, 0, 1);
    function renderShadow(bounds) {
      const center = new T.Vector3((bounds.min[0] + bounds.max[0]) / 2, (bounds.min[1] + bounds.max[1]) / 2, (bounds.min[2] + bounds.max[2]) / 2);
      const size = new T.Vector3(bounds.max[0] - bounds.min[0], bounds.max[1] - bounds.min[1], bounds.max[2] - bounds.min[2]);
      const radius = size.length() / 2 + 2;
      shadowCam.position.copy(center).addScaledVector(U.sunDir.value, radius + 10);
      shadowCam.up.set(0, 1, 0);
      if (Math.abs(U.sunDir.value.y) > 0.98) shadowCam.up.set(0, 0, 1);
      shadowCam.lookAt(center);
      shadowCam.updateMatrixWorld();
      // Fit the ortho box to the hall's corners in light space.
      const inv = shadowCam.matrixWorldInverse;
      let x0 = Infinity, x1 = -Infinity, y0 = Infinity, y1 = -Infinity, z0 = Infinity, z1 = -Infinity;
      for (const x of [bounds.min[0], bounds.max[0]]) for (const y of [bounds.min[1], bounds.max[1]]) for (const z of [bounds.min[2], bounds.max[2]]) {
        const p = new T.Vector3(x, y, z).applyMatrix4(inv);
        x0 = Math.min(x0, p.x); x1 = Math.max(x1, p.x); y0 = Math.min(y0, p.y); y1 = Math.max(y1, p.y); z0 = Math.min(z0, p.z); z1 = Math.max(z1, p.z);
      }
      shadowCam.left = x0 - 0.5; shadowCam.right = x1 + 0.5; shadowCam.bottom = y0 - 0.5; shadowCam.top = y1 + 0.5;
      shadowCam.near = Math.max(0.1, -z1 - 12); shadowCam.far = -z0 + 2;
      shadowCam.updateProjectionMatrix();
      U.shadowMatrix.value.copy(bias).multiply(shadowCam.projectionMatrix).multiply(shadowCam.matrixWorldInverse);
      const override = scene.overrideMaterial;
      scene.overrideMaterial = depthMaterial;
      sky.visible = false;
      const hidden = [];
      scene.traverse(o => { if (o.userData.noShadow && o.visible) { o.visible = false; hidden.push(o); } });
      renderer.setRenderTarget(shadowRT);
      renderer.clear();
      renderer.render(scene, shadowCam);
      renderer.setRenderTarget(null);
      for (const o of hidden) o.visible = true;
      sky.visible = true;
      scene.overrideMaterial = override;
    }

    // ── Post chain ──────────────────────────────────────────────────────
    const quadGeo = new T.BufferGeometry();
    quadGeo.setAttribute('position', new T.Float32BufferAttribute([-1, -1, 0, 3, -1, 0, -1, 3, 0], 3));
    quadGeo.setAttribute('uv', new T.Float32BufferAttribute([0, 0, 2, 0, 0, 2], 2));
    const quad = new T.Mesh(quadGeo);
    quad.frustumCulled = false;
    const quadScene = new T.Scene();
    quadScene.add(quad);
    const quadCam = new T.OrthographicCamera(-1, 1, 1, -1, 0, 1);

    const mat = (frag, uniforms) => new T.ShaderMaterial({uniforms, vertexShader: FULL_VERT, fragmentShader: frag, depthTest: false, depthWrite: false});
    const downMat = mat(DOWN_FRAG, {src: {value: null}, texel: {value: new T.Vector2()}, threshold: {value: 0}});
    const upMat = mat(UP_FRAG, {src: {value: null}, base: {value: null}, texel: {value: new T.Vector2()}, radius: {value: 1}});
    const blurMat = mat(BLUR_FRAG, {src: {value: null}, dir: {value: new T.Vector2()}});
    const volumeMat = mat(VOLUME_FRAG, {
      ...U, depth: {value: null}, invProj: {value: new T.Matrix4()}, invView: {value: new T.Matrix4()},
      cameraPos: {value: new T.Vector3()}, boxMin: {value: new T.Vector3()}, boxMax: {value: new T.Vector3()}, steps: {value: 20},
    });
    const compositeMat = mat(COMPOSITE_FRAG, {
      ...U, scene: {value: null}, bloom: {value: null}, dofBlur: {value: null}, volume: {value: null}, depth: {value: null},
      texel: {value: new T.Vector2()}, near: {value: 0.05}, far: {value: 200}, focus: {value: 6}, aperture: {value: 0},
      blurAll: {value: 0}, bloomLevel: {value: 0.6}, volumeLevel: {value: 1}, exposure: {value: 1}, vignette: {value: 0.9},
      fade: {value: 1}, grain: {value: 0.012},
    });

    let sceneRT = null, bloomLevels = [], dofA = null, dofB = null, volumeRT = null, volumeBlur = null;
    let width = 1, height = 1, pixelRatio = 1;
    const settings = {msaa: 4, bloom: true, volume: true, dof: true, shadowSize: 2048, volumeSteps: 20, scale: 1};

    function rt(w, h, opts = {}) {
      return new T.WebGLRenderTarget(Math.max(1, w), Math.max(1, h), {type: T.HalfFloatType, depthBuffer: false, ...opts});
    }

    function allocate() {
      for (const t of [sceneRT, dofA, dofB, volumeRT, volumeBlur, ...bloomLevels.flatMap(l => [l.down, l.up])]) t?.dispose();
      const w = Math.round(width * pixelRatio * settings.scale), h = Math.round(height * pixelRatio * settings.scale);
      sceneRT = rt(w, h, {depthBuffer: true, samples: settings.msaa});
      sceneRT.depthTexture = new T.DepthTexture(w, h, T.UnsignedIntType);
      bloomLevels = [];
      let bw = w, bh = h;
      for (let i = 0; i < 5; i++) {
        bw = Math.max(1, bw >> 1); bh = Math.max(1, bh >> 1);
        bloomLevels.push({down: rt(bw, bh), up: rt(bw, bh), w: bw, h: bh});
      }
      dofA = rt(w >> 1, h >> 1); dofB = rt(w >> 1, h >> 1);
      volumeRT = rt(w >> 1, h >> 1); volumeBlur = rt(w >> 1, h >> 1);
    }

    function resize(w, h, ratio) {
      width = w; height = h; pixelRatio = ratio;
      renderer.setPixelRatio(ratio);
      renderer.setSize(w, h, false);
      camera.aspect = w / Math.max(1, h);
      camera.updateProjectionMatrix();
      allocate();
    }

    function pass(material, target) {
      quad.material = material;
      renderer.setRenderTarget(target);
      renderer.render(quadScene, quadCam);
    }

    const post = {focus: 6, aperture: 0, blurAll: 0, exposure: 1, fade: 1, volumeLevel: 1, bloomLevel: 0.55, box: null};

    function render() {
      U.shadowOn.value = settings.volume || settings.shadowSize > 0 ? 1 : 0;
      renderer.setRenderTarget(sceneRT);
      renderer.render(scene, camera);

      // Bloom: threshold on the way down, tent filter on the way up.
      if (settings.bloom) {
        let src = sceneRT.texture, sw = sceneRT.width, sh = sceneRT.height;
        bloomLevels.forEach((level, i) => {
          downMat.uniforms.src.value = src;
          downMat.uniforms.texel.value.set(1 / sw, 1 / sh);
          downMat.uniforms.threshold.value = i === 0 ? 0.9 : 0;
          pass(downMat, level.down);
          src = level.down.texture; sw = level.w; sh = level.h;
        });
        for (let i = bloomLevels.length - 1; i > 0; i--) {
          const from = i === bloomLevels.length - 1 ? bloomLevels[i].down : bloomLevels[i].up;
          upMat.uniforms.src.value = from.texture;
          upMat.uniforms.base.value = bloomLevels[i - 1].down.texture;
          upMat.uniforms.texel.value.set(1 / bloomLevels[i].w, 1 / bloomLevels[i].h);
          pass(upMat, bloomLevels[i - 1].up);
        }
      }

      if (settings.dof && (post.aperture > 0.001 || post.blurAll > 0.001)) {
        downMat.uniforms.src.value = sceneRT.texture;
        downMat.uniforms.texel.value.set(1 / sceneRT.width, 1 / sceneRT.height);
        downMat.uniforms.threshold.value = 0;
        pass(downMat, dofA);
        const strength = 1 + post.blurAll * 2;
        for (let i = 0; i < 2; i++) {
          blurMat.uniforms.src.value = dofA.texture;
          blurMat.uniforms.dir.value.set(strength / dofA.width, 0);
          pass(blurMat, dofB);
          blurMat.uniforms.src.value = dofB.texture;
          blurMat.uniforms.dir.value.set(0, strength / dofA.height);
          pass(blurMat, dofA);
        }
      }

      const volumeOn = settings.volume && post.box && post.volumeLevel > 0.01;
      if (volumeOn) {
        const vu = volumeMat.uniforms;
        vu.depth.value = sceneRT.depthTexture;
        vu.invProj.value.copy(camera.projectionMatrixInverse);
        vu.invView.value.copy(camera.matrixWorld);
        vu.cameraPos.value.copy(camera.position);
        vu.boxMin.value.set(...post.box.min);
        vu.boxMax.value.set(...post.box.max);
        vu.steps.value = settings.volumeSteps;
        pass(volumeMat, volumeRT);
        blurMat.uniforms.src.value = volumeRT.texture;
        blurMat.uniforms.dir.value.set(1 / volumeRT.width, 0);
        pass(blurMat, volumeBlur);
        blurMat.uniforms.src.value = volumeBlur.texture;
        blurMat.uniforms.dir.value.set(0, 1 / volumeRT.height);
        pass(blurMat, volumeRT);
      }

      const cu = compositeMat.uniforms;
      cu.scene.value = sceneRT.texture;
      cu.depth.value = sceneRT.depthTexture;
      cu.bloom.value = settings.bloom ? bloomLevels[0].up.texture : null;
      cu.bloomLevel.value = settings.bloom ? post.bloomLevel : 0;
      cu.dofBlur.value = dofA.texture;
      cu.volume.value = volumeRT.texture;
      cu.volumeLevel.value = volumeOn ? post.volumeLevel : 0;
      cu.near.value = camera.near; cu.far.value = camera.far;
      cu.focus.value = post.focus;
      cu.aperture.value = settings.dof ? post.aperture : 0;
      cu.blurAll.value = settings.dof ? post.blurAll : 0;
      cu.exposure.value = post.exposure;
      cu.fade.value = post.fade;
      cu.texel.value.set(1 / sceneRT.width, 1 / sceneRT.height);
      pass(compositeMat, null);
    }

    return {
      renderer, scene, camera, U, sky, skyUniforms, gl,
      blockMaterial, glassMaterial, depthMaterial,
      renderShadow, ensureShadow, resize, render, post, settings,
      applySettings(next) {
        Object.assign(settings, next);
        ensureShadow(settings.shadowSize || 1024);
        allocate();
      },
    };
  }

  window.LibraryRender = {create};
})();
