// Local-only camera bridge. No video or landmarks are transmitted externally.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const dgram = require('node:dgram');
const HOST = '127.0.0.1', PORT = 19751;
const root = __dirname;
const udp = dgram.createSocket('udp4');
let lastAck = 0, lastRequest = Date.now();
udp.on('message', (data, peer) => {
  if (peer.address === HOST && peer.port === 19750 && data.toString() === 'HELIOS_ACK') lastAck = Date.now();
});
udp.on('error', error => console.error(error.message));
const mime = {'.html':'text/html; charset=utf-8','.mjs':'text/javascript','.js':'text/javascript','.wasm':'application/wasm','.task':'application/octet-stream'};
const server = http.createServer((req, res) => {
  lastRequest = Date.now();
  const origin = req.headers.origin;
  if (req.headers.host !== `${HOST}:${PORT}` || (origin && origin !== `http://${HOST}:${PORT}`)) {
    res.writeHead(403); return res.end('Local requests only');
  }
  const route = new URL(req.url, `http://${HOST}:${PORT}`).pathname;
  if (route === '/gesture' && req.method === 'POST') {
    let body = '', oversized = false;
    req.on('data', chunk => {
      body += chunk;
      if (body.length > 4096) { oversized = true; req.destroy(); }
    });
    req.on('end', () => {
      if (oversized) return;
      try {
        const source = JSON.parse(body);
        const unit = value => Math.max(0, Math.min(1, Number(value) || 0));
        const packet = {hands: Math.max(0, Math.min(2, Number(source.hands) || 0)),
          x: unit(source.x), y: unit(source.y), pinch: source.pinch === true,
          open: source.open === true, thrust: unit(source.thrust),
          protocol: 2, x2: unit(source.x2), y2: unit(source.y2),
          view: source.view === true, salvo: source.salvo === true, wave: source.wave === true, cancel: source.cancel === true,
          spread: unit(source.spread), angle: Math.max(-Math.PI,Math.min(Math.PI,Number(source.angle)||0)),
          quality: unit(source.quality), seq: Math.max(0,Number(source.seq)||0),
          status: String(source.status || '摄像头已连接').slice(0, 100)};
        udp.send(Buffer.from(JSON.stringify(packet)), 19750, HOST);
        res.writeHead(200, {'Content-Type':'application/json'});
        res.end(JSON.stringify({gameConnected: Date.now() - lastAck < 3000}));
      } catch { res.writeHead(400); res.end('Invalid gesture'); }
    });
    return;
  }
  if (route === '/status') {
    res.writeHead(200, {'Content-Type':'application/json', 'Cache-Control':'no-store'});
    return res.end(JSON.stringify({gameConnected: Date.now() - lastAck < 3000, localOnly: true, version: 2}));
  }
  const relative = route === '/' ? 'index.html' : route.slice(1);
  if (!/^(index\.html|tracker\.mjs|gestures\.mjs|vision_bundle\.mjs|hand_landmarker\.task|wasm\/vision_wasm_(nosimd_)?internal\.(js|wasm))$/.test(relative)) {
    res.writeHead(404); return res.end('Not found');
  }
  const file = path.join(root, relative);
  fs.stat(file, (error, stat) => {
    if (error || !stat.isFile()) { res.writeHead(404); return res.end('Missing local asset'); }
    res.writeHead(200, {'Content-Type':mime[path.extname(file)] || 'application/octet-stream',
      'Content-Length':stat.size, 'Cache-Control':'no-cache', 'X-Content-Type-Options':'nosniff',
      'Content-Security-Policy':"default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; connect-src 'self'; worker-src 'self' blob:; img-src 'self' blob: data:; media-src 'self' blob:; object-src 'none'; frame-ancestors 'none'"});
    fs.createReadStream(file).pipe(res);
  });
});
server.on('error', error => {
  if (error.code !== 'EADDRINUSE') console.error(error.message);
  udp.close(); process.exit(error.code === 'EADDRINUSE' ? 0 : 1);
});
server.listen(PORT, HOST, () => console.log(`HELIOS camera bridge: http://${HOST}:${PORT}`));
setInterval(() => {
  if (Date.now() - lastRequest > 180000) { server.close(); udp.close(); process.exit(0); }
}, 15000).unref();
