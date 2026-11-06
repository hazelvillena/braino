import http from 'node:http';
import {readFile} from 'node:fs/promises';
const routes = new Map([['/', new URL('./index.html', import.meta.url)], ['/icon.png', new URL('../Assets/BrainoIcon.png', import.meta.url)], ...['styles.css','app.mjs','model.mjs'].map(name=>['/'+name,new URL('./'+name,import.meta.url)])]);
const server = http.createServer(async (req, res) => {
  const route = routes.get(new URL(req.url, 'http://localhost').pathname);
  if (!route) { res.writeHead(404); res.end('Not found'); return; }
  try { const content = await readFile(route); res.writeHead(200, {'Content-Type': route.pathname.endsWith('.png') ? 'image/png' : route.pathname.endsWith('.css') ? 'text/css; charset=utf-8' : route.pathname.endsWith('.mjs') ? 'text/javascript; charset=utf-8' : 'text/html; charset=utf-8', 'Cache-Control':'no-store', 'X-Content-Type-Options':'nosniff'}); res.end(content); }
  catch { res.writeHead(500); res.end('Preview file unavailable'); }
});
server.listen(4317, '127.0.0.1', () => console.log('Braino preview: http://localhost:4317'));
server.on('error', error => { console.error(error.message); process.exit(1); });
