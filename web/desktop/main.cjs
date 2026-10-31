const { app, BrowserWindow, ipcMain, Tray, Menu, nativeImage, screen, session, Notification, powerMonitor, shell, globalShortcut } = require('electron');
const path = require('node:path');
const http = require('node:http');
const fs = require('node:fs');
const { execFileSync } = require('node:child_process');
const { createCoffeeGateway } = require('./coffee.cjs');
const { startCoffeeDemo } = require('./coffee-demo.cjs');
const { createLuckinGateway } = require('./luckin.cjs');
const { createShansongDelivery } = require('./shansong.cjs');
const { locate } = require('./location.cjs');
const { createCompanion } = require('./companion.cjs');
const { createTts } = require('./tts.cjs');
const { createLocalTts } = require('./local-tts.cjs');
const { createOverlays } = require('./overlays.cjs');
const brightness = require('./screen-brightness.cjs').createBrightnessController();
let panel, pet, island, overlays, monitor, tray, server, origin, coffeeDemo, companion, quitting = false;
let snapshot = { running: false, status: 'starting', source: '正在启动后台感知', focus: null, fatigue: null, state: 'normal' };
let buildTrayMenu = () => {};
let selectedPet = 'hiyori', offeredAt = 0, suspended = false, notifications = false;
let coffee = createCoffeeGateway({ baseUrl: process.env.NEURODESK_COFFEE_API, token: process.env.NEURODESK_COFFEE_TOKEN });
// Config lives in web/.runtime for both dev and the packaged build. When packaged, the exe sits in
// release/win-unpacked, so walk up to the web folder instead of using the exe's own directory —
// otherwise a packaged build silently loses the saved Luckin token and DeepSeek key.
const runtimeRoot = path.join(app.isPackaged ? path.resolve(path.dirname(process.execPath), '..', '..') : path.resolve(__dirname, '..'), '.runtime');
// Local neural TTS is the primary voice engine: it needs no network and answers in a fraction
// of a second, where edge-tts waits on a round trip to Microsoft and can fail outright when the
// network hiccups during a live demo.
const localTts = createLocalTts({
  // The voice model lives outside the asar: the Python service reads it from disk.
  // In a packaged build extraResources puts it at resources/voices/piper.
  piperDir: process.env.NEURODESK_PIPER_DIR
    || (app.isPackaged
      ? path.join(process.resourcesPath || path.join(path.dirname(process.execPath), 'resources'), 'voices', 'piper')
      : (fs.existsSync(path.join(runtimeRoot, 'piper', 'tokens.txt')) ? path.join(runtimeRoot, 'piper') : path.resolve(__dirname, '../voices/piper'))),
  kokoroDir: process.env.NEURODESK_KOKORO_DIR || path.join(runtimeRoot, 'kokoro'),
  engine: process.env.NEURODESK_TTS_ENGINE || 'piper',
  port: Number(process.env.NEURODESK_TTS_PORT) || 18090,
  python: process.env.NEURODESK_TTS_PYTHON || process.env.PYTHON || 'python',
  provider: process.env.NEURODESK_TTS_PROVIDER || 'cpu',
  logFile: path.join(runtimeRoot, 'tts-service.log'),
});
const tts = createTts({
  cacheDir: path.join(runtimeRoot, 'tts-cache'),
  voice: process.env.NEURODESK_TTS_VOICE || 'zh-CN-XiaoxiaoNeural',
  rate: process.env.NEURODESK_TTS_RATE || '+0%',
  enabled: process.env.NEURODESK_TTS !== '0',
  local: localTts,
});
let luckinToken = process.env.NEURODESK_LUCKIN_TOKEN || '';
if (process.env.NEURODESK_TEST !== '1' || process.env.NEURODESK_COFFEE_PROVIDER === 'luckin') {
  const configPath = process.env.NEURODESK_LUCKIN_CONFIG || path.join(runtimeRoot, 'luckin-config.json');
  if (!luckinToken && fs.existsSync(configPath)) luckinToken = JSON.parse(fs.readFileSync(configPath, 'utf8')).token || '';
}
// An explicit merchant adapter (e.g. the Bailu gateway) always wins over the stored Luckin token,
// so a saved token can never silently hijack a merchant-adapter demo.
const useLuckin = process.env.NEURODESK_COFFEE_PROVIDER === 'luckin'
  || (!process.env.NEURODESK_COFFEE_PROVIDER && !process.env.NEURODESK_COFFEE_API && process.env.NEURODESK_TEST !== '1' && Boolean(luckinToken));
let shansongConfig = {};
const shansongConfigPath = process.env.NEURODESK_SHANSONG_CONFIG || path.join(runtimeRoot, 'shansong-config.json');
if (useLuckin && (process.env.NEURODESK_TEST !== '1' || process.env.NEURODESK_SHANSONG_CONFIG) && fs.existsSync(shansongConfigPath)) {
  shansongConfig = JSON.parse(fs.readFileSync(shansongConfigPath, 'utf8'));
}
const delivery = useLuckin ? createShansongDelivery({ config: shansongConfig, journalPath: process.env.NEURODESK_SHANSONG_ORDERS || path.join(runtimeRoot, 'shansong-orders.json') }) : null;
const luckin = useLuckin ? createLuckinGateway({ token: luckinToken, delivery, journalPath: process.env.NEURODESK_LUCKIN_ORDERS || path.join(runtimeRoot, 'luckin-orders.json') }) : null;
const useCoffeeDemo = !useLuckin && process.env.NEURODESK_COFFEE_DEMO !== '0' && !process.env.NEURODESK_COFFEE_API;
const parkLocation = process.env.NEURODESK_COFFEE_LOCATION === 'bailu'
  ? { latitude: 30.58, longitude: 104.12 } : null;
const broadcast = (channel, value) => [panel, pet, island].forEach((w) => { if (w && !w.isDestroyed()) w.webContents.send(channel, value); });
function openPanel(coffeeOffer = false) {
  panel.show(); panel.focus();
  if (coffeeOffer) panel.webContents.send('offer-coffee');
}
function command(value) { monitor.webContents.send('monitor-command', value); }
function secureWindow(options) {
  const w = new BrowserWindow({ ...options, webPreferences: { preload: path.join(__dirname, 'preload.cjs'), contextIsolation: true, nodeIntegration: false, sandbox: true, backgroundThrottling: false } });
  w.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
  w.webContents.on('will-navigate', (e, url) => { if (!url.startsWith(`${origin}/`)) e.preventDefault(); });
  return w;
}
async function serve() {
  const root = path.resolve(__dirname, '../dist');
  const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.wasm': 'application/wasm', '.task': 'application/octet-stream', '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp' };
  server = http.createServer((req, res) => {
    try {
      if (!['GET', 'HEAD'].includes(req.method)) { res.writeHead(405).end(); return; }
      const url = new URL(req.url, 'http://localhost');
      const pathname = decodeURIComponent(url.pathname);
      // Synthesized speech is served from the local origin so an <audio> element can stream it
      // under the existing media-src CSP. Ids are opaque hashes; the cache path never leaves main.
      if (pathname === '/tts') {
        const entry = tts.file(url.searchParams.get('id'));
        if (!entry) { res.writeHead(404).end('Not found'); return; }
        const audio = fs.readFileSync(entry.file);
        res.writeHead(200, { 'Content-Type': entry.mime || 'audio/mpeg', 'Cache-Control': 'private, max-age=3600', 'Content-Length': audio.length });
        res.end(req.method === 'HEAD' ? undefined : audio);
        return;
      }
      const file = path.resolve(root, `.${pathname === '/' ? '/index.html' : pathname}`);
      if (!file.startsWith(`${root}${path.sep}`)) { res.writeHead(403).end(); return; }
      const data = fs.readFileSync(file);
      res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff', 'Content-Security-Policy': "default-src 'self' data: blob:; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob: https://*.lkcoffee.com https://*.luckincoffeecdn.com; connect-src 'self' ws: wss:; media-src 'self' blob:" });
      res.end(req.method === 'HEAD' ? undefined : data);
    } catch { res.writeHead(404).end('Not found'); }
  });
  // Stable origin keeps pet uploads and preferences across launches; never expose to the LAN.
  // Tests (or a second instance) may override the port, and an occupied port falls back to a
  // free one instead of aborting startup, so two launches cannot deadlock on a hard-coded port.
  const preferredPort = Number(process.env.NEURODESK_PORT) || 17863;
  const listen = (port) => new Promise((resolve, reject) => {
    const onError = (error) => { server.removeListener('listening', onListening); reject(error); };
    const onListening = () => { server.removeListener('error', onError); resolve(server.address().port); };
    server.once('error', onError);
    server.once('listening', onListening);
    server.listen(port, '127.0.0.1');
  });
  let port;
  try {
    port = await listen(preferredPort);
  } catch (error) {
    if (error.code !== 'EADDRINUSE') throw error;
    port = await listen(0);
  }
  origin = `http://127.0.0.1:${port}`;
}
function handle(channel, allowed, fn) {
  ipcMain.handle(channel, (event, ...args) => {
    if (!allowed().some((w) => w?.webContents === event.sender)) throw new Error('无权执行此操作');
    return fn(...args);
  });
}
// The single-instance lock and the Windows tray icon both live in the userData folder and need
// to create, replace and delete files there. Managed environments sometimes mark a directory with
// an Everyone:(DENY)(DC) ACE, which makes those operations fail: Chromium then reports
// "Lock file can not be created! Error code: 5" and exits, and the tray icon is never shown.
// Probe the default location first and only fall back when it cannot host the lock.
function canHostLock(dir) {
  try {
    fs.mkdirSync(dir, { recursive: true });
    const probe = path.join(dir, `.nd-lock-probe-${process.pid}`);
    fs.writeFileSync(probe, 'x');
    // Chromium replaces the lock file, so deleting must work too.
    fs.rmSync(probe, { force: true });
    fs.rmSync(probe, { force: true });
    return true;
  } catch { return false; }
}
// A directory can accept new files yet still refuse the delete/rename that Chromium's
// single-instance lock and the shell's tray registration need. Probe for that explicitly.
function canReplaceFiles(dir) {
  try {
    fs.mkdirSync(dir, { recursive: true });
    const a = path.join(dir, `.nd-replace-a-${process.pid}`);
    const b = path.join(dir, `.nd-replace-b-${process.pid}`);
    fs.writeFileSync(a, 'x');
    fs.rmSync(b, { force: true });
    fs.renameSync(a, b);
    fs.rmSync(b, { force: true });
    return true;
  } catch { return false; }
}
// Managed installs can put an explicit Everyone:(DENY)(DC) ACE on a folder. Chromium then cannot
// register the tray icon there even though ordinary writes succeed, so the icon silently
// disappears and the user has no tray entry to quit from. Detect that ACE and skip the folder.
function hasDenyDeleteChild(dir) {
  try {
    if (!fs.existsSync(dir)) return false;
    const ps = `$ErrorActionPreference='SilentlyContinue'; Get-Acl -LiteralPath '${String(dir).replace(/'/g, "''")}' | ForEach-Object { $_.Access | ForEach-Object { "$($_.IdentityReference)|$($_.FileSystemRights)|$($_.AccessControlType)|$($_.IsInherited)" } }`;
    const out = execFileSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', ps], { encoding: 'utf8', timeout: 8000, windowsHide: true, stdio: ['ignore', 'pipe', 'ignore'] });
    return out.split(/\r?\n/).some((line) => /\|DeleteChild\|\|Deny/i.test(line));
  } catch { return false; }
}
function resolveUserData() {
  const forced = process.env.NEURODESK_USER_DATA;
  const candidates = [];
  if (forced) candidates.push(forced);
  // A per-user folder outside %APPDATA%: the Windows notification area refuses to register a
  // tray icon when the profile directory cannot be written to, and some managed setups make
  // %APPDATA% read-only for the app.
  try { candidates.push(path.join(app.getPath('home'), '.neurodesk')); } catch { /* ignore */ }
  try { candidates.push(path.join(app.getPath('appData'), 'neurodesk-desktop')); } catch { /* ignore */ }
  try { candidates.push(app.getPath('userData')); } catch { /* ignore */ }
  candidates.push(path.join(app.getPath('temp'), 'neurodesk-desktop'));
  candidates.push(path.join(runtimeRoot, 'electron-userdata'));
  // Only directories that accept writes are worth an ACL check: the deny probe shells out and
  // must not run for every candidate, or startup gets noticeably slower.
  const writable = candidates.filter((dir) => canHostLock(dir) && canReplaceFiles(dir));
  const clean = writable.find((dir) => !hasDenyDeleteChild(dir));
  const chosen = clean || writable[0] || candidates[candidates.length - 1];
  app.setPath('userData', chosen);
  return chosen;
}
const userDataDir = resolveUserData();
if (!app.requestSingleInstanceLock()) app.quit();
else {
  app.on('second-instance', () => { if (panel) openPanel(); });
  app.whenReady().then(async () => {
    app.setAppUserModelId('com.neurodesk.desktop');
    await serve();
    if (useCoffeeDemo) {
      coffeeDemo = await startCoffeeDemo();
      coffee = createCoffeeGateway({ baseUrl: coffeeDemo.origin });
    }
    panel = secureWindow({ width: 1320, height: 900, minWidth: 960, minHeight: 680, show: false, backgroundColor: '#f5f6f3', title: 'NeuroDesk · 工作台', autoHideMenuBar: true });
    monitor = secureWindow({ width: 640, height: 480, show: false, skipTaskbar: true, title: 'NeuroDesk 后台感知' });
    // The pet and the Dynamic Island are independent native windows (see overlays.cjs): small,
    // transparent, click-through everywhere except their solid pixels.
    overlays = createOverlays({
      secureWindow, userDataDir, getPanel: () => panel, openPanel, quit: () => app.quit(),
      sendToPanel: (channel, value) => { if (panel && !panel.isDestroyed()) panel.webContents.send(channel, value); },
      handle, broadcast: (channel, value) => { broadcast(channel, value); buildTrayMenu(); },
    });
    pet = overlays.pet; island = overlays.island;
    const chatConfigPath = process.env.NEURODESK_CHAT_CONFIG || path.join(process.env.NEURODESK_TEST === '1' ? app.getPath('userData') : runtimeRoot, 'deepseek-config.json');
    const chatConfig = fs.existsSync(chatConfigPath) ? JSON.parse(fs.readFileSync(chatConfigPath, 'utf8')) : {};
    companion = createCompanion({
      ...chatConfig,
      apiKey: process.env.NEURODESK_CHAT_API_KEY || (process.env.NEURODESK_TEST !== '1' ? process.env.DEEPSEEK_API_KEY : '') || chatConfig.apiKey || '',
      model: process.env.NEURODESK_CHAT_MODEL || chatConfig.model || 'deepseek-flash',
      configPath: chatConfigPath, getSnapshot: () => snapshot,
      onEvent: (event) => { if (panel && !panel.isDestroyed()) panel.webContents.send('chat-event', event); },
      onSpeech: (value) => {
        if (pet && !pet.isDestroyed()) pet.webContents.send('companion-speech', value);
        if (panel && !panel.isDestroyed()) panel.webContents.send('companion-speech', value);
      },
    });
    session.defaultSession.setPermissionCheckHandler((contents, permission, requestingOrigin, details) => {
      if (permission === 'media') return contents === monitor.webContents && requestingOrigin === origin && (!details?.mediaType || details.mediaType === 'video');
      return permission === 'geolocation' && contents === panel.webContents && requestingOrigin === origin;
    });
    session.defaultSession.setPermissionRequestHandler((contents, permission, callback, details) => {
      callback(permission === 'media' && contents === monitor.webContents && details.mediaTypes?.every((t) => t === 'video') || permission === 'geolocation' && contents === panel.webContents);
    });
    handle('snapshot', () => [panel, pet, monitor], () => snapshot);
    handle('open-panel', () => [pet, island, panel], () => openPanel());
    handle('hide-panel', () => [panel], () => panel.hide());
    handle('show-pet', () => [panel], () => { overlays.set({ pet: true }); return true; });
    handle('selected-pet', () => [pet], () => selectedPet);
    handle('select-pet', () => [panel], (id, name) => { if (typeof id === 'string' && id.length < 120) { selectedPet = id; companion.setPersona(name); broadcast('select-pet', id); } });
    handle('monitor-control', () => [panel], (value) => { if (!['start', 'stop', 'calibrate'].includes(value)) throw new Error('未知监测操作'); command(value); });
    const loginOptions = { path: process.execPath, args: app.isPackaged ? [] : [app.getAppPath()] };
    handle('auto-start', () => [panel], (value) => { app.setLoginItemSettings({ ...loginOptions, openAtLogin: value === true }); return app.getLoginItemSettings(loginOptions).openAtLogin; });
    handle('auto-start-status', () => [panel], () => app.getLoginItemSettings(loginOptions).openAtLogin);
    handle('notifications', () => [panel], (value) => { notifications = value === true; });
    handle('chat-status', () => [panel], () => companion.status());
    handle('chat-send', () => [panel], (input) => companion.start({ requestId: input?.requestId, text: input?.text, name: input?.name }));
    handle('chat-cancel', () => [panel], (id) => companion.cancel(id));
    handle('chat-clear', () => [panel], () => companion.clear());
    handle('chat-settings', () => [panel], (input) => companion.configure(input));
    handle('chat-mode', () => [panel], (mode) => companion.setMode(mode));
    handle('screen-brightness', () => [panel], () => brightness.read());
    // In-app quit: the tray icon is not always available (locked-down profiles can refuse the
    // notification-area registration), and the user must never be stuck with a running app.
    handle('quit-app', () => [panel, pet], () => { app.quit(); return true; });
    handle('tts-status', () => [panel, pet], () => tts.status());
    handle('tts-speak', () => [panel, pet], (input) => tts.speak(input || {}));
    handle('set-screen-brightness', () => [panel], (value) => {
      if (!Number.isInteger(value) || value < 0 || value > 100) throw new Error('亮度需为 0–100 的整数');
      return brightness.set(value);
    });
    handle('coffee-config', () => [panel], () => useLuckin
      ? { configured: luckin.configured, demo: false, provider: 'luckin', location: null }
      : { configured: coffee.configured, demo: useCoffeeDemo, location: parkLocation });
    handle('coffee-nearby', () => [panel], (coords) => useLuckin ? luckin.nearby(coords) : coffee.nearby(coords));
    handle('coffee-order', () => [panel], (input) => useLuckin ? luckin.order(input) : coffee.order(input));
    handle('coffee-order-status', () => [panel], (id) => useLuckin ? luckin.orderStatus(id) : coffee.orderStatus(id));
    handle('luckin-products', () => [panel], (input) => luckin?.products(input));
    handle('delivery-config', () => [panel], () => luckin?.deliveryConfig() || { configured: false, message: '请使用瑞幸真实点单服务' });
    handle('delivery-preview', () => [panel], (input) => luckin?.deliveryPreview(input));
    handle('delivery-create', () => [panel], (input) => luckin?.deliveryCreate(input));
    handle('delivery-recover', () => [panel], (input) => luckin?.deliveryRecover(input));
    handle('locate', () => [panel], () => locate());
    handle('location-settings', () => [panel], () => shell.openExternal('ms-settings:privacy-location'));
    handle('luckin-detail', () => [panel], (input) => luckin?.detail(input));
    handle('luckin-switch', () => [panel], (input) => luckin?.switchAttribute(input));
    handle('luckin-preview', () => [panel], (input) => luckin?.preview(input));
    handle('luckin-history', () => [panel], () => luckin?.history() || []);
    handle('luckin-resolve', () => [panel], (input) => luckin?.resolveUnknown(input));
    handle('luckin-recover', () => [panel], (input) => luckin?.recover(input));
    handle('luckin-payment', () => [panel], (url) => {
      if (!luckin?.canOpenPayment(url)) throw new Error('支付链接无效或不属于本机订单');
      return shell.openExternal(url);
    });
    ipcMain.on('monitor-snapshot', (e, data) => {
      if (e.sender !== monitor.webContents || !data || typeof data !== 'object') return;
      snapshot = data; broadcast('snapshot', snapshot);
      companion.observe(snapshot);
      tray?.setToolTip(`NeuroDesk · ${data.running ? '后台监测中' : '监测已暂停'}`);
      if (data.running && ['tired', 'drowsy'].includes(data.state) && Date.now() - offeredAt > 20 * 60000) {
        offeredAt = Date.now(); openPanel(true);
        if (notifications && Notification.isSupported()) {
          const n = new Notification({ title: 'NeuroDesk · 休息一下', body: '检测到疲劳，起身活动一下，也可以看看附近的咖啡。' });
          n.on('click', () => openPanel(true)); n.show();
        }
      }
    });
    panel.on('close', (e) => { if (!quitting) { e.preventDefault(); panel.hide(); } });
    monitor.webContents.on('render-process-gone', () => {
      snapshot = { running: false, status: 'error', error: '后台感知进程已退出，请退出并重新启动 NeuroDesk', focus: null, fatigue: null, state: 'normal', source: '后台感知异常' };
      broadcast('snapshot', snapshot);
    });
    // Tray icon drawn as a 16x16 bitmap, matching the format Windows is known to place in the
    // notification area. A decoded PNG buffer was tried and the shell refused to show it.
    const pixels = Buffer.alloc(16 * 16 * 4);
    for (let y = 0; y < 16; y++) for (let x = 0; x < 16; x++) {
      const p = (y * 16 + x) * 4;
      if ((x - 7.5) ** 2 + (y - 7.5) ** 2 > 57) continue;
      const eye = y >= 6 && y <= 8 && (x === 5 || x === 10);
      pixels.set(eye ? [230, 245, 225, 255] : [65, 91, 52, 255], p);
    }
    const icon = nativeImage.createFromBitmap(pixels, { width: 16, height: 16 });
    tray = new Tray(icon); tray.setToolTip('NeuroDesk · 后台感知');
    buildTrayMenu = () => {
      if (!tray || tray.isDestroyed()) return;
      const o = overlays.state();
      tray.setContextMenu(Menu.buildFromTemplate([
        { label: '打开工作台', click: () => openPanel() },
        { label: o.pet ? '隐藏桌宠' : '显示桌宠', click: () => overlays.set({ pet: !o.pet }) },
        { label: o.island ? '隐藏灵动岛' : '显示灵动岛', click: () => overlays.set({ island: !o.island }) },
        { label: '隐藏/恢复全部悬浮窗  (Ctrl+Shift+H)', click: () => overlays.toggleAll() },
        { type: 'separator' },
        { label: '开始监测', click: () => command('start') }, { label: '暂停监测', click: () => command('stop') },
        { type: 'separator' }, { label: '退出 NeuroDesk', click: () => app.quit() },
      ]));
    };
    buildTrayMenu();
    tray.on('click', () => openPanel());
    await panel.loadURL(`${origin}/index.html`);
    await pet.loadURL(`${origin}/pet.html`);
    await island.loadURL(`${origin}/island.html`);
    await monitor.loadURL(`${origin}/monitor.html`);
    overlays.apply();
    overlays.registerShortcut();
    if (process.env.NEURODESK_TEST !== '1') {
      powerMonitor.on('suspend', () => { suspended = snapshot.running; command('stop'); });
      powerMonitor.on('resume', () => { if (suspended) command('start'); suspended = false; });
    }
    if (process.argv.includes('--show-panel')) openPanel();
  }).catch((error) => { require('electron').dialog.showErrorBox('NeuroDesk 启动失败', error.message); app.quit(); });
}
app.on('before-quit', () => { quitting = true; overlays?.dispose(); companion?.cancel(); server?.close(); coffeeDemo?.server.close(); localTts.stop(); });
app.on('window-all-closed', () => { if (quitting) app.quit(); });
// Third way out, in case the tray icon is missing and the in-app button is not noticed.
try { globalShortcut.register('Control+Shift+Q', () => app.quit()); } catch { /* already owned */ }
