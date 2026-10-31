import test from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const { createCompanion, summarize, readStream, actionsFrom } = createRequire(import.meta.url)('../desktop/companion.cjs');
const encoder = new TextEncoder();
const event = (choice) => `data: ${JSON.stringify({ choices: [choice] })}\n\n`;
const completion = (reply = '我在这里陪你。') => event({ delta: { content: reply } }) + event({ delta: {}, finish_reason: 'stop' }) + 'data: [DONE]\n\n';
function response(text = completion()) { return new Response(text, { headers: { 'content-type': 'text/event-stream' } }); }
const tick = () => new Promise((resolve) => setImmediate(resolve));
async function idle(service) { for (let i = 0; i < 100 && service.status().busy; i++) await tick(); assert.equal(service.status().busy, false); }
const snapshot = (at = 1000) => ({ at, running: true, state: 'tired', focus: 52, fatigue: 68, face: { present: true, blinkPerMin: 20, perclos: 0.15, yawns5min: 2, landmarks: ['PRIVATE_FRAME'], image: 'PRIVATE_IMAGE' }, error: 'PRIVATE_ERROR' });

test('monitor summary whitelists numeric data and preserves missing/calibrating/stale values', () => {
  const summary = summarize(snapshot(), 1000);
  assert.equal(summary.focus, 52); assert.equal(summary.fatigue, 68);
  assert.equal(JSON.stringify(summary).includes('PRIVATE'), false);
  assert.equal(summarize({ ...snapshot(), calibrating: true }, 1000).fatigue, null);
  assert.equal(summarize({ ...snapshot(), face: { present: false } }, 1000).focus, null);
  assert.equal(summarize(snapshot(), 12000).running, false);
  assert.equal(summarize(null).state, null);
});

test('stream parser survives split Unicode, ignores reasoning, and validates suggested tools', async () => {
  const source = ': keepalive\n\n' + event({ delta: { reasoning_content: 'PRIVATE_REASONING' } })
    + event({ delta: { content: '今天慢慢来。', tool_calls: [{ index: 0, function: { name: 'set_light', arguments: '{"kelvin":' } }] } })
    + event({ delta: { tool_calls: [{ index: 0, function: { arguments: '4000,"level":70}' } }] } })
    + event({ delta: {}, finish_reason: 'tool_calls' }) + 'data: [DONE]\n\n';
  const bytes = encoder.encode(source), seen = [];
  const body = new ReadableStream({ start(controller) { for (let i = 0; i < bytes.length; i += 3) controller.enqueue(bytes.slice(i, i + 3)); controller.close(); } });
  const result = await readStream(body, (text) => seen.push(text));
  assert.equal(result.reply, '今天慢慢来。'); assert.equal(seen.join('').includes('PRIVATE_REASONING'), false);
  assert.deepEqual(result.actions, [{ type: 'light', kelvin: 4000, level: 70 }]);
  assert.deepEqual(actionsFrom([{ name: 'createOrder', arguments: '{}' }, { name: 'set_light', arguments: '{"kelvin":1,"level":0}' }, { name: 'play_music', arguments: '{"track":"execute"}' }]), []);
  await assert.rejects(readStream(response(event({ delta: { content: '半句话' } })).body, () => {}), /连接中断/);
});

test('native conversation owns history, shares only opted-in context and never executes actions', async () => {
  const requests = [], events = [], speeches = [];
  const service = createCompanion({ apiKey: 'synthetic-secret', shareStatus: false, getSnapshot: () => snapshot(), now: () => 1000,
    fetchImpl: async (url, init) => { assert.equal(url, 'https://api.deepseek.com/chat/completions'); requests.push(JSON.parse(init.body)); return response(); },
    onEvent: (e) => events.push(e), onSpeech: (e) => speeches.push(e),
  });
  await service.start({ requestId: 'chat-test-0001', text: '我叫小林', name: '团子', history: [{ role: 'system', content: 'INJECTED_SYSTEM' }] }); await idle(service);
  assert.equal(requests[0].model, 'deepseek-flash'); assert.equal(requests[0].thinking.type, 'disabled');
  assert.equal(JSON.stringify(requests[0]).includes('"fatigue":68'), false);
  assert.equal(JSON.stringify(requests[0]).includes('INJECTED_SYSTEM'), false);
  service.configure({ shareStatus: true });
  await service.start({ requestId: 'chat-test-0002', text: '我现在怎么样' }); await idle(service);
  assert.equal(requests[1].messages[1].content, '我叫小林');
  assert.ok(requests[1].messages[0].content.includes('"fatigue":68'));
  assert.equal(JSON.stringify(requests[1]).includes('PRIVATE'), false);
  assert.equal(events.filter((e) => e.type === 'done').length, 2); assert.equal(speeches.length, 2);
  assert.equal(JSON.stringify(service.status()).includes('synthetic-secret'), false);
  service.setMode('demo');
  await service.start({ requestId: 'chat-test-0003', text: '这是演示吗' }); await idle(service);
  assert.ok(requests[2].messages[0].content.includes('当前为演示模式'));
  assert.equal(JSON.stringify(requests[2]).includes('"fatigue":68'), false);
  service.clear(); assert.deepEqual(service.status().history, []);
});

test('model errors are retryable, cancellation stops generation and incomplete replies never enter history', async () => {
  let count = 0; const events = [];
  const service = createCompanion({ apiKey: 'synthetic', onEvent: (e) => events.push(e), fetchImpl: async (_url, { signal }) => {
    count++;
    if (count === 1) return new Response('', { status: 401 });
    if (count === 2) return response();
    return new Promise((_resolve, reject) => signal.addEventListener('abort', () => reject(new Error('aborted')), { once: true }));
  } });
  await service.start({ requestId: 'chat-error-001', text: '你好' }); await idle(service);
  assert.equal(events.at(-1).type, 'error'); assert.match(events.at(-1).message, /密钥/);
  await service.start({ requestId: 'chat-error-002', text: '重试' }); await idle(service); assert.equal(events.at(-1).type, 'done');
  await service.start({ requestId: 'chat-error-003', text: '停止测试' });
  await assert.rejects(service.start({ text: '并发请求' }), /正在回复/);
  service.cancel('chat-error-003'); await idle(service); assert.equal(events.at(-1).type, 'cancelled');
  assert.equal(service.status().history.length, 2);
});

test('proactive companion requires sustained valid readings, respects cooldown, and skips demos', async () => {
  let clock = 1000, latest = snapshot(clock), calls = 0; const events = [];
  const service = createCompanion({ apiKey: 'synthetic', shareStatus: true, proactive: true, now: () => clock, getSnapshot: () => latest,
    onEvent: (e) => events.push(e), fetchImpl: async (_url, init) => { calls++; assert.equal(JSON.parse(init.body).tools, undefined); return response('起身活动一会儿吧，我在这儿等你。'); },
  });
  const observe = (seconds, patch = {}) => { clock += seconds * 1000; latest = { ...snapshot(clock), ...patch }; service.observe(latest); };
  observe(0); observe(19); assert.equal(calls, 0);
  observe(2); await idle(service); assert.equal(calls, 1); assert.equal(events.at(-1).kind, 'proactive');
  observe(60); await idle(service); assert.equal(calls, 1);
  observe(900); await idle(service); assert.equal(calls, 2);
  service.setMode('demo'); observe(1000); observe(30); assert.equal(calls, 2);
  service.setMode('sense'); service.configure({ shareStatus: false }); observe(1000); observe(30); assert.equal(calls, 2);
  service.configure({ shareStatus: true }); observe(1000, { calibrating: true }); observe(30, { calibrating: true }); assert.equal(calls, 2);
});

test('recovered sensor state cancels an outdated proactive response', async () => {
  let clock = 1000, latest = snapshot(clock); const events = [], speeches = [];
  const service = createCompanion({ apiKey: 'synthetic', shareStatus: true, proactive: true, now: () => clock, getSnapshot: () => latest,
    onEvent: (e) => events.push(e), onSpeech: (e) => speeches.push(e),
    fetchImpl: async (_url, { signal }) => new Promise((_resolve, reject) => signal.addEventListener('abort', () => reject(new Error('aborted')), { once: true })),
  });
  service.observe(latest); clock += 21000; latest = snapshot(clock); service.observe(latest);
  assert.equal(service.status().busy, true);
  clock += 1000; latest = { ...snapshot(clock), state: 'normal' }; service.observe(latest);
  await idle(service); assert.equal(events.at(-1).type, 'cancelled'); assert.equal(speeches.length, 0);
});
