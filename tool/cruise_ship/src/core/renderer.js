import * as THREE from 'three/webgpu';

/**
 * WebGPU when the browser has it (Edge/Chrome and luma's WebView2 do),
 * WebGL2 otherwise. `?webgl` in the URL forces the fallback for testing.
 */
export async function createRenderer(canvas) {
  const params = new URLSearchParams(location.search);
  const forceWebGL = params.has('webgl') || !('gpu' in navigator);
  const renderer = new THREE.WebGPURenderer({
    canvas,
    antialias: false,              // TRAA handles it
    forceWebGL,
    reversedDepthBuffer: true,     // 5 cm to 40 km without z-fighting
    powerPreference: 'high-performance',
    trackTimestamp: params.has('gputime'),   // dev: GPU timings via timestamp queries
  });
  await renderer.init();
  renderer.toneMapping = THREE.AgXToneMapping;
  renderer.toneMappingExposure = 1.0;
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFShadowMap;
  renderer.setClearColor(0x000000, 1);
  const backend = renderer.backend?.isWebGPUBackend ? 'WebGPU' : 'WebGL 2';
  return { renderer, backend };
}
