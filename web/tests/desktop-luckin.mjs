import { createRequire } from 'node:module';
import { mkdirSync } from 'node:fs';
import { resolve } from 'node:path';
import assert from 'node:assert/strict';
import { ensureFakeCamera } from './fake-camera.mjs';
const require = createRequire(import.meta.url);
const { _electron } = require('playwright-core');
const userData = resolve('.runtime/test-userdata-luckin'); mkdirSync(userData, { recursive: true });
const env = { ...process.env, NEURODESK_TEST: '1', NEURODESK_COFFEE_PROVIDER: 'luckin', NEURODESK_LUCKIN_TOKEN: 'synthetic-test-token', NEURODESK_LUCKIN_ORDERS: resolve('.runtime/test-luckin-orders.json'), NEURODESK_SHANSONG_CONFIG: resolve('.runtime/test-shansong-unconfigured.json'), NEURODESK_SHANSONG_ORDERS: resolve('.runtime/test-shansong-orders.json') };
delete env.ELECTRON_RUN_AS_NODE;
const electron = await _electron.launch({ executablePath: require('electron'), args: [
  '--no-sandbox', `--user-data-dir=${userData}`, '--use-fake-device-for-media-stream',
  '--use-fake-ui-for-media-stream', `--use-file-for-fake-video-capture=${ensureFakeCamera()}`, '.',
], env, timeout: 60000 });
try {
  await electron.firstWindow();
  for (let i = 0; i < 300 && !electron.windows().some((page) => page.url().endsWith('/index.html')); i++) await new Promise((resolve) => setTimeout(resolve, 100));
  const panel = electron.windows().find((page) => page.url().endsWith('/index.html'));
  assert.ok(panel); await panel.waitForFunction(() => window.neuro?.coffee.onOffer);
  const config = await panel.evaluate(() => window.neuroDesktop.coffeeConfig());
  assert.deepEqual(config, { configured: true, provider: 'luckin', demo: false, location: null });
  await panel.evaluate(() => window.neuroDesktop.openPanel());
  await panel.click('[data-view="desk"]'); await panel.click('#coffee-go');
  await panel.waitForSelector('#luckin-locate');
  assert.match(await panel.locator('#coffee-status').textContent(), /瑞幸真实点单/);
  assert.equal(await panel.evaluate(() => typeof window.neuroDesktop.locate), 'function');
  assert.equal(await panel.evaluate(() => typeof window.neuroDesktop.luckinPreview), 'function');
  assert.equal(await panel.evaluate(() => typeof window.neuroDesktop.deliveryCreate), 'function');
  const deliveryConfig = await panel.evaluate(() => window.neuroDesktop.deliveryConfig());
  assert.equal(deliveryConfig.configured, false);
  assert.match(deliveryConfig.message, /待开通/);
  assert.equal(Object.hasOwn(deliveryConfig, 'token'), false);
  assert.equal(await panel.evaluate(() => JSON.stringify(window.neuroDesktop).includes('synthetic-test-token')), false);
  const pet = electron.windows().find((page) => page.url().endsWith('/pet.html'));
  assert.ok(pet);
  const forbidden = await pet.evaluate(async () => { try { await window.neuroDesktop.luckinPreview({}); return false; } catch (error) { return error.message.includes('无权执行'); } });
  assert.equal(forbidden, true, 'pet cannot call checkout APIs');
  for (const method of ['deliveryConfig', 'deliveryPreview', 'deliveryCreate', 'deliveryRecover']) {
    const denied = await pet.evaluate(async (name) => { try { await window.neuroDesktop[name]({}); return false; } catch (error) { return error.message.includes('无权执行'); } }, method);
    assert.equal(denied, true, `pet cannot call ${method}`);
  }
  await assert.rejects(panel.evaluate(() => window.neuroDesktop.deliveryPreview({ orderId: 'unowned' })), /本机/);
  await assert.rejects(panel.evaluate(() => window.neuroDesktop.order({})), /确认/);
  await assert.rejects(panel.evaluate(() => window.neuroDesktop.luckinPayment('file:///C:/Windows/a.exe')), /链接无效/);
  mkdirSync('artifacts', { recursive: true });
  await panel.screenshot({ path: 'artifacts/desktop-luckin-location.png', fullPage: true });
  console.log('Desktop Luckin passed: provider selection, isolated IPC, location-first UI, no exposed credential, unconfirmed orders/payment links blocked. No merchant request or purchase.');
} finally { await electron.close(); }
