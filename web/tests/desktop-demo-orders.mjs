import { createRequire } from 'node:module';
import assert from 'node:assert/strict';
import { mkdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { ensureFakeCamera } from './fake-camera.mjs';
const require = createRequire(import.meta.url);
const { _electron } = require('playwright-core');
const env = { ...process.env, NEURODESK_TEST: '1' };
delete env.ELECTRON_RUN_AS_NODE; delete env.NEURODESK_COFFEE_API; delete env.NEURODESK_COFFEE_DEMO;
const userData = resolve('.runtime/test-userdata-demo'); mkdirSync(userData, { recursive: true });
const fakeCamera = ensureFakeCamera();
const electron = await _electron.launch({ executablePath: require('electron'), args: ['--no-sandbox', `--user-data-dir=${userData}`, '--use-fake-device-for-media-stream', '--use-fake-ui-for-media-stream', `--use-file-for-fake-video-capture=${fakeCamera}`, '.'], env, timeout: 60000 });
const errors = [];
electron.on('window', (page) => page.on('pageerror', (error) => errors.push(error.message)));
try {
  await electron.firstWindow();
  for (let i = 0; i < 300 && !electron.windows().some((p) => p.url().endsWith('/index.html')); i++) await new Promise((r) => setTimeout(r, 100));
  const panel = electron.windows().find((p) => p.url().endsWith('/index.html'));
  await panel.waitForFunction(() => window.neuro?.coffee.onOffer);
  assert.deepEqual(await panel.evaluate(() => window.neuroDesktop.coffeeConfig()), { configured: true, demo: true, location: null });
  await panel.evaluate(() => window.neuroDesktop.openPanel());
  await panel.click('#coffee-go');
  await panel.waitForSelector('.coffee-product button:enabled');
  assert.match(await panel.textContent('#coffee-sample'), /本机演示/);
  await panel.locator('.coffee-product button').first().click();
  await panel.waitForFunction(() => document.querySelector('#coffee-status').textContent.includes('DEMO-'));
  const first = await panel.textContent('#coffee-status');
  assert.match(first, /本机演示/);
  assert.equal(await panel.evaluate(() => localStorage.getItem('nd-pending-order')), null);
  await panel.waitForFunction(() => /演示订单已到达/.test(document.querySelector('#coffee-status').textContent), undefined, { timeout: 15000 });
  assert.match(await panel.textContent('#coffee-status'), /4\/4/);
  await panel.screenshot({ path: 'artifacts/desktop-demo-order-ready.png', fullPage: true });
  assert.deepEqual(errors, []);
  console.log('Local coffee demo passed: no location needed, clear demo labels, order ID, idempotent submission, progress polling to 4/4.');
} catch (error) {
  const panel = electron.windows().find((p) => p.url().endsWith('/index.html'));
  if (panel) console.error('Demo diagnostics:', await panel.evaluate(() => ({ status: document.querySelector('#coffee-status')?.textContent, stores: document.querySelector('#coffee-stores')?.innerHTML, pending: window.neuro?.coffee.pending, busy: window.neuro?.coffee.busy })), errors);
  throw error;
} finally { await electron.close(); }
