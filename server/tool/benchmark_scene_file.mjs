import fs from 'node:fs';
import path from 'node:path';

export function benchmarkSceneFile({ root, override, id, ext }) {
  const direct = [
    override && path.join(override, `${id}.${ext}`),
    override && ext === 'html' && path.join(override, id, 'index.html'),
  ].filter(Boolean).find(file => fs.existsSync(file));
  if (direct) return direct;
  const seed = [
    path.join(root, 'scenes', `${id}.${ext}`),
    ext === 'html' && path.join(root, 'scenes', id, 'index.html'),
  ].filter(Boolean).find(file => fs.existsSync(file));
  const upload = override && path.join(override, 'uploads', `${id}.${ext}`);
  if (upload && fs.existsSync(upload) &&
      (!seed || fs.statSync(upload).mtimeMs > fs.statSync(seed).mtimeMs)) return upload;
  return seed ?? null;
}
