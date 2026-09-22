const http = require('http'), fs = require('fs'), path = require('path');
const root = process.cwd(), dir = path.join(root, 'assets/asset_studio');
const out = path.join(dir, 'thumbs');
fs.mkdirSync(out, {recursive: true});
const read = (p) => fs.readFileSync(p, 'utf8');
const js = (s) => s.replace(/<\/script/gi, '<\/script');
const catalog = JSON.parse(read(path.join(dir, 'catalog.json')));
const scripts = [
  `<script>${js(read(path.join(root, 'assets/airline_tycoon/scene/vendor/three-0.160.1.min.js')))}</script>`,
  ...catalog.map((a) => `<script type="text/plain" data-model="${a.id}">\n${js(read(path.join(dir, 'models', a.functionName + '.js')))}\n</script>`),
  `<script>window.STUDIO = ${JSON.stringify({catalog}).replace(/<\//g, '<\/')};</script>`,
].join('\n');
const page = read(path.join(__dirname, 'bake_thumbnails.html')).replace('<!-- @scripts -->', () => scripts);
let written = 0;
http.createServer((q, s) => {
  if (q.method === 'POST' && q.url === '/write') {
    let body = '';
    q.on('data', (c) => body += c);
    q.on('end', () => {
      const {id, dataUrl} = JSON.parse(body);
      fs.writeFileSync(path.join(out, `${id}.png`), Buffer.from(dataUrl.split(',')[1], 'base64'));
      written++;
      console.log(`wrote ${id}.png (${written})`);
      s.writeHead(200); s.end('ok');
    });
    return;
  }
  s.writeHead(200, {'Content-Type': 'text/html', 'Cache-Control': 'no-store'});
  s.end(page);
}).listen(8129, () => console.log('thumbnail bake on 8129'));
