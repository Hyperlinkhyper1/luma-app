import http from 'node:http';
import { readFile } from 'node:fs/promises';
const file = new URL('../../server/benchmarks/scenes/cruise_ship_gpt6_astra_ultra/index.html', import.meta.url);
const server = http.createServer(async (req, res) => {
  if (req.url === '/favicon.ico') { res.writeHead(204).end(); return; }
  try { res.setHeader('Content-Type', 'text/html; charset=utf-8'); res.end(await readFile(file)); }
  catch (error) { res.writeHead(500).end(String(error)); }
});
server.listen(5187, '127.0.0.1', () => console.log('Astra cruise preview: http://127.0.0.1:5187'));
