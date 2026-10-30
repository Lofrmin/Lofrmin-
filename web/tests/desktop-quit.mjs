// The app must always offer a way to quit, even when the Windows tray icon cannot be
// registered (locked-down profiles can refuse the notification-area entry). This checks the
// in-app button and the IPC bridge behind it.
import { createRequire } from 'node:module';
import { mkdirSync } from 'node:fs';
import { resolve } from 'node:path';
import assert from 'node:assert/strict';
const require = createRequire(import.meta.url);
const { _electron } = require('playwright-core');

const web = resolve('.');
const userData = resolve('.runtime/test-userdata-quit');
mkdirSync(userData, { recursive: true });
const env = { ...process.env, NEURODESK_TEST: '1', NEURODESK_COFFEE_DEMO: '0' };
delete env.ELECTRON_RUN_AS_NODE;

let electron;
try {
  electron = await _electron.launch({
    executablePath: require(resolve(web, 'node_modules/electron')),
    args: ['--no-sandbox', `--user-data-dir=${userData}`, '.'],
    env,
    timeout: 60000,
  });
  await electron.firstWindow();
  let panel;
  for (let i = 0; i < 300 && !panel; i++) {
    panel = electron.windows().find((p) => p.url().endsWith('/index.html'));
    if (!panel) await new Promise((r) => setTimeout(r, 100));
  }
  assert.ok(panel, 'panel window did not open');
  await panel.waitForFunction(() => window.neuroDesktop, null, { timeout: 20000 });
  await panel.waitForSelector('#btn-quit', { state: 'attached', timeout: 20000 });

  assert.equal(await panel.evaluate(() => typeof window.neuroDesktop.quitApp), 'function', 'quitApp bridge missing');
  await panel.click('#btn-quit');
  const closed = await electron.waitForEvent('close', { timeout: 15000 }).then(() => true).catch(() => false);
  assert.equal(closed, true, 'clicking the quit button did not terminate the app');
  console.log('Quit affordance passed: in-app button and IPC bridge both terminate the app.');
} finally {
  await electron?.close().catch(() => {});
}
