import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright-core');

const OUT = process.argv[2] ?? 'shots';
const browser = await chromium.launch({ channel: 'msedge', headless: true });
const page = await browser.newPage({ viewport: { width: 1600, height: 1000 } });
const errors = [];
page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
page.on('console', (m) => { if (m.type() === 'error') errors.push('console: ' + m.text()); });
await page.goto('http://localhost:4173/');
await page.waitForTimeout(2500);
await page.screenshot({ path: `${OUT}/01-home.png`, fullPage: true });

await page.click('[data-mode="demo"]');
for (const q of ['focused', 'tired', 'drowsy', 'away']) {
  await page.click(`[data-q="${q}"]`);
  await page.waitForTimeout(q === 'away' ? 9000 : 7000);
  const st = await page.textContent('#state-pill span');
  console.log(q, '→', st, '|', await page.textContent('.pet-bubble p').catch(() => ''));
  await page.locator('.stage-card').screenshot({ path: `${OUT}/02-${q}.png` });
}
await page.click('[data-q="normal"]');
await page.waitForTimeout(6000);
await page.screenshot({ path: `${OUT}/03-demo.png`, fullPage: true });

for (const id of ['soot', 'robot']) {
  await page.click(`.pet-card:nth-child(${id === 'soot' ? 2 : 7})`);
  await page.waitForTimeout(800);
}
await page.locator('#gallery').screenshot({ path: `${OUT}/04-gallery.png` });

await page.fill('#chat-input', '放点雨声');
await page.press('#chat-input', 'Enter');
await page.waitForTimeout(1500);
await page.click('#coffee-go');
await page.waitForTimeout(4000);
await page.locator('.col.right').screenshot({ path: `${OUT}/05-right.png` });

await page.click('.pet-card.upload');
await page.waitForTimeout(500);
await page.locator('.upload-dlg').screenshot({ path: `${OUT}/06-upload-empty.png` });
const svg = Buffer.from('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><circle cx="50" cy="55" r="40" fill="#f472b6"/><circle cx="36" cy="50" r="6" fill="#222"/><circle cx="64" cy="50" r="6" fill="#222"/><path d="M40 68q10 8 20 0" stroke="#222" stroke-width="4" fill="none"/></svg>');
await page.setInputFiles('.slot[data-k="normal"] input', { name: 'me.svg', mimeType: 'image/svg+xml', buffer: svg });
await page.fill('input[name="pname"]', '测试形象');
await page.click('.up-moods button[data-m="sleepy"]');
await page.waitForTimeout(600);
await page.locator('.upload-dlg').screenshot({ path: `${OUT}/07-upload-filled.png` });
await page.click('.upload-dlg button[value="ok"]');
await page.waitForTimeout(1200);
console.log('custom cards:', await page.locator('.pet-card-tools').count(), '| chat-name:', await page.textContent('#chat-name'));
await page.locator('#gallery').screenshot({ path: `${OUT}/08-gallery-custom.png` });

await page.click('#btn-settings');
await page.waitForTimeout(400);
await page.screenshot({ path: `${OUT}/09-settings.png` });

await page.setViewportSize({ width: 420, height: 900 });
await page.keyboard.press('Escape');
await page.waitForTimeout(500);
await page.screenshot({ path: `${OUT}/10-mobile.png` });
console.log(errors.length ? errors.join('\n') : 'no errors');
await browser.close();
