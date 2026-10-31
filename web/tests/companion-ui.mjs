import { createRequire } from 'node:module';
import { mkdirSync } from 'node:fs';
import assert from 'node:assert/strict';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright-core');
const { createCompanion } = require('../desktop/companion.cjs');
const { preview } = await import('vite');
const server = await preview({ preview: { host: '127.0.0.1', port: 4177, strictPort: true } });
const browser = await chromium.launch({ channel: 'msedge', headless: true });
const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
const errors = [], requests = []; let clock = 1000, failures = 0;
page.on('pageerror', (error) => errors.push(error.message));
const chunk = (choice) => `data: ${JSON.stringify({ choices: [choice] })}\n\n`;
const service = createCompanion({ apiKey: 'synthetic', shareStatus: true, proactive: true, now: () => clock,
  getSnapshot: () => ({ at: clock, running: true, state: 'tired', focus: 52, fatigue: 68, face: { present: true } }),
  onEvent: (event) => { void page.evaluate((e) => window.__chatListener?.(e), event).catch(() => {}); },
  fetchImpl: async (_url, { body, signal }) => {
    const request = JSON.parse(body); requests.push(request);
    const text = request.messages.at(-1).content;
    if (text.includes('测试出错') && failures++ === 0) return new Response('', { status: 401 });
    const slow = text.includes('慢慢说');
    const content = !request.tools ? '看起来有点累了，先起身活动一小会儿吧。' : text.includes('雨声') ? '可以给你放雨声，点击下面的按钮就好。' : text.includes('叫什么') ? '你叫小林，我记得。' : '你好，我在这里陪你。';
    const parts = [chunk({ delta: { content: content.slice(0, 3) } }), chunk({ delta: { content: content.slice(3) } })];
    if (text.includes('雨声')) parts.push(chunk({ delta: { tool_calls: [{ index: 0, function: { name: 'play_music', arguments: '{"track":"rain"}' } }] } }));
    parts.push(chunk({ delta: {}, finish_reason: text.includes('雨声') ? 'tool_calls' : 'stop' }), 'data: [DONE]\n\n');
    let index = 0;
    return new Response(new ReadableStream({ async pull(controller) {
      await new Promise((resolve) => setTimeout(resolve, slow ? 800 : 70));
      if (signal.aborted) { controller.error(new Error('aborted')); return; }
      if (index < parts.length) controller.enqueue(new TextEncoder().encode(parts[index++])); else controller.close();
    } }), { headers: { 'content-type': 'text/event-stream' } });
  },
});
await page.exposeFunction('companionCall', async (method, input) => service[method](input));
await page.addInitScript(() => {
  const noop = () => {};
  window.neuroDesktop = {
    selectPet: noop, setNotifications: noop, onSnapshot: noop, onCoffee: noop, autoStart: async () => false,
    snapshot: async () => ({ running: false, status: 'paused' }), screenBrightness: async () => ({ supported: false, message: 'Synthetic UI test' }),
    coffeeConfig: async () => ({ configured: false, demo: false }),
    onChat: (fn) => { window.__chatListener = fn; },
    chatStatus: () => window.companionCall('status'), chatSend: (input) => window.companionCall('start', input),
    chatCancel: (input) => window.companionCall('cancel', input), chatClear: () => window.companionCall('clear'),
    chatSettings: (input) => window.companionCall('configure', input), companionMode: async () => {},
  };
});
async function send(text) { await page.fill('#chat-input', text); await page.click('#chat-send'); }
async function finished() { await page.waitForFunction(() => window.neuro.chat.pending.size === 0 && !document.querySelector('#chat-send').disabled); }
try {
  await page.goto('http://127.0.0.1:4177/'); await page.waitForFunction(() => window.neuro?.chat.config.model);
  await page.evaluate(() => {
    window.neuro.hub.voice = false;
    window.__spoken = []; window.__stops = 0;
    window.neuro.hub.utter = (text) => window.__spoken.push(text);
    window.neuro.hub.stopSpeaking = () => window.__stops++;
    window.neuro.music.play = (name) => { window.__musicPlayed = name; };
  });
  await page.click('.nd-nav[data-action="chat"]');
  await send('我叫小林');
  await page.waitForFunction(() => document.querySelector('#chat .bot .chat-text')?.textContent === '你好，');
  assert.equal(await page.locator('#chat-send').isDisabled(), true, 'stream is visible before completion');
  assert.deepEqual(await page.evaluate(() => window.__spoken), [], 'partial reply is not read');
  await finished(); assert.match(await page.locator('#chat').textContent(), /你好，我在这里陪你/);
  assert.deepEqual(await page.evaluate(() => window.__spoken), ['你好，我在这里陪你。'], 'ordinary model reply is read even with pet speech off');
  await page.click('#chat-voice-stop');
  assert.ok(await page.evaluate(() => window.__stops >= 2));
  await page.uncheck('#chat-voice');
  await send('我叫什么'); await finished();
  assert.equal(await page.evaluate(() => window.__spoken.length), 1, 'muting automatic chat speech suppresses new replies');
  await page.locator('#chat .bot').last().getByRole('button', { name: '朗读回复' }).click();
  assert.equal(await page.evaluate(() => window.__spoken.at(-1)), '你叫小林，我记得。');
  assert.equal(await page.evaluate(() => localStorage.getItem('nd-chat-voice')), '0');
  await page.check('#chat-voice');
  assert.ok(requests[1].messages.some((m) => m.role === 'user' && m.content === '我叫小林'));
  await send('放点雨声'); await finished();
  assert.equal(await page.evaluate(() => window.__musicPlayed), undefined, 'model cannot execute actions on its own');
  await page.locator('#chat').getByRole('button', { name: '播放雨声' }).click();
  assert.equal(await page.evaluate(() => window.__musicPlayed), 'rain');
  await send('测试出错'); await finished();
  assert.match(await page.locator('#chat .chat-error').last().textContent(), /密钥/);
  await page.getByRole('button', { name: '重试这条' }).click(); await finished();
  assert.match(await page.locator('#chat-via').textContent(), /DeepSeek/);
  await send('慢慢说'); await page.locator('#chat-stop').waitFor(); await page.click('#chat-stop'); await finished();
  assert.match(await page.locator('#chat .bot').last().textContent(), /已停止/);
  assert.equal(service.status().history.some((m) => m.content === '慢慢说'), false);
  let synthetic = { at: clock, running: true, state: 'tired', focus: 52, fatigue: 68, face: { present: true } };
  service.observe(synthetic); clock += 21000; synthetic.at = clock; service.observe(synthetic);
  await page.waitForFunction(() => document.querySelector('#log').textContent.includes('AI关心'));
  mkdirSync('artifacts', { recursive: true });
  await page.screenshot({ path: 'artifacts/companion-chat-test.png', fullPage: true });
  await page.click('.nd-side-footer [data-action="settings"]'); await page.locator('label.switch').filter({ has: page.locator('#opt-ai-share') }).click();
  await page.waitForFunction(() => !window.neuro.chat.config.shareStatus);
  assert.equal(await page.locator('#opt-ai-proactive').isDisabled(), true);
  await page.locator('#settings button[aria-label="关闭"]').click();
  await send('再说一句你好'); await finished();
  assert.equal(requests.at(-1).messages[0].content.includes('"fatigue":68'), false);
  await page.setViewportSize({ width: 420, height: 900 });
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
  await page.screenshot({ path: 'artifacts/companion-mobile-test.png', fullPage: true });
  await page.click('#chat-clear'); await page.waitForFunction(() => document.querySelector('#chat').children.length === 0);
  assert.deepEqual(service.status().history, []); assert.deepEqual(errors, []);
  console.log('Companion UI passed: streamed text, context, action approval, retry, cancellation, proactive message, privacy toggle, clear history, mobile layout. Synthetic model only.');
} finally { service.cancel(); await browser.close(); server.httpServer.closeAllConnections(); await new Promise((resolve) => server.httpServer.close(resolve)); }
