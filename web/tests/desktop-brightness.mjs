// Explicit hardware test: changes screen brightness briefly, always restores it.
import { createRequire } from 'node:module';
import { mkdirSync } from 'node:fs';
import { resolve } from 'node:path';
import assert from 'node:assert/strict';
import { ensureFakeCamera } from './fake-camera.mjs';
const require = createRequire(import.meta.url);
const { _electron } = require('playwright-core');
const native = require('../desktop/screen-brightness.cjs').createBrightnessController();
const original = await native.read();
assert.equal(original.supported, true, original.message);
const userData = resolve(`.runtime/test-userdata-brightness-${Date.now()}`);
mkdirSync(userData, { recursive: true });
const env = { ...process.env, NEURODESK_COFFEE_DEMO: '0', NEURODESK_TEST: '1' };
delete env.ELECTRON_RUN_AS_NODE;
let electron;
try {
  electron = await _electron.launch({ executablePath: require('electron'), args: [
    '--no-sandbox', `--user-data-dir=${userData}`, '--use-fake-device-for-media-stream',
    '--use-fake-ui-for-media-stream', `--use-file-for-fake-video-capture=${ensureFakeCamera()}`, '.',
  ], env, timeout: 60000 });
  await electron.firstWindow();
  for (let i = 0; i < 300 && !electron.windows().some((page) => page.url().endsWith('/index.html')); i++) {
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  const panel = electron.windows().find((page) => page.url().endsWith('/index.html'));
  assert.ok(panel, `Panel missing: ${electron.windows().map((page) => page.url()).join(', ')}`);
  await panel.waitForFunction(() => document.querySelector('#screen-status')?.dataset.state === 'ready');
  await panel.evaluate(() => { window.neuro.auto = false; window.neuroDesktop.openPanel(); });
  assert.equal(await panel.locator('#sync-screen').isChecked(), true);
  assert.equal(Number(await panel.locator('#level').inputValue()), original.brightness, 'startup reads actual brightness');
  const target = original.brightness > 70 ? 70 : 85;
  await panel.evaluate((value) => {
    const slider = document.querySelector('#level'); slider.value = value;
    slider.dispatchEvent(new Event('input', { bubbles: true }));
  }, target);
  await panel.waitForFunction(() => document.querySelector('#screen-status').dataset.state === 'ready' && !window.neuro.light.screenBusy);
  const actual = await native.read();
  assert.equal(actual.brightness, target, 'slider changes physical screen brightness');
  assert.equal(Number(await panel.locator('#level').inputValue()), actual.brightness);
  await panel.evaluate(() => { const sync = document.querySelector('#sync-screen'); sync.checked = false; sync.dispatchEvent(new Event('change')); });
  await panel.evaluate(() => { const slider = document.querySelector('#level'); slider.value = 50; slider.dispatchEvent(new Event('input')); });
  await new Promise((resolve) => setTimeout(resolve, 350));
  assert.equal((await native.read()).brightness, target, 'disabled sync leaves physical brightness alone');
  await panel.reload();
  await panel.waitForFunction(() => document.querySelector('#screen-status')?.dataset.state === 'off');
  assert.equal(await panel.locator('#sync-screen').isChecked(), false, 'opt-out survives reload');
  console.log(`Hardware passed: startup ${original.brightness}%, slider -> ${target}%, WMI readback ${actual.brightness}%, opt-out preserved.`);
} catch (error) {
  console.error('Hardware test failed:', error);
  console.error('Windows:', electron?.windows().map((page) => page.url()));
  throw error;
} finally {
  if (electron) await electron.close();
  const restored = await native.set(original.brightness);
  assert.equal(restored.ok, true, restored.message);
  assert.equal((await native.read()).brightness, original.brightness);
  console.log(`Restored original brightness: ${original.brightness}%.`);
}
