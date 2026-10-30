import { createRequire } from 'node:module';
import assert from 'node:assert/strict';
import { mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import { spawn } from 'node:child_process';
import { ensureFakeCamera } from './fake-camera.mjs';
const require = createRequire(import.meta.url);
const { _electron } = require('playwright-core');
const ROOT = fileURLToPath(new URL('../..', import.meta.url));
const HEALTH = 'http://127.0.0.1:18182/health';
const PORT = '18182';
async function isHealthy() {
  try { return (await fetch(HEALTH)).ok; } catch { return false; }
}
// Start the gateway directly instead of via bailu_fixture.py: the fixture forks a
// grandchild, so killing it left an orphan holding the port and the stdio pipes open,
// which also kept the node process from exiting.
let gateway = null, startedByUs = false;
if (!(await isHealthy())) {
  gateway = spawn('python', ['server/bailu_coffee_adapter.py'], {
    cwd: ROOT,
    stdio: 'ignore',
    env: {
      ...process.env,
      BAILU_PORT: PORT,
      BAILU_DATA_DIR: resolve(ROOT, 'server/.runtime-test'),
      BAILU_CAR_UDP_DRY_RUN: '1',
      BAILU_STAGE_SCALE: '0.05',
      PYTHONUNBUFFERED: '1',
    },
  });
  startedByUs = true;
}
async function waitHealthy() {
  for (let i = 0; i < 120; i++) {
    if (await isHealthy()) return;
    await new Promise((r) => setTimeout(r, 400));
  }
  throw new Error('bailu gateway did not become ready');
}
await waitHealthy();
const env = {
  ...process.env,
  NEURODESK_COFFEE_API: 'http://127.0.0.1:18182/api',
  NEURODESK_COFFEE_TOKEN: 'bailu-2026-secret',
  NEURODESK_COFFEE_DEMO: '0',
  NEURODESK_COFFEE_LOCATION: 'bailu',
  NEURODESK_TEST: '1',
};
delete env.ELECTRON_RUN_AS_NODE;
const userData = resolve('.runtime/test-userdata-bailu'); mkdirSync(userData, { recursive: true });
const fakeCamera = ensureFakeCamera();
const electron = await _electron.launch({
  executablePath: require('electron'),
  args: ['--no-sandbox', `--user-data-dir=${userData}`, '--use-fake-device-for-media-stream', '--use-fake-ui-for-media-stream', `--use-file-for-fake-video-capture=${fakeCamera}`, '.'],
  env,
  timeout: 60000,
});
const errors = [];
electron.on('window', (page) => page.on('pageerror', (error) => errors.push(error.message)));
try {
  await electron.firstWindow();
  for (let i = 0; i < 300 && !electron.windows().some((p) => p.url().endsWith('/index.html')); i++) await new Promise((r) => setTimeout(r, 100));
  const panel = electron.windows().find((p) => p.url().endsWith('/index.html'));
  await panel.waitForFunction(() => window.neuro?.coffee.onOffer);
  assert.deepEqual(await panel.evaluate(() => window.neuroDesktop.coffeeConfig()), {
    configured: true, demo: false, location: { latitude: 30.58, longitude: 104.12 },
  });
  await panel.evaluate(() => {
    localStorage.removeItem('nd-pending-order');
    window.neuro.coffee.pending = null;
    // If the UI wrongly asks for geolocation, fail instead of hanging.
    navigator.geolocation.getCurrentPosition = () => { throw new Error('bailu mode must use the fixed park location'); };
    window.neuroDesktop.openPanel();
  });
  await panel.click('[data-view="desk"]');
  await panel.click('#coffee-go');
  await panel.waitForSelector('.coffee-product button:enabled');
  assert.match(await panel.locator('.coffee-store h3').first().textContent(), /瑞幸咖啡（白鹭湾科技生态园店）/);
  assert.match(await panel.locator('.coffee-store').first().textContent(), /160 m/);
  assert.match(await panel.textContent('#coffee-sample'), /商户服务/);
  await panel.locator('.coffee-product button').first().click();
  await panel.waitForFunction(() => /LK\d{4}[A-F0-9]{6}/.test(document.querySelector('#coffee-status').textContent), undefined, { timeout: 20000 });
  assert.match(await panel.textContent('#coffee-status'), /订单 LK\d{4}[A-F0-9]{6}/);
  assert.doesNotMatch(await panel.textContent('#coffee-status'), /本机演示|DEMO-/);
  // The test gateway compresses stages; UI polls every 2s, so intermediate stages may be skipped.
  await panel.waitForFunction(() => /无人车已停靠工位右侧/.test(document.querySelector('#coffee-status').textContent), undefined, { timeout: 20000 });
  assert.match(await panel.textContent('#coffee-status'), /4\/4/);
  await panel.screenshot({ path: 'artifacts/desktop-bailu-ready.png', fullPage: true });
  assert.deepEqual(errors, []);
  console.log('Bailu merchant UI passed: fixed park location, real store names, Bearer order, 4-stage progress without geolocation.');
} catch (error) {
  const panel = electron.windows().find((p) => p.url().endsWith('/index.html'));
  if (panel) console.error('Bailu diagnostics:', await panel.evaluate(() => ({ status: document.querySelector('#coffee-status')?.textContent, config: window.neuroDesktop?.coffeeConfig() })));
  throw error;
} finally {
  await electron.close();
  if (startedByUs && gateway) {
    gateway.kill();
    for (let i = 0; i < 40 && await isHealthy(); i++) await new Promise((r) => setTimeout(r, 100));
  }
}
