import { createRequire } from 'node:module';
import { mkdirSync } from 'node:fs';
import assert from 'node:assert/strict';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright-core');
const { preview } = await import('vite');
const server = await preview({ preview: { host: '127.0.0.1', port: 4175, strictPort: true } });
mkdirSync('artifacts', { recursive: true });
const browser = await chromium.launch({ channel: 'msedge', headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
const errors = [];
page.on('pageerror', (error) => errors.push(error.message));
try {
  await page.goto('http://127.0.0.1:4175/');
  await page.waitForFunction(() => window.neuro?.player.session);
  assert.equal(await page.textContent('#g-fatigue b'), '--', 'dataset playback must not produce live fatigue scores');
  await page.screenshot({ path: 'artifacts/overview.png', fullPage: true });
  for (const view of ['companion', 'insights', 'desk']) {
    await page.click(`[data-view="${view}"]`);
    await page.screenshot({ path: `artifacts/${view}.png`, fullPage: true });
  }
  await page.click('#coffee-go');
  await page.waitForSelector('.coffee-store');
  await page.waitForFunction(() => getComputedStyle(document.querySelector('#coffee-dialog')).opacity === '1');
  assert.match(await page.textContent('#coffee-status'), /示例/);
  assert.equal(await page.locator('.coffee-product button:enabled').count(), 0);
  await page.screenshot({ path: 'artifacts/coffee.png', fullPage: true });
  await page.click('#coffee-close');
  await page.click('[data-view="overview"]');
  await page.click('[data-mode="demo"]');
  await page.click('[data-q="tired"]');
  await page.waitForSelector('#coffee-dialog[open]', { timeout: 20000 });
  assert.match(await page.textContent('#state-pill span'), /疲劳/);
  await page.click('#coffee-later');
  await page.click('[data-mode="sense"]');
  await page.waitForFunction(() => document.querySelector('#g-fatigue b').textContent === '--');
  await page.setViewportSize({ width: 420, height: 900 });
  await page.screenshot({ path: 'artifacts/mobile.png', fullPage: true });
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false, 'no horizontal overflow');
  assert.deepEqual(errors, []);
  console.log('UI passed: four views, no synthetic live scores, sample orders disabled, fatigue popup, mobile layout; no page errors.');
} finally { await browser.close(); server.httpServer.closeAllConnections(); await new Promise((resolve) => server.httpServer.close(resolve)); process.exit(); }
