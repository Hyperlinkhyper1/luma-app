import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { benchmarkSceneFile } from '../tool/benchmark_scene_file.mjs';

function fixture(t) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'luma-scene-selection-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const root = path.join(directory, 'seed');
  const override = path.join(directory, 'data');
  const id = 'pagoda_demo';
  function write(relative, text, seconds) {
    const file = path.join(directory, relative);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, text);
    fs.utimesSync(file, seconds, seconds);
    return file;
  }
  return { write, select: (ext = 'html') => benchmarkSceneFile({ root, override, id, ext }) };
}

test('deployed repair supersedes an older dashboard upload', t => {
  const f = fixture(t);
  f.write('data/uploads/pagoda_demo.html', 'old broken upload', 1000);
  const repaired = f.write('seed/scenes/pagoda_demo.html', 'repaired scene', 2000);
  assert.equal(f.select(), repaired);
});

test('an upload newer than the seed remains active', t => {
  const f = fixture(t);
  f.write('seed/scenes/pagoda_demo.html', 'old seed', 1000);
  const uploaded = f.write('data/uploads/pagoda_demo.html', 'new upload', 2000);
  assert.equal(f.select(), uploaded);
});

test('equal timestamps prefer the seed as the serving store does', t => {
  const f = fixture(t);
  f.write('data/uploads/pagoda_demo.html', 'upload', 1000);
  const seed = f.write('seed/scenes/pagoda_demo.html', 'seed', 1000);
  assert.equal(f.select(), seed);
});

test('hand-dropped overrides retain priority regardless of age', t => {
  const f = fixture(t);
  const direct = f.write('data/pagoda_demo.html', 'operator override', 1000);
  f.write('data/uploads/pagoda_demo.html', 'upload', 2000);
  f.write('seed/scenes/pagoda_demo.html', 'seed', 3000);
  assert.equal(f.select(), direct);
});

test('directory scenes use the same upload freshness rules', t => {
  const f = fixture(t);
  f.write('data/uploads/pagoda_demo.html', 'old upload', 1000);
  const seed = f.write('seed/scenes/pagoda_demo/index.html', 'repaired directory scene', 2000);
  assert.equal(f.select(), seed);
});

test('a direct directory override takes priority', t => {
  const f = fixture(t);
  const direct = f.write('data/pagoda_demo/index.html', 'direct directory scene', 1000);
  f.write('data/uploads/pagoda_demo.html', 'upload', 2000);
  assert.equal(f.select(), direct);
});

test('an upload with no seed and a missing scene are handled', t => {
  const f = fixture(t);
  assert.equal(f.select(), null);
  const uploaded = f.write('data/uploads/pagoda_demo.html', 'new scene', 1000);
  assert.equal(f.select(), uploaded);
});

test('binary scenes also prefer a newer seed', t => {
  const f = fixture(t);
  f.write('data/uploads/pagoda_demo.glb', 'old binary', 1000);
  const seed = f.write('seed/scenes/pagoda_demo.glb', 'repaired binary', 2000);
  assert.equal(f.select('glb'), seed);
});
