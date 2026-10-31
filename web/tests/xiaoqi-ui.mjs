import assert from 'node:assert/strict';
import { mkdirSync } from 'node:fs';
import { createRequire } from 'node:module';
import { preview } from 'vite';
const { chromium } = createRequire(import.meta.url)('playwright-core');
const server = await preview({ preview: { host: '127.0.0.1', port: 4198, strictPort: true } });
const browser = await chromium.launch({ channel: 'msedge', headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
const errors = [];
page.on('pageerror', error => errors.push(error.message));
await page.addInitScript(() => { localStorage.setItem('nd-pet', 'robot'); localStorage.setItem('nd-voice', '0'); });
const robot = page.locator('#v2-pet-stage .xiaoqi-robot');
try {
  await page.goto('http://127.0.0.1:4198/');
  await robot.waitFor();
  await page.evaluate(() => { window.neuro.hub.voice = false; window.neuro.hub.sound = false; });
  await page.waitForFunction(() => [...document.querySelectorAll('.xiaoqi-robot .robot-base')].every(img => img.complete && img.naturalWidth > 0));
  assert.equal(await robot.getAttribute('data-stage'), '0');
  const box = await robot.locator('.robot-layer').evaluate(el => ({ width: el.offsetWidth, height: el.offsetHeight }));
  assert.ok(Math.abs(box.width / box.height - 825 / 1197) < .005, 'reference aspect ratio');
  const canvas = robot.locator('canvas');
  const first = await canvas.evaluate(c => c.toDataURL());
  await page.waitForTimeout(150);
  assert.notEqual(await canvas.evaluate(c => c.toDataURL()), first, 'cube continues rotating');
  for (const stage of [1, 2, 3, 4, 5, 6, 1]) {
    await robot.click({ force: true });
    assert.equal(await robot.getAttribute('data-stage'), String(stage));
    assert.ok(await page.evaluate(stage => [...window.neuro.hub.views].every(v => v.robot?.getStage() === stage), stage), 'mounted views stay synchronized');
    if (stage === 3) assert.equal(await robot.locator('[id$="starFaceOverlay"]').evaluate(el => el.style.opacity), '1');
    if (stage === 5 || stage === 6) {
      await page.waitForTimeout(750);
      assert.ok(Math.abs(Number(await robot.locator('[id$="centerSeal"]').getAttribute('opacity')) - (stage === 5 ? 1 : 0)) < .001);
      assert.match(await robot.locator('img').getAttribute('src'), stage === 5 ? /serious-red/ : /serious\.webp/);
      if (stage === 5) {
        mkdirSync('artifacts', { recursive: true });
        await page.screenshot({ path: 'artifacts/xiaoqi-mask.png' });
      }
    }
  }
  for (const [mood, stage] of [['tired', 2], ['love', 3], ['curious', 4], ['alert', 5], ['normal', 0]]) {
    await page.evaluate(mood => window.neuro.hub.setMood(mood), mood);
    assert.equal(await robot.getAttribute('data-stage'), String(stage));
  }
  const ids = await page.locator('.xiaoqi-robot [id]').evaluateAll(els => els.map(el => el.id));
  assert.equal(new Set(ids).size, ids.length, 'SVG references have unique IDs across views');
  await page.click('#v2-switch-companion');
  assert.equal(await page.locator('[data-v2-pet="robot"] image').getAttribute('href'), '/pets/xiaoqi/serious.webp');
  await page.click('[data-v2-pet="cat"]');
  assert.equal(await page.locator('#v2-pet-stage .xiaoqi-robot').count(), 0, 'old renderer removed');
  await page.click('#v2-switch-companion');
  await page.click('[data-v2-pet="robot"]');
  await page.evaluate(() => { clearTimeout(window.neuro.reactions.flashT); window.neuro.hub.setMood('normal'); });
  await page.waitForFunction(() => document.querySelector('#v2-pet-stage .robot-base')?.complete);
  await page.screenshot({ path: 'artifacts/xiaoqi-updated.png' });
  await page.setViewportSize({ width: 420, height: 900 });
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
  assert.deepEqual(errors, []);
  console.log('XiaoQi UI passed: offline assets, proportions, rotating cube, seven-step click cycle, mask opening/closing, moods, synchronized views, unique SVG IDs, selection and mobile layout.');
} finally {
  await browser.close();
  server.httpServer.closeAllConnections();
  await new Promise(resolve => server.httpServer.close(resolve));
}
