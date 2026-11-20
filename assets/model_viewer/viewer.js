import * as THREE from './vendor/build/three.module.min.js';
import { OrbitControls } from './vendor/examples/jsm/controls/OrbitControls.js';

const stage = document.querySelector('#stage');
const status = document.querySelector('#status');
const controlsBar = document.querySelector('#controls');
const reset = document.querySelector('#reset');
const animation = document.querySelector('#animation');

const viewerRoot = new URL('./', location.href);
const fileRoot = new URL('files/', viewerRoot);

async function fetchFile(url) {
  const response = await fetch(url);
  if (response.ok) return response;
  const detail = response.status === 422 ? await response.text() : '';
  throw new Error(detail);
}

function dataUrl(address) {
  if (address.startsWith('data:') || address.startsWith('blob:')) return address;
  const resolved = new URL(address, viewerRoot);
  const decoderRoot = new URL('vendor/examples/jsm/libs/draco/gltf/', viewerRoot);
  if (resolved.href.startsWith(fileRoot.href) ||
      resolved.href.startsWith(decoderRoot.href)) return resolved.href;
  throw new Error();
}

function material(vertexColors = false) {
  return new THREE.MeshStandardMaterial({
    color: vertexColors ? 0xffffff : 0xb8c9da,
    roughness: 0.72,
    side: THREE.DoubleSide,
    vertexColors,
  });
}

async function loadObj(bytes, base, manager) {
  const [{ OBJLoader }, { MTLLoader }] = await Promise.all([
    import('./vendor/examples/jsm/loaders/OBJLoader.js'),
    import('./vendor/examples/jsm/loaders/MTLLoader.js'),
  ]);
  const source = new TextDecoder().decode(bytes);
  const libraries = Array.from(source.matchAll(/^mtllib[ \t]+([^\r\n]+)$/gm),
    (match) => match[1].trim());
  const materials = (await Promise.all(libraries.map(async (name) => {
    try {
      const url = dataUrl(new URL(name, base).href);
      const response = await fetchFile(url);
      return new MTLLoader(manager).parse(await response.text(), new URL('./', url).href);
    } catch {
      manager.itemError(name);
      return null;
    }
  }))).filter(Boolean);
  const loader = new OBJLoader(manager);
  if (materials.length) {
    loader.setMaterials({
      create: (name) => materials.find((library) =>
        Object.hasOwn(library.materialsInfo, name))?.create(name),
    });
  }
  return loader.parse(source);
}

async function loadModel(format, url, manager) {
  const data = await (await fetchFile(url)).arrayBuffer();
  const base = new URL('./', url).href;
  switch (format) {
    case 'glb':
    case 'gltf': {
      const [{ GLTFLoader }, { DRACOLoader }, { MeshoptDecoder }] = await Promise.all([
        import('./vendor/examples/jsm/loaders/GLTFLoader.js'),
        import('./vendor/examples/jsm/loaders/DRACOLoader.js'),
        import('./vendor/examples/jsm/libs/meshopt_decoder.module.js'),
      ]);
      const draco = new DRACOLoader(manager)
        .setDecoderPath(new URL('vendor/examples/jsm/libs/draco/gltf/', viewerRoot).href);
      try {
        const gltf = await new GLTFLoader(manager)
          .setDRACOLoader(draco)
          .setMeshoptDecoder(MeshoptDecoder)
          .parseAsync(data, base);
        gltf.scene.animations = gltf.animations;
        return gltf.scene;
      } finally {
        draco.dispose();
      }
    }
    case 'obj':
      return loadObj(data, base, manager);
    case 'fbx': {
      const [{ FBXLoader }, { TGALoader }] = await Promise.all([
        import('./vendor/examples/jsm/loaders/FBXLoader.js'),
        import('./vendor/examples/jsm/loaders/TGALoader.js'),
      ]);
      manager.addHandler(/\.tga$/i, new TGALoader(manager));
      return new FBXLoader(manager).parse(data, base);
    }
    case 'stl': {
      const { STLLoader } = await import('./vendor/examples/jsm/loaders/STLLoader.js');
      const geometry = new STLLoader().parse(data);
      return new THREE.Mesh(geometry, material(geometry.hasAttribute('color')));
    }
    case 'ply': {
      const { PLYLoader } = await import('./vendor/examples/jsm/loaders/PLYLoader.js');
      const geometry = new PLYLoader().parse(data);
      const colored = geometry.hasAttribute('color');
      if (!geometry.index && !geometry.hasAttribute('uv')) {
        return new THREE.Points(geometry, new THREE.PointsMaterial({
          color: colored ? 0xffffff : 0xb8c9da,
          size: 2,
          sizeAttenuation: false,
          vertexColors: colored,
        }));
      }
      if (!geometry.hasAttribute('normal')) geometry.computeVertexNormals();
      return new THREE.Mesh(geometry, material(colored));
    }
    default:
      throw new Error();
  }
}

async function start(config) {
  status.textContent = config.loading;
  const manager = new THREE.LoadingManager();
  manager.setURLModifier(dataUrl);
  let missing = false;
  let loaded = false;
  let render = () => {};
  manager.onError = () => {
    missing = true;
    if (loaded) status.textContent = config.missing;
  };
  manager.onLoad = () => render();
  const object = await loadModel(config.format, new URL(config.file, viewerRoot), manager);
  const box = new THREE.Box3().setFromObject(object);
  const span = box.getSize(new THREE.Vector3()).length();
  if (box.isEmpty() || !Number.isFinite(span)) throw new Error();

  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  stage.append(renderer.domElement);
  const scene = new THREE.Scene();
  const group = new THREE.Group();
  const center = box.getCenter(new THREE.Vector3());
  const scale = span > 0 ? 6 / span : 1;
  group.scale.setScalar(scale);
  group.position.copy(center).multiplyScalar(-scale);
  group.add(object);
  scene.add(group);

  const grid = new THREE.GridHelper(16, 16, 0x526581, 0x354557);
  grid.position.y = (box.min.y - center.y) * scale;
  scene.add(grid, new THREE.HemisphereLight(0xe4eeff, 0x525666, 2.2));
  const key = new THREE.DirectionalLight(0xffffff, 3.2);
  key.position.set(6, 8, 4);
  scene.add(key);

  const camera = new THREE.PerspectiveCamera(42, 1, 0.01, 350);
  const controls = new OrbitControls(camera, renderer.domElement);
  controls.minDistance = 0.05;
  controls.maxDistance = 180;
  render = () => renderer.render(scene, camera);
  controls.addEventListener('change', render);
  const resize = () => {
    renderer.setSize(stage.clientWidth, Math.max(stage.clientHeight, 1));
    camera.aspect = stage.clientWidth / Math.max(stage.clientHeight, 1);
    camera.updateProjectionMatrix();
    render();
  };
  const home = () => {
    const halfVertical = THREE.MathUtils.degToRad(camera.fov / 2);
    const halfHorizontal = Math.atan(Math.tan(halfVertical) * camera.aspect);
    const distance = 3.25 / Math.sin(Math.min(halfVertical, halfHorizontal));
    camera.position.set(1, 0.65, 1.15).setLength(distance);
    controls.target.set(0, 0, 0);
    controls.update();
    render();
  };
  resize();
  home();
  new ResizeObserver(resize).observe(stage);
  reset.textContent = config.reset;
  reset.onclick = home;
  if (object.animations.length > 0) {
    const mixer = new THREE.AnimationMixer(object);
    mixer.clipAction(object.animations[0]).play();
    animation.hidden = false;
    animation.textContent = config.play;
    let playing = false;
    let lastFrame;
    let frameId;
    const frame = (time) => {
      if (!playing) return;
      mixer.update(Math.min((time - (lastFrame ?? time)) / 1000, 0.05));
      lastFrame = time;
      render();
      frameId = requestAnimationFrame(frame);
    };
    animation.onclick = () => {
      playing = !playing;
      animation.textContent = playing ? config.pause : config.play;
      lastFrame = undefined;
      if (playing) frameId = requestAnimationFrame(frame);
      else cancelAnimationFrame(frameId);
    };
  }
  loaded = true;
  status.textContent = missing ? config.missing : '';
  controlsBar.hidden = false;
}

const config = await (await fetch('config.json')).json();
try {
  await start(config);
} catch (error) {
  status.textContent = error.message
    ? `${config.error} ${error.message}`
    : config.error;
}
