import * as THREE from 'three';

const TAU = Math.PI * 2;
const clamp = THREE.MathUtils.clamp;
const lerp = THREE.MathUtils.lerp;
const WEATHER = {
  clear: { cover: 0.2, rain: 0, storm: 0, fog: 0.000026, wave: 0.46 },
  overcast: { cover: 0.85, rain: 0, storm: 0.12, fog: 0.00011, wave: 0.72 },
  fog: { cover: 1, rain: 0, storm: 0, fog: 0.013, wave: 0.34 },
  rain: { cover: 0.94, rain: 0.68, storm: 0.3, fog: 0.00035, wave: 0.95 },
  storm: { cover: 1, rain: 1, storm: 1, fog: 0.00064, wave: 1.65 },
};
const PRESETS = {
  low: { grid: 128, shadow: 1024, drops: 500 },
  medium: { grid: 176, shadow: 2048, drops: 1000 },
  high: { grid: 224, shadow: 2048, drops: 1700 },
  ultra: { grid: 280, shadow: 4096, drops: 2500 },
};
const WAVES = [
  [0.88, 0.48, 0.12, 0.56, 1.25],
  [-0.34, 0.94, 0.23, 0.24, 1.68],
  [0.65, -0.76, 0.48, 0.11, 2.12],
  [0.99, 0.13, 0.91, 0.045, 2.83],
];

const noiseGLSL = `
float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 345.45));
  p += dot(p, p + 34.345);
  return fract(p.x * p.y);
}
float noise21(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash21(i), hash21(i + vec2(1,0)), f.x),
    mix(hash21(i + vec2(0,1)), hash21(i + vec2(1)), f.x), f.y);
}
float fbm(vec2 p) {
  float f = 0.0, a = 0.5;
  for (int i = 0; i < 5; i++) {
    f += a * noise21(p);
    p = mat2(1.6, -1.2, 1.2, 1.6) * p + 17.2;
    a *= 0.5;
  }
  return f;
}
`;

const waveGLSL = `
uniform float uTime, uWave;
float waveHeight(vec2 p) {
  float h = sin(dot(p, vec2(.88,.48)) * .12 + uTime * 1.25) * .56;
  h += sin(dot(p, vec2(-.34,.94)) * .23 + uTime * 1.68) * .24;
  h += sin(dot(p, vec2(.65,-.76)) * .48 + uTime * 2.12) * .11;
  h += sin(dot(p, vec2(.99,.13)) * .91 + uTime * 2.83) * .045;
  return h * uWave;
}
vec2 waveSlope(vec2 p) {
  vec2 d = cos(dot(p, vec2(.88,.48)) * .12 + uTime * 1.25) * .56 * .12 * vec2(.88,.48);
  d += cos(dot(p, vec2(-.34,.94)) * .23 + uTime * 1.68) * .24 * .23 * vec2(-.34,.94);
  d += cos(dot(p, vec2(.65,-.76)) * .48 + uTime * 2.12) * .11 * .48 * vec2(.65,-.76);
  d += cos(dot(p, vec2(.99,.13)) * .91 + uTime * 2.83) * .045 * .91 * vec2(.99,.13);
  return d * uWave;
}
`;

function oceanGrid(segments) {
  const geometry = new THREE.PlaneGeometry(2, 2, segments, segments);
  const positions = geometry.attributes.position;
  for (let i = 0; i < positions.count; i++) {
    const x = positions.getX(i), z = positions.getY(i);
    positions.setXYZ(i, x * 190 + x * x * x * 23810, 0, z * 190 + z * z * z * 23810);
  }
  const indices = geometry.index;
  for (let i = 0; i < indices.count; i += 3) {
    const a = indices.getX(i);
    indices.setX(i, indices.getX(i + 2));
    indices.setX(i + 2, a);
  }
  geometry.computeBoundingSphere();
  return geometry;
}

export function createEnvironment(scene, renderer, camera) {
  let elapsed = 0, currentQuality = '', lightningWait = 13, lightningAge = 100;
  let disposed = false;
  const state = { ...WEATHER.clear };
  const uniforms = {
    uTime: { value: 0 }, uWave: { value: state.wave },
    uSun: { value: new THREE.Vector3(0.7, 0.65, 0.25).normalize() },
    uNight: { value: 0 }, uCover: { value: state.cover },
    uStorm: { value: 0 }, uFlash: { value: 0 }, uFog: { value: state.fog },
    uWind: { value: 1 }, uHorizon: { value: new THREE.Color('#aac5d1') },
    uZenith: { value: new THREE.Color('#3b79ab') },
    uSunColor: { value: new THREE.Color('#fff1d5') },
  };
  const skyMaterial = new THREE.ShaderMaterial({
    side: THREE.BackSide, depthWrite: false, depthTest: false,
    uniforms,
    vertexShader: `varying vec3 vDirection;
      void main() { vDirection = position; vec4 clip = projectionMatrix * modelViewMatrix * vec4(position, 1.0); gl_Position = clip.xyww; }`,
    fragmentShader: `
      varying vec3 vDirection;
      uniform vec3 uSun, uHorizon, uZenith, uSunColor;
      uniform float uTime, uNight, uCover, uStorm, uFlash, uWind;
      ${noiseGLSL}
      void main() {
        vec3 d = normalize(vDirection);
        float elevation = max(0.0, d.y);
        vec3 color = mix(uHorizon, uZenith, pow(elevation, .48));
        float sunDot = max(dot(d, uSun), 0.0);
        float moonDot = max(dot(d, -uSun), 0.0);
        color += uSunColor * pow(sunDot, 26.0) * .23 * (1.0-uNight);
        color += uSunColor * smoothstep(.99968, .99983, sunDot) * 9.0 * (1.0-uNight);
        color += vec3(.42,.54,.78) * (pow(moonDot, 100.0) * .12 + smoothstep(.99968,.99986,moonDot) * 1.15) * uNight;
        vec2 starUV = vec2(atan(d.z,d.x), asin(clamp(d.y,-1.0,1.0))) * vec2(410.0, 500.0);
        vec2 cell = floor(starUV);
        float starSeed = hash21(cell);
        float star = (1.0-smoothstep(.02,.22,length(fract(starUV)-.5))) * step(.992,starSeed);
        color += vec3(.63,.75,.95) * star * uNight * smoothstep(0.02,.4,d.y) * (1.0-uCover*.9) * (.75+.25*sin(uTime+starSeed*80.0));
        vec2 cloudUV = d.xz / max(.13,d.y+.12) * 2.7 + vec2(uTime*.003*uWind,uTime*.001);
        float clouds = fbm(cloudUV);
        float cloudMask = smoothstep(.74-uCover*.53,.92-uCover*.42,clouds);
        cloudMask *= smoothstep(-.04,.18,d.y);
        vec3 cloudLight = mix(vec3(.68,.75,.8),vec3(.022,.035,.055),uNight);
        cloudLight *= mix(1.0,.28,uStorm);
        cloudLight += vec3(.19,.17,.14) * pow(sunDot,12.0) * (1.0-uNight);
        float silver = max(0.0,fbm(cloudUV+vec2(.025,.015))-clouds) * 9.0;
        cloudLight += uSunColor * silver * (1.0-uNight) * (1.0-uStorm*.7);
        color = mix(color,cloudLight,cloudMask * .96);
        color += vec3(.53,.65,.9) * uFlash * (0.65+cloudMask*.7);
        gl_FragColor = vec4(max(color,vec3(.001)),1.0);
        #include <tonemapping_fragment>
        #include <colorspace_fragment>
      }`,
  });
  const sky = new THREE.Mesh(new THREE.SphereGeometry(21000, 32, 16), skyMaterial);
  sky.renderOrder = -100;
  sky.frustumCulled = false;
  scene.add(sky);

  const oceanMaterial = new THREE.ShaderMaterial({
    uniforms,
    vertexShader: `
      #include <common>
      #include <logdepthbuf_pars_vertex>
      varying vec3 vWorld;
      ${waveGLSL}
      void main() {
        vec3 world = (modelMatrix * vec4(position,1.0)).xyz;
        world.y = waveHeight(world.xz);
        vWorld = world;
        gl_Position = projectionMatrix * viewMatrix * vec4(world,1.0);
        #include <logdepthbuf_vertex>
      }`,
    fragmentShader: `
      #include <logdepthbuf_pars_fragment>
      varying vec3 vWorld;
      uniform vec3 uSun, uHorizon, uZenith, uSunColor;
      uniform float uNight, uCover, uStorm, uFlash, uFog, uWind;
      ${noiseGLSL}
      ${waveGLSL}
      void main() {
        #include <logdepthbuf_fragment>
        vec2 p = vWorld.xz;
        vec3 view = normalize(cameraPosition-vWorld);
        float distanceToEye = distance(cameraPosition,vWorld);
        vec2 slope = waveSlope(p);
        float detailFade = 1.0-smoothstep(80.0,1500.0,distanceToEye);
        vec2 microP = p + vec2(noise21(p*.19+uTime*.03),noise21(p*.15-13.0))*5.0;
        float detailAA = 1.0-smoothstep(.15,1.3,length(fwidth(p)));
        slope += vec2(
          sin(microP.x*2.7+microP.y*1.8+uTime*3.5)+sin(microP.x*5.1-microP.y*3.9-uTime*4.2)*.36,
          cos(microP.x*1.3-microP.y*3.1+uTime*3.9)+cos(microP.x*4.7+microP.y*5.2+uTime*4.7)*.32
        ) * .046 * (1.0+uStorm) * detailFade * detailAA;
        vec3 normal = normalize(vec3(-slope.x,1.0,-slope.y));
        vec3 reflected = reflect(-view,normal);
        float fresnel = .035 + .965 * pow(1.0-max(dot(normal,view),0.0),5.0);
        vec3 skyColor = mix(uHorizon,uZenith,pow(max(reflected.y,0.0),.48));
        skyColor = mix(skyColor,mix(vec3(.3,.36,.4),vec3(.009,.018,.035),uNight),uCover*.36);
        vec3 deep = mix(vec3(.004,.027,.048),vec3(.0015,.007,.014),uNight);
        vec3 shallow = mix(vec3(.012,.091,.125),vec3(.003,.018,.028),uNight);
        vec3 water = mix(deep,shallow,clamp(vWorld.y*.3+.25,0.0,.8)) * (1.0-uStorm*.4);
        vec3 color = mix(water,skyColor,fresnel);
        float gloss = mix(420.0,95.0,uStorm);
        float sunGlint = pow(max(dot(reflected,uSun),0.0),gloss);
        float moonGlint = pow(max(dot(reflected,-uSun),0.0),230.0);
        color += uSunColor * sunGlint * 3.5 * (1.0-uNight) * (1.0-uCover*.84);
        color += vec3(.27,.4,.65) * moonGlint * uNight * 1.6 * (1.0-uCover*.85);
        float crest = smoothstep(.46,.86,vWorld.y/max(uWave,.1));
        float churn = fbm(p*.075+vec2(uTime*.15,uTime*.05));
        float wakeLength = max(0.0,-p.x-153.0);
        float wakeWidth = 7.0+wakeLength*.045;
        float sternWake = exp(-pow(p.y/wakeWidth,2.0)) * exp(-wakeLength/430.0) * step(p.x,-153.0);
        float kelvin = exp(-pow((abs(p.y)-wakeLength*.23-10.0)/5.5,2.0)) * exp(-wakeLength/650.0) * step(p.x,-140.0);
        float sideWash = exp(-pow((abs(p.y)-22.0)/2.4,2.0)) * (1.0-smoothstep(140.0,175.0,abs(p.x)));
        float foam = clamp((sternWake*.7+kelvin*.3+sideWash*.32)*smoothstep(.31,.72,churn)+crest*churn*uStorm*.36,0.0,.8);
        color = mix(color,mix(vec3(.57,.7,.7),vec3(.035,.064,.09),uNight),foam);
        float contact = exp(-pow((abs(p.y)-20.0)/4.0,2.0))*(1.0-smoothstep(145.0,177.0,abs(p.x)));
        color *= 1.0-contact*.35;
        color += vec3(.22,.3,.47) * uFlash * (.25+fresnel);
        float haze = 1.0-exp(-pow(distanceToEye*uFog,1.3));
        color = mix(color,uHorizon,haze);
        gl_FragColor = vec4(color,1.0);
        #include <tonemapping_fragment>
        #include <colorspace_fragment>
      }`,
  });
  const ocean = new THREE.Mesh(oceanGrid(PRESETS.high.grid), oceanMaterial);
  ocean.frustumCulled = false;
  scene.add(ocean);

  const key = new THREE.DirectionalLight('#fff3d8', 3.2);
  key.castShadow = true;
  key.shadow.camera.near = 1;
  key.shadow.camera.far = 360;
  key.shadow.camera.left = -82;
  key.shadow.camera.right = 82;
  key.shadow.camera.top = 82;
  key.shadow.camera.bottom = -82;
  key.shadow.bias = -0.00012;
  key.shadow.normalBias = 0.18;
  key.shadow.radius = 2;
  const fill = new THREE.HemisphereLight('#b9d6ee', '#273139', 1.25);
  scene.add(key, key.target, fill);
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFShadowMap;
  const previousFog = scene.fog;
  const previousEnvironment = scene.environment;
  const previousEnvironmentIntensity = scene.environmentIntensity;
  scene.fog = new THREE.FogExp2('#b2c4cb', state.fog);
  const reflectionScene = new THREE.Scene();
  const reflectionSky = new THREE.Mesh(new THREE.SphereGeometry(10,24,12),skyMaterial);
  reflectionScene.add(reflectionSky);
  const pmrem = new THREE.PMREMGenerator(renderer);
  let reflection = null, reflectionTime = -100, reflectionNight = -1, reflectionCover = -1;

  const maxDrops = PRESETS.ultra.drops;
  const rainPositions = new Float32Array(maxDrops * 6);
  const rainSeeds = new Float32Array(maxDrops * 4);
  for (let i = 0; i < maxDrops; i++) {
    rainSeeds.set([(Math.random()-.5)*70, Math.random()*46-12, (Math.random()-.5)*70, .6+Math.random()*.8], i*4);
  }
  const rainGeometry = new THREE.BufferGeometry();
  rainGeometry.setAttribute('position', new THREE.BufferAttribute(rainPositions, 3).setUsage(THREE.DynamicDrawUsage));
  const rainMaterial = new THREE.LineBasicMaterial({ color: '#c3d5e4', transparent: true, opacity: 0, depthWrite: false });
  const rain = new THREE.LineSegments(rainGeometry, rainMaterial);
  rain.frustumCulled = false;
  scene.add(rain);

  const lightDirection = new THREE.Vector3();
  const focus = new THREE.Vector3();
  const dayHorizon = new THREE.Color('#b6cad1'), dayZenith = new THREE.Color('#3a79ac');
  const nightHorizon = new THREE.Color('#101a2a'), nightZenith = new THREE.Color('#020713');
  const duskHorizon = new THREE.Color('#e4a175'), cloudHorizon = new THREE.Color('#89969b');
  const warmSun = new THREE.Color('#ffb46b'), whiteSun = new THREE.Color('#fff0d6');
  const daylightFill = new THREE.Color('#bdd6ec'), nightFill = new THREE.Color('#829bbb');
  const api = { night: 0, wet: 0, storm: 0, flash: 0, update, seaHeight, dispose };

  function setQuality(quality) {
    const name = PRESETS[quality] ? quality : 'high';
    if (name === currentQuality) return;
    currentQuality = name;
    const preset = PRESETS[name];
    ocean.geometry.dispose();
    ocean.geometry = oceanGrid(preset.grid);
    key.shadow.mapSize.set(preset.shadow, preset.shadow);
    key.shadow.map?.dispose();
    key.shadow.map = null;
    key.shadow.needsUpdate = true;
    rainGeometry.setDrawRange(0, preset.drops * 2);
  }

  function update(dt, { hour = 15, weather = 'clear', wind = 1, quality = 'high', lightning = true } = {}) {
    if (disposed) return;
    const transitionDt = clamp(dt, 0, 180);
    dt = Math.min(transitionDt,.1);
    elapsed += transitionDt;
    setQuality(quality);
    const target = WEATHER[weather] || WEATHER.clear;
    const blend = 1-Math.exp(-transitionDt/7);
    for (const property of Object.keys(state)) state[property] = lerp(state[property], target[property], blend);
    api.wet = lerp(api.wet, state.rain, 1-Math.exp(-transitionDt/(state.rain > api.wet ? 5 : 35)));
    api.storm = state.storm;
    uniforms.uTime.value = elapsed;
    uniforms.uWave.value = state.wave;
    uniforms.uCover.value = state.cover;
    uniforms.uStorm.value = state.storm;
    uniforms.uWind.value = clamp(wind, .1, 4) * (1+state.storm*1.5);
    const angle = ((hour-6)/24)*TAU;
    const sun = uniforms.uSun.value.set(Math.cos(angle),Math.sin(angle)*.95,.34).normalize();
    api.night = 1-THREE.MathUtils.smoothstep(sun.y,-.14,.18);
    uniforms.uNight.value = api.night;
    const dusk = Math.exp(-Math.pow(sun.y/.22,2)) * (1-state.cover*.7);
    uniforms.uHorizon.value.copy(dayHorizon).lerp(cloudHorizon,state.cover*.7).lerp(duskHorizon,dusk*.67).lerp(nightHorizon,api.night);
    uniforms.uZenith.value.copy(dayZenith).lerp(cloudHorizon,state.cover*.45).lerp(nightZenith,api.night);
    uniforms.uSunColor.value.copy(whiteSun).lerp(warmSun,dusk);
    uniforms.uFog.value = state.fog;
    scene.fog.color.copy(uniforms.uHorizon.value);
    scene.fog.density = state.fog;

    lightningWait -= dt;
    lightningAge += dt;
    if (lightning && state.storm > .55 && lightningWait <= 0) {
      lightningAge = 0;
      lightningWait = 10+Math.random()*22;
    }
    if (lightningWait <= 0 && state.storm <= .55) lightningWait = 6;
    api.flash = lightning ? Math.max(0, Math.exp(-lightningAge*24) + .6*Math.exp(-Math.pow((lightningAge-.17)/.045,2))) : 0;
    uniforms.uFlash.value = api.flash;

    const nightLight = api.night > .7;
    lightDirection.copy(sun).multiplyScalar(nightLight ? -1 : 1);
    lightDirection.y = Math.max(.09,lightDirection.y);
    lightDirection.normalize();
    focus.set(clamp(camera.position.x,-165,165),clamp(camera.position.y,8,65),clamp(camera.position.z,-26,26));
    const texel = 164/PRESETS[currentQuality].shadow;
    focus.x = Math.round(focus.x/texel)*texel;
    focus.z = Math.round(focus.z/texel)*texel;
    key.target.position.copy(focus);
    key.position.copy(focus).addScaledVector(lightDirection,160);
    key.color.copy(nightLight ? nightFill : uniforms.uSunColor.value);
    key.intensity = nightLight ? .55*(1-state.cover*.68) : 3.4*(1-api.night)*(1-state.cover*.76);
    key.intensity += api.flash*5;
    fill.color.copy(daylightFill).lerp(nightFill,api.night);
    fill.intensity = lerp(.55,.46,api.night)*(1-state.storm*.28)+api.flash*1.7;
    scene.environmentIntensity = lerp(.32,.28,api.night);
    const reflectionChanged = Math.abs(api.night-reflectionNight) > .18 || Math.abs(state.cover-reflectionCover) > .18;
    if (!reflection || (elapsed-reflectionTime > 12 && reflectionChanged) || elapsed-reflectionTime > 90) {
      const previousReflection = reflection;
      const savedFlash = uniforms.uFlash.value;
      uniforms.uFlash.value = 0;
      reflection = pmrem.fromScene(reflectionScene,.08,.1,100);
      uniforms.uFlash.value = savedFlash;
      scene.environment = reflection.texture;
      previousReflection?.dispose();
      reflectionTime = elapsed;
      reflectionNight = api.night;
      reflectionCover = state.cover;
    }
    sky.position.copy(camera.position);
    ocean.position.x = Math.round(camera.position.x/16)*16;
    ocean.position.z = Math.round(camera.position.z/16)*16;

    const sheltered = camera.position.y < 35 && Math.abs(camera.position.z) < 20 && Math.abs(camera.position.x) < 162;
    rain.visible = state.rain > .015 && !sheltered;
    rainMaterial.opacity = state.rain*(.25+api.night*.11);
    rain.position.copy(camera.position);
    if (rain.visible) {
      const count = PRESETS[currentQuality].drops;
      const windSpeed = uniforms.uWind.value*3.5;
      for (let i = 0; i < count; i++) {
        const offset = i*4, vertex = i*6;
        rainSeeds[offset+1] -= dt*(23+rainSeeds[offset+3]*8);
        rainSeeds[offset] += dt*windSpeed;
        if (rainSeeds[offset+1] < -12) rainSeeds[offset+1] += 46;
        if (rainSeeds[offset] > 35) rainSeeds[offset] -= 70;
        const x = rainSeeds[offset], y = rainSeeds[offset+1], z = rainSeeds[offset+2];
        rainPositions[vertex] = x;
        rainPositions[vertex+1] = y;
        rainPositions[vertex+2] = z;
        rainPositions[vertex+3] = x+windSpeed*.024;
        rainPositions[vertex+4] = y-rainSeeds[offset+3]*.95;
        rainPositions[vertex+5] = z+.035;
      }
      rainGeometry.attributes.position.needsUpdate = true;
    }
  }

  function seaHeight(x, z) {
    let h = 0;
    for (const [dx, dz, frequency, amplitude, speed] of WAVES) {
      h += Math.sin((x*dx+z*dz)*frequency+elapsed*speed)*amplitude;
    }
    return h*state.wave;
  }

  function dispose() {
    if (disposed) return;
    disposed = true;
    scene.remove(sky,ocean,key,key.target,fill,rain);
    scene.fog = previousFog;
    scene.environment = previousEnvironment;
    scene.environmentIntensity = previousEnvironmentIntensity;
    sky.geometry.dispose();
    skyMaterial.dispose();
    ocean.geometry.dispose();
    oceanMaterial.dispose();
    rainGeometry.dispose();
    rainMaterial.dispose();
    key.shadow.map?.dispose();
    reflection?.dispose();
    reflectionSky.geometry.dispose();
    pmrem.dispose();
  }
  return api;
}
