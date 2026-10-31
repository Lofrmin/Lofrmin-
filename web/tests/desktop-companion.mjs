import { createRequire } from 'node:module';
import { mkdirSync, readFileSync, writeFileSync, unlinkSync } from 'node:fs';
import { resolve, join } from 'node:path';
import assert from 'node:assert/strict';
import { ensureFakeCamera } from './fake-camera.mjs';
const require = createRequire(import.meta.url);
const { _electron } = require('playwright-core');
const live = process.env.NEURODESK_COMPANION_LIVE === '1';
const userData = resolve(`.runtime/test-userdata-companion-${Date.now()}`); mkdirSync(userData, { recursive: true });
const configPath = join(userData, 'chat-config.json');
const source = live ? JSON.parse(readFileSync('.runtime/deepseek-config.json', 'utf8')) : {};
writeFileSync(configPath, JSON.stringify({ apiKey: source.apiKey || '', model: source.model || 'deepseek-flash', shareStatus: false, proactive: false }), { mode: 0o600 });
const env = { ...process.env, NEURODESK_TEST: '1', NEURODESK_COFFEE_DEMO: '0', NEURODESK_CHAT_CONFIG: configPath };
delete env.ELECTRON_RUN_AS_NODE; delete env.NEURODESK_CHAT_API_KEY;
let electron;
try {
  electron = await _electron.launch({ executablePath: require('electron'), args: [
    '--no-sandbox', `--user-data-dir=${userData}`, '--use-fake-device-for-media-stream',
    '--use-fake-ui-for-media-stream', `--use-file-for-fake-video-capture=${ensureFakeCamera()}`, '.',
  ], env, timeout: 60000 });
  await electron.firstWindow();
  for (let i = 0; i < 300 && !electron.windows().some((page) => page.url().endsWith('/index.html')); i++) await new Promise((resolve) => setTimeout(resolve, 100));
  const panel = electron.windows().find((page) => page.url().endsWith('/index.html'));
  assert.ok(panel); await panel.waitForFunction(() => window.neuro?.chat.config.model);
  const status = await panel.evaluate(() => window.neuroDesktop.chatStatus());
  assert.equal(status.configured, live); assert.equal(status.shareStatus, false); assert.equal(status.proactive, false);
  assert.ok(!source.apiKey || !JSON.stringify(status).includes(source.apiKey), 'credential stays in main process');
  const pet = electron.windows().find((page) => page.url().endsWith('/pet.html'));
  const denied = await pet.evaluate(async () => { try { await window.neuroDesktop.chatStatus(); return false; } catch (error) { return error.message.includes('无权执行'); } });
  assert.equal(denied, true);
  await panel.evaluate(() => { window.neuro.hub.voice = false; window.neuroDesktop.openPanel(); });
  await panel.click('[data-view="desk"]');
  if (live) {
    await panel.evaluate(() => { window.__deltas = 0; window.neuroDesktop.onChat((event) => { if (event.type === 'delta') window.__deltas++; }); });
    await panel.fill('#chat-input', '这是一段桌面接入自检。请用一句自然的中文跟我打招呼。');
    await panel.click('#chat-send');
    await panel.waitForFunction(() => document.querySelector('#chat .bot') && window.neuro.chat.pending.size === 0 && !document.querySelector('#chat-send').disabled, undefined, { timeout: 55000 });
    assert.ok(await panel.evaluate(() => window.__deltas > 0), 'real stream reaches renderer');
    assert.equal((await panel.evaluate(() => window.neuroDesktop.chatStatus())).lastReply.ok, true);
    const reply = await panel.locator('#chat .bot .chat-text').last().textContent();
    await pet.waitForFunction((text) => document.querySelector('#pet-speech').textContent === text, reply);
    assert.match(await panel.locator('#chat-via').textContent(), /DeepSeek/);
    mkdirSync('artifacts', { recursive: true });
    await panel.screenshot({ path: 'artifacts/desktop-companion-live.png', fullPage: true });
    await pet.screenshot({ path: 'artifacts/desktop-companion-pet.png', omitBackground: true });
    await panel.click('#chat-clear');
    await panel.waitForFunction(() => document.querySelector('#chat').children.length === 0);
    assert.deepEqual((await panel.evaluate(() => window.neuroDesktop.chatStatus())).history, []);
    console.log('Live desktop companion passed: real DeepSeek streaming, renderer conversation, desktop-pet speech bubble, credential/IPC isolation, clear history. Fake camera; status sharing disabled for this test.');
  } else {
    await assert.rejects(panel.evaluate(() => window.neuroDesktop.chatSend({ text: 'test' })), /密钥/);
    console.log('Desktop companion passed: isolated settings, unconfigured API blocked, pet denied access. No remote model request.');
  }
} finally {
  if (electron) await electron.close();
  unlinkSync(configPath);
}
