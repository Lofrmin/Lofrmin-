// Desktop TTS end-to-end: verifies the IPC bridge, local /tts endpoint, and that the renderer
// receives a playable audio element. Uses a synthetic voice path but real file serving.
import { createRequire } from 'node:module';
import { mkdirSync, writeFileSync, existsSync, statSync } from 'node:fs';
import { resolve, join } from 'node:path';
import assert from 'node:assert/strict';
const require = createRequire(import.meta.url);
const { _electron } = require('playwright-core');

const web = 'E:/office_workspace/hks/web';
process.chdir(web);
const userData = resolve('.runtime/test-userdata-tts');
mkdirSync(userData, { recursive: true });
const env = { ...process.env, NEURODESK_TEST: '1', NEURODESK_COFFEE_DEMO: '0' };
delete env.ELECTRON_RUN_AS_NODE;

let electron;
try {
  electron = await _electron.launch({
    executablePath: require(join(web, 'node_modules/electron')),
    args: ['--no-sandbox', `--user-data-dir=${userData}`, '--autoplay-policy=no-user-gesture-required', '.'],
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

  const status = await panel.evaluate(() => window.neuroDesktop.ttsStatus());
  console.log('tts status:', status);
  assert.equal(status.enabled, true, 'tts should be enabled');

  // Synthesize through the real bridge.
  const t0 = Date.now();
  const result = await panel.evaluate(() => window.neuroDesktop.ttsSpeak({ text: '测试语音合成，一二三。' }));
  console.log('synthesized:', result, 'elapsed', Date.now() - t0, 'ms');
  assert.match(result.id, /^[a-f0-9]{32}$/, 'id must be an opaque hash');
  assert.ok(result.bytes > 1000, 'audio should have content');

  // The local endpoint must serve the synthesised audio under the page origin.
  const served = await panel.evaluate(async (id) => {
    const response = await fetch(`/tts?id=${id}`);
    const buffer = await response.arrayBuffer();
    return { ok: response.ok, type: response.headers.get('content-type'), bytes: buffer.byteLength };
  }, result.id);
  console.log('served:', served);
  assert.equal(served.ok, true);
  // The local engine produces WAV; edge-tts produces MP3. Either is fine as long as the
  // endpoint reports the type that actually matches the bytes.
  assert.ok(['audio/wav', 'audio/mpeg'].includes(served.type), `unexpected content type ${served.type}`);
  assert.ok(served.bytes > 1000);

  // Unknown/forged ids must 404 rather than leak files.
  const denied = await panel.evaluate(async () => {
    const response = await fetch('/tts?id=../../desktop/main.cjs');
    return response.status;
  });
  console.log('forged id status:', denied);
  assert.equal(denied, 404);

  // Renderer playback path: audio element reaches a playable state.
  const playback = await panel.evaluate(async (id) => {
    const audio = new Audio(`${location.origin}/tts?id=${id}`);
    const state = await new Promise((resolve) => {
      const timer = setTimeout(() => resolve({ ok: false, reason: 'timeout', ready: audio.readyState, error: audio.error?.code ?? null }), 8000);
      audio.addEventListener('canplaythrough', () => { clearTimeout(timer); resolve({ ok: true, duration: audio.duration }); }, { once: true });
      audio.addEventListener('error', () => { clearTimeout(timer); resolve({ ok: false, reason: 'error', code: audio.error?.code ?? null }); }, { once: true });
      audio.load();
    });
    return state;
  }, result.id);
  console.log('playback:', playback);
  assert.equal(playback.ok, true, 'audio element must become playable');

  console.log('TTS DESKTOP PASS');
} finally {
  await electron.close();
}
