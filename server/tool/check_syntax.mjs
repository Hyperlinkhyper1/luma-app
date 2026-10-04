import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

// Finds the first syntax error in a scene's inline scripts and says where it
// is in the HTML file, without a browser:
//
//   node check_syntax.mjs <scene.html>
//
// Prints one JSON line: {"ok":true}, or {"ok":false,"line":N,"column":N,
// "message":"..."} with the line counted in the HTML file itself. Scripts are
// only parsed (`node --check`), never run, so a bare `import ... from 'three'`
// is fine here. The renderer's own error for a syntax mistake is a bare
// "Unexpected token '.'" with no position, which is no use to anyone fixing
// a 60 kB page; the repair flow asks this for the position instead.

const file = process.argv[2];
if (!file) {
  console.log(JSON.stringify({ ok: true }));
  process.exit(0);
}

const html = fs.readFileSync(file, 'utf8');
const scripts = /<script([^>]*)>([\s\S]*?)<\/script>/gi;
const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'luma_syntax_'));
let problem = null;
try {
  let found;
  let n = 0;
  while (!problem && (found = scripts.exec(html))) {
    const attrs = found[1];
    const code = found[2];
    if (/\bsrc\s*=/.test(attrs) || !code.trim()) continue;
    const type = /\btype\s*=\s*["']?([^"'\s>]+)/i.exec(attrs)?.[1]?.toLowerCase() ?? '';
    if (type && type !== 'module' && type !== 'text/javascript' && type !== 'application/javascript') continue;
    const codeStart = found.index + found[0].indexOf('>') + 1;
    const firstLine = html.slice(0, codeStart).split('\n').length;
    const tmp = path.join(tmpDir, `s${n++}.${type === 'module' ? 'mjs' : 'js'}`);
    fs.writeFileSync(tmp, code);
    try {
      execFileSync(process.execPath, ['--check', tmp], { stdio: 'pipe' });
    } catch (e) {
      const lines = String(e.stderr).split(/\r?\n/);
      const where = /:(\d+)\s*$/.exec(lines[0] ?? '');
      const caret = lines.findIndex((l) => /^\s*\^+\s*$/.test(l));
      const message = (lines.find((l) => /^\w*Error:/.test(l)) ?? 'SyntaxError').replace(/^SyntaxError:\s*/, '');
      const scriptLine = where ? Number(where[1]) : 1;
      problem = {
        ok: false,
        line: firstLine + scriptLine - 1,
        column: caret >= 0 ? lines[caret].indexOf('^') + 1 : 1,
        message,
      };
    }
  }
} finally {
  fs.rmSync(tmpDir, { recursive: true, force: true });
}
console.log(JSON.stringify(problem ?? { ok: true }));
