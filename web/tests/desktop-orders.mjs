import { createRequire } from 'node:module';
import { createServer } from 'node:http';
import assert from 'node:assert/strict';
import { mkdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { ensureFakeCamera } from './fake-camera.mjs';
const require = createRequire(import.meta.url);
const { _electron } = require('playwright-core');
let submissions = 0, submitted;
const api = createServer(async (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  if (req.url.startsWith('/stores/nearby')) return res.end(JSON.stringify({ stores: [
    { id: 'far', name: '测试远店', distanceMeters: 700, address: '本机测试', products: [{ id: 'latte', name: '测试拿铁', priceCents: 2400, available: true }] },
    { id: 'near', name: '测试近店', distanceMeters: 100, address: '本机测试', products: [{ id: 'americano', name: '测试美式', priceCents: 1800, available: true }] },
  ] }));
  if (req.method === 'POST' && req.url === '/orders') {
    submissions++;
    let body = ''; for await (const part of req) body += part;
    submitted = { body: JSON.parse(body), key: req.headers['idempotency-key'], auth: req.headers.authorization };
    return res.end(JSON.stringify({ orderId: 'LOCAL-TEST-ONLY', status: 'accepted', pickupCode: 'T001' }));
  }
  res.writeHead(404).end('{}');
});
await new Promise((resolve) => api.listen(0, '127.0.0.1', resolve));
const env = { ...process.env, NEURODESK_COFFEE_API: `http://127.0.0.1:${api.address().port}`, NEURODESK_COFFEE_TOKEN: 'local-test-token', NEURODESK_TEST: '1' };
delete env.ELECTRON_RUN_AS_NODE;
let electron;
const userData = resolve('.runtime/test-userdata-orders'); mkdirSync(userData, { recursive: true });
const fakeCamera = ensureFakeCamera();
try {
  electron = await _electron.launch({ executablePath: require('electron'), args: ['--no-sandbox', `--user-data-dir=${userData}`, '--use-fake-device-for-media-stream', '--use-fake-ui-for-media-stream', `--use-file-for-fake-video-capture=${fakeCamera}`, '.'], env });
  await electron.firstWindow();
  for (let i = 0; i < 300 && !electron.windows().some((p) => p.url().endsWith('/index.html')); i++) await new Promise((resolve) => setTimeout(resolve, 100));
  const panel = electron.windows().find((p) => p.url().endsWith('/index.html'));
  await panel.waitForFunction(() => window.neuro?.coffee.onOffer);
  await panel.evaluate(() => {
    localStorage.removeItem('nd-pending-order');
    window.neuro.coffee.pending = null;
    navigator.geolocation.getCurrentPosition = (ok) => ok({ coords: { latitude: 31.23, longitude: 121.47 } });
    window.neuroDesktop.openPanel();
  });
  await panel.click('[data-view="desk"]');
  await panel.click('#coffee-go');
  await panel.waitForSelector('.coffee-product button:enabled');
  assert.match(await panel.locator('.coffee-store h3').first().textContent(), /测试近店/);
  assert.equal(submissions, 0, 'opening recommendations never places an order');
  await panel.locator('.coffee-product button').first().click();
  await panel.waitForFunction(() => document.querySelector('#coffee-status').textContent.includes('LOCAL-TEST-ONLY'));
  assert.equal(submissions, 1);
  assert.equal(submitted.body.storeId, 'near');
  assert.equal(submitted.body.expectedPriceCents, 1800);
  assert.equal(submitted.auth, 'Bearer local-test-token');
  assert.ok(submitted.key);
  assert.match(await panel.textContent('#coffee-status'), /门店已接单/);
  assert.equal(await panel.evaluate(() => localStorage.getItem('nd-pending-order')), null);
  await panel.screenshot({ path: 'artifacts/desktop-order-confirmed.png', fullPage: true });
  console.log('Native order integration passed: location, distance sorting, one click => one local test order, real confirmation fields, no order on popup.');
} finally {
  await electron?.close();
  api.closeAllConnections();
  await new Promise((resolve) => api.close(resolve));
}
