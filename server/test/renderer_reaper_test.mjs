import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { descendants, processTable, reapOrphans } from '../tool/renderer_service.mjs';

test('reads parent pids from /proc, even with spaces and parens in comm', async () => {
  const proc = await fs.mkdtemp(path.join(os.tmpdir(), 'luma_proc_'));
  try {
    const entries = { 1: '1 (docker-init) S 0 1 1', 7: '7 (node) S 1 7 7', 40: '40 (chromium) S 1 40 40', 41: '41 (Chrome (gpu) x) S 40 40 40' };
    for (const [pid, stat] of Object.entries(entries)) {
      await fs.mkdir(path.join(proc, pid));
      await fs.writeFile(path.join(proc, pid, 'stat'), stat);
    }
    await fs.mkdir(path.join(proc, 'self'));
    assert.deepEqual([...processTable(proc)].sort((a, b) => a[0] - b[0]), [[1, 0], [7, 1], [40, 1], [41, 40]]);
  } finally {
    await fs.rm(proc, { recursive: true, force: true });
  }
});

test('walks the whole tree under a process', () => {
  const table = new Map([[7, 1], [20, 7], [30, 20], [31, 30], [32, 30], [50, 1]]);
  assert.deepEqual(descendants(table, 20).sort(), [30, 31, 32]);
  assert.deepEqual(descendants(table, 50), []);
});

test('reaps only what hangs off init, never the service itself', () => {
  // 7 is the service with a live render under it; 40 is a leaked browser.
  const table = new Map([[7, 1], [20, 7], [21, 20], [40, 1], [41, 40], [42, 41]]);
  const killed = [];
  const kill = process.kill;
  process.kill = (pid) => { killed.push(pid); };
  try {
    assert.deepEqual(reapOrphans({ table, self: 7 }), [40]);
  } finally {
    process.kill = kill;
  }
  assert.deepEqual(killed, [42, 41, 40]);
});
