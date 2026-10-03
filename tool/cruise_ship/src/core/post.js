import * as THREE from 'three/webgpu';
import {
  pass, mrt, output, velocity, normalView, Fn, vec3, vec4, float,
  uniform, mix, uv, length, smoothstep, screenCoordinate, frameId, fract, sin, dot, vec2, renderOutput,
  luminance, max, saturate, pow,
} from 'three/tsl';
import { traa } from 'three/addons/tsl/display/TRAANode.js';
import { ao } from 'three/addons/tsl/display/GTAONode.js';
import { bloom } from 'three/addons/tsl/display/BloomNode.js';
import { denoise } from 'three/addons/tsl/display/DenoiseNode.js';

// Post stack: scene pass (MRT colour/normal/velocity) -> TRAA -> denoised
// GTAO -> exposure -> bloom -> AgX tone map -> vignette and film grain.
// Exposure is applied before bloom so lamps at night bloom the way the eye
// expects.

export const postU = {
  exposure: uniform(1.0),
  aoStrength: uniform(0.75),
  bloomStrength: uniform(0.16),
  vignette: uniform(0.22),
  grain: uniform(0.018),
  flash: uniform(0.0),
};

export class Post {
  constructor(renderer, scene, camera) {
    this.renderer = renderer;
    this.scene = scene;
    this.camera = camera;
    this.pipeline = null;
    this.opts = null;
  }

  build(opts) {
    const key = JSON.stringify(opts);
    if (key === this._key) return;
    this._key = key;
    if (this.pipeline) this.pipeline.dispose?.();
    const { renderer, scene, camera } = this;
    const pipeline = new THREE.RenderPipeline(renderer);
    pipeline.outputColorTransform = false;

    const scenePass = pass(scene, camera);
    const outs = { output };
    if (opts.taa) outs.velocity = velocity;
    if (opts.ao) outs.normal = vec4(normalView, 1.0);
    scenePass.setMRT(mrt(outs));


    let color = scenePass.getTextureNode('output');
    const depth = scenePass.getTextureNode('depth');

    // TRAA resolves the raw HDR pass directly (it needs a real texture, not
    // a composite), then AO and exposure are applied to the stable result.
    if (opts.taa) {
      color = traa(color, depth, scenePass.getTextureNode('velocity'), camera);
    }

    if (opts.ao) {
      const n = scenePass.getTextureNode('normal');
      const aoNode = ao(depth, n, camera);
      aoNode.resolutionScale = 0.5;
      aoNode.radius.value = 0.9;
      aoNode.thickness.value = 1.2;
      aoNode.distanceExponent.value = 1.4;
      aoNode.scale.value = 1.1;
      aoNode.samples.value = 16;
      this.aoNode = aoNode;
      // Edge-aware denoise so the half-resolution AO doesn't crawl.
      const aoClean = denoise(aoNode.getTextureNode(), depth, n, camera);
      color = color.mul(vec4(vec3(mix(float(1.0), aoClean.r, postU.aoStrength)), 1.0));
    }

    color = color.mul(vec4(vec3(postU.exposure.mul(postU.flash.add(1.0))), 1.0));
    if (opts.bloom) {
      const b = bloom(color, 0.16, 0.55, 0.92);
      b.strength = postU.bloomStrength;
      color = color.add(b);
    }

    const graded = Fn(() => {
      const mapped = renderOutput(color, THREE.AgXToneMapping, THREE.SRGBColorSpace).toVar();
      const q = uv().sub(0.5);
      const v = float(1.0).sub(smoothstep(0.35, 0.95, length(q.mul(vec2(1.0, 0.85)))).mul(postU.vignette));
      const g = fract(sin(dot(screenCoordinate.xy.add(float(frameId).mul(13.37)), vec2(12.9898, 78.233))).mul(43758.5453)).sub(0.5);
      return vec4(mapped.rgb.mul(v).add(g.mul(postU.grain)), 1.0);
    })();

    pipeline.outputNode = graded;
    pipeline.needsUpdate = true;
    this.pipeline = pipeline;
    this.scenePass = scenePass;
  }

  render() { this.pipeline.render(); }
}
