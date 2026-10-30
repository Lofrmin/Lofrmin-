import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { Light } from '../src/desk/light.js';
const { createBrightnessController } = createRequire(import.meta.url)('../desktop/screen-brightness.cjs');
const wait = (ms = 180) => new Promise((resolve) => setTimeout(resolve, ms));
const light = () => new Light({ style: { setProperty() {} } });

test('native controller reports unavailable hardware and permission failures honestly', async () => {
  assert.equal((await createBrightnessController({ platform: 'linux' }).read()).supported, false);
  assert.equal((await createBrightnessController({ run: async () => 'null' }).read()).supported, false);
  const controller = createBrightnessController({ run: async () => { throw new Error('Access denied'); } });
  assert.match((await controller.read()).message, /拒绝访问/);
  assert.equal((await controller.set(60)).ok, false);
});

test('native controller validates input, serializes writes and reports readback', async () => {
  let active = 0, maximum = 0, calls = 0;
  const controller = createBrightnessController({ run: async () => {
    calls++; maximum = Math.max(maximum, ++active);
    await wait(5); active--;
    return '{"brightness":65}';
  } });
  for (const value of [-1, 101, 1.5, '50', NaN, '50; exit']) await assert.rejects(controller.set(value));
  assert.equal(calls, 0);
  assert.deepEqual(await controller.read(), { supported: true, brightness: 65 });
  assert.deepEqual(await Promise.all([controller.set(64), controller.set(66)]), [
    { ok: true, brightness: 65 }, { ok: true, brightness: 65 },
  ]);
  assert.equal(maximum, 1);
});

test('slider coalesces changes and disabling sync cancels pending writes', async () => {
  const writes = [];
  globalThis.window = { neuroDesktop: { setScreenBrightness: async (value) => { writes.push(value); return { ok: true, brightness: value }; } } };
  const l = light();
  l.setSyncScreen(true, { apply: false });
  await wait(); assert.deepEqual(writes, [], 'initial synchronization must not change the screen');
  l.set({ level: 70 }, { publish: false });
  l.set({ level: 55 }, { publish: false });
  await wait(); await l.screenQueue;
  assert.deepEqual(writes, [55]);
  l.set({ kelvin: 3000 }, { publish: false });
  await wait(); assert.deepEqual(writes, [55], 'color temperature alone must not write brightness');
  l.set({ level: 45 }, { publish: false });
  l.setSyncScreen(false);
  await wait(); assert.deepEqual(writes, [55]);
});

test('stale writes cannot replace the latest slider value; errors remain visible', async () => {
  let finish;
  const writes = [], states = [];
  globalThis.window = { neuroDesktop: { setScreenBrightness: (value) => {
    writes.push(value);
    return writes.length === 1 ? new Promise((resolve) => { finish = resolve; }) : Promise.resolve({ ok: false, message: 'test failure' });
  } } };
  const l = light(); l.onScreenChange((state) => states.push(state));
  l.setSyncScreen(true, { apply: false });
  l.set({ level: 70 }, { publish: false }); await wait();
  l.set({ level: 40 }, { publish: false }); await wait();
  finish({ ok: true, brightness: 70 }); await l.screenQueue;
  assert.equal(l.level, 40);
  assert.deepEqual(writes, [70, 40]);
  assert.deepEqual(states.at(-1), { state: 'error', message: 'test failure' });
});
