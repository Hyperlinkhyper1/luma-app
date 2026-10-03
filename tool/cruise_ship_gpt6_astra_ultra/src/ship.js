import * as THREE from 'three';

const TAU = Math.PI * 2;

function canvasTexture(width, height, draw) {
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  draw(canvas.getContext('2d'), width, height);
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.anisotropy = 8;
  return texture;
}

function deckingTexture() {
  return canvasTexture(1024, 1024, (ctx, width, height) => {
    ctx.fillStyle = '#ac8b65';
    ctx.fillRect(0, 0, width, height);
    for (let row = 0; row < 32; row++) {
      const shade = 146 + (row * 17 % 39);
      ctx.fillStyle = `rgb(${shade + 23},${shade},${shade - 39})`;
      ctx.fillRect(0, row * 32 + 1, width, 30);
      ctx.strokeStyle = 'rgba(43,35,25,.48)';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(0, row * 32);
      ctx.lineTo(width, row * 32);
      ctx.stroke();
      for (let seam = -1; seam < 5; seam++) {
        const x = seam * 256 + (row % 3) * 85;
        ctx.fillStyle = '#6b5742';
        ctx.fillRect(x, row * 32, 1.4, 32);
      }
      for (let grain = 0; grain < 8; grain++) {
        ctx.strokeStyle = `rgba(62,42,23,${0.025 + grain * .006})`;
        ctx.lineWidth = .7;
        ctx.beginPath();
        ctx.moveTo(0, row * 32 + 3 + grain * 3.4);
        ctx.bezierCurveTo(300, row * 32 + grain * 3.4, 650, row * 32 + 7 + grain * 3.4, width, row * 32 + 3 + grain * 3.4);
        ctx.stroke();
      }
    }
  });
}

function hullGeometry(stations, bottom, top) {
  const positions = [];
  const indices = [];
  const rings = [
    {y: bottom, width: .62, length: .955},
    {y: -2.5, width: .89, length: .99},
    {y: 1, width: .97, length: 1},
    {y: top, width: 1, length: 1},
  ];
  const outline = [...stations.map(([x, z]) => [x, z]), ...stations.slice().reverse().map(([x, z]) => [x, -z])];
  for (const ring of rings) {
    for (const [x, z] of outline) positions.push(x * ring.length, ring.y, z * ring.width);
  }
  const count = outline.length;
  for (let r = 0; r < rings.length - 1; r++) {
    for (let i = 0; i < count; i++) {
      const a = r * count + i;
      const b = r * count + (i + 1) % count;
      const c = (r + 1) * count + i;
      const d = (r + 1) * count + (i + 1) % count;
      indices.push(a, b, c, b, d, c);
    }
  }
  const topCenter = positions.length / 3;
  positions.push(0, top, 0);
  for (let i = 0; i < count; i++) indices.push(topCenter, (rings.length - 1) * count + i, (rings.length - 1) * count + (i + 1) % count);
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geometry.setIndex(indices);
  geometry.computeVertexNormals();
  return geometry;
}

export function buildShip() {
  const root = new THREE.Group();
  root.name = 'MSC Virtuosa — GPT 6 Astra (Ultra)';
  const surfaces = [];
  const obstacles = [];
  const lamps = [];
  const batches = new Map();
  const deckMap = deckingTexture();
  deckMap.wrapS = deckMap.wrapT = THREE.RepeatWrapping;
  deckMap.repeat.set(24, 6);
  const mat = {
    white: new THREE.MeshStandardMaterial({color: 0xe9ebe7, roughness: .55, metalness: .06}),
    ivory: new THREE.MeshStandardMaterial({color: 0xe5e1d2, roughness: .72}),
    shade: new THREE.MeshStandardMaterial({color: 0xb8bec0, roughness: .61, metalness: .22}),
    navy: new THREE.MeshStandardMaterial({color: 0x122334, roughness: .36, metalness: .28}),
    black: new THREE.MeshStandardMaterial({color: 0x182127, roughness: .56, metalness: .25}),
    window: new THREE.MeshStandardMaterial({color: 0x25424c, roughness: .16, metalness: .65}),
    litWindow: new THREE.MeshStandardMaterial({color: 0x2a4248, roughness: .18, metalness: .48, emissive: 0xffc783, emissiveIntensity: 0}),
    glass: new THREE.MeshStandardMaterial({color: 0x84b9c2, transparent: true, opacity: .37, roughness: .13, metalness: .28, depthWrite: false, side: THREE.DoubleSide}),
    rail: new THREE.MeshStandardMaterial({color: 0xc5c9c8, roughness: .27, metalness: .84}),
    wood: new THREE.MeshStandardMaterial({color: 0xa88051, roughness: .64}),
    deck: new THREE.MeshStandardMaterial({color: 0xfff1d8, map: deckMap, roughness: .79, metalness: .02}),
    orange: new THREE.MeshStandardMaterial({color: 0xf36a11, roughness: .46}),
    lifeboat: new THREE.MeshStandardMaterial({color: 0xf5f2dc, roughness: .47}),
    red: new THREE.MeshStandardMaterial({color: 0xb83429, roughness: .71}),
    pool: new THREE.MeshStandardMaterial({color: 0x0e9fac, transparent: true, opacity: .86, roughness: .1, metalness: .38}),
    tile: new THREE.MeshStandardMaterial({color: 0x7fc1c5, roughness: .34}),
    chair: new THREE.MeshStandardMaterial({color: 0xeff0de, roughness: .8}),
    cushion: new THREE.MeshStandardMaterial({color: 0x214b5f, roughness: .91}),
    sport: new THREE.MeshStandardMaterial({color: 0x638c79, roughness: .86}),
    lamp: new THREE.MeshStandardMaterial({color: 0xfff1cf, roughness: .4, emissive: 0xffcc85, emissiveIntensity: .15}),
    blueSlide: new THREE.MeshStandardMaterial({color: 0x26a5d5, roughness: .31}),
    yellowSlide: new THREE.MeshStandardMaterial({color: 0xf4b947, roughness: .35}),
  };
  const geometries = {
    box: new THREE.BoxGeometry(1, 1, 1),
    cylinder: new THREE.CylinderGeometry(1, 1, 1, 12),
    sphere: new THREE.SphereGeometry(1, 20, 12),
    dome: new THREE.SphereGeometry(1, 24, 12, 0, TAU, 0, Math.PI / 2),
    torus: new THREE.TorusGeometry(1, .09, 6, 16),
  };
  const transform = new THREE.Object3D();

  function part(material, x, y, z, sx, sy, sz, rx = 0, ry = 0, rz = 0, shape = 'box') {
    const key = `${material}:${shape}`;
    if (!batches.has(key)) batches.set(key, {material, shape, items: []});
    batches.get(key).items.push([x, y, z, sx, sy, sz, rx, ry, rz]);
  }

  function tube(material, a, b, radius = .045) {
    const start = new THREE.Vector3(...a);
    const end = new THREE.Vector3(...b);
    const direction = end.clone().sub(start);
    const midpoint = start.add(end).multiplyScalar(.5);
    transform.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), direction.clone().normalize());
    const rotation = new THREE.Euler().setFromQuaternion(transform.quaternion);
    part(material, midpoint.x, midpoint.y, midpoint.z, radius, direction.length(), radius, rotation.x, rotation.y, rotation.z, 'cylinder');
  }

  function slab(x0, x1, z0, z1, y, material = 'deck', thickness = .24) {
    part(material, (x0 + x1) / 2, y - thickness / 2, (z0 + z1) / 2, x1 - x0, thickness, z1 - z0);
    part('white', (x0 + x1) / 2, y - thickness - .17, (z0 + z1) / 2, x1 - x0 + .04, .34, z1 - z0 + .04);
  }

  function floor(id, deck, x0, x1, z0, z1, y, render = true) {
    surfaces.push({id, deck, x0, x1, z0, z1, y});
    if (render) slab(x0, x1, z0, z1, y);
  }

  function obstacle(x0, x1, z0, z1, y0, y1) {
    obstacles.push({x0, x1, z0, z1, y0, y1});
  }

  function rail(a, b, y, glass = false) {
    const length = Math.hypot(b[0] - a[0], b[1] - a[1]);
    const count = Math.ceil(length / 1.75);
    for (let i = 0; i <= count; i++) {
      const f = i / count;
      part('rail', a[0] + (b[0] - a[0]) * f, y + .56, a[1] + (b[1] - a[1]) * f, .045, 1.12, .045, 0, 0, 0, 'cylinder');
    }
    for (const h of [.34, .7, 1.12]) tube(h === 1.12 ? 'wood' : 'rail', [a[0], y + h, a[1]], [b[0], y + h, b[1]], h === 1.12 ? .06 : .027);
    if (glass) {
      const angle = -Math.atan2(b[1] - a[1], b[0] - a[0]);
      part('glass', (a[0] + b[0]) / 2, y + .57, (a[1] + b[1]) / 2, length, .88, .027, 0, angle);
    }
  }

  function sign(text, x, y, z, yaw, width = 1.45, height = .55, subtitle = '') {
    const texture = canvasTexture(1024, 384, (ctx, w, h) => {
      ctx.fillStyle = '#112936';
      ctx.fillRect(0, 0, w, h);
      ctx.strokeStyle = '#bfa774';
      ctx.lineWidth = 7;
      ctx.strokeRect(18, 18, w - 36, h - 36);
      ctx.fillStyle = '#f4f1e3';
      ctx.textAlign = 'center';
      ctx.font = '600 74px sans-serif';
      ctx.fillText(text, w / 2, subtitle ? 163 : 220);
      if (subtitle) {
        ctx.font = '36px sans-serif';
        ctx.fillStyle = '#c1d0d3';
        ctx.fillText(subtitle, w / 2, 263);
      }
    });
    const mesh = new THREE.Mesh(new THREE.PlaneGeometry(width, height), new THREE.MeshStandardMaterial({map: texture, roughness: .62, side: THREE.DoubleSide}));
    mesh.position.set(x, y, z);
    mesh.rotation.y = yaw;
    root.add(mesh);
  }

  function mscLogo(x, y, z, yaw, width = 13, height = 3.7, wording = 'MSC') {
    const texture = canvasTexture(2048, 512, (ctx, w, h) => {
      ctx.fillStyle = '#142c3d';
      ctx.save();
      ctx.translate(235, h / 2);
      for (let i = 0; i < 8; i++) {
        ctx.rotate(Math.PI / 4);
        ctx.beginPath();
        ctx.moveTo(0, -204);
        ctx.lineTo(34, -51);
        ctx.lineTo(0, -70);
        ctx.lineTo(-34, -51);
        ctx.closePath();
        ctx.fill();
      }
      ctx.beginPath();
      ctx.arc(0, 0, 87, 0, TAU);
      ctx.lineWidth = 10;
      ctx.strokeStyle = '#142c3d';
      ctx.stroke();
      ctx.font = 'bold 46px Georgia';
      ctx.textAlign = 'center';
      ctx.fillText('MSC', 0, 15);
      ctx.restore();
      ctx.font = wording === 'MSC' ? 'bold 360px Georgia' : 'bold 184px Georgia';
      ctx.fillText(wording, 515, 376);
    });
    const mesh = new THREE.Mesh(new THREE.PlaneGeometry(width, height), new THREE.MeshStandardMaterial({map: texture, transparent: true, alphaTest: .02, roughness: .6, side: THREE.DoubleSide}));
    mesh.position.set(x, y, z);
    mesh.rotation.y = yaw;
    root.add(mesh);
  }

  const hullStations = [[-165.5, 8], [-163, 12], [-158, 16.5], [-151, 19.4], [-140, 21.1], [-120, 21.5], [90, 21.5], [112, 20.7], [129, 18.2], [143, 13.9], [155, 8.2], [162, 3.6], [165.5, .08]];
  const hull = new THREE.Mesh(hullGeometry(hullStations, -7.5, 15.62), mat.white);
  hull.castShadow = hull.receiveShadow = true;
  root.add(hull);
  part('red', 0, -2.05, 0, 306, 3.2, 40.2);
  part('navy', -2, 13.2, 21.52, 240, 2.5, .08);
  part('navy', -2, 13.2, -21.52, 240, 2.5, .08);
  for (const side of [-1, 1]) {
    for (let x = -130; x <= 114; x += 4.9) {
      part('black', x, 8.55, side * 21.51, .32, .06, .32, Math.PI / 2, 0, 0, 'cylinder');
      part('rail', x, 8.55, side * 21.55, .37, .37, .37, 0, 0, 0, 'torus');
      if (x > -104 && x < 104) part('window', x, 11.05, side * 21.49, 2.45, 1.05, .045);
    }
    for (let x = -139; x < 140; x += 17.8) {
      const z = Math.abs(x) > 130 ? 18.3 : 21.43;
      part('shade', x, 3.7, side * z, 2.5, 1.7, .07);
      part('white', x, 3.7, side * (z + .05), 2.3, 1.45, .055);
    }
    mscLogo(-10, 6.25, side * 21.53, side > 0 ? 0 : Math.PI, 17, 4.2);
    sign('MSC VIRTUOSA', 134, 13.2, side * 16.8, side > 0 ? .3 : Math.PI - .3, 9.5, 1.35);
  }
  part('black', 154, 3.4, 6.8, 5.2, 2, .18, 0, -.7, -.1);
  part('black', 154, 3.4, -6.8, 5.2, 2, .18, 0, .7, -.1);
  part('shade', 155, 1.3, 6, 1.3, 3.2, .36, 0, -.7, -.18);
  part('shade', 155, 1.3, -6, 1.3, 3.2, .36, 0, .7, -.18);

  part('ivory', -3, 17.5, 0, 226, 3, 31.6);
  obstacle(-116, 110, -15.8, 15.8, 16, 19.05);
  part('white', 1.5, 18.94, 0, 235, .3, 39.8);
  part('white', -120.5, 18.94, -4.85, 9, .3, 30.1);
  part('white', -120.5, 18.94, 18.05, 9, .3, 3.7);
  part('white', -118.5, 18.94, 13.2, 5, .3, 6);
  floor('deck7-starboard', 7, -141, 126, 16.08, 19.7, 16);
  floor('deck7-port', 7, -141, 126, -19.7, -16.08, 16);
  floor('deck7-aft', 7, -146, -116, -19.7, 19.7, 16);
  floor('deck7-forward', 7, 110, 131, -19.7, 19.7, 16);
  for (const side of [-1, 1]) {
    rail([-143, side * 19.83], [126, side * 19.83], 16, true);
    obstacle(-143, 126, side > 0 ? 19.85 : -20, side > 0 ? 20 : -19.85, 16, 17.3);
    for (let x = -112; x <= 108; x += 7.7) {
      part('shade', x, 17.28, side * 15.94, .085, 2.25, .055);
      part('shade', x + 3.85, 18.45, side * 15.955, 7.58, .019, .025);
      part('shade', x + 3.85, 16.24, side * 15.96, 7.58, .045, .07);
      part('white', x + 5.5, 17.08, side * 15.97, 1.48, 1.09, .12);
      part('shade', x + 5.5, 17.62, side * 16.05, 1.5, .025, .055);
      part('shade', x + 5.5, 16.54, side * 16.05, 1.5, .025, .055);
      for (const dx of [-.72, .72]) part('shade', x + 5.5 + dx, 17.08, side * 16.05, .024, 1.08, .055);
      part('rail', x + 6.05, 17.13, side * 16.085, .045, .18, .032);
      part('shade', x + .65, 18.38, side * 16.04, .56, .28, .045);
      for (let vent = 0; vent < 4; vent++) part('black', x + .65, 18.29 + vent * .056, side * 16.075, .44, .015, .03);
      part('ivory', x + 2.2, 17.2, side * 15.94, 1.13, 2.35, .08);
      part('rail', x + 2.64, 17.12, side * 16.04, .08, .3, .065);
      part('navy', x + 2.2, 17.78, side * 16.04, .38, .42, .02);
      part('white', x, 17.48, side * 19.15, .18, 2.9, .18);
      part('lamp', x + 3.85, 18.71, side * 17.48, .48, .065, .23);
      part('shade', x + 3.85, 18.77, side * 17.48, .6, .09, .32);
      if (Math.round((x + 112) / 7.7) % 3 === 0) {
        part('red', x + 1.15, 17.03, side * 16.02, .35, .6, .2);
        part('white', x + 1.15, 17.42, side * 16.04, .4, .18, .025);
      }
    }
    for (let x = -64; x <= 64; x += 64) {
      const light = new THREE.PointLight(0xffcf94, 0, 13, 2);
      light.position.set(x, 18.38, side * 17.45);
      light.userData.nightIntensity = 10;
      root.add(light);
      lamps.push(light);
    }
    for (let x = -98; x <= 99; x += 24.5) {
      const z = side * 22.05;
      part('lifeboat', x, 18.02, z, 8.72, .88, 2.25, 0, 0, 0, 'sphere');
      part('orange', x, 19.01, z, 8.31, 1.21, 2.14, 0, 0, 0, 'sphere');
      part('orange', x, 19.2, z, 13.8, .83, 3.91);
      part('lifeboat', x, 18.27, z, 17, .23, 4.36);
      part('lifeboat', x - 1.5, 20.29, z, 3.6, .42, 2.9);
      part('window', x - 1.5, 20.16, z + side * 1.51, 2.6, .5, .07);
      for (const boatSide of [-1, 1]) {
        for (let panel = -3; panel <= 3; panel++) {
          part('window', x + panel * 1.75, 19.39, z + boatSide * 1.99, 1.22, .57, .075);
          part('lifeboat', x + panel * 1.75 - .69, 19.35, z + boatSide * 2.04, .075, 1, .075);
        }
        tube('black', [x - 7.9, 18.44, z + boatSide * 2.16], [x + 7.9, 18.44, z + boatSide * 2.16], .04);
      }
      for (const offset of [-6.05, 6.05]) {
        const base = [x + offset, 19.07, side * 18.85];
        const bend = [x + offset, 23.05, side * 19.3];
        const end = [x + offset, 22.4, side * 23.18];
        tube('shade', base, bend, .14);
        tube('white', bend, end, .16);
        tube('shade', [base[0] + .38, 19.18, side * 19.1], [bend[0], 22.3, side * 19.25], .065);
        tube('black', end, [x + offset, 19.88, z], .027);
        part('rail', x + offset, 22.41, side * 23.17, .21, .17, .21, 0, 0, Math.PI / 2, 'cylinder');
        part('shade', x + offset, 18.95, side * 19.18, .64, .35, .65);
      }
      for (const offset of [-7.1, 7.1]) tube('shade', [x + offset, 17.6, side * 20.1], [x + offset, 17.5, side * 22.2], .085);
    }
    sign('07  |  PROMENADE', -70, 17.64, side * 16.04, side > 0 ? 0 : Math.PI, 2, .58, 'FORWARD  →     SUN DECKS  ↑');
    sign('07  |  PROMENADE', 72, 17.64, side * 16.04, side > 0 ? 0 : Math.PI, 2, .58, '←  AFT     EXTERIOR STAIRS  ↑');
  }
  rail([-146, -19.7], [-146, 19.7], 16, true);
  rail([131, -19.7], [131, 19.7], 16, true);
  for (let x = -108; x < 106; x += 31) {
    for (const side of [-1, 1]) {
      part('wood', x, 16.44, side * 16.66, 2.5, .13, .64);
      part('wood', x, 16.81, side * 16.36, 2.5, .67, .075);
      part('shade', x - .85, 16.19, side * 16.63, .085, .38, .5);
      part('shade', x + .85, 16.19, side * 16.63, .085, .38, .5);
      obstacle(x - 1.3, x + 1.3, side > 0 ? 16.1 : -17, side > 0 ? 17 : -16.1, 16, 17.2);
    }
  }

  part('white', -90.5, 29.28, 0, 55, 20.65, 30.8);
  part('white', 66.5, 29.28, 0, 87, 20.65, 30.8);
  obstacle(-118, 110, -15.4, 15.4, 19, 39.5);
  for (let row = 0; row < 7; row++) {
    const y = 19 + row * 2.94;
    const x0 = -119 + Math.max(0, row - 3) * 1.6;
    const x1 = 111 - Math.max(0, row - 3) * 1.7;
    const recess = 1.9 + row * .23;
    const setback = x => {
      if (x < -63 || x > 23) return 0;
      if (x < -55) return recess * (x + 63) / 8;
      if (x > 15) return recess * (23 - x) / 8;
      return recess;
    };
    part('white', -20, y + 1.47, 0, 70, 2.94, (15.4 - recess) * 2);
    for (const [xa, xb] of [[-63, -55], [15, 23]]) {
      for (let x = xa; x < xb; x += .5) part('white', x + .25, y + 1.47, 0, .51, 2.94, (15.4 - setback(x + .25)) * 2);
    }
    for (const side of [-1, 1]) {
      const sections = [[x0, 0], [-63, 0], [-55, recess], [15, recess], [23, 0], [x1, 0]];
      for (let i = 0; i < sections.length - 1; i++) {
        const [a, da] = sections[i];
        const [b, db] = sections[i + 1];
        const length = Math.hypot(b - a, db - da);
        const angle = Math.atan2(side * (db - da), b - a);
        const depth = (da + db) / 2;
        part('white', (a + b) / 2, y, side * (17.25 - depth), length + .06, .2, 3.6, 0, angle);
        part('white', (a + b) / 2, y + .22, side * (18.98 - depth), length + .06, .38, .13, 0, angle);
        part('rail', (a + b) / 2, y + 1.15, side * (18.98 - depth), length + .06, .065, .075, 0, angle);
        part('glass', (a + b) / 2, y + .76, side * (18.91 - depth), length + .06, .72, .032, 0, angle);
      }
      for (let x = x0 + 1.6, n = 0; x < x1 - 1; x += 3.12, n++) {
        const selected = ((n * 13 + row * 7) % 11) < 3;
        const depth = setback(x);
        part(selected ? 'litWindow' : 'window', x, y + 1.47, side * (15.47 - depth), 2.75, 2.32, .045);
        part('white', x - 1.5, y + 1.46, side * (17.15 - setback(x - 1.5)), .07, 2.7, 3.16);
        part('rail', x, y + 1.45, side * (15.53 - depth), .06, 2.32, .07);
        part('ivory', x, y + 2.66, side * (15.56 - depth), 2.9, .09, .11);
        part('cushion', x + .64, y + .51, side * (16.64 - depth), .51, .1, .66);
        part('chair', x + .64, y + .81, side * (16.39 - depth), .52, .58, .09);
        part('rail', x - .41, y + .46, side * (16.82 - depth), .29, .055, .29, 0, 0, 0, 'cylinder');
      }
    }
    const stern = -145 + row * 3.25;
    const halfWidth = (35.4 - row * .58) / 2;
    part('white', (stern - 119) / 2, y, (-halfWidth + 10.2) / 2, -119 - stern, .3, halfWidth + 10.2);
    if (halfWidth > 16.2) part('white', (stern - 119) / 2, y, (halfWidth + 16.2) / 2, -119 - stern, .3, halfWidth - 16.2);
    if (stern < -131) part('white', (stern - 131) / 2, y, 13.2, -131 - stern, .3, 6);
    part('white', -120, y, 13.2, 2, .3, 6);
    part('window', stern + .04, y + 1.3, -2.6, .08, 2.3, 24.8);
    part('white', stern, y + .26, (-halfWidth + 10.2) / 2, .12, .42, halfWidth + 10.2);
    part('rail', stern, y + 1.13, (-halfWidth + 10.2) / 2, .065, .065, halfWidth + 10.2);
    for (let z = -15; z <= 10; z += 3.1) part('ivory', stern + 1.05, y + 1.47, z, 2.1, 2.6, .065);
  }

  part('navy', 109, 34.4, 0, 19.5, 5.2, 36.8);
  part('white', 113, 37.16, 0, 29, .45, 40.1);
  part('white', 113, 32.2, 0, 24, .4, 39.2);
  for (const side of [-1, 1]) {
    part('window', 113, 34.92, side * 18.48, 21, 2.23, .08);
    part('white', 117.5, 35.25, side * 21.16, 8.1, 2.8, 5.8);
    part('window', 117.5, 35.78, side * 24.12, 7.8, 1.4, .06);
    part('window', 121.57, 35.78, side * 21.16, .055, 1.4, 5.6);
    part('white', 117.5, 37.03, side * 21.16, 9, .24, 6.25);
    for (let x = 103; x < 123; x += 1.7) part('white', x, 34.9, side * 18.55, .075, 2.32, .09);
  }
  part('window', 122.5, 34.8, 0, .09, 2.5, 35.7);
  for (let z = -16; z <= 16; z += 2.2) part('white', 122.57, 34.8, z, .1, 2.5, .09);

  function stairs(id, deck, x0, x1, z0, z1, y0, y1) {
    surfaces.push({id, deck, x0, x1, z0, z1, y: y0, axis: 'x', y1});
    const steps = Math.ceil(Math.abs(y1 - y0) / .17);
    const dx = (x1 - x0) / steps;
    for (let i = 0; i < steps; i++) {
      const f = (i + .5) / steps;
      const stepY = y0 + (y1 - y0) * f;
      part('shade', x0 + (i + .5) * dx, stepY - .09, (z0 + z1) / 2, dx + .015, .18, z1 - z0);
      part('white', x0 + (i + .5) * dx, stepY + .008, z0 + .05, dx, .025, .09);
      part('white', x0 + (i + .5) * dx, stepY + .008, z1 - .05, dx, .025, .09);
    }
    for (const z of [z0 + .06, z1 - .06]) {
      tube('rail', [x0, y0 + 1.12, z], [x1, y1 + 1.12, z], .045);
      tube('rail', [x0, y0 + .5, z], [x1, y1 + .5, z], .025);
      for (let i = 0; i <= 5; i++) {
        const f = i / 5;
        part('rail', x0 + (x1 - x0) * f, y0 + (y1 - y0) * f + .52, z, .035, 1.04, .035, 0, 0, 0, 'cylinder');
      }
    }
  }

  function stairTower(id, x0, z0) {
    const x1 = x0 + 10;
    const rise = (39.6 - 16) / 8;
    floor(`${id}-entrance`, 7, x0 - 3, x0, z0, z0 + 5.8, 16);
    for (let i = 0; i < 8; i++) {
      const low = 16 + i * rise;
      const high = low + rise;
      const outbound = i % 2 === 0;
      const za = z0 + (outbound ? 0 : 3.05);
      stairs(`${id}-flight-${i + 1}`, i === 7 ? 15 : 7 + i, x0, x1, za, za + 2.75, outbound ? low : high, outbound ? high : low);
      const xa = outbound ? x1 : x0 - 3;
      floor(`${id}-landing-${i + 1}`, i === 7 ? 15 : 8 + i, xa, xa + 3, z0, z0 + 5.8, high);
      rail([xa + (outbound ? 3 : 0), z0], [xa + (outbound ? 3 : 0), z0 + 5.8], high, true);
    }
    for (const x of [x0 - 2.85, x1 + 2.85]) {
      for (const z of [z0 + .08, z0 + 5.72]) part('white', x, 27.85, z, .21, 24, .21);
    }
    sign('EXTERIOR STAIRS', x0 - 2.8, 18.2, z0 + 2.9, -Math.PI / 2, 2.6, .65, 'DECK 15  ·  POOLS & SUN DECKS');
  }
  stairTower('stairs-aft', -131, 10.3);
  stairTower('stairs-forward', 131, -16.1);

  floor('deck15-main', 15, -119, 111, -19.65, 19.65, 39.6);
  floor('deck15-aft-terrace', 15, -142, -119, -18.7, 10.3, 39.6);
  floor('deck15-aft-stair-outer', 15, -142, -119, 16.1, 18.7, 39.6);
  floor('deck15-aft-stair-exit', 15, -142, -131, 10.3, 16.1, 39.6);
  floor('deck15-aft-stair-inner', 15, -121, -119, 10.3, 16.1, 39.6);
  floor('deck15-forward-terrace', 15, 111, 129, -18.7, 18.7, 39.6);
  for (const side of [-1, 1]) {
    rail([-141, side * 18.8], [-119, side * 18.8], 39.6, true);
    rail([-119, side * 19.78], [110, side * 19.78], 39.6, true);
    rail([110, side * 18.8], [129, side * 18.8], 39.6, true);
  }
  rail([-142, -18.8], [-142, 18.8], 39.6, true);
  rail([129, -18.8], [129, 18.8], 39.6, true);

  function pool(x, z, length, width, y) {
    part('white', x, y + .22, z, length + 1.3, .45, width + 1.3);
    part('tile', x, y + .47, z, length + .25, .11, width + .25);
    part('pool', x, y + .54, z, length, .035, width);
    obstacle(x - length / 2 - .55, x + length / 2 + .55, z - width / 2 - .55, z + width / 2 + .55, y, y + .6);
    for (const side of [-1, 1]) {
      tube('rail', [x + length * .34, y + .5, z + side * width / 2], [x + length * .34, y + 1.2, z + side * (width / 2 + .2)], .04);
      tube('rail', [x + length * .34 + .5, y + .5, z + side * width / 2], [x + length * .34 + .5, y + 1.2, z + side * (width / 2 + .2)], .04);
    }
    for (let i = 0; i < 5; i++) part('white', x - length / 2 + (i + .5) * length / 5, y + .56, z, .075, .015, width - .1);
  }
  pool(-16, 0, 29, 7.8, 39.6);
  pool(32, 0, 15, 7, 39.6);
  pool(-131, 0, 8.5, 10, 39.6);
  for (const side of [-1, 1]) {
    for (const x of [-42, 48]) {
      part('white', x, 40.17, side * 9, 2.3, .95, 2.3, 0, 0, 0, 'cylinder');
      part('pool', x, 40.67, side * 9, 1.98, .07, 1.98, 0, 0, 0, 'cylinder');
      obstacle(x - 2.4, x + 2.4, side * 9 - 2.4, side * 9 + 2.4, 39.6, 40.8);
    }
  }

  function lounger(x, z, y, yaw = 0, collide = true) {
    part('chair', x, y + .35, z, .77, .1, 1.95, 0, yaw);
    part('cushion', x, y + .43, z + .04, .66, .075, 1.72, 0, yaw);
    part('chair', x, y + .64, z - .72, .77, .65, .075, -.48, yaw);
    for (const dx of [-.28, .28]) for (const dz of [-.68, .68]) part('rail', x + dx, y + .18, z + dz, .05, .3, .05);
    if (collide) obstacle(x - .45, x + .45, z - 1.05, z + 1.05, y, y + 1.05);
  }
  for (const side of [-1, 1]) {
    for (let x = -52; x < 63; x += 2.35) {
      if (Math.abs(x + 42) < 4 || Math.abs(x - 48) < 4 || x > 50 || x < -50) continue;
      lounger(x, side * 11.9, 39.6, side > 0 ? Math.PI : 0);
      lounger(x, side * 15.1, 39.6, side > 0 ? Math.PI : 0);
    }
    for (let x = -137; x <= -122; x += 2.4) lounger(x, side * 13, 39.6);
  }
  for (let x = -50; x <= 59; x += 21.8) {
    for (const side of [-1, 1]) {
      part('white', x, 41.38, side * 8.2, .065, 3.5, .065, 0, 0, 0, 'cylinder');
      part('ivory', x, 43.06, side * 8.2, 2.1, .45, 2.1, 0, 0, 0, 'dome');
      obstacle(x - .16, x + .16, side * 8.2 - .16, side * 8.2 + .16, 39.6, 43.4);
    }
  }

  part('white', 6, 41.25, 0, 6, 3.3, 11.7);
  part('navy', 2.94, 42.1, 0, .13, 4.1, 10.5);
  const screenTexture = canvasTexture(1024, 512, (ctx, w, h) => {
    const gradient = ctx.createLinearGradient(0, 0, w, h);
    gradient.addColorStop(0, '#173343');
    gradient.addColorStop(1, '#668797');
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, w, h);
    ctx.fillStyle = '#e8e5d4';
    ctx.textAlign = 'center';
    ctx.font = '38px sans-serif';
    ctx.fillText('MSC', w / 2, 140);
    ctx.font = '72px Georgia';
    ctx.fillText('VIRTUOSA', w / 2, 265);
    ctx.font = '22px sans-serif';
    ctx.fillText('THE SEA. THE SKY. NOTHING ELSE.', w / 2, 350);
  });
  const screen = new THREE.Mesh(new THREE.PlaneGeometry(9.7, 4.3), new THREE.MeshStandardMaterial({map: screenTexture, emissiveMap: screenTexture, emissive: 0xffffff, emissiveIntensity: .22, roughness: .6}));
  screen.position.set(2.83, 43.2, 0);
  screen.rotation.y = -Math.PI / 2;
  root.add(screen);
  obstacle(2.5, 9.5, -6, 6, 39.6, 45.5);

  floor('deck16-starboard', 16, -120, 112, 16.7, 20.3, 42.6);
  floor('deck16-port', 16, -120, 112, -20.3, -16.7, 42.6);
  floor('deck16-aft', 16, -125, -63, -20.3, 20.3, 42.6);
  floor('deck16-forward', 16, 68, 123, -20.3, 20.3, 42.6);
  for (const side of [-1, 1]) {
    rail([-124, side * 20.4], [122, side * 20.4], 42.6, true);
    rail([-62, side * 16.64], [67, side * 16.64], 42.6, true);
    for (let x = -116; x < 115; x += 8.4) part('white', x, 41.02, side * 18.74, .25, 2.86, .25);
    stairs(`stairs15-16-${side}`, 16, 52, 66, side > 0 ? 13.2 : -16.7, side > 0 ? 16.7 : -13.2, 39.6, 42.6);
    floor(`stairs15-16-${side}-upper`, 16, 66, 69, side > 0 ? 13.2 : -20.3, side > 0 ? 20.3 : -13.2, 42.6);
    stairs(`stairs15-16-aft-${side}`, 16, -66, -52, side > 0 ? 13.2 : -16.7, side > 0 ? 16.7 : -13.2, 42.6, 39.6);
  }
  rail([-125, -20.3], [-125, 20.3], 42.6, true);
  rail([123, -20.3], [123, 20.3], 42.6, true);

  part('white', 95, 44.66, 0, 45, 4.12, 28.3);
  part('window', 94, 45.23, 14.21, 42.3, 2.45, .08);
  part('window', 94, 45.23, -14.21, 42.3, 2.45, .08);
  obstacle(72.5, 117.5, -14.15, 14.15, 42.6, 47);
  part('white', 95, 46.79, 0, 47.2, .2, 30);
  const roofCurve = [];
  for (let i = 0; i <= 32; i++) {
    const theta = i / 32 * Math.PI;
    roofCurve.push(new THREE.Vector3(0, Math.sin(theta) * 4.1, Math.cos(theta) * 13.2));
  }
  for (let x = 75; x <= 114; x += 4.2) {
    for (let i = 0; i < roofCurve.length - 1; i++) {
      const a = roofCurve[i];
      const b = roofCurve[i + 1];
      tube('white', [x, 46.86 + a.y, a.z], [x, 46.86 + b.y, b.z], .075);
    }
  }
  part('glass', 94, 46.78, 0, 22.2, 4.15, 13.15, 0, 0, 0, 'dome');

  part('sport', -92, 42.65, 0, 34, .1, 21);
  for (const z of [-10.25, 10.25]) part('white', -92, 42.72, z, 33, .012, .09);
  for (const x of [-108.5, -92, -75.5]) part('white', x, 42.72, 0, .09, .012, 20.5);
  for (const side of [-1, 1]) {
    part('rail', -92 + side * 15.4, 44.32, 0, .1, 3.4, .1);
    part('white', -92 + side * 15.05, 45.6, 0, .09, 1.03, 1.68);
    part('orange', -92 + side * 14.45, 45.12, 0, .55, .055, .55, 0, 0, 0, 'cylinder');
    for (let x = -111; x < -72; x += 5) part('rail', x, 45.18, side * 11.25, .045, 5.1, .045, 0, 0, 0, 'cylinder');
    for (let h = 43; h < 47.7; h += .5) tube('shade', [-111, h, side * 11.25], [-72, h, side * 11.25], .009);
    for (let x = -111; x <= -72; x += .5) tube('shade', [x, 42.66, side * 11.25], [x, 47.75, side * 11.25], .009);
  }

  floor('deck18-aft', 18, -128, -70, -17, 17, 48.6);
  floor('deck18-aft-starboard', 18, -128, -85, 17, 20.3, 48.6);
  floor('deck18-aft-port', 18, -128, -85, -20.3, -17, 48.6);
  floor('deck18-forward', 18, 86, 128, -20.3, 20.3, 48.6);
  obstacle(86.5, 116, -13.5, 13.5, 48.6, 51.2);
  for (const side of [-1, 1]) {
    stairs(`stairs16-18-aft-${side}`, 18, -85, -69, side > 0 ? 17 : -20.3, side > 0 ? 20.3 : -17, 48.6, 42.6);
    stairs(`stairs16-18-forward-${side}`, 18, 70, 86, side > 0 ? 17 : -20.3, side > 0 ? 20.3 : -17, 42.6, 48.6);
    rail([-128, side * 20.4], [-86, side * 20.4], 48.6, true);
    rail([87, side * 20.4], [128, side * 20.4], 48.6, true);
    rail([-128, side * 17.05], [-118, side * 17.05], 48.6, true);
  }
  rail([-128, -20.3], [-128, 20.3], 48.6, true);
  rail([128, -20.3], [128, 20.3], 48.6, true);
  floor('deck19-aft', 19, -119, -91, -14.2, 14.2, 51.6);
  floor('deck19-forward', 19, 91, 116, -13.5, 13.5, 51.6);
  stairs('stairs18-19-aft', 19, -108, -98, -17.5, -14.2, 51.6, 48.6);
  floor('deck19-aft-landing', 19, -111, -108, -17.5, -13, 51.6);
  stairs('stairs18-19-forward', 19, 93, 103, 13.5, 16.8, 48.6, 51.6);
  floor('deck19-forward-landing', 19, 103, 106, 12.5, 16.8, 51.6);
  for (const side of [-1, 1]) {
    if (side < 0) {
      rail([-119, side * 14.3], [-111, side * 14.3], 51.6, true);
      rail([-108, side * 14.3], [-91, side * 14.3], 51.6, true);
      rail([91, side * 13.6], [116, side * 13.6], 51.6, true);
    } else {
      rail([-119, side * 14.3], [-91, side * 14.3], 51.6, true);
      rail([91, side * 13.6], [103, side * 13.6], 51.6, true);
      rail([106, side * 13.6], [116, side * 13.6], 51.6, true);
    }
    for (let x = -116; x < -92; x += 2.5) lounger(x, side * 10.9, 51.6);
    for (let x = 93; x < 114; x += 2.5) lounger(x, side * 9.8, 51.6);
  }
  rail([-119, -14.3], [-119, 14.3], 51.6, true);
  rail([-91, -14.3], [-91, 14.3], 51.6, true);
  rail([91, -13.6], [91, 13.6], 51.6, true);
  rail([116, -13.6], [116, 13.6], 51.6, true);

  part('navy', -50, 46.2, 0, 22, 9, 19);
  part('white', -50, 50.9, 0, 24, .45, 21);
  part('navy', -49, 54.65, 0, 18, 7.3, 14.3, 0, 0, -.15);
  part('black', -48.6, 58.1, 0, 18, .6, 14.4, 0, 0, -.15);
  for (const side of [-1, 1]) {
    const funnelTexture = canvasTexture(512, 512, (ctx, w, h) => {
      ctx.fillStyle = '#f1f3ed';
      ctx.translate(w / 2, h / 2);
      for (let i = 0; i < 8; i++) {
        ctx.rotate(Math.PI / 4);
        ctx.beginPath();
        ctx.moveTo(0, -225);
        ctx.lineTo(32, -72);
        ctx.lineTo(0, -107);
        ctx.lineTo(-32, -72);
        ctx.closePath();
        ctx.fill();
      }
      ctx.textAlign = 'center';
      ctx.font = 'bold 92px Georgia';
      ctx.fillText('MSC', 0, 26);
    });
    const emblem = new THREE.Mesh(new THREE.PlaneGeometry(6.1, 6.1), new THREE.MeshStandardMaterial({map: funnelTexture, transparent: true, roughness: .5}));
    emblem.position.set(-49, 54.6, side * 7.28);
    emblem.rotation.y = side > 0 ? 0 : Math.PI;
    root.add(emblem);
  }
  for (let i = 0; i < 4; i++) part('black', -54 + i * 3.2, 58.4, 0, 1.12, 2.3, 1.12, 0, 0, 0, 'cylinder');
  obstacle(-62, -37, -11, 11, 39.6, 60);
  for (const x of [-34, 62]) {
    part('white', x, 44.1, 0, 4.2, 8.7, 4.2, 0, 0, 0, 'cylinder');
    part('white', x, 49, 0, 4.9, 4.9, 4.9, 0, 0, 0, 'sphere');
    obstacle(x - 4.5, x + 4.5, -4.5, 4.5, 39.6, 54);
  }
  part('white', 71, 53.7, 0, .24, 21, .24, 0, 0, 0, 'cylinder');
  tube('white', [66, 59.8, 0], [76, 59.8, 0], .1);
  tube('white', [71, 57, -4.6], [71, 57, 4.6], .08);
  for (const side of [-1, 1]) {
    tube('rail', [64, 47, side * 4], [71, 63.2, 0], .018);
    part('white', 71, 57.3, side * 4.6, .8, .26, 2.6);
  }
  part('navy', 71.7, 63.15, 0, 1.3, .6, .035);

  part('tile', -79, 48.66, 0, 12, .13, 23);
  obstacle(-85, -73, -11.5, 11.5, 48.6, 49);
  for (const [index, material] of ['blueSlide', 'yellowSlide'].entries()) {
    const points = [];
    for (let i = 0; i <= 56; i++) {
      const f = i / 56;
      const angle = f * TAU * 1.5 + index * Math.PI;
      points.push(new THREE.Vector3(-78 + Math.cos(angle) * (3.2 + f * 2.5), 56.2 - f * 6.6, Math.sin(angle) * (5.1 + f * 2.7)));
    }
    const slide = new THREE.Mesh(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(points), 100, .59, 10, false), mat[material]);
    slide.castShadow = slide.receiveShadow = true;
    root.add(slide);
  }
  for (const x of [-82, -75]) for (const z of [-5, 5]) part('white', x, 52.1, z, .15, 7.2, .15, 0, 0, 0, 'cylinder');
  part('white', -77, 56.5, 0, 3, .2, 3.8);
  rail([-78.5, -1.9], [-78.5, 1.9], 56.6);
  part('orange', -80, 53.5, 8, .7, 1.1, .7, 0, 0, .3, 'cylinder');

  for (const x of [-133, -95, -61, -2, 44, 120]) {
    for (const side of [-1, 1]) {
      const z = side * (x < -119 || x > 111 ? 17.3 : 19);
      part('white', x, 41.05, z, .12, 2.9, .12, 0, 0, 0, 'cylinder');
      part('lamp', x, 42.45, z, .26, .5, .26);
      part('navy', x, 42.73, z, .4, .085, .4);
    }
  }
  for (const [x, z] of [[-38, -8], [25, 8]]) {
    const light = new THREE.PointLight(0xffd1a2, 0, 20, 2);
    light.position.set(x, 43.3, z);
    light.userData.nightIntensity = 20;
    root.add(light);
    lamps.push(light);
  }
  for (const [text, x, z, yaw] of [['15  |  POOL DECK', -118, 6, -Math.PI / 2], ['15  |  FORWARD', 111, -6, Math.PI / 2]]) sign(text, x, 41.15, z, yaw, 2.1, .58);

  for (const batch of batches.values()) {
    const mesh = new THREE.InstancedMesh(geometries[batch.shape], mat[batch.material], batch.items.length);
    mesh.name = `ship-${batch.material}-${batch.shape}`;
    for (let i = 0; i < batch.items.length; i++) {
      const [x, y, z, sx, sy, sz, rx, ry, rz] = batch.items[i];
      transform.position.set(x, y, z);
      transform.rotation.set(rx, ry, rz);
      transform.scale.set(sx, sy, sz);
      transform.updateMatrix();
      mesh.setMatrixAt(i, transform.matrix);
    }
    mesh.castShadow = !['glass', 'lamp', 'window', 'litWindow', 'pool'].includes(batch.material);
    mesh.receiveShadow = batch.material !== 'glass';
    mesh.computeBoundingBox();
    mesh.computeBoundingSphere();
    root.add(mesh);
  }

  const ramps = surfaces.filter(surface => surface.axis);
  for (const ramp of ramps) {
    const base = Math.min(ramp.y, ramp.y1);
    for (let i = surfaces.length - 1; i >= 0; i--) {
      const s = surfaces[i];
      if (s.axis || Math.abs(s.y - base) > .03 || s.x1 <= ramp.x0 || s.x0 >= ramp.x1 || s.z1 <= ramp.z0 || s.z0 >= ramp.z1) continue;
      const x0 = Math.max(s.x0, ramp.x0);
      const x1 = Math.min(s.x1, ramp.x1);
      const z0 = Math.max(s.z0, ramp.z0);
      const z1 = Math.min(s.z1, ramp.z1);
      surfaces.splice(i, 1);
      const sections = [[s.x0, x0, s.z0, s.z1], [x1, s.x1, s.z0, s.z1], [x0, x1, s.z0, z0], [x0, x1, z1, s.z1]];
      for (let n = 0; n < sections.length; n++) {
        const [a, b, c, d] = sections[n];
        if (b - a > .04 && d - c > .04) surfaces.push({...s, id: `${s.id}-cut${n}`, x0: a, x1: b, z0: c, z1: d});
      }
    }
  }
  for (const surface of surfaces) {
    surface.x0 -= .04;
    surface.x1 += .04;
    surface.z0 -= .04;
    surface.z1 += .04;
  }

  const spots = [
    {id: 'deck7-starboard', label: 'Deck 7 · Lifeboat promenade', deck: 7, x: -58, y: 16, z: 18.1, yaw: 0, pitch: .12},
    {id: 'deck7-port', label: 'Deck 7 · Port promenade', deck: 7, x: 43, y: 16, z: -18.1, yaw: 0, pitch: .06},
    {id: 'pool', label: 'Deck 15 · Atmosphere pool', deck: 15, x: -33, y: 39.6, z: 6.2, yaw: 0, pitch: -.08},
    {id: 'aft', label: 'Deck 15 · Aft sea terrace', deck: 15, x: -139, y: 39.6, z: 14.9, yaw: Math.PI / 2, pitch: -.06},
    {id: 'bow', label: 'Deck 18 · Forward lookout', deck: 18, x: 125, y: 48.6, z: 8, yaw: -Math.PI / 2, pitch: -.12},
    {id: 'top', label: 'Deck 19 · Upper sun deck', deck: 19, x: -113, y: 51.6, z: 5.5, yaw: -Math.PI / 2, pitch: -.1},
    {id: 'sports', label: 'Deck 16 · Sports court', deck: 16, x: -114, y: 42.6, z: -7, yaw: -Math.PI / 2, pitch: -.03},
    {id: 'stairs-aft-bottom', label: 'Deck 7 · Aft exterior stairs', deck: 7, x: -132.5, y: 16, z: 11.6, yaw: -Math.PI / 2, pitch: .15},
    {id: 'stairs-aft-top', label: 'Deck 15 · Aft stair landing', deck: 15, x: -132.5, y: 39.6, z: 14.6, yaw: -Math.PI / 2, pitch: 0},
  ];

  let previousNight = -1;
  let previousWet = -1;
  function setNight(value) {
    const n = THREE.MathUtils.clamp(value, 0, 1);
    if (Math.abs(n - previousNight) < .002) return;
    previousNight = n;
    mat.litWindow.emissiveIntensity = n * 1.55;
    mat.lamp.emissiveIntensity = .15 + n * 3.1;
    for (const lamp of lamps) lamp.intensity = n * lamp.userData.nightIntensity;
  }
  function setWet(value) {
    const n = THREE.MathUtils.clamp(value, 0, 1);
    if (Math.abs(n - previousWet) < .005) return;
    previousWet = n;
    mat.deck.roughness = .79 - n * .52;
    mat.deck.color.setRGB(1 - n * .2, .88 - n * .19, .7 - n * .17, THREE.SRGBColorSpace);
    mat.white.roughness = .55 - n * .21;
    mat.wood.roughness = .64 - n * .37;
  }
  setNight(0);
  setWet(0);
  root.updateMatrixWorld(true);
  return {root, surfaces, obstacles, spots, lamps, setNight, setWet};
}
